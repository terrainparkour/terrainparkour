--!strict

--NOT WORKING, but should. TODO fix, not working for months now.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local mt = require(game.ServerScriptService.EphemeralMarathons.ephemeralMarathonTypes)
local colors = require(game.ReplicatedStorage.util.colors)

local module = {}

local ephemeralMarathons: { mt.ephemeralMarathon } = {}

local marathonId = 1

--put best run into best runs for this marathon.
local integrateRun = function(run: mt.lbUpdateFromEphemeralMarathonRun): mt.emRunResults?
	local em = run.em
	local bestRun: mt.ephemeralMarathonBestRun = {
		userId = run.userId,
		timeMs = run.timeMs,
		rank = 1, -- Will be recalculated
		userRunCount = 1, -- Will be recalculated
	}
	table.insert(em.bestRuns, bestRun)
	local res: mt.emRunResults = {
		userId = run.userId,
		formattedRunMilliseconds = "100",
		kind = "",
		raceName = "",
		yourText = "",
		yourColor = colors.defaultGrey,
		runEntries = {},
		afterRunData = {},
		username = "Username",
		actionResults = {},
		run = run,
	}
	return res
end

local findEphemeralMarathon = function(targetMarathonId: number): mt.ephemeralMarathon?
	for ii, em in ipairs(ephemeralMarathons) do
		if em.marathonId == targetMarathonId then
			return em
		end
	end
	warn("fail.")
	return nil
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

local serverInvokeEphemeralMarathonComplete = function(player: Player, targetMarathonId: number, runMilliseconds: number)
	local can = findEphemeralMarathon(targetMarathonId)
	if can == nil then
		_annotate("no such")
		return
	end
	local em: mt.ephemeralMarathon = can :: mt.ephemeralMarathon
	local run: mt.lbUpdateFromEphemeralMarathonRun = {
		em = em,
		userId = player.UserId,
		marathonId = targetMarathonId,
		timeMs = runMilliseconds,
	}

	local res: mt.emRunResults? = integrateRun(run)
	if not res then
		_annotate("no res from integrateRun")
		return
	end
	-- TODO: Implement notify.notifyPlayerOfEphemeralMarathonRun(player, res)
	-- This function does not exist yet - ephemeral marathon notifications not implemented
	_annotate(string.format("Ephemeral marathon completed for player %d, result: %s", player.UserId, tostring(res)))

	--TODO fix this to update their marathon display.
	-- Ephemeral marathon leaderboard updates not yet implemented
	-- for _, otherPlayer in ipairs(PlayerService:GetPlayers()) do
	-- 	lbUpdaterServer.updateLeaderboardForEphemeralMarathon(otherPlayer, run)
	-- end
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
