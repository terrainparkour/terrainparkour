--!strict

-- findersCommand.lua :: ReplicatedStorage.commands.findersCommand
-- SERVER-ONLY: Lists top sign finders.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local PlayersService = game:GetService("Players")

local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)

local tt = require(game.ReplicatedStorage.types.gametypes)
local playerData2 = require(game.ServerScriptService.playerData2)
local text = require(game.ReplicatedStorage.util.text)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "data_only",
	AutocompleteVisible = true,
}

function module.Execute(player: Player, _parts: { string }): boolean
	local finderLeaders = playerData2.getFinderLeaders()

	commandUtils.SendMessage("Top Finders:", player)
	local playersInServer = {}
	for _, serverPlayer in ipairs(PlayersService:GetPlayers()) do
		playersInServer[serverPlayer.UserId] = true
	end
	local function getter(userId: number): any
		local data: tt.lbUserStats = playerData2.GetStatsByUserId(userId, "finders_command")
		return { rank = data.findRank, count = data.findCount }
	end
	local res = text.generateTextForRankedList(finderLeaders, playersInServer, player.UserId, getter)
	for _, el in ipairs(res) do
		commandUtils.SendMessage(el.message, player)
	end

	commandUtils.GrantCmdlineBadge(player.UserId)
	return true
end

_annotate("end")
return module

