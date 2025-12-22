--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local remotes = require(game.ReplicatedStorage.util.remotes)
local rdb = require(game.ServerScriptService.rdb)
local tt = require(game.ReplicatedStorage.types.gametypes)
local playerData2 = require(game.ServerScriptService.playerData2)
local usernameCache = require(game.ServerScriptService.usernameCache)
local textUtil = require(game.ReplicatedStorage.util.textUtil)
local PopularResponseTypes = require(game.ReplicatedStorage.types.PopularResponseTypes)
local tpUtil: typeof(require(game.ReplicatedStorage.util.tpUtil)) = require(game.ReplicatedStorage.util.tpUtil)

local module = {}

module.GetPopularRaces = function(player: Player, userIds: { number }): { PopularResponseTypes.popularRaceResult }
	local userIdsInServer: { string } = {}
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
	if not signs then
		return pops
	end
	for _, el in ipairs(pops) do
		el.hasFoundStart = playerData2.HasUserFoundSign(player.UserId, el.startSignId)
		--also patch up username
		for _, thing in ipairs(el.userPlaces) do
			thing.username = usernameCache.GetUsernameByUserId(thing.userId)
		end

		local sInstance = signs:FindFirstChild(el.startSignName) :: Instance?
		local eInstance = signs:FindFirstChild(el.endSignName) :: Instance?
		if not sInstance or not sInstance:IsA("Part") or not eInstance or not eInstance:IsA("Part") then
			el.distance = 0
		else
			local s = sInstance :: Part
			local e = eInstance :: Part
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
