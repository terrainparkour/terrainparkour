--!strict

-- pinCommand.lua :: ReplicatedStorage.commands.pinCommand
-- SERVER-ONLY: Pins a race to profile.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)

local pinRaceCommand = require(game.ReplicatedStorage.commands.pinRaceCommand)
local tt = require(game.ReplicatedStorage.types.gametypes)
local textUtil = require(game.ReplicatedStorage.util.textUtil)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "any",
	AutocompleteVisible = true,
}

function module.Execute(player: Player, parts: { string }): boolean
	if not commandUtils.RequireArguments(parts, 1) then
		commandUtils.SendMessage("Usage: /pin <sign1> <sign2>", player)
		return true
	end
	local userInput = textUtil.stringJoin(" ", parts)
	local ret: tt.RaceParseResult = tpUtil.AttemptToParseRaceFromInput(userInput)
	if ret.error ~= "" then
		commandUtils.SendMessage(ret.error, player)
		return true
	end
	local res = pinRaceCommand.PinRace(player, ret.signId1, ret.signId2)
	commandUtils.SendMessage(res.message, player)
	commandUtils.GrantCmdlineBadge(player.UserId)
	return true
end

_annotate("end")
return module

