--!strict

-- wrsCommand.lua :: ReplicatedStorage.commands.wrsCommand
-- SERVER-ONLY: Displays top world record holders.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local PlayersService = game:GetService("Players")

local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)
local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)

local tt = require(game.ReplicatedStorage.types.gametypes)
local playerData2 = require(game.ServerScriptService.playerData2)
local rdb = require(game.ServerScriptService.rdb)
local text = require(game.ReplicatedStorage.util.text)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "private",
	ChannelRestriction = "data_only",
	AutocompleteVisible = true,
}

function module.Execute(player: Player, _parts: { string }): boolean
	local request: tt.postRequest = {
		remoteActionName = "getWRLeaders",
		data = { userId = player.UserId },
	}
	local data = rdb.MakePostRequest(request)
	if typeof(data) ~= "table" then
		error("getWRLeaders returned non-table response")
	end
	commandUtils.SendMessage("Top World Record Holders (including CWRs):", player)
	local playersInServer = {}
	for _, serverPlayer in ipairs(PlayersService:GetPlayers()) do
		playersInServer[serverPlayer.UserId] = true
	end
	local function getter(userId: number): any
		local data2: tt.lbUserStats = playerData2.GetStatsByUserId(userId, "wrs_command")
		return { rank = data2.wrRank, count = data2.wrCount }
	end
	local res = text.generateTextForRankedList(data, playersInServer, player.UserId, getter)
	if typeof(res) ~= "table" then
		error("generateTextForRankedList returned non-table for wrs command")
	end
	for _, el in ipairs((res :: any) :: { any }) do
		local messageValue = if type(el) == "table" then el.message else nil
		if type(messageValue) == "string" then
			commandUtils.SendMessage(messageValue, player)
		end
	end

	commandUtils.GrantCmdlineBadge(player.UserId)
	return true
end

_annotate("end")
return module
