--!strict

-- sfCommand.lua :: ReplicatedStorage.commands.sfCommand
-- SERVER-ONLY: Shows favorite races shortcut.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)

local userFavoriteRacesCommand = require(game.ReplicatedStorage.commands.userFavoriteRacesCommand)
local tt = require(game.ReplicatedStorage.types.gametypes)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "any",
	AutocompleteVisible = true,
}

function module.Execute(player: Player, _parts: { string }): boolean
	local otherUsersInServer = tpUtil.GetUserIdsInServer()
	local theFavorites: tt.serverFavoriteRacesResponse =
		userFavoriteRacesCommand.GetFavoriteRaces(player, player.UserId, player.UserId, otherUsersInServer)
	for _, el in pairs(theFavorites.racesAndInfo) do
		local raceHead = string.format("Favorite race: %s", el.theRace.raceName)
		commandUtils.SendMessage(raceHead, player)
		for _2, simpleRunInfo in pairs(el.theResults) do
			local theTime = (simpleRunInfo.runMilliseconds / 1000)
			local line =
				string.format("\t%s %s %0.3f", tpUtil.getCardinal(simpleRunInfo.place), simpleRunInfo.username, theTime)
			commandUtils.SendMessage(line, player)
		end
	end
	commandUtils.GrantCmdlineBadge(player.UserId)
	return true
end

_annotate("end")
return module
