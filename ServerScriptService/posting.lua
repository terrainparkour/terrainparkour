--!strict

local module = {}

local HttpService = game:GetService("HttpService")
local tt = require(game.ReplicatedStorage.types.gametypes)

local config = require(game.ReplicatedStorage.config)

local host
local s, c = pcall(function()
	host = require(game.ServerScriptService.hostSecret)
end)
if not s then
	error("no host secret")
end

local postUrl = "http://" .. host.HOST .. "terrain/postEndpoint/"

-------------- ADJUST HOW MANY REQUESTS WE CAN DO ------------------------

module.MakePostRequest = function(request: tt.postRequest): any
	host.addSecretTbl(request)
	local post = HttpService:JSONEncode(request)
	if not request.remoteActionName then
		error("no remoteActionName")
	end
	if not request.data then
		error("no data")
	end

	local url = postUrl

	local res
	local s, theError = pcall(function()
		res = HttpService:PostAsync(url, post, Enum.HttpContentType.ApplicationUrlEncoded)
	end)

	if not s then
		error(theError)
	end

	local ret
	local s2, err2: string = pcall(function()
		ret = HttpService:JSONDecode(res)
	end)
	if not s2 then
		error(err2)
	end

	return ret
end

return module
