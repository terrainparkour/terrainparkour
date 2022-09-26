--!strict

--eval 9.25.22

local rdb = require(game.ServerScriptService.rdb)
local notify = require(game.ReplicatedStorage.notify)

local tt = require(game.ReplicatedStorage.types.gametypes)
local lbupdater = require(game.ServerScriptService.lbupdater)
local PlayerService = game:GetService("Players")

local grantBadge = require(game.ServerScriptService.grantBadge)

local mds = require(game.ReplicatedStorage.marathonDescriptors)

local module = {}

--the client has decided a marathon is complete.
--this should actually be determined from python server.
--callback from server to client, just relaying metadata defined in python.

local serverInvokeMarathonComplete =
	function(player: Player, marathonKind: string, orderedSigns: string, runMilliseconds: number)
		local pyUserFinishedRunResponse: tt.pyUserFinishedRunResponse =
			rdb.userFinishedMarathon(player.UserId, marathonKind, orderedSigns, runMilliseconds)

		local descTry = mds[marathonKind]
		if descTry == nil then
			print("bad mk" .. marathonKind)
		end
		if descTry ~= nil then
			if descTry.awardBadge ~= nil then
				grantBadge.GrantBadge(player.UserId, descTry.awardBadge)
			end
		end

		pyUserFinishedRunResponse.kind = "marathon results"

		notify.notifyPlayerAboutMarathonResults(player, pyUserFinishedRunResponse)

		for _, otherPlayer in ipairs(PlayerService:GetPlayers()) do
			lbupdater.updateLeaderboardForMarathon(otherPlayer, pyUserFinishedRunResponse)
		end
	end

local rf = require(game.ReplicatedStorage.util.remotes)
module.init = function()
	local marathonCompleteEvent: RemoteEvent = rf.getRemoteEvent("MarathonCompleteEvent") :: RemoteEvent
	if marathonCompleteEvent == nil then
		warn("Fail")
	end
	marathonCompleteEvent.OnServerEvent:Connect(serverInvokeMarathonComplete)
end

return module
