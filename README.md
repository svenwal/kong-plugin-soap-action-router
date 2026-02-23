# Kong Plugin: SOAP Action Router

A Kong plugin to extract information from an XML SOAP POST request body and add it as headers before route definition (the plugin is intended to be applied globally).

The plugin:
- Inspects incoming `POST` requests whose **path starts with** a configured prefix  
- Parses the SOAP XML body  
- Derives an **action** from the first operation element in the SOAP Body  
- Optionally extracts additional fields (for example `Verb` and `Noun`) from anywhere in the parsed SOAP message  
- Injects all extracted values into configurable headers for downstream routing or processing

---

## Overview

SOAP (Simple Object Access Protocol) requests often do not include a reliable HTTP `SOAPAction` header that downstream systems can use for routing.  
The **soap-action-router** plugin parses the incoming SOAP XML and derives:

- an **action** from the first operation element in the SOAP Body
- zero or more **additional values** from named XML elements (e.g. `Verb`, `Noun`)

These values are written to headers so that:
- Routing can be based on SOAP operation names and/or other fields  
- Logging and analytics can use extracted SOAP metadata  
- Protocol bridging scenarios can expose SOAP details to REST/JSON consumers

---

## Configuration Parameters

All parameters live under the plugin `config` section.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `path_to_watch` | `string` | `"/soap"` | Path prefix to inspect. Only requests whose path **starts with** this prefix are processed. |
| `header_name_action` | `string` | `"x-soap-action"` | Header name that will receive the extracted SOAP action. |
| `body_nodes_to_extract` | `array[string]` | `["Verb", "Noun"]` | List of XML element names to search for anywhere inside the parsed SOAP message. The first occurrence of each element is used. |
| `header_names_for_nodes` | `array[string]` | `["x-soap-verb", "x-soap-noun"]` | Header names to use for each entry in `body_nodes_to_extract` (matched by index). If a header name at an index is missing, that element is ignored. |
| `deny_if_no_action` | `boolean` | `true` | When `true`, if no SOAP action can be found the plugin logs an error and stops processing. When `false`, the request continues without setting the action header. |
| `clean_header_before_upstrem` | `boolean` | `false` | When `true`, the plugin clears all headers it created (`header_name_action` and all `header_names_for_nodes`) in the `access` phase before the request is sent upstream. |
| `content_to_scan` | `array[string]` | `["application/xml"]` | List of `Content-Type` values to be treated as SOAP XML. Only requests whose `Content-Type` matches one of these entries are parsed. |

---

## Example Configurations

### 1. Basic: Extract Only SOAP Action

Enable the plugin globally and extract just the SOAP action into `x-soap-action`:

```yaml
plugins:
  - name: soap-action-router
    config:
      path_to_watch: "/soap"
      header_name_action: "x-soap-action"
      body_nodes_to_extract: []
      header_names_for_nodes: []
      deny_if_no_action: true
      content_to_scan:
        - "application/xml"
```

For a request with body:

```xml
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
  <soapenv:Body>
    <ns1:GetUser xmlns:ns1="http://example.org/wsdl"/>
  </soapenv:Body>
</soapenv:Envelope>
```

The upstream request will contain:

```http
X-Soap-Action: GetUser
```

---

### 2. Default: Extract Action + Verb/Noun

Using the defaults, the plugin will also extract `Verb` and `Noun` from anywhere inside the parsed SOAP tree and put them into `x-soap-verb` and `x-soap-noun`:

```yaml
plugins:
  - name: soap-action-router
    config:
      path_to_watch: "/soap-router"
      header_name_action: "x-soap-action"
      # Defaults shown explicitly here for clarity
      body_nodes_to_extract:
        - "Verb"
        - "Noun"
      header_names_for_nodes:
        - "x-soap-verb"
        - "x-soap-noun"
      deny_if_no_action: true
      content_to_scan:
        - "application/xml"
```

Given a payload like:

