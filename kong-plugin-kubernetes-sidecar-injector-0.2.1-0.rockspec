package = "kong-plugin-kubernetes-sidecar-injector"
version = "0.2.1-0"

source = {
	url = "https://github.com/kong/kubernetes-sidecar-injector/archive/v0.2.1.zip";
	dir = "kubernetes-sidecar-injector-0.2.1";
}

description = {
	summary = "This plugin allows Kong to inject Kong sidecars into Kubernetes Pods";
	homepage = "https://github.com/kong/kubernetes-sidecar-injector";
	license = "Apache 2.0";
}

dependencies = {
	"lua >= 5.1";
	--"lua-cjson"; -- kong comes with openresty forked lua-cjson
}

build = {
	type = "builtin";
	modules = {
		["kong.plugins.kubernetes-sidecar-injector.api"] = "kong/plugins/kubernetes-sidecar-injector/api.lua";
		["kong.plugins.kubernetes-sidecar-injector.config"] = "kong/plugins/kubernetes-sidecar-injector/config.lua";
		["kong.plugins.kubernetes-sidecar-injector.handler"] = "kong/plugins/kubernetes-sidecar-injector/handler.lua";
		["kong.plugins.kubernetes-sidecar-injector.schema"] = "kong/plugins/kubernetes-sidecar-injector/schema.lua";
		["kong.plugins.kubernetes-sidecar-injector.typedefs"] = "kong/plugins/kubernetes-sidecar-injector/typedefs.lua";
	};
}
