--!strict

--NOT WORKING, but should. TODO fix, not working for months now.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local notify = require(game.ReplicatedStorage.notify)
local lbupdater = require(game.ServerScriptService.lbupdater)
local mt = require(game.ServerScriptService.EphemeralMarathons.ephemeralMarathonTypes)
local PlayerService = game:GetService("Players")

local module = {}

local ephemeralMarathons: { mt.ephemeralMarathon } = {}

local marathonId = 1

--put best run into best runs for this marathon.
local integrateRun = function(run: mt.lbUpdateFromEphemeralMarathonRun): mt.emRunResults?
	local em = run.em
	table.insert(em.bestRuns, run)
	local res: mt.emRunResults = {
		userId = run.userId,
		formattedRunMilliseconds = "100",
		kind = "",
		raceName = "",
		yourText = "",
		runEntries = {},
		afterRunData = {},
		username = "Username",
		actionResults = {},
		run = run,
	}
	return res
end

local findEphemeralMarathon = function(marathonId: number): mt.ephemeralMarathon?
	for ii, em in ipairs(ephemeralMarathons) do
		if em.marathonId == marathonId then
			return em
		end
	end
	warn("fail.")
end

local serverInvokeCreateEphemeralMarathon = function(player: Player, ...): any
	if #ephemeralMarathons > 3 then
		return { result = "Fail too many" }
	end
	local em: mt.ephemeralMarathon = {
		signNames = { "Mazatlan", "A" },
		count = 2,
		marathonId = marathonId,
		start = tick(),
		duration = 1000,
		bestRuns = {},
	}
	marathonId += 1
	table.insert(ephemeralMarathons, em)
	return { result = "Succcess" }
end

local serverInvokeEphemeralMarathonComplete = function(player: Player, marathonId: number, runMilliseconds: number)
	local can = findEphemeralMarathon(marathonId)
	if can == nil then
		--_annotate("no such")
		return
	end
	local em: mt.ephemeralMarathon = can :: mt.ephemeralMarathon
	local run: mt.lbUpdateFromEphemeralMarathonRun = {
		em = em,
		userId = player.UserId,
		marathonId = marathonId,
		timeMs = runMilliseconds,
	}

	local res: mt.emRunResults = integrateRun(run)
	notify.notifyPlayerOfEphemeralMarathonRun(player, res)

	--TODO fix this to update their marathon display.
	for _, otherPlayer in ipairs(PlayerService:GetPlayers()) do
		lbupdater.updateLeaderboardForEphemeralMarathon(otherPlayer, run)
	end
end

local remotes = require(game.ReplicatedStorage.util.remotes)

module.Init = function()
	local ephemeralMarathonCompleteEvent = remotes.getRemoteEvent("EphemeralMarathonCompleteEvent")
	ephemeralMarathonCompleteEvent.OnServerEvent:Connect(serverInvokeEphemeralMarathonComplete)

	local ephemeralMarathonCreateFunction = remotes.getRemoteFunction("EphemeralMarathonCreateFunction")
	ephemeralMarathonCreateFunction.OnServerInvoke = serverInvokeCreateEphemeralMarathon
end

_annotate("end")
return module