```xml
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
                  xmlns:mes="http://iec.ch/TC57/2011/schema/message">
  <soapenv:Body>
    <mes:RequestMessage>
      <Header>
        <Verb>create</Verb>
        <Noun>GetAuthorizationCodes</Noun>
      </Header>
      <Payload>
        <!-- ... -->
      </Payload>
    </mes:RequestMessage>
  </soapenv:Body>
</soapenv:Envelope>
```

The upstream request will contain headers similar to:

```http
X-Soap-Action: RequestMessage
X-Soap-Verb: create
X-Soap-Noun: GetAuthorizationCodes
```

---

### 3. Custom Nodes and Headers

You can extract any other XML elements into arbitrary headers.  
For example, to extract `Revision` and `MessageID`:

```yaml
plugins:
  - name: soap-action-router
    config:
      path_to_watch: "/soap"
      header_name_action: "x-soap-action"
      body_nodes_to_extract:
        - "Revision"
        - "MessageID"
      header_names_for_nodes:
        - "x-soap-revision"
        - "x-soap-message-id"
      deny_if_no_action: true
      content_to_scan:
        - "application/xml"
```

The plugin will search the parsed SOAP tree for the first `Revision` and `MessageID` elements and set them on the configured headers.

---

### 4. Allow Requests Without an Action

If your SOAP messages sometimes lack a clear operation element and you still want the request to pass through, you can disable the strict behavior:

```yaml
plugins:
  - name: soap-action-router
    config:
      path_to_watch: "/soap"
      header_name_action: "x-soap-action"
      deny_if_no_action: false
      body_nodes_to_extract:
        - "Verb"
      header_names_for_nodes:
        - "x-soap-verb"
      content_to_scan:
        - "application/xml"
```

In this mode:
- If an action is found, `x-soap-action` is set as usual.  
- If no action is found, the plugin logs an error but does **not** stop processing; any configured node headers that can be found are still set, and the request continues to the upstream.

---

### 5. Clean Headers Before Upstream

If you only want to use the extracted headers for internal Kong routing or logging, and **do not** want them to be visible to the upstream service, enable header cleanup:

```yaml
plugins:
  - name: soap-action-router
    config:
      path_to_watch: "/soap"
      header_name_action: "x-soap-action"
      body_nodes_to_extract:
        - "Verb"
        - "Noun"
      header_names_for_nodes:
        - "x-soap-verb"
        - "x-soap-noun"
      clean_header_before_upstrem: true
      content_to_scan:
        - "application/xml"
```

With `clean_header_before_upstrem: true`:
- Headers are still created in the `rewrite` phase so other plugins (and routing) can use them.  
- In the `access` phase, the plugin removes `header_name_action` and all headers listed in `header_names_for_nodes` before the request is forwarded upstream.

---

## Behavior Notes

- The plugin only inspects **POST** requests.  
- The request path must **start with** `config.path_to_watch` for the plugin to run.  
- The request `Content-Type` is matched against all values in `content_to_scan`; if none match, the body is not parsed.  
- The SOAP action is derived from the first operation element found under `soapenv:Body`.  
- Additional node values are looked up by name in the parsed SOAP tree (using a recursive search) and written to the headers configured in `header_names_for_nodes`.  
- Headers are set using `kong.service.request.set_header`, so they are visible to later plugins and, unless `clean_header_before_upstrem` is `true`, to the upstream service.

---

## How It Works (Internals)

1. The plugin hooks into the `rewrite` phase.  
2. It checks HTTP method, path prefix, and `Content-Type`.  
3. It reads the raw request body and parses the XML using `xml2lua` with the `xmlhandler.tree` handler.  
4. It traverses the parsed SOAP Envelope/Body to find the first operation and derive the action name.  
5. It optionally recursively searches the parsed tree for any elements listed in `body_nodes_to_extract` and maps them to headers via `header_names_for_nodes`.  
6. Depending on `deny_if_no_action`, the plugin either stops processing when no action is found or lets the request pass through without an action header.

---

## Dependencies

This plugin uses:
- `xml2lua` – to parse SOAP XML to a Lua table  
- `xmlhandler.tree` – as the XML handler implementation  

Both are part of the default Kong Enterprise image.