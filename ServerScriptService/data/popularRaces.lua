--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local remotes = require(game.ReplicatedStorage.util.remotes)
local rdb = require(game.ServerScriptService.rdb)
local tt = require(game.ReplicatedStorage.types.gametypes)
local playerData2 = require(game.ServerScriptService.playerData2)
local textUtil = require(game.ReplicatedStorage.util.textUtil)
local PopularResponseTypes = require(game.ReplicatedStorage.types.PopularResponseTypes)
local enums = require(game.ReplicatedStorage.util.enums)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)

local module = {}

module.GetPopularRaces = function(player: Player, userIds: { number }): { PopularResponseTypes.popularRaceResult }
	local userIdsInServer: { number } = { 261, tostring(enums.objects.TerrainParkourUserId), -1, -2 }
	userIdsInServer = {}
	for _, userId in ipairs(userIds) do
		table.insert(userIdsInServer, tostring(userId))
	end
	local joined = textUtil.stringJoin(",", userIdsInServer)

	local request: tt.postRequest = {
		remoteActionName = "getPopularRaces",
		data = { userId = player.UserId, otherUserIdsInServer = joined },
	}
	local pops: { PopularResponseTypes.popularRaceResult } = rdb.MakePostRequest(request)

	--patch up foundness which is reliably stored inside remotedb..
	local signs = game.Workspace:FindFirstChild("Signs")
	for _, el in ipairs(pops) do
		el.hasFoundStart = playerData2.HasUserFoundSign(player.UserId, el.startSignId)
		--also patch up username
		for _, thing in ipairs(el.userPlaces) do
			thing.username = playerData2.GetUsernameByUserId(thing.userId)
		end

		local s: Part = signs:FindFirstChild(el.startSignName)
		local e: Part = signs:FindFirstChild(el.endSignName)
		if e == nil or s == nil then
			el.distance = 0
		else
			el.distance = tpUtil.getDist(s.Position, e.Position)
		end
	end

	return pops
end

module.Init = function()
	local GetPopularRacesFunction = remotes.getRemoteFunction("GetPopularRacesFunction") :: RemoteFunction
	GetPopularRacesFunction.OnServerInvoke = function(player: Player, userIds: { number }): any
		return module.GetPopularRaces(player, userIds)
	end
end

_annotate("end")
return module
