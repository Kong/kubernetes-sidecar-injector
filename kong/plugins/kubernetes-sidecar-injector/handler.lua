local BasePlugin = require "kong.plugins.base_plugin"

local K8SHandler = BasePlugin:extend()

K8SHandler.VERSION = "scm"

return K8SHandler
