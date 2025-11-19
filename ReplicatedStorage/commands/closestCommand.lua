--!strict

-- closestCommand.lua :: ReplicatedStorage.commands.closestCommand
-- SERVER-ONLY: Finds the closest sign a player has found.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "any",
	AutocompleteVisible = true,
}

function module.Execute(player: Player, _parts: { string }): boolean
	local bestsign: Instance? = commandUtils.GetClosestSignToPlayer(player)
	local message = ""
	if bestsign == nil then
		message = "You have not found any signs."
	else
		message = "The closest found sign to " .. player.Name .. " is " .. bestsign.Name .. "!"
	end

	commandUtils.SendMessage(message, player)
	commandUtils.GrantCmdlineBadge(player.UserId)
	return true
end

_annotate("end")
return module

