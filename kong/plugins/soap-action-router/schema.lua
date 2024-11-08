return {
  name = "soap-action-router",
  fields = {
    { config = {
        type = "record",
        fields = {
		{ path_to_watch = { type = "string", required = true, default = "/soap"}, },
                { header_name = { type = "string",required = true,  default = "x-soap-action"}, },
		{ content_to_scan = { type = "array", required = true, default = {"application/xml"}, elements = { type = "string"}, }, },
        },
      },
    },
  },
  entity_checks = {
    -- Add any checks here if needed
  },
}
