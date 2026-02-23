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
    local path = kong.request.get_path()
    if path:sub(1, #config.path_to_watch) ~= config.path_to_watch then
	 kong.log.debug("Not the path to be listened at")
	 return
    end

    if kong.request.get_header("content-type") ~= config.content_to_scan then
	 --kong.log.debug("Not watched content type")
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

    local action
    local key
    local _
    if soap_data and soap_data["soapenv:Envelope"] and soap_data["soapenv:Envelope"]["soapenv:Body"] then
        local body_node = soap_data["soapenv:Envelope"]["soapenv:Body"]
        for key, _ in pairs(body_node) do
            -- key is the operation name, like ns:create
            action = key:match(":(%w+)$") or key
            kong.log.info("SOAP action " .. action .. " will be added to header " .. config.header_name_action)
            break
        end

        if not action then
            kong.log.err("Action not found in SOAP body")
            return
        end

        -- Try to get configured body nodes (e.g., Verb/Noun) from the parsed XML under the same operation node
        if key and body_node[key] then
            local op_node = body_node[key]

            -- If there are multiple operation nodes, take the first
            if type(op_node) == "table" and op_node[1] and type(op_node[1]) == "table" then
                op_node = op_node[1]
            end

            if type(op_node) == "table" then
                local nodes = config.body_nodes_to_extract or {}
                local headers = config.header_names_for_nodes or {}

                for idx, node_name in ipairs(nodes) do
                    local header_name = headers[idx]
                    if header_name then
                        local value = find_node_value(op_node, node_name)
                        if type(value) == "string" and value ~= "" then
                            kong.log.info("SOAP node " .. node_name .. " value " .. value .. " will be added to header " .. header_name)
                            kong.service.request.set_header(header_name, value)
                        end
                    end
                end
            end
        end

        -- Set the action header
        kong.service.request.set_header(config.header_name_action, action)
    end
end

return soapactionrouter

