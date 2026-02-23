return {
  name = "soap-action-router",
  fields = {
    { config = {
        type = "record",
        fields = {
          { path_to_watch = { type = "string", required = true, default = "/soap"}, },
          { header_name_action = { type = "string", required = true, default = "x-soap-action"}, },
          { body_nodes_to_extract = { type = "array", required = false, default = {"Verb", "Noun"}, elements = { type = "string" }, }, },
          { header_names_for_nodes = { type = "array", required = false, default = {"x-soap-verb", "x-soap-noun"}, elements = { type = "string" }, }, },
          { deny_if_no_action = { type = "boolean", required = false, default = true }, },
          { clean_headers_before_upstream = { type = "boolean", required = false, default = false }, },
          { content_to_scan = { type = "array", required = true, default = {"application/xml"}, elements = { type = "string"}, }, },
        },
      },
    },
  },
  entity_checks = {
    -- Add any checks here if needed
  },
}
