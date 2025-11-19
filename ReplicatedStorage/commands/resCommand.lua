--!strict

-- resCommand.lua :: ReplicatedStorage.commands.resCommand
-- SERVER-ONLY: Shows run results between two signs.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)

local runResultsCommand = require(game.ReplicatedStorage.commands.runResultsCommand)
local tt = require(game.ReplicatedStorage.types.gametypes)
local playerData2 = require(game.ServerScriptService.playerData2)
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
		commandUtils.SendMessage("Usage: /res <sign1> <sign2>", player)
		return true
	end
	local rest = textUtil.stringJoin(" ", parts)
	local res: tt.RaceParseResult = tpUtil.AttemptToParseRaceFromInput(rest)
	if res.error ~= "" then
		commandUtils.SendMessage(res.error, player)
		return true
	end
	if
		not playerData2.HasUserFoundSign(player.UserId, res.signId1)
		or not playerData2.HasUserFoundSign(player.UserId, res.signId2)
	then
		commandUtils.SendMessage("You haven't found one or both of those signs.", player)
		return true
	end

	commandUtils.GrantCmdlineBadge(player.UserId)
	return runResultsCommand.SendRunResults(player, res.signId1, res.signId2)
end

_annotate("end")
return module

