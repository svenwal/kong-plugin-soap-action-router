local soapactionrouter = {
    PRIORITY = 1010, -- set the plugin priority, which determines plugin execution order
    VERSION = "0.9",
  }
local xml2lua = require("xml2lua")
local xmlhandler = require("xmlhandler.tree")

function soapactionrouter:rewrite(config)
    if kong.request.get_method() ~= "POST" then
	 kong.log.debug("No POST request")
	 return
    end

    if kong.request.get_path() ~= config.path_to_watch then
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
        for key, _ in pairs(soap_data["soapenv:Envelope"]["soapenv:Body"]) do
	    action = key:match(":(%w+)$") or key
	    kong.log.info("SOAP action " .. action .. " will be added to header " .. config.header_name)
            break
        end
    end

    if not action then
        kong.log.err("Action not found in SOAP body")
        return
    end

    -- Set the x-soap-action header with the extracted action
    kong.service.request.set_header(config.header_name, action)
end

return soapactionrouter

