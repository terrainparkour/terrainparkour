--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local rdb = require(game.ServerScriptService.rdb)
local remoteDbInternal = require(game.ServerScriptService.remoteDbInternal)
local remotes = require(game.ReplicatedStorage.util.remotes)

local module = {}

local banCache: { [number]: number } = {}
local banDebounce: { [number]: boolean } = {}

local NOBAN = 0
local SOFTBAN = 1
local HARDBAN = 2

module.getBanLevel = function(userId: number): number
	while banDebounce[userId] do
		wait(0.2)
	end

	if banCache[userId] == nil then
		banDebounce[userId] = true
		local res = remoteDbInternal.remoteGet("getUserBanLevel", { userId = userId })
		banCache[userId] = tonumber(res.banLevel)
		banDebounce[userId] = false
	end
	return banCache[userId]
end

local function saveBan(userId: number, banLevel)
	banCache[userId] = banLevel
	remoteDbInternal.remoteGet("setUserBanLevel", { userId = userId, banLevel = banLevel })
end

module.unBanUser = function(userId: number)
	saveBan(userId, NOBAN)
end

module.softBanUser = function(userId: number)
	saveBan(userId, SOFTBAN)
end

module.hardBanUser = function(userId: number)
	saveBan(userId, HARDBAN)
end

module.Init = function()
	local getBanStatusRemoteFunction = remotes.getRemoteFunction("GetBanStatusRemoteFunction")

	getBanStatusRemoteFunction.OnServerInvoke = function(player: Player): any
		local res = module.getBanLevel(player.UserId)
		return res
	end
end

_annotate("end")
return module
