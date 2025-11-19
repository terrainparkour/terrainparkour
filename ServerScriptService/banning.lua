--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local rdb = require(game.ServerScriptService.rdb)
local tt = require(game.ReplicatedStorage.types.gametypes)

local remotes = require(game.ReplicatedStorage.util.remotes)

local module = {}

local banCache: { [number]: number? } = {}
local banDebounce: { [number]: boolean } = {}

local NOBAN = 0
local SOFTBAN = 1
local HARDBAN = 2

module.getBanLevel = function(userId: number): number
	while banDebounce[userId] do
		wait(0.2)
	end

	if banCache[userId] == nil then
		banCache[userId] = NOBAN
		banDebounce[userId] = true
		local request: tt.postRequest = {
			remoteActionName = "getUserBanLevel",
			data = { userId = userId },
		}
		local banLevelNumber: number = NOBAN
		local ok, res = pcall(function()
			return rdb.MakePostRequest(request)
		end)
		if ok and res and typeof(res) == "table" and res.banLevel ~= nil then
			local raw = res.banLevel
			if typeof(raw) == "number" then
				banLevelNumber = raw
			elseif typeof(raw) == "string" then
				local parsed = tonumber(raw)
				if parsed ~= nil then
					banLevelNumber = parsed
				else
					_annotate(string.format("Warn: getUserBanLevel returned non-numeric string for %d", userId))
				end
			else
				_annotate(
					string.format("Warn: getUserBanLevel returned unsupported type (%s) for %d", typeof(raw), userId)
				)
			end
		else
			_annotate(string.format("Warn: getUserBanLevel failed for %d (%s)", userId, tostring(res)))
		end
		banCache[userId] = banLevelNumber
		banDebounce[userId] = false
	end
	return banCache[userId] or NOBAN
end

local function saveBan(userId: number, banLevel)
	banCache[userId] = banLevel
	local request: tt.postRequest = {
		remoteActionName = "setUserBanLevel",
		data = { userId = userId, banLevel = banLevel },
	}
	local res = rdb.MakePostRequest(request)
	return res
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
