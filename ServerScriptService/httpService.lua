--!strict
--eval 9.25.22

local config = require(game.ReplicatedStorage.config)

local HttpService = game:GetService("HttpService")

local module = {}

--configurations
local httpremaining = 10
local httpPerMinMax = 480
local httpaddPerTime = math.floor(httpPerMinMax / 60)
local waitTime = 0.3

spawn(function()
	while true do
		httpremaining = math.min(httpPerMinMax, httpremaining + httpaddPerTime)
		wait(1)
	end
end)
--so, we add 8 new requests per second.

local getRequestSuccessCounter = 0
local getRequestFailCounter = 0
local getWaitCounter = 0

local postSuccessCount = 0
local postFailureCount = 0
local postRetryCount = 0
local postRetrySuccessCount = 0
local postRetryFailureCount = 0
local postDecodeFailCount = 0

local urlCounts = {}

local postWaitCounter = 0

local doHttpMonitoring = false

spawn(function()
	if not doHttpMonitoring then
		return
	end
	print("starting HTTP monitor loop: 5s")
	while true do
		print(string.format("\n\t%0.0f httpremaining=%d", tick(), httpremaining))
		print(
			string.format(
				"GET in last 5s: success=%d fail=%d wait=%d",
				getRequestSuccessCounter,
				getRequestFailCounter,
				getWaitCounter
			)
		)
		getRequestSuccessCounter = 0
		getRequestFailCounter = 0
		getWaitCounter = 0

		print(
			string.format(
				"POST in last 5s: success=%d fail=%d wait=%d retry=%d, retryS=%d retryF=%d, dcode=%d",
				postSuccessCount,
				postFailureCount,
				postWaitCounter,
				postRetryCount,
				postRetrySuccessCount,
				postRetryFailureCount,
				postDecodeFailCount
			)
		)

		for u, c in pairs(urlCounts) do
			print(string.format("counts: %d - %s", c, u))
		end

		postSuccessCount = 0
		postFailureCount = 0
		postRetryCount = 0
		postRetrySuccessCount = 0
		postRetryFailureCount = 0
		postDecodeFailCount = 0
		postWaitCounter = 0

		urlCounts = {}
		wait(5)
	end
end)

--infinite retrying, blocking.
module.httpThrottledJsonGet = function(url: string): any
	while true do
		if httpremaining > 0 then
			httpremaining -= 1
			local res
			local loggingUrl = "GET: " .. string.split(url, "?")[1]
			if not urlCounts[loggingUrl] then
				urlCounts[loggingUrl] = 0
			end
			urlCounts[loggingUrl] += 1

			local success, err: string = pcall(function()
				res = HttpService:GetAsync(url, true, nil)
			end)
			if success then
				getRequestSuccessCounter = getRequestSuccessCounter + 1
			else
				getRequestFailCounter += 1
				if config.isInStudio() then
					--if you break here, it's likely that httpservice is off. enable in game settings.
					local cleanUrl: string = string.split(url, "?")[1]
					print("Error doing httpGet. " .. err .. "clean url:\n" .. cleanUrl)
				else
					local cleanUrl: string = string.split(url, "?")[1]
					print("Error doing httpGet. " .. err .. "clean url:\n" .. cleanUrl)
				end
				wait(waitTime)
				continue
			end
			local ret
			local success2, err2: string = pcall(function()
				ret = HttpService:JSONDecode(res)
			end)
			if not success2 then
				print("Error doing decode. " .. err2 .. res)
				wait(waitTime)
				continue
			end

			return ret
		end
		getWaitCounter = getWaitCounter + 1
		wait(waitTime)
	end
end

module.httpThrottledJsonPost = function(url: string, data: any): any
	local post = HttpService:JSONEncode(data)
	post = post .. "&retry=false"
	while true do
		if httpremaining > 0 then
			httpremaining -= 1
			local loggingUrl = "POST:" .. string.split(url, "?")[1]
			if not urlCounts[loggingUrl] then
				urlCounts[loggingUrl] = 1
			end
			urlCounts[loggingUrl] += 1

			local res
			local success, error = pcall(function()
				res = HttpService:PostAsync(url, post, Enum.HttpContentType.ApplicationUrlEncoded)
			end)
			if success then
				postSuccessCount += 1
			else
				postFailureCount += 1
				print("error getting url. retrying.", url, error)
				print(error)

				--we have to pre-emptively steal an http request...
				httpremaining -= 1
				success, error = pcall(function()
					postRetryCount += 1
					post = post .. "&retry=true"
					res = HttpService:PostAsync(url, post, Enum.HttpContentType.ApplicationUrlEncoded)
				end)
				if success then
					postRetrySuccessCount += 1
				else
					postRetryFailureCount += 1
					wait(waitTime)
					continue
				end
			end
			local ret
			local success2, err2: string = pcall(function()
				ret = HttpService:JSONDecode(res)
			end)
			if not success2 then
				postDecodeFailCount += 1
				print("Error doing decode. " .. err2 .. res)
				wait(waitTime)
				continue
			end

			return ret
		end
		warn("http.post.wait.")
		postWaitCounter += 1
		wait(waitTime)
	end
end

return module
