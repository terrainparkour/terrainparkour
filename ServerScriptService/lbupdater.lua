--!strict
--eval 9.25.22

--hook in events from server so that they update lb on client efficiently.

local tt = require(game.ReplicatedStorage.types.gametypes)
local mt = require(game.ServerScriptService.EphemeralMarathons.ephemeralMarathonTypes)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local module = {}

local leaderboardUpdateEvent: RemoteEvent = ReplicatedStorage:WaitForChild("RemoteEvents")
	:WaitForChild("LeaderboardUpdateEvent")

module.updateLeaderboardForRun = function(player: Player, data: tt.lbUpdateFromRun)
	leaderboardUpdateEvent:FireClient(player, data)
end

module.updateLeaderboardForFind = function(player: Player, data: tt.signFindOptions)
	leaderboardUpdateEvent:FireClient(player, data)
end

module.updateLeaderboardForEphemeralMarathon = function(player: Player, data: mt.lbUpdateFromEphemeralMarathonRun)
	leaderboardUpdateEvent:FireClient(player, data)
end

module.updateLeaderboardForMarathon = function(player: Player, data: tt.pyUserFinishedRunResponse)
	leaderboardUpdateEvent:FireClient(player, data)
end

module.updateLeaderboardForLeave = function(player: Player, userId: number)
	local data: tt.leaveOptions = { userId = userId, kind = "leave" }
	leaderboardUpdateEvent:FireClient(player, data)
end

module.updateLeaderboardForJoin = function(player: Player, data: tt.afterData_getStatsByUser)
	leaderboardUpdateEvent:FireClient(player, data)
end

module.updateLeaderboardBadgeStats = function(player: Player, data: tt.badgeUpdate)
	leaderboardUpdateEvent:FireClient(player, data)
end

module.updateLeaderboardForServerEventCompletionRun = function(player: Player, data: tt.lbUpdateFromRun)
	leaderboardUpdateEvent:FireClient(player, data)
end

return module
