-- Loads a plugin config from the datastore.
-- @return plugin config table or an empty sentinel table in case of a db-miss
local function load_plugin_into_memory(key)
  local row, err = kong.db.plugins:select_by_cache_key(key)
  if err then
    return nil, tostring(err)
  end

  return row
end


--- Get the configuration for a plugin entry in the DB.
-- Given a Route, Service, Consumer and a plugin name, retrieve the plugin's
-- configuration if it exists. Results are cached in ngx.dict
-- @param[type=string] route_id ID of the route being proxied.
-- @param[type=string] service_id ID of the service being proxied.
-- @param[type=string] consumer_id ID of the Consumer making the request (if any).
-- @param[type=stirng] plugin_name Name of the plugin being tested for.
-- @treturn table Plugin retrieved from the cache or database.
local function get_plugin_configuration(plugin_name,
                                        route_id,
                                        service_id,
                                        consumer_id)
  local key = kong.db.plugins:cache_key(plugin_name,
                                        route_id,
                                        service_id,
                                        consumer_id)

  local plugin, err = kong.cache:get(key, nil, load_plugin_into_memory, key)
  if err then
    ngx.log(ngx.ERR, tostring(err))
    return ngx.exit(ngx.ERROR)
  end

  if not plugin or not plugin.enabled then
    return nil
  end

  return plugin.config or {}
end

return {
  get_plugin_configuration = get_plugin_configuration,
}
