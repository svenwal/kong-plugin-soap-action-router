# Kong Plugin: SOAP Action Router

A Kong plugin to extract the SOAP Action from an XML SOAP POST request body and add it as a header before route definition (needs to be applied globally).

This plugin inspects incoming `POST` requests at a specified **path**, parses the SOAP XML, extracts the first operation name from the SOAP Body, and injects it into a header for downstream routing or processing.

---

## Overview

SOAP (Simple Object Access Protocol) requests often do not include a reliable HTTP `SOAPAction` header that downstream systems can use for routing.  
The **soap-action-router** plugin parses the incoming SOAP XML and derives an action name from the first operation element in the SOAP Body, then sets it as a request header.

This enables:
- Routing based on SOAP operation names  
- Logging and analytics based on SOAP actions  
- Protocol bridging scenarios where SOAP action needs to be exposed to REST/JSON consumers

---

## Configuration Parameters

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `path_to_watch` | `string` | `"/soap"` | The path on which SOAP requests should be inspected. It is used to limit down the used CPU as it needs to be enabled globally |
| `header_name` | `string` | `"x-soap-action"` | The name of the header to set with the extracted SOAP action. |
| `content_to_scan` | `array[string]` | `["application/xml"]` | List of content-type values to consider as SOAP XML. |

---

## Example Configurations

### Basic Setup

Enable the plugin on a service expecting SOAP POST requests to `/soap`:

```yaml
plugins:
  - name: soap-action-router
    config:
      path_to_watch: "/soap"
      header_name: "x-soap-action"
      content_to_scan:
        - "application/xml"
```

When a POST request with SOAP XML is sent to `/soap`, the plugin will parse the SOAP body and add the extracted action as a header.

---

## Behavior Notes

- The plugin only inspects **POST** requests (because of SOAPs nature).  
- Only requests matching `config.path_to_watch` are processed.  
- The request `Content-Type` is checked against the list in `content_to_scan`; if it doesn’t match, the plugin does not parse the body.  
- The first operation in the SOAP Body is used as the action.  
- The extracted action is set using `kong.service.request.set_header`, allowing subsequent route matching, plugins or upstream services to receive it.

---

## How It Works

1. The plugin hooks into the `rewrite` phase of the request.  
2. If the HTTP method is `POST` and the request path equals `path_to_watch`, it proceeds.  
3. The plugin reads the raw request body and parses the XML.  
4. It traverses the SOAP Envelope/Body and extracts the operation name.  
5. The plugin sets the configured header with the SOAP action.

---

## Example In Action

#### Incoming SOAP Request

```
POST /soap HTTP/1.1
Host: example.com
Content-Type: application/xml

<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
  <soapenv:Body>
    <ns1:GetUser xmlns:ns1="http://example.org/wsdl"/>
  </soapenv:Body>
</soapenv:Envelope>
```

With the plugin configured:

```yaml
config:
  path_to_watch: "/soap"
  header_name: "x-soap-action"
```

#### Resulting Header Added

```
x-soap-action: GetUser
```

---

## Dependencies

This plugin uses:
- `xml2lua` – to parse SOAP XML to a Lua table
- `xmlhandler.tree` – as the XML handler implementation

Both are part of the default Kong Enterprise image