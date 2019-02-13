local BasePlugin = require "kong.plugins.base_plugin"

local Handler = BasePlugin:extend()

Handler.VERSION = "0.1.0"

-- priority doesn't matter, just need to pick something unique for kong tests
Handler.PRIORITY = 1006

return Handler
