--!strict

--any backend that notices something happening that is part of the leaderboard should import this
--list of events and call the appropriate one, with the appropriate luau typed data on it,
--so that all users currently connected to that instance will get the LB update.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local tt = require(game.ReplicatedStorage.types.gametypes)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local module = {}

local remotes = require(game.ReplicatedStorage.util.remotes)
local LeaderboardUpdateEvent: RemoteEvent = remotes.getRemoteEvent("LeaderboardUpdateEvent")

module.SendUpdateToPlayer = function(player: Player, lbuserStats: tt.lbUserStats)
	assert(type(lbuserStats.userId) == "number", "lbuserStats.userId must be a number")
	task.spawn(function()
		local message: tt.genericLeaderboardUpdateDataType = {
			kind = "lbupdate",
			userId = lbuserStats.userId,
			lbUserStats = lbuserStats,
		}

		LeaderboardUpdateEvent:FireClient(player, message)
	end)
end

module.SendLeaveInfoToSomeone = function(player: Player, userId: number)
	task.spawn(function()
		local data = { userId = userId, data = {}, kind = "leave" }
		LeaderboardUpdateEvent:FireClient(player, data)
	end)
end

_annotate("end")
return module
