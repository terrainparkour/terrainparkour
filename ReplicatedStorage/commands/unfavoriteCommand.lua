--!strict

-- unfavoriteCommand.lua :: ReplicatedStorage.commands.unfavoriteCommand
-- SERVER-ONLY: Removes a favorite race.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)

local userFavoriteRacesCommand = require(game.ReplicatedStorage.commands.userFavoriteRacesCommand)
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
		commandUtils.SendMessage("Usage: /unfavorite <sign1> <sign2>", player)
		return true
	end
	local rest = textUtil.stringJoin(" ", parts)
	local res: tt.RaceParseResult = tpUtil.AttemptToParseRaceFromInput(rest)
	if res.error ~= "" then
		commandUtils.SendMessage(res.error, player)
		return true
	end
	commandUtils.SendMessage(string.format("%s unfavorited %s-%s", player.Name, res.signName1, res.signName2), player)
	commandUtils.GrantCmdlineBadge(player.UserId)
	return userFavoriteRacesCommand.AdjustFavoriteRace(player, res.signId1, res.signId2, false)
end

_annotate("end")
return module

