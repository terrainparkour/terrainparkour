--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local rdb = require(game.ServerScriptService.rdb)
local notify = require(game.ReplicatedStorage.notify)

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

	local dcRunResponse: tt.dcRunResponse = rdb.MakePostRequest(request)

	local descTry = mds[marathonKind]
	if descTry == nil then
		_annotate(string.format("bad mk" .. marathonKind))
	end
	if descTry ~= nil then
		if descTry.awardBadge ~= nil then
			grantBadge.GrantBadge(player.UserId, descTry.awardBadge)
		end
	end

	dcRunResponse.kind = "marathon results"

	notify.notifyPlayerAboutMarathonResults(player, dcRunResponse)

	for _, otherPlayer in ipairs(PlayerService:GetPlayers()) do
		lbUpdaterServer.SendUpdateToPlayer(otherPlayer, dcRunResponse.lbUserStats)
	end
end

module.Init = function()
	local marathonCompleteEvent: RemoteEvent = remotes.getRemoteEvent("MarathonCompleteEvent") :: RemoteEvent
	if marathonCompleteEvent == nil then
		warn("Fail")
	end
	marathonCompleteEvent.OnServerEvent:Connect(serverInvokeMarathonComplete)
end

_annotate("end")
return module
