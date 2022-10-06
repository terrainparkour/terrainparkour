--!strict
--eval 9.25.22

local config = require(game.ReplicatedStorage.config)

local HttpService = game:GetService("HttpService")
local vscdebug = require(game.ReplicatedStorage.vscdebug)

local module = {}

--configurations
local httpremaining = 10
local httpaddEvery = 1
local httpperMinMax = 480
local httpaddPerTime = math.floor(httpperMinMax / (60 / httpaddEvery))
spawn(function()
	while true do
		httpremaining = math.min(httpperMinMax, httpremaining + httpaddPerTime)
		wait(httpaddEvery)
	end
end)

--infinite retrying, blocking.
module.httpThrottledJsonGet = function(url: string): any
	while true do
		if httpremaining > 0 then
			httpremaining -= 1
			local res

			local success, err: string = pcall(function()
				res = HttpService:GetAsync(url, true, nil)
			end)
			if not success then
				if config.isInStudio() then
					--if you break here, it's likely that httpservice is off. enable in game settings.
					local cleanUrl: string = string.split(url, "?")[1]
					error("Error doing httpGet. " .. err .. "clean url:\n" .. cleanUrl)
				else
					error("Error doing httpGet. " .. err)
				end
			end
			local ret
			local success2, err2: string = pcall(function()
				ret = HttpService:JSONDecode(res)
			end)
			if not success2 then
				error("Error doing decode. " .. err2 .. res)
			end
			return ret
		end
		warn("httpGetwait." .. httpremaining)
		wait(0.05)
	end
end

module.httpThrottledJsonPost = function(url: string, data: any): any
	local post = HttpService:JSONEncode(data)
	post = post .. "&retry=false"
	while true do
		if httpremaining > 0 then
			httpremaining -= 1
			local res
			local s, e = pcall(function()
				res = HttpService:PostAsync(url, post, Enum.HttpContentType.ApplicationUrlEncoded)
			end)
			if not s then
				print("error getting url. retrying.", url, e)
				print(e)

				s, e = pcall(function()
					post = post .. "&retry=true"
					res = HttpService:PostAsync(url, post, Enum.HttpContentType.ApplicationUrlEncoded)
				end)
				error(e)
			end

			return HttpService:JSONDecode(res)
		end
		warn("http.post.wait.")
		wait(0.05)
	end
end

return module
