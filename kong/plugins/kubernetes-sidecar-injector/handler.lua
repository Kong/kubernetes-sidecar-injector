local BasePlugin = require "kong.plugins.base_plugin"

local Handler = BasePlugin:extend()

Handler.VERSION = "0.1.1"

-- priority doesn't matter, just need to pick something unique for kong tests
Handler.PRIORITY = 1006

function Handler:new()
  Handler.super.new(self, "kubernetes-sidecar-injector")
end

return Handler
