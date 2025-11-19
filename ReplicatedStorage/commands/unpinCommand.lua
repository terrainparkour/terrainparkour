--!strict

-- unpinCommand.lua :: ReplicatedStorage.commands.unpinCommand
-- SERVER-ONLY: Removes pinned race from profile.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)

local pinRaceCommand = require(game.ReplicatedStorage.commands.pinRaceCommand)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "any",
	AutocompleteVisible = true,
}

function module.Execute(player: Player, _parts: { string }): boolean
	local res = pinRaceCommand.UnpinRace(player)
	commandUtils.SendMessage(res.message, player)
	commandUtils.GrantCmdlineBadge(player.UserId)
	return true
end

_annotate("end")
return module

