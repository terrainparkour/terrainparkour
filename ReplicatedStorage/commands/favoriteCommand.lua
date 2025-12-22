--!strict

-- favoriteCommand.lua :: ReplicatedStorage.commands.favoriteCommand
-- SERVER-ONLY: Pins a favorite race.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)

local userFavoriteRacesCommand = require(game.ReplicatedStorage.commands.userFavoriteRacesCommand)
local tt = require(game.ReplicatedStorage.types.gametypes)
local textUtil = require(game.ReplicatedStorage.util.textUtil)

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
		commandUtils.SendMessage("Usage: /favorite <sign1> <sign2>", player)
		return true
	end
	local rest = textUtil.stringJoin(" ", parts)
	local res: tt.RaceParseResult = commandUtils.ParseRaceFromInput(rest, player.UserId)
	if res.error ~= "" then
		commandUtils.SendMessage(res.error, player)
		return true
	end

	commandUtils.GrantCmdlineBadge(player.UserId)
	local result = userFavoriteRacesCommand.AdjustFavoriteRace(player, res.signId1, res.signId2, true)

	if result.raceNotFound then
		commandUtils.SendMessage(string.format("No one has run %s-%s yet. Be the first!", res.signName1, res.signName2), player)
		return false
	end

	if result.success then
		commandUtils.SendMessage(string.format("%s favorited %s-%s", player.Name, res.signName1, res.signName2), player)
	end
	return result.success
end

_annotate("end")
return module
