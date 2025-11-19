--!strict

-- badgesCommand.lua :: ReplicatedStorage.commands.badgesCommand
-- SERVER-ONLY: Displays badge progress for a player.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local PlayersService = game:GetService("Players")

local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)

local badges = require(game.ServerScriptService.badges)
local leaderboardBadgeEvents = require(game.ServerScriptService.leaderboardBadgeEvents)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "any",
	AutocompleteVisible = true,
}

function module.Execute(player: Player, _parts: { string }): boolean
	local allBadgeStatuses = badges.GetAllBadgeProgressDetailsForUserId(player.UserId, "cmdline")
	commandUtils.SendMessage("Badge status for: " .. player.Name, player)
	local gotStr = "BADGES GOTTEN:"
	local ungotStr = "BADGES NOT GOTTEN:"
	local gotct = 0
	local ungotct = 0

	local allBadgeClasses = {}

	for _, badgeStatus in ipairs(allBadgeStatuses) do
		allBadgeClasses[badgeStatus.badge.badgeClass] = true
		continue
	end
	for badgeClass, _ in pairs(allBadgeClasses) do
		local hasOneThisClass = false
		for _, ba in pairs(allBadgeStatuses) do
			if ba.badge.badgeClass ~= badgeClass then
				continue
			end

			if ba.got then
				if not hasOneThisClass then
					gotStr = gotStr .. "\r\n" .. badgeClass .. ": => "
					hasOneThisClass = true
				end
				gotct += 1
				gotStr = gotStr .. ", " .. ba.badge.name
			else
				ungotct += 1
				ungotStr = ungotStr .. ", " .. ba.badge.name
			end
		end
	end

	commandUtils.SendMessage(gotStr, player)
	commandUtils.SendMessage(ungotStr, player)

	local total = "Got: " .. gotct .. " Not got: " .. ungotct
	commandUtils.SendMessage(total, player)

	local badgecount = badges.getBadgeCountByUser(player.UserId, "CommandService.badges")
	for _, otherPlayer: Player in ipairs(PlayersService:GetPlayers()) do
		leaderboardBadgeEvents.updateBadgeLb(player, otherPlayer.UserId, badgecount)
	end
	commandUtils.GrantCmdlineBadge(player.UserId)
	return true
end

_annotate("end")
return module

