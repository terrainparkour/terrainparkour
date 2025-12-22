--!strict

-- wrProgressionCommand.lua :: ReplicatedStorage.commands.wrProgressionCommand
-- SERVER-ONLY: Fetch world record progression data and send to client for display.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)
local remotes = require(game.ReplicatedStorage.util.remotes)
local tt = require(game.ReplicatedStorage.types.gametypes)
local tpUtil: typeof(require(game.ReplicatedStorage.util.tpUtil)) = require(game.ReplicatedStorage.util.tpUtil)
local rdb = require(game.ServerScriptService.rdb)

local ServerToClientEvent = remotes.getRemoteEvent("ServerToClientEvent")

type Module = {
	GetWRProgression: (player: Player, signId1: number, signId2: number, showChartOnly: boolean?) -> boolean,
}

local module: Module = {} :: Module

module.GetWRProgression = function(player: Player, signId1: number, signId2: number, showChartOnly: boolean?): boolean
	local req = {
		remoteActionName = "wrProgressionRequest",
		data = {
			startSignId = signId1,
			endSignId = signId2,
			userId = player.UserId,
		},
	}

	_annotate("getting wr progression")
	local rawResponse: any = rdb.MakePostRequest(req)
	_annotate("got wr progression data")

	-- Handle "Race not found" - legitimate scenario when no one has run between these signs
	if rawResponse.error then
		local startName = tpUtil.signId2signName(signId1)
		local endName = tpUtil.signId2signName(signId2)
		commandUtils.SendMessage(
			string.format("No one has run %s-%s yet. Be the first!", startName, endName),
			player
		)
		return false
	end

	local typedResponse = rawResponse :: tt.WRProgressionEndpointResponse

	-- Determine notification kind based on whether we want chart only or full modal
	local notificationKind: "wrProgression" | "wrProgressionChart" = if showChartOnly then "wrProgressionChart" else "wrProgression"

	local notification: tt.wrProgressionNotification | tt.wrProgressionChartNotification = {
		kind = notificationKind,
		wrProgression = typedResponse.wrProgression,
		raceHistoryData = typedResponse.raceHistoryData,
		raceExists = typedResponse.raceExists,
		userRaceInfo = typedResponse.userRaceInfo,
	}

	ServerToClientEvent:FireClient(player, notification)
	return true
end

_annotate("end")
return module
