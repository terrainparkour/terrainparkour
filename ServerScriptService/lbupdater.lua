--!strict
--eval 9.25.22

--any backend that notices something happening that is part of the leaderboard should import this
--list of events and call the appropriate one, with the appropriate luau typed data on it,
--so that all users currently connected to that instance will get the LB update.

local tt = require(game.ReplicatedStorage.types.gametypes)
local mt = require(game.ServerScriptService.EphemeralMarathons.ephemeralMarathonTypes)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local module = {}

local leaderboardUpdateEvent: RemoteEvent = ReplicatedStorage:WaitForChild("RemoteEvents")
	:WaitForChild("LeaderboardUpdateEvent")

module.updateLeaderboardForRun = function(player: Player, data: tt.lbUpdateFromRun)
	spawn(function()
		leaderboardUpdateEvent:FireClient(player, data)
	end)
end

--ie tell player p about (their or another user's) find, with details within "data."
module.updateLeaderboardForFind = function(player: Player, data: tt.signFindOptions)
	spawn(function()
		leaderboardUpdateEvent:FireClient(player, data)
	end)
end

module.updateLeaderboardForEphemeralMarathon = function(player: Player, data: mt.lbUpdateFromEphemeralMarathonRun)
	spawn(function()
		leaderboardUpdateEvent:FireClient(player, data)
	end)
end

module.updateLeaderboardForMarathon = function(player: Player, data: tt.pyUserFinishedRunResponse)
	spawn(function()
		leaderboardUpdateEvent:FireClient(player, data)
	end)
end

module.sendLeaveInfoToSomeone = function(player: Player, userId: number)
	spawn(function()
		local data: tt.leaveOptions = { userId = userId, kind = "leave" }
		leaderboardUpdateEvent:FireClient(player, data)
	end)
end

module.sendUpdateToPlayer = function(player: Player, data: tt.afterData_getStatsByUser)
	spawn(function()
		leaderboardUpdateEvent:FireClient(player, data)
	end)
end

module.updateLeaderboardBadgeStats = function(player: Player, data: tt.badgeUpdate)
	spawn(function()
		leaderboardUpdateEvent:FireClient(player, data)
	end)
end

module.updateLeaderboardForServerEventCompletionRun = function(player: Player, data: tt.lbUpdateFromRun)
	spawn(function()
		leaderboardUpdateEvent:FireClient(player, data)
	end)
end

return module
