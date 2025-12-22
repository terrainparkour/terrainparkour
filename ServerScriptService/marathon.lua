--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local rdb = require(game.ServerScriptService.rdb)
local messageDispatcher = require(game.ReplicatedStorage.ChatSystem.messageDispatcher)

local tt = require(game.ReplicatedStorage.types.gametypes)
local lbUpdaterServer = require(game.ServerScriptService.lbUpdaterServer)
local PlayerService = game:GetService("Players")

local grantBadge = require(game.ServerScriptService.grantBadge)

local mds = require(game.ReplicatedStorage.marathon.marathonDescriptors)
local remotes = require(game.ReplicatedStorage.util.remotes)
local runResultsCommand = require(game.ReplicatedStorage.commands.runResultsCommand)

--the client has decided a marathon is complete.
--this should actually be determined from python server.
--callback from server to client, just relaying metadata defined in python.

local serverInvokeMarathonComplete = function(
	player: Player,
	marathonKind: string,
	orderedSigns: string,
	runMilliseconds: number
)
	local request: tt.postRequest = {
		remoteActionName = "userFinishedMarathon",
		data = {
			userId = player.UserId,
			marathonKind = marathonKind,
			orderedSigns = orderedSigns,
			runMilliseconds = runMilliseconds,
		},
	}

	local rawResponse: any = rdb.MakePostRequest(request)

	if not rawResponse then
		annotater.Error("userFinishedMarathon: nil response from backend", {
			userId = player.UserId,
			marathonKind = marathonKind,
		})
		return
	end
	if rawResponse.error or rawResponse.banned then
		annotater.Error("userFinishedMarathon returned error response", {
			userId = player.UserId,
			marathonKind = marathonKind,
			error = rawResponse.error,
			banned = rawResponse.banned,
		})
		if rawResponse.banned == true then
			messageDispatcher.SendSystemMessageToPlayer(player, "Chat", "You are banned. Please find another game to play.")
		end
		return
	end

	local typedResponse: tt.userFinishedRunResponse = rawResponse :: tt.userFinishedRunResponse

	local descTry = mds.marathons[marathonKind]
	if descTry == nil then
		_annotate(string.format("bad mk %s", marathonKind))
	end
	if descTry ~= nil then
		if descTry.awardBadge ~= nil then
			grantBadge.GrantBadge(player.UserId, descTry.awardBadge)
		end
	end

	-- Use shared command to send discipline results notification (symmetric with race completion)
	runResultsCommand.SendDisciplineResults(player, "marathonResults", typedResponse)

	if typedResponse.lbUserStats then
		for _, otherPlayer in ipairs(PlayerService:GetPlayers()) do
			lbUpdaterServer.SendUpdateToPlayer(otherPlayer, typedResponse.lbUserStats)
		end
	end
end

module.Init = function()
	local marathonCompleteEvent: RemoteEvent? = remotes.getRemoteEvent("MarathonCompleteEvent")
	if not marathonCompleteEvent then
		warn("marathon.Init: MarathonCompleteEvent not found")
		return
	end
	local event: RemoteEvent = marathonCompleteEvent :: RemoteEvent
	event.OnServerEvent:Connect(serverInvokeMarathonComplete)
end

_annotate("end")
return module
