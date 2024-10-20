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

-- it is very bad if the requstdata or any child has any non-string (?) here. at least, vector3 are very unhappy.
-- so, please check that you convert them first, as does, e.g. sendUserData for movement event datas which have Vector3 positions and lookvectors etc in them.
-- TODO also someone at some point should automatically ora t least sometimes chek that JSONEncode isn't being called on items with vector2s and otehr roblox object in them
-- because they'll just show up null with no warning.
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
