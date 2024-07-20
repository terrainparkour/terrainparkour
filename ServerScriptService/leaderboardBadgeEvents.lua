--!strict
--eval 9.25.22

-- on join type methods for triggering other players local LBs to update.

local lbupdater = require(game.ServerScriptService.lbupdater)
local tt = require(game.ReplicatedStorage.types.gametypes)

local PlayerService = game:GetService("Players")
local module = {}

local doAnnotation = false

local function annotate(s: string)
	if doAnnotation then
		print("server: " .. string.format("%.0f", tick()) .. " : " .. s)
	end
end

matches = {}

--utility function for others to call in
module.updateBadgeLb = function(player: Player, userIdToInformThemAbout: number, badgecount: number)
	spawn(function()
		local bstats: tt.badgeUpdate =
			{ kind = "badge update", userId = userIdToInformThemAbout, badgeCount = badgecount }
		annotate("Updating " .. player.UserId .. " about badges from: " .. userIdToInformThemAbout)
		lbupdater.updateLeaderboardBadgeStats(player, bstats)
	end)
end

module.TellPlayerAboutAllOthersBadges = function(player: Player)
	local badges = require(game.ServerScriptService.badges)
	local badgecount: number = badges.getBadgeCountByUser(player.UserId)
	for _, otherPlayer: Player in ipairs(PlayerService:GetPlayers()) do
		module.updateBadgeLb(otherPlayer, player.UserId, badgecount)
		annotate("Updating " .. otherPlayer.UserId .. " about all badges from: " .. player.Name)
	end
end

local function updateSomeoneAboutAllBadgesImmediate(player: Player)
	local badges = require(game.ServerScriptService.badges)
	for _, otherPlayer: Player in ipairs(PlayerService:GetPlayers()) do
		local badgecount: number = badges.getBadgeCountByUser(otherPlayer.UserId)
		module.updateBadgeLb(player, otherPlayer.UserId, badgecount)
		annotate("Updating " .. player.UserId .. " about all badges fr: " .. otherPlayer.Name)
	end
end

--tell player about otherplayers badges.
module.TellMeAboutOBadges = function(player: Player)
	player.CharacterAdded:Connect(function()
		annotate("Player " .. player.Name .. " was added OUTER, so telling others about it.")
		return updateSomeoneAboutAllBadgesImmediate(player)
	end)
	updateSomeoneAboutAllBadgesImmediate(player)
end

return module
