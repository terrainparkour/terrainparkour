--!strict

-- cwrsCommand.lua :: ReplicatedStorage.commands.cwrsCommand
-- SERVER-ONLY: Displays top competitive world record holders.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local PlayersService = game:GetService("Players")

local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)

local tt = require(game.ReplicatedStorage.types.gametypes)
local playerData2 = require(game.ServerScriptService.playerData2)
local rdb = require(game.ServerScriptService.rdb)
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
	commandUtils.SendMessage("Top Competitive World Record Holders:", player)
	local request: tt.postRequest = {
		remoteActionName = "getCWRLeaders",
		data = { userId = player.UserId },
	}
	local data = rdb.MakePostRequest(request)
	if typeof(data) ~= "table" then
		error("getCWRLeaders returned non-table response")
	end

	local a = data.totalCwrCountA
	local b = data.totalCwrCountB
	local message = ""
	if a and b then
		if a == b then
			message = string.format("%d total", a)
		else
			message = string.format("%d total, or maybe %d?", a, b)
		end
	end
	commandUtils.SendMessage(message, player)

	local playersInServer = {}
	for _, serverPlayer in ipairs(PlayersService:GetPlayers()) do
		playersInServer[serverPlayer.UserId] = true
	end

	local function getter(userId: number): any
		local data2 = playerData2.GetStatsByUserId(userId, "cwrs_command")
		return { rank = data2.cwrRank, count = data2.cwrs }
	end

	local leaders = data.leaders
	if typeof(leaders) ~= "table" then
		error("getCWRLeaders returned missing leaders table")
	end

	local res = text.generateTextForRankedList(leaders, playersInServer, player.UserId, getter)
	if typeof(res) ~= "table" then
		error("generateTextForRankedList returned non-table for cwrs command")
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

