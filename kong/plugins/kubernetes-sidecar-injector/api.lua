local cjson = require "cjson"
local Schema = require "kong.db.schema"
local kong_pdk = require "kong.pdk".new({}, 1)
local k8s_typedefs = require "kong.plugins.kubernetes-sidecar-injector.typedefs"
local get_plugin_configuration = require "kong.plugins.kubernetes-sidecar-injector.config".get_plugin_configuration

local tinsert = table.insert
local tostring = tostring
local log_info = kong_pdk.log.info
local encode_base64 = ngx.encode_base64

local function skip_injection(plugin_config, review_request) -- luacheck: ignore 212
  if type(review_request)                 == "table" and
     type(review_request.object)          == "table" and
     type(review_request.object.metadata) == "table" then

    local annotations = review_request.object.metadata.annotations

    if type(annotations) == "table" then
      -- Behave similar to sidecar.istio.io/inject annotation
      if annotations["k8s.konghq.com/sidecar-inject"] == "false" then
        return true
      end
    end
  end

  -- TODO: allow injection to be more configurable

  return false
end


-- Refine schema to what we actually want to accept
local podschema = Schema.new(k8s_typedefs.Pod)

local admissionreviewschema = Schema.new {
  name = "admissionregistration.k8s.io/v1beta1 AdmissionReview",
  fields = {
    { kind = { type = "string", eq = "AdmissionReview", required = true } },
    { apiVersion = { type = "string", eq = "admission.k8s.io/v1beta1", required = true } },
    { request = k8s_typedefs.AdmissionRequest { required = true, custom_validator = function(review_request)
      if review_request.operation ~= "CREATE" then
        return nil, "unsupported operation (this controller only understands the CREATE operation)"
      end

      local group_kind = review_request.kind
      if group_kind.group ~= "" or group_kind.version ~= "v1" or group_kind.kind ~= "Pod" then
        return nil, "unknown resource type (this controller only accepts v1 Pods)"
      end

      local object = podschema:process_auto_fields(review_request.object, "select", false)
      local ok, err = podschema:validate(object)
      if not ok then
        local err_t = kong.db.errors:schema_violation({ object = err })
        return nil, tostring(err_t)
      end

      if type(object.spec) ~= "table" then
        -- workaround for incomplete podspec definition
        return nil, "invalid object.spec field"
      end

      return true
    end } },
  }
}

