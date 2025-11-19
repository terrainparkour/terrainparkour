--!strict

-- showCommand.lua :: ReplicatedStorage.commands.showCommand
-- SERVER-ONLY: Displays sign highlights for a player.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local PlayersService = game:GetService("Players")

local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)

local showSignsCommand = require(game.ReplicatedStorage.commands.showSignsCommand)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "any",
	AutocompleteVisible = true,
}

function module.Execute(player: Player, parts: { string }): boolean
	local targetUserId: number? = nil
	if parts and #parts > 0 and parts[1] ~= "" then
		for _, serverPlayer in ipairs(PlayersService:GetPlayers()) do
			if serverPlayer.Name:lower() == parts[1]:lower() then
				targetUserId = serverPlayer.UserId
				break
			end
		end
	end
	commandUtils.GrantCmdlineBadge(player.UserId)
	return showSignsCommand.ShowSignCommand(player, targetUserId)
end

_annotate("end")
return module

