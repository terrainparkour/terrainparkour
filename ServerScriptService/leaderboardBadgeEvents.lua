--!strict

-- on join type methods for triggering other players local LBs to update.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local lbUpdaterServer = require(game.ServerScriptService.lbUpdaterServer)
local tt = require(game.ReplicatedStorage.types.gametypes)

local PlayerService = game:GetService("Players")
local module = {}

-- utility function for others to call in
-- that is, tell player about this other guy's badge count.
module.updateBadgeLb = function(player: Player, userIdToInformThemAbout: number, badgecount: number)
	task.spawn(function()
		local lbUserStats: tt.lbUserStats =
			{ kind = "badge update", userId = userIdToInformThemAbout, badgeCount = badgecount }
		_annotate("Updating " .. player.UserId .. " about badges from: " .. userIdToInformThemAbout)
		lbUpdaterServer.SendUpdateToPlayer(player, lbUserStats)
	end)
end

module.TellPlayerAboutAllOthersBadges = function(player: Player)
	local start = tick()
	local badges = require(game.ServerScriptService.badges)
	local fetchStart = tick()
	local badgecount: number = badges.getBadgeCountByUser(player.UserId, "tellPlayerAboutAllOthers")
	local fetchTime = tick() - fetchStart
	
	local playerCount = #PlayerService:GetPlayers()
	for _, otherPlayer: Player in ipairs(PlayerService:GetPlayers()) do
		module.updateBadgeLb(otherPlayer, player.UserId, badgecount)
	end
	
	_annotate(string.format("TellAllAboutMyBadges DONE for %s (%.3fs: %.3fs fetch + %.3fs broadcast to %d)", 
		player.Name, tick() - start, fetchTime, tick() - start - fetchTime, playerCount))
end

local function updateSomeoneAboutAllBadgesImmediate(player: Player)
	local start = tick()
	local badges = require(game.ServerScriptService.badges)
	local playerCount = #PlayerService:GetPlayers()
	_annotate(string.format("TellMeAboutOtherBadges START for %s (%d players)", player.Name, playerCount))
	
	local totalFetchTime = 0
	for _, otherPlayer: Player in ipairs(PlayerService:GetPlayers()) do
		local fetchStart = tick()
		local badgecount: number =
			badges.getBadgeCountByUser(otherPlayer.UserId, "updateSomeoneAboutAllBadgesImmediate")
		local fetchTime = tick() - fetchStart
		totalFetchTime = totalFetchTime + fetchTime
		module.updateBadgeLb(player, otherPlayer.UserId, badgecount)
	end
	
	_annotate(string.format("TellMeAboutOtherBadges DONE for %s (%.3fs: %.3fs fetches + %.3fs sends, %d players)", 
		player.Name, tick() - start, totalFetchTime, tick() - start - totalFetchTime, playerCount))
end

--tell player about otherplayers badges.
module.TellMeAboutOBadges = function(player: Player)
	player.CharacterAdded:Connect(function()
		_annotate("Player " .. player.Name .. " was added OUTER, so telling others about it.")
		return updateSomeoneAboutAllBadgesImmediate(player)
	end)
	updateSomeoneAboutAllBadgesImmediate(player)
end

_annotate("end")
return module
