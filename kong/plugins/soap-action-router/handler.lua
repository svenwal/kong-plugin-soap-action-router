local soapactionrouter = {
    PRIORITY = 1010, -- set the plugin priority, which determines plugin execution order
    VERSION = "0.9",
  }
local xml2lua = require("xml2lua")
local xmlhandler = require("xmlhandler.tree")

-- Recursively search a parsed XML node for the first occurrence
-- of a given child element name and return its text value.
local function find_node_value(node, target)
    if type(node) ~= "table" then
        return nil
    end

    -- Direct child match
    if node[target] ~= nil then
        local v = node[target]
        if type(v) == "table" then
            -- xmlhandler.tree may keep text in the first entry
            return v[1]
        end
        return v
    end

    -- Look recursively in children
    for _, child in pairs(node) do
        if type(child) == "table" then
            local v = find_node_value(child, target)
            if v ~= nil then
                return v
            end
        end
    end

    return nil
end

function soapactionrouter:rewrite(config)
    if kong.request.get_method() ~= "POST" then
	 kong.log.debug("No POST request")
	 return
    end
    local path = kong.request.get_path() or ""
    kong.log.debug("soap-action-router: incoming path: " .. path)
    if path:sub(1, #config.path_to_watch) ~= config.path_to_watch then
	 kong.log.debug("soap-action-router: not the path to be listened at, expected prefix " .. config.path_to_watch)
	 return
    end

    local ct = kong.request.get_header("content-type") or ""
    kong.log.debug("soap-action-router: content-type: " .. ct)
    -- config.content_to_scan is an array; check membership
    local watch_ct = false
    if type(config.content_to_scan) == "table" then
        for _, v in ipairs(config.content_to_scan) do
            if v == ct then
                watch_ct = true
                break
            end
        end
    end
    if not watch_ct then
	 kong.log.debug("soap-action-router: not a watched content type")
    end
    -- Read the request body
    local body = kong.request.get_raw_body()
    
    if not body then
	kong.log.notice("No body found so not setting SOAP Action header")
        return
    end

    xmlhandler = xmlhandler:new()
    -- Parse the XML
    --kong.log.debug(body)
    local parser = xml2lua.parser(xmlhandler)
    parser:parse(body)

    if not xmlhandler then
        kong.log.err("Failed to parse SOAP XML")
	kong.response.exit(400, "Bad Request - no XML Content")
    end
    local soap_data = xmlhandler.root
    kong.log.debug("soap-action-router: parsed SOAP root type: " .. type(soap_data))

    local action
    local key
    local _
    if soap_data and soap_data["soapenv:Envelope"] and soap_data["soapenv:Envelope"]["soapenv:Body"] then
        local body_node = soap_data["soapenv:Envelope"]["soapenv:Body"]
        kong.log.debug("soap-action-router: found soapenv:Body, type=" .. type(body_node))
        for key, _ in pairs(body_node) do
            -- key is the operation name, like ns:create
            action = key:match(":(%w+)$") or key
            kong.log.info("SOAP action " .. action .. " will be added to header " .. config.header_name_action)
            break
        end

        if not action then
            kong.log.info("Action not found in SOAP body")
            if config.deny_if_no_action ~= false then
                return
            end
        else
            kong.service.request.set_header(config.header_name_action, action)
        end

        local nodes = config.body_nodes_to_extract or {}
        local headers = config.header_names_for_nodes or {}
        kong.log.debug("soap-action-router: body_nodes_to_extract size=" .. tostring(#nodes) ..
            ", header_names_for_nodes size=" .. tostring(#headers))

        for idx, node_name in ipairs(nodes) do
            local header_name = headers[idx]
            kong.log.debug("soap-action-router: checking node[" .. tostring(idx) .. "]=" .. tostring(node_name) ..
                " -> header=" .. tostring(header_name))
            if header_name then
                local value = find_node_value(soap_data, node_name)
                kong.log.debug("soap-action-router: find_node_value(" .. tostring(node_name) .. ") returned " .. tostring(value))
                if type(value) == "string" and value ~= "" then
                    kong.log.info("SOAP node " .. node_name .. " value " .. value .. " will be added to header " .. header_name)
                    kong.service.request.set_header(header_name, value)
                end
            end
        end
    end
end

return soapactionrouter

