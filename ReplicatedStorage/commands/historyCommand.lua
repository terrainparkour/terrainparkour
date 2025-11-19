--!strict

-- historyCommand.lua :: ReplicatedStorage.commands.historyCommand
-- SERVER-ONLY: Shows WR progression between two signs.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)

local wrProgressionCommand = require(game.ReplicatedStorage.commands.wrProgressionCommand)
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
		commandUtils.SendMessage("Usage: /history <sign1> <sign2>", player)
		return true
	end
	local rest = textUtil.stringJoin(" ", parts)
	local res: tt.RaceParseResult = tpUtil.AttemptToParseRaceFromInput(rest)
	_annotate("parsed result of history query to: ", res)
	if res.error ~= "" then
		commandUtils.SendMessage(res.error, player)
		return true
	end
	commandUtils.GrantCmdlineBadge(player.UserId)
	return wrProgressionCommand.GetWRProgression(player, res.signId1, res.signId2)
end

_annotate("end")
return module

