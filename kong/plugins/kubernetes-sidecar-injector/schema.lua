local typedefs = require "kong.db.schema.typedefs"
local k8s_typedefs = require "kong.plugins.kubernetes-sidecar-injector.typedefs"

return {
  name = "kubernetes-sidecar-injector",
  fields = {
    -- This plugin should only be loaded globally
    { route = typedefs.no_route },
    { service = typedefs.no_service },
    { consumer = typedefs.no_consumer },

    { config = { type = "record", fields = {
        { initImage = { type = "string", default = "istio/proxy_init:1.0.5" } },
        { initImagePullPolicy = k8s_typedefs.ImagePullPolicy { default = "IfNotPresent" } },
        { initArgs = { type = "array", elements = { type = "string" }, default = {
          "-p", "7000",
          "-u", "1337",
          "-m", "TPROXY",
          "-i", "*",
          "-b", "*",
        } } },
        { image = { type = "string", default = "kong" } },
        { imagePullPolicy = k8s_typedefs.ImagePullPolicy { default = "IfNotPresent" } },
        { extra_env = { type = "map",
          keys = { type = "string" },
          values = { type = "string" }
        } },
        { http_port = typedefs.port { default = 8000 } },
        { https_port = typedefs.port { default = 8443 } },
        { stream_port = typedefs.port { default = 7000 } }, -- should match initArgs default
        { namespace_blacklist = { type = "array", elements = { type = "string" },
                                  default = { "kube-system" } } },
    } } },
  },
}