return {
  ["/kubernetes-sidecar-injector"] = {
    schema = admissionreviewschema,
    methods = {
      POST = function(self)
        local plugin_config = get_plugin_configuration("kubernetes-sidecar-injector")
        -- 404 if plugin not found/enabled
        if not plugin_config then
          return kong.response.exit(404, { message = "Not found" })
        end

        -- TODO: only accept JSON?
        local args = admissionreviewschema:process_auto_fields(self.args.post, "select", false)
        local ok, err = admissionreviewschema:validate(args)
        if not ok then
          return kong.response.exit(422, { message = err })
        end

        local review_request = args.request
        local object = review_request.object

        -- Same log format as istio
        log_info("AdmissionReview for",
          " Kind=", review_request.kind.kind, "/", review_request.kind.version,
          " Namespace=", review_request.namespace,
          " Name=", review_request.name or "", " (", object.metadata.name or "", ")",
          " UID=", review_request.uid,
          " Rfc6902PatchOperation=", review_request.operation,
          -- XXX: even though required=true is set on the userInfo field, it can still be nil
          " UserInfo=", (review_request.userInfo or {}).username or ""
        )

        local reply = {
          kind = "AdmissionReview",
          apiVersion = "admission.k8s.io/v1beta1",
          response = { -- https://github.com/kubernetes/kubernetes/blob/v1.11.0/staging/src/k8s.io/api/admission/v1beta1/types.go#L77
            uid = review_request.uid,
            allowed = true,
            status = nil, -- only required if 'allowed' is false
            patch = nil,
            patchType = nil,
          }
        }

        if skip_injection(plugin_config, review_request) then
          log_info("Skipping ", review_request.namespace, "/", object.metadata.name, " due to policy check")
          return { json = reply }
        end

        -- Patches in RFC 6902 format
        local patches = { nil, nil }

        -- iptables setup container
        patches[1] = {
          op = "add",
          path = "/spec/initContainers/-",
          value = {
            name = "kong-iptables-setup",
            image = plugin_config.initImage,
            imagePullPolicy = plugin_config.initImagePullPolicy,
            args = plugin_config.initArgs,
            securityContext = { capabilities = { add = { "NET_ADMIN" } } },
          },
        }
        if not object.spec.initContainers then
          -- need to add array member instead of adding *to* it.
          patches[1].path = "/spec/initContainers"
          patches[1].value = { patches[1].value }
        end

        -- Add proxy sidecar container
        local config = kong.configuration
        local env = {
          -- disable admin interface in data plane
          { name = "KONG_ADMIN_LISTEN", value = "off" },
          { name = "KONG_PROXY_LISTEN", value =
            string.format("0.0.0.0:%d transparent", plugin_config.http_port) .. "," ..
            string.format("0.0.0.0:%d ssl transparent", plugin_config.https_port)
          },
          { name = "KONG_STREAM_LISTEN", value =
            string.format("0.0.0.0:%d transparent", plugin_config.stream_port)
          },
          { name = "KONG_PROXY_ACCESS_LOG", value = "/dev/stdout" },
          { name = "KONG_PROXY_ERROR_LOG", value = "/dev/stderr" },
          -- need to copy relevant database configuration
          { name = "KONG_DATABASE", value = config.database },
        }
        if config.database == "postgres" then
          tinsert(env, { name = "KONG_PG_HOST",
                         value = config.pg_host })
          tinsert(env, { name = "KONG_PG_PORT",
                         value = string.format("%d", config.pg_port) })
          tinsert(env, { name = "KONG_PG_TIMEOUT",
                         value = string.format("%d", config.pg_timeout) })
          tinsert(env, { name = "KONG_PG_USER",
                         value = config.pg_user })
          if config.pg_password then
            tinsert(env, { name = "KONG_PG_PASSWORD",
                           value = config.pg_password })
          end
          tinsert(env, { name = "KONG_PG_DATABASE",
                         value = config.pg_database })
          if config.pg_schema then
            tinsert(env, { name = "KONG_PG_SCHEMA",
                           value = config.pg_schema })
          end
          tinsert(env, { name = "KONG_PG_SSL",
                         value = config.pg_ssl and "ON" or "OFF" })
          tinsert(env, { name = "KONG_PG_SSL_VERIFY",
                         value = config.pg_ssl_verify and "ON" or "OFF" })
        elseif config.database == "cassandra" then
          tinsert(env, { name = "KONG_CASSANDRA_USERNAME",
                         value = config.cassandra_username })
          tinsert(env, { name = "KONG_CASSANDRA_PORT",
                         value = string.format("%d", config.cassandra_port) })
          tinsert(env, { name = "KONG_CASSANDRA_LB_POLICY",
                         value = config.cassandra_lb_policy })
          tinsert(env, { name = "KONG_CASSANDRA_DATA_CENTERS",
                         value = table.concat(config.cassandra_data_centers, ",") })
          tinsert(env, { name = "KONG_CASSANDRA_SSL",
                         value = config.cassandra_ssl and "ON" or "OFF" })
          tinsert(env, { name = "KONG_CASSANDRA_CONSISTENCY",
                         value = config.cassandra_consistency })
          tinsert(env, { name = "KONG_CASSANDRA_REPL_STRATEGY",
                         value = config.cassandra_repl_strategy })
          tinsert(env, { name = "KONG_CASSANDRA_CONTACT_POINTS",
                         value = table.concat(config.cassandra_contact_points, ",") })
          tinsert(env, { name = "KONG_CASSANDRA_SCHEMA_CONSENSUS_TIMEOUT",
                         value = string.format("%d", config.cassandra_schema_consensus_timeout) })
          tinsert(env, { name = "KONG_CASSANDRA_REPL_FACTOR",
                         value = string.format("%d", config.cassandra_repl_factor) })
          tinsert(env, { name = "KONG_CASSANDRA_TIMEOUT",
                         value = string.format("%d", config.cassandra_timeout) })
          tinsert(env, { name = "KONG_CASSANDRA_SSL_VERIFY",
                         value = config.cassandra_ssl_verify and "ON" or "OFF" })
          tinsert(env, { name = "KONG_CASSANDRA_KEYSPACE",
                         value = config.cassandra_keyspace })
        end

        -- Allow plugin config to add extra env vars
        if plugin_config.extra_env then
          for k, v in pairs(plugin_config.extra_env) do
            tinsert(env, { name = k, value = v })
          end
        end

        patches[2] = {
          op = "add",
          path = "/spec/containers/-",
          value = {
            name = "kong-sidecar",
            image = plugin_config.image,
            imagePullPolicy = plugin_config.imagePullPolicy,
            env = env,
            ports = {
             { name = "http", containerPort = 8000, protocol = "TCP" },
             { name = "https", containerPort = 8443, protocol = "TCP" },
             { name = "tcp", containerPort = 7000, protocol = "TCP" },
            },
          },
        }
        if not object.spec.containers then
          -- need to add array member instead of adding *to* it.
          patches[2].path = "/spec/containers"
          patches[2].value = { patches[2].value }
        end

        reply.response.patchType = "JSONPatch"
        reply.response.patch = encode_base64(cjson.encode(patches))
        return { json = reply }
      end,
    },
  },
}
