--!strict

-- playerCommand.lua :: ReplicatedStorage.commands.playerCommand
-- SERVER-ONLY: Shows player stats (online/offline).

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)

local playerData2 = require(game.ServerScriptService.playerData2)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "any",
	AutocompleteVisible = true,
}

function module.Execute(player: Player, parts: { string }): boolean
	if not parts or #parts == 0 or not parts[1] then
		commandUtils.SendMessage("Usage: /player <username>", player)
		return true
	end
	local playerDescription = playerData2.getPlayerDescriptionMultilineByUsername(parts[1])
	if playerDescription ~= "unknown" then
		local res = "stats: " .. playerDescription
		commandUtils.SendMessage(res, player)
		commandUtils.GrantCmdlineBadge(player.UserId)
		return true
	end
	commandUtils.SendMessage("Could not find player: " .. parts[1], player)
	return true
end

_annotate("end")
return module

