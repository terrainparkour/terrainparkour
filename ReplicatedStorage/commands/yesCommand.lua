--!strict

-- yesCommand.lua :: ReplicatedStorage.commands.yesCommand
-- SERVER-ONLY: Confirms pending actions that require user confirmation.
-- Currently supports: /requestRemoval confirmation

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)
local requestRemovalCommand = require(game.ReplicatedStorage.commands.requestRemovalCommand)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "any",
	AutocompleteVisible = false,
}

function module.Execute(player: Player, _parts: { string }): boolean
	-- Check if there's a pending removal request
	if requestRemovalCommand.HasPendingConfirmation(player.UserId) then
		return requestRemovalCommand.ProcessConfirmation(player)
	end

	-- No pending confirmation found
	commandUtils.SendMessage("No pending action to confirm.", player)
	return true
end

_annotate("end")
return module
