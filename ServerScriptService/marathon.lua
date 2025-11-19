--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local rdb = require(game.ServerScriptService.rdb)
local notify = require(game.ReplicatedStorage.notify)
local MessageDispatcher = require(game.ReplicatedStorage.ChatSystem.messageDispatcher)

local tt = require(game.ReplicatedStorage.types.gametypes)
local lbUpdaterServer = require(game.ServerScriptService.lbUpdaterServer)
local PlayerService = game:GetService("Players")

local grantBadge = require(game.ServerScriptService.grantBadge)

local mds = require(game.ReplicatedStorage.marathon.marathonDescriptors)
local remotes = require(game.ReplicatedStorage.util.remotes)

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

	local userFinishedRunResponse: tt.userFinishedRunResponseOrError = rdb.MakePostRequest(request)

	local responseAsAny: any = userFinishedRunResponse
	if responseAsAny.error or responseAsAny.banned then
		local errorResponse: tt.userFinishedRunErrorResponse =
			userFinishedRunResponse :: tt.userFinishedRunErrorResponse
		annotater.Error("userFinishedMarathon returned error response", {
			userId = player.UserId,
			marathonKind = marathonKind,
			error = errorResponse.error,
			banned = errorResponse.banned,
		})
		if errorResponse.banned == true then
			MessageDispatcher.SendSystemMessageToPlayer(player, "Chat", "You are banned. Please find another game to play.")
		end
		return
	end

	local typedResponse: tt.userFinishedRunResponse = userFinishedRunResponse :: tt.userFinishedRunResponse

	local descTry = mds[marathonKind]
	if descTry == nil then
		_annotate(string.format("bad mk %s", marathonKind))
	end
	if descTry ~= nil then
		if descTry.awardBadge ~= nil then
			grantBadge.GrantBadge(player.UserId, descTry.awardBadge)
		end
	end

	local responseWithKind: any = {}
	for k, v in pairs(typedResponse) do
		responseWithKind[k] = v
	end
	responseWithKind.kind = "marathon results"

	notify.notifyPlayerAboutMarathonResults(player, responseWithKind :: tt.userFinishedRunResponse)

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
