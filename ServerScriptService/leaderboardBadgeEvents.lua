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
module.updateBadgeLb = function(userId: number, target: Player, badgecount: number)
	spawn(function()
		local bstats: tt.badgeUpdate = { kind = "badge update", userId = userId, badgeCount = badgecount }
		lbupdater.updateLeaderboardBadgeStats(target, bstats)
	end)
end

module.TellAllAboutMeBadges = function(player: Player)
	local badges = require(game.ServerScriptService.badges)
	local badgecount: number = badges.getBadgeCountByUser(player.UserId)
	for _, otherPlayer: Player in ipairs(PlayerService:GetPlayers()) do
		module.updateBadgeLb(player.UserId, otherPlayer, badgecount)
	end
end

local function updateSomeoneAboutAllBadges(player: Player)
	local badges = require(game.ServerScriptService.badges)
	for _, otherPlayer: Player in ipairs(PlayerService:GetPlayers()) do
		local badgecount: number = badges.getBadgeCountByUser(otherPlayer.UserId)
		module.updateBadgeLb(otherPlayer.UserId, player, badgecount)
	end
end

--tell player about otherplayers badges.
module.TellMeAboutOBadges = function(player: Player)
	player.CharacterAdded:Connect(function()
		return updateSomeoneAboutAllBadges(player)
	end)
	updateSomeoneAboutAllBadges(player)
end

return module
