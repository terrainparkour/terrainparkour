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
	local badges = require(game.ServerScriptService.badges)
	local badgecount: number = badges.getBadgeCountByUser(player.UserId, "tellPlayerAboutAllOthers")
	for _, otherPlayer: Player in ipairs(PlayerService:GetPlayers()) do
		module.updateBadgeLb(otherPlayer, player.UserId, badgecount)
		_annotate("Updating " .. otherPlayer.UserId .. " about all badges from: " .. player.Name)
	end
end

local function updateSomeoneAboutAllBadgesImmediate(player: Player)
	local badges = require(game.ServerScriptService.badges)
	for _, otherPlayer: Player in ipairs(PlayerService:GetPlayers()) do
		local badgecount: number =
			badges.getBadgeCountByUser(otherPlayer.UserId, "updateSomeoneAboutAllBadgesImmediate")
		module.updateBadgeLb(player, otherPlayer.UserId, badgecount)
		_annotate("Updating " .. player.UserId .. " about all badges fr: " .. otherPlayer.Name)
	end
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
