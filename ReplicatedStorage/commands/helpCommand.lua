--!strict

-- helpCommand.lua :: ReplicatedStorage.commands.helpCommand
-- SERVER-ONLY: Displays available commands and usage information.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local MessageFormatter = require(game.ReplicatedStorage.ChatSystem.messageFormatter)
local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "any",
	AutocompleteVisible = true,
	Aliases = { "?" },
}

function module.Execute(player: Player, _parts: { string }): boolean
	commandUtils.SendMessage(MessageFormatter.usageCommandDesc, player)
	return true
end

_annotate("end")
return module

