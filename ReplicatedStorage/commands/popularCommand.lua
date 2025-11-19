--!strict

-- popularCommand.lua :: ReplicatedStorage.commands.popularCommand
-- SERVER-ONLY: Shows popular runs overview.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local PlayersService = game:GetService("Players")

local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)

local PopularResponseTypes = require(game.ReplicatedStorage.types.PopularResponseTypes)
local playerData2 = require(game.ServerScriptService.playerData2)
local popular = require(game.ServerScriptService.data.popularRaces)
local textUtil = require(game.ReplicatedStorage.util.textUtil)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "data_only",
	AutocompleteVisible = true,
}

function module.Execute(player: Player, _parts: { string }): boolean
	local userIdsInServer = {}
	for _, serverPlayer in ipairs(PlayersService:GetPlayers()) do
		table.insert(userIdsInServer, serverPlayer.UserId)
	end
	local popResults: { PopularResponseTypes.popularRaceResult } = popular.GetPopularRaces(player, userIdsInServer)

	local messages: { string } = {}
	table.insert(messages, "Top Recent Runs:")
	for _, rr in ipairs(popResults) do
		local userPlaces = {}
		for _, el in ipairs(rr.userPlaces) do
			local userIdValue = el.userId
			if typeof(userIdValue) ~= "number" then
				continue
			end
			local userPlace = el.place
			local username = playerData2.GetUsernameByUserId(userIdValue)
			local usePlace: string = ""

			if userPlace == nil then
				continue
			end
			if userPlace == 0 then
				usePlace = "DNP	"
			elseif userPlace > 10 then
				usePlace = "DNP"
			else
				usePlace = tpUtil.getCardinalEmoji(userPlace)
			end
			local msg = username .. ":" .. usePlace
			table.insert(userPlaces, msg)
		end
		local placeJoined = textUtil.stringJoin(", ", userPlaces)

		local msg = string.format("%d %s-%s - %s", rr.ct or 0, rr.startSignName, rr.endSignName, placeJoined)
		table.insert(messages, msg)
	end
	local res = textUtil.stringJoin("\n", messages)
	commandUtils.SendMessage(res, player)
	commandUtils.GrantCmdlineBadge(player.UserId)
	return true
end

_annotate("end")
return module

