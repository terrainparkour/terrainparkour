--!strict

--any backend that notices something happening that is part of the leaderboard should import this
--list of events and call the appropriate one, with the appropriate luau typed data on it,
--so that all users currently connected to that instance will get the LB update.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local tt = require(game.ReplicatedStorage.types.gametypes)
local mt = require(game.ServerScriptService.EphemeralMarathons.ephemeralMarathonTypes)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local module = {}

local LeaderboardUpdateEvent: RemoteEvent = ReplicatedStorage:WaitForChild("RemoteEvents")
	:WaitForChild("LeaderboardUpdateEvent")



-- -- that is, tell player about other guy's extended/rarely changing data.
-- module.updateRarelyChangingDataLb = function(player: Player, userIdToInformThemAbout: number, data: tt.lb_rareData)
-- 	task.spawn(function()
-- 		LeaderboardUpdateEvent:FireClient(player, data)
-- 	end)
-- end


module.sendUpdateToPlayer = function(player: Player, data: tt.afterData_getStatsByUser)
	task.spawn(function()
		LeaderboardUpdateEvent:FireClient(player, data)
	end)
end


module.updateLeaderboardForRun = function(player: Player, data: tt.lbUpdateFromRun)
	task.spawn(function()
		LeaderboardUpdateEvent:FireClient(player, data)
	end)
end

--ie tell player p about (their or another user's) find, with details within "data."
module.updateLeaderboardForFind = function(player: Player, data: tt.signFindOptions)
	task.spawn(function()
		LeaderboardUpdateEvent:FireClient(player, data)
	end)
end

module.updateLeaderboardForEphemeralMarathon = function(player: Player, data: mt.lbUpdateFromEphemeralMarathonRun)
	task.spawn(function()
		LeaderboardUpdateEvent:FireClient(player, data)
	end)
end

module.updateLeaderboardForMarathon = function(player: Player, data: tt.pyUserFinishedRunResponse)
	task.spawn(function()
		LeaderboardUpdateEvent:FireClient(player, data)
	end)
end

module.sendLeaveInfoToSomeone = function(player: Player, userId: number)
	task.spawn(function()
		local data: tt.leaveOptions = { userId = userId, kind = "leave" }
		LeaderboardUpdateEvent:FireClient(player, data)
	end)
end

module.updateLeaderboardBadgeStats = function(player: Player, data: tt.badgeUpdate)
	task.spawn(function()
		LeaderboardUpdateEvent:FireClient(player, data)
	end)
end

module.updateLeaderboardForServerEventCompletionRun = function(player: Player, data: tt.lbUpdateFromRun)
	task.spawn(function()
		LeaderboardUpdateEvent:FireClient(player, data)
	end)
end

_annotate("end")
return module
