--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local remotes = require(game.ReplicatedStorage.util.remotes)
local rdb = require(game.ServerScriptService.rdb)
local remoteDbInternal = require(game.ServerScriptService.remoteDbInternal)
local textUtil = require(game.ReplicatedStorage.util.textUtil)
local PopularResponseTypes = require(game.ReplicatedStorage.types.PopularResponseTypes)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local enums = require(game.ReplicatedStorage.util.enums)

local module = {}

module.GetNew = function(player: Player, userIds: { number }): { PopularResponseTypes.popularRaceResult }
	local userIdsInServer: { number } = { 261, tostring(enums.objects.TerrainParkour), -1, -2 }
	userIdsInServer = {}
	for _, userId in ipairs(userIds) do
		table.insert(userIdsInServer, tostring(userId))
	end
	local joined = textUtil.stringJoin(",", userIdsInServer)
	local pops: { PopularResponseTypes.popularRaceResult } =
		remoteDbInternal.remoteGet("getNew", { userId = player.UserId, otherUserIdsInServer = joined })["res"]

	local signs = game.Workspace:FindFirstChild("Signs")
	for _, el in ipairs(pops) do
		el.hasFoundStart = rdb.hasUserFoundSign(player.UserId, el.startSignId)
		--also patch up username
		for _, thing in ipairs(el.userPlaces) do
			thing.username = rdb.getUsernameByUserId(thing.userId)
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
	local getNewRunsFunction = remotes.getRemoteFunction("GetNewRunsFunction") :: RemoteFunction
	getNewRunsFunction.OnServerInvoke = function(player: Player, userIds: { number }): any
		return module.GetNew(player, userIds)
	end
end

_annotate("end")
return module
