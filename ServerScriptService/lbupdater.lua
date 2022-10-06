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
	spawn(function()
		leaderboardUpdateEvent:FireClient(player, data)
	end)
end

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

module.updateLeaderboardForLeave = function(player: Player, userId: number)
	spawn(function()
		local data: tt.leaveOptions = { userId = userId, kind = "leave" }
		leaderboardUpdateEvent:FireClient(player, data)
	end)
end

module.updateLeaderboardForJoin = function(player: Player, data: tt.afterData_getStatsByUser)
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
