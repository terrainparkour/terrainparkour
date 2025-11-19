--!strict

-- timeCommand.lua :: ReplicatedStorage.commands.timeCommand
-- SERVER-ONLY: Displays server time.

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
	local serverTime = os.date("Server Time - %H:%M %d-%m-%Y", tick())
	commandUtils.SendMessage(serverTime, player)
	commandUtils.GrantUndocumentedCommandBadge(player.UserId)
	return true
end

_annotate("end")
return module

