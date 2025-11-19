--!strict

-- missingCommand.lua :: ReplicatedStorage.commands.missingCommand
-- SERVER-ONLY: Lists non-top10 races for a player.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local MessageFormatter = require(game.ReplicatedStorage.ChatSystem.messageFormatter)
local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)

local tt = require(game.ReplicatedStorage.types.gametypes)
local playerData2 = require(game.ServerScriptService.playerData2)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "any",
	AutocompleteVisible = false
}

function module.Execute(player: Player, _parts: { string }): boolean
	commandUtils.SendMessage("NonTop10 races for: " .. player.Name, player)
	local data: tt.getNonTop10RacesByUser = playerData2.getNonTop10RacesByUserId(player.UserId, "nontop10_command")
	for _, runDesc in ipairs(data.raceDescriptions) do
		local formatted = MessageFormatter.formatWithFont(" * " .. runDesc, "Code")
		commandUtils.SendMessage(formatted, player)
	end
	commandUtils.GrantCmdlineBadge(player.UserId)
	return true
end

_annotate("end")
return module

