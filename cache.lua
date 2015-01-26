	 -- Check required variable "key", which must be trasferred as GET parameter
        local cacheKey = ngx.var.arg_key
        if (cacheKey == nil or cacheKey == '') then
            ngx.say ('{error: "Cache key must be specified"}')
            return
        end

        -- Declare local link to shared Nginx cache
        local cache = ngx.shared.SharedCache

        -- Try load data from shared dictionary
        local cacheValue = cache:get(cacheKey)
        
        if (cacheValue == nil) then

            -- Shared dictionary return "not found", we gotta check Redis Server
            local redis = require "resty.redis"
            local red = redis:new()
            red:set_timeout(1000) -- 1 second

            -- Try connect to Redis Server
            local ok, err = red:connect("127.0.0.1", 6379)
            if not ok then
                ngx.say('{error: "failed to connect: ' .. err .. '"}')
                ngx.log(ngx.ERR, 'Failed to connect to Redis Server ' .. err);
                return
            end

            local res, err = red:get(cacheKey)
            if not res then
               ngx.say("failed to get dog: ", err)
               return
            end

            cacheValue = res

            if cacheValue == ngx.null then
                ngx.say('{error: "Cache data not found"}')
                return
            end

            -- Store cache data from Redis Server to shared cache provided by Nginx
            -- Default lifetime for data on shared Nginx cache - 5 seconds
            cache:set(cacheKey, cacheValue, 5)
            
            ngx.log(ngx.INFO, "Cache from Redis Server stored to shared memory");

            -- Release redis server connection
            red:set_keepalive()
        end

        ngx.say(cacheValue)

