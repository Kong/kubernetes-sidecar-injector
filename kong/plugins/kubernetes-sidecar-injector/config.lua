local ngx = ngx
local kong = kong
local tostring = tostring


-- Loads a plugin config from the datastore.
-- @return plugin config table or an empty sentinel table in case of a db-miss
local function load_plugin_from_db(key)
  local row, err = kong.db.plugins:select_by_cache_key(key)
  if err then
    return nil, tostring(err)
  end

  return row
end


--- Load the configuration for a plugin entry.
-- Given a Route, Service, Consumer and a plugin name, retrieve the plugin's
-- configuration if it exists. Results are cached in ngx.dict
-- @param[type=string] name Name of the plugin being tested for configuration.
-- @param[type=string] route_id Id of the route being proxied.
-- @param[type=string] service_id Id of the service being proxied.
-- @param[type=string] consumer_id Id of the consumer making the request (if any).
-- @treturn table Plugin configuration, if retrieved.
local function load_configuration(name,
                                  route_id,
                                  service_id,
                                  consumer_id)
  local key = kong.db.plugins:cache_key(name,
                                        route_id,
                                        service_id,
                                        consumer_id)
  local plugin, err = kong.cache:get(key,
                                     nil,
                                     load_plugin_from_db,
                                     key)
  if err then
    ngx.log(ngx.ERR, tostring(err))
    return ngx.exit(ngx.ERROR)
  end

  if not plugin or not plugin.enabled then
    return
  end

  return plugin.config or {}
end


return load_configuration
