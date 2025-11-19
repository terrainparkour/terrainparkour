--!strict

-- showInterestingCommand.lua :: ReplicatedStorage.commands.showInterestingCommand
-- SERVER-ONLY: Experimental run suggestions (not fully implemented).

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
	commandUtils.SendMessage("This command is under development. Check back later!", player)
	return true
end

_annotate("end")
return module

