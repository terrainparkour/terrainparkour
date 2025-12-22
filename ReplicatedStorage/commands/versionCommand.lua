--!strict

-- versionCommand.lua :: ReplicatedStorage.commands.versionCommand
-- SERVER-ONLY: Shows server version.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)
local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)

local enums = require(game.ReplicatedStorage.util.enums)
local environment = require(game.ReplicatedStorage.environment)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "any",
	AutocompleteVisible = true,
}

function module.Execute(player: Player, _parts: { string }): boolean
	local testMessage = ""
	if environment.UseTestDb() then
		testMessage = " TEST VERSION, db will be wiped"
	end

	local message = string.format("Terrain Parkour - Version %s%s", enums.gameVersion, testMessage)
	local targetChannel = commandUtils.GetActiveCommandChannel(player)
	commandUtils.SendMessage(message, player, { channel = targetChannel })
	commandUtils.GrantUndocumentedCommandBadge(player.UserId)
	return true
end

_annotate("end")
return module
