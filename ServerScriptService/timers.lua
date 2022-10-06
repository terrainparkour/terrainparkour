--!strict

--timers is about: starting and stopping races, AND also generating very complex text to describe the results
--to the runner and to others.
--eval 9.25.22

local tt = require(game.ReplicatedStorage.types.gametypes)
local enums = require(game.ReplicatedStorage.util.enums)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local signInfo = require(game.ReplicatedStorage.signInfo)
local rdb = require(game.ServerScriptService.rdb)
local banning = require(game.ServerScriptService.banning)
local raceCompleteData = require(game.ServerScriptService.raceCompleteData)
local lbupdater = require(game.ServerScriptService.lbupdater)
local badgeCheckers = require(game.ServerScriptService.badgeCheckersSecret)
local remotes = require(game.ReplicatedStorage.util.remotes)

--the gap before client allows retouch when you finish a run.
local NO_RETOUCH_GAP = 0.8
-- NO_RETOUCH_GAP = 0.0

local module = {}

--map of player:runningRaceStartSignId?
--this is super legacy but does work. single server-side in-memory object tracking currently running races.
--2022.04 refactoring
-- map of the player's currently running race and start time. canonical but also let client know when it changes, so UI there can update.
local playerStatuses: { [number]: { st: number, signId: number } } = {}

local PlayerService = game:GetService("Players")

--for sending messages to the client.
local runStartEvent = remotes.getRemoteEvent("RunStartEvent")
local runEndEvent = remotes.getRemoteEvent("RunEndEvent")
local cancelRunRemoteFunction = remotes.getRemoteFunction("CancelRunRemoteFunction")
-- local delayedStartTimeUpdateEvent = remotes.getRemoteEvent("DelayedStartTimeUpdateEvent")
local clientControlledRunEndEvent = remotes.getRemoteEvent("ClientControlledRunEndEvent")

-- tell marathon client that the user really hit a sign.
-- local hitSignEvent = remotes.getRemoteEvent("HitSignEvent")

--userId:tick for absolute protection from doing any notifyHit within 1s of warping.
local lastWarpTimes: { [number]: number } = {}
local lastTimePlayerHitSign: { [number]: { [string]: number } } = {}

local endingDebouncers: { [number]: boolean } = {}

local doAnnotation = false
local annotationStart = tick()
local function annotate(s: string)
	if doAnnotation then
		print("server.timer: " .. string.format("%.3f", tick() - annotationStart) .. " : " .. s)
	end
end

cancelRunRemoteFunction.OnServerInvoke = function(player: Player)
	return module.cancelRun(player, "cancelRunEvent")
end

module.isRunningRun = function(userId: number)
	if not playerStatuses[userId] then
		return false
	end
	if playerStatuses[userId].st == nil then
		return false
	end
	return true
end

local function isSignDifferentThanCurrentRace(userId: number, signId: number)
	if playerStatuses[userId].st then
		if playerStatuses[userId].signId == signId then
			-- annotate("isSignDifferentThanCurrentRace.false")
			return false
		end
	end
	-- annotate("isSignDifferentThanCurrentRace.true")
	return true
end

--server-side actually cancel.
--is it even possible that warping would double-trigger before this is done? seems impossible.
--user is running race; user does "/rr"; this results in server processing and sending server-cancel call.
--this is relatively independent from the user touching the new sign which happens after.
module.cancelRun = function(player: Player, reason: string)
	-- annotate("cancelRun.reason=" .. reason)

	--pull status out because we are about to clear it.
	local status = playerStatuses[player.UserId]
	if status == nil or status.signId == nil then
		--status should be a running record of player's active race.
		-- annotate("cancelRun.status was nil so can't cancel run")
		return
	end
	playerStatuses[player.UserId] = nil
	-- annotate("cancelRun.reset status. sign was: " .. status.signId)
	--changing this to spawn makes the cancel event on client arrive too late?
	--it's rather important that this be verified from client before clearing s tatus and accepting a new race.

	--do this in a pcall cause it's irrelevant to get a response.
	-- you should have already skipped out cases where they weren't actually in a run yet.
	local s, e = pcall(function()
		local cancellingSignId = status.signId
		--TODO convert this to fireClient.
		--send the name of the sign we're cancelling so we don't kill a just started race.
		-- annotate("cancelRun.fireclient-cancelling signId:" .. cancellingSignId)
		runEndEvent:FireClient(player, cancellingSignId)
	end)
	if not s then
		-- annotate("cancelRun.error in pcall fireclient." .. e)
	else
		-- annotate("cancelRun.success in fireclient.")
	end
	status.st = nil
	status.sign = nil
	-- annotate("cancelRun done.")
end

local function shouldBlockHitDueToWarping(warpTime: number, hitTime: number): boolean
	if warpTime ~= nil then
		local gap = hitTime - warpTime
		if gap < 0.9 then
			-- annotate(" block hit due to recent warp" .. gap)
			return true
		end
		-- annotate(" hit after warp, but long gap. " .. gap)
		return false
	end
	return false
end

--in new trust the client code, just call this directly with the actual details.
--note: it would be nice to retain server-side timing to detect hackers. nearly every one would give themselves away.
local function serverEndRunPromptedByClient(
	player: Player,
	startSignName: string,
	endSignName: string,
	newFind: boolean,
	runMilliseconds: number
)
	if banning.getBanLevel(player.UserId) > 0 then
		return
	end

	local userId = player.UserId
	local startSignId = enums.namelower2signId[startSignName:lower()]
	local endSignId = enums.namelower2signId[endSignName:lower()]
	local startSignPosition = signInfo.getSignPosition(startSignId)
	local endSignPosition = signInfo.getSignPosition(endSignId)
	local distance = (startSignPosition - endSignPosition).magnitude
	local speed = distance / runMilliseconds

	local raceName = startSignName .. " to " .. endSignName
	local spd = math.ceil(speed * 100) / 100

	local userIds = tpUtil.GetUserIdsInServer()

	userIds = table.concat(userIds, ",")

	--this is where we save the time to db, and then continue to display runresults.
	spawn(function()
		local userFinishedRunOptions: tt.userFinishedRunOptions = {
			userId = userId,
			startId = startSignId,
			endId = endSignId,
			runMilliseconds = runMilliseconds,
			otherPlayerUserIds = userIds,
			remoteActionName = "userFinishedRun",
		}
		local userFinishedRunResponse: tt.pyUserFinishedRunResponse = rdb.userFinishedRun(userFinishedRunOptions)
		-- annotate("spawn - before check badge: " .. tostring(userId))

		spawn(function()
			badgeCheckers.checkBadgeGrantingAfterRun(userId, userFinishedRunResponse, startSignId, endSignId)
			--simulate "finding" the start, end
			-- 2022.04 patching this up
			-- badges.checkBadgeGrantingAfterFind(userId, startSignId, userFinishedRunResponse.userTotalFindCount)
			-- badges.checkBadgeGrantingAfterFind(userId, endSignId, userFinishedRunResponse.userTotalFindCount)
		end)

		-- annotate("spawn - showbesttimes for: " .. tostring(userId))
		raceCompleteData.showBestTimes(player, raceName, startSignId, endSignId, spd, newFind, userFinishedRunResponse)
		-- annotate("spawn - preparing datatosend to otherPlayer LB.")
		local lbRunUpdate: tt.lbUpdateFromRun = {
			kind = "lbUpdate from run",
			userId = userId,
			userTix = userFinishedRunResponse.userTix,
			top10s = userFinishedRunResponse.userTotalTop10Count,
			races = userFinishedRunResponse.userTotalRaceCount,
			runs = userFinishedRunResponse.userTotalRunCount,
			userCompetitiveWRCount = userFinishedRunResponse.userCompetitiveWRCount,
			userTotalWRCount = userFinishedRunResponse.userTotalWRCount,
			awardCount = userFinishedRunResponse.awardCount,
		}

		for _, otherPlayer in ipairs(PlayerService:GetPlayers()) do
			lbupdater.updateLeaderboardForRun(otherPlayer, lbRunUpdate)
		end
	end)
	local serverEventBindableEvent = remotes.getBindableEvent("ServerEventBindableEvent")
	local data: tt.serverFinishRunNotifierType = {
		startSignId = startSignId,
		endSignId = endSignId,
		timeMs = runMilliseconds,
		userId = userId,
		username = rdb.getUsernameByUserId(userId),
	}
	serverEventBindableEvent:Fire(data)
	endingDebouncers[userId] = false
end

clientControlledRunEndEvent.OnServerEvent:Connect(
	function(player: Player, startSignName: string, endSignName: string, clientSideTimeMs: number): any
		serverEndRunPromptedByClient(player, startSignName, endSignName, false, clientSideTimeMs)
	end
)

module.notifyWarp = function(userId, timeInTicks)
	if lastWarpTimes[userId] == nil then
		lastWarpTimes[userId] = timeInTicks
		return
	end
	lastWarpTimes[userId] = math.max(lastWarpTimes[userId], timeInTicks)
end

--track the last server touch received event time.
local globalHighestUpdateTick = 0

--track the last update sent to client.
local globalHighestUpdateTickSent = 0

--the idea is that as touch events come in, they will bump up the upper one of these.
--and that at a somewhat lesser time, they'll ping out to client for update there too.

-- tell the race module that a sign has been touched
-- 2022 path goes: local script, hit, tell client race started, client sees UI
-- 2022.04 this is called after debouncing and is guaranteed to be a "new" (from client pov) run start (or end if already running)

-- local rec = tick()
--2022.05 post local timer: this is never called
module.notifyHit = function(sign: Part, player: Player, newFind: boolean, theHitTick: number)
	print("server.timer.notifyHit.shouldNotHappen")
	-- local nn = tick()
	-- print(string.format("gap between NHit calls. %0.4f", nn - rec))
	-- rec = nn
	--store the time this method gets called for use if this is a valid runTime.
	--problems occur if: user warped recently AND they still are marked as having just hit a sign.
	-- annotate("notify Hit from: " .. tostring(player.Name) .. player.Name)
	local userId = player.UserId

	if playerStatuses[userId] ~= nil and playerStatuses[userId].signId ~= nil then
		-- annotate("did hit while running from sign:" .. playerStatuses[userId].sign.Name)
		if shouldBlockHitDueToWarping(lastWarpTimes[userId], theHitTick) then
			return
		end
	end

	--2022 never seen this
	if lastTimePlayerHitSign[userId] == nil then
		-- annotate("notifyHit.set lastTimePlayerHitSign" .. sign.Name)
		lastTimePlayerHitSign[userId] = {}
	end

	local signId = enums.name2signId[sign.Name]

	--we fallthrough if user is already running race from this sign.
	if module.isRunningRun(userId) then --user is ending a race or re-hitting
		-- annotate("notifyHit.isRunning.check.passed")
		if isSignDifferentThanCurrentRace(userId, signId) then
			-- annotate("notifyHit.isRunning.Wasdifferent.EndRun:" .. player.Name)
			if shouldBlockHitDueToWarping(lastWarpTimes[userId], theHitTick) then
				return
			end

			--moved this here to avoid spamming client so much when you stand on a sign.
			-- spawn(function()
			-- 	--2022.04 notify marathon client system that a hit occurred.
			-- 	hitSignEvent:FireClient(player, sign.Name, theHitTick)
			-- end)
			lastTimePlayerHitSign[userId][sign.Name] = theHitTick

			--2022.04 disable this; FINDs are controlled by server, but runs directly call endRun
			-- endRun(player, sign, newFind, theHitTick)
		else --they're running a run, but from the same sign that was just hit.
			--update start time.
			local playerStatus = playerStatuses[userId]
			if playerStatus.st < theHitTick then
				--spawn a thread which will try to update client with start time if needed.
				if theHitTick > globalHighestUpdateTick then
					local lastst = playerStatus.st
					playerStatus.st = math.max(theHitTick, globalHighestUpdateTick)

					--if a thread is not running, start one.
					if globalHighestUpdateTickSent == globalHighestUpdateTick then
						globalHighestUpdateTick = math.max(theHitTick, globalHighestUpdateTick)
						spawn(function()
							wait(0.3)
							if globalHighestUpdateTickSent < globalHighestUpdateTick then
								globalHighestUpdateTickSent = globalHighestUpdateTick
							end
						end)
					else
						-- print("server.no thread, just update.")
						globalHighestUpdateTick = math.max(theHitTick, globalHighestUpdateTick)
					end
				else
					-- print("was not an increase.")
				end
			else
				-- print(string.format("didn't update time by %0.10f", theHitTick - playerStatus.st))
			end
		end
	else --player is starting a new run.
		-- also do debouncing according to this rule: if you last hit this sign within gap, do NOT continue here.
		if lastTimePlayerHitSign[userId] ~= nil then
			if lastTimePlayerHitSign[userId][sign.Name] ~= nil then
				local gap = theHitTick - lastTimePlayerHitSign[userId][sign.Name]
				if gap < NO_RETOUCH_GAP then
					--this is when the player spams server-side hits from standing on a sign while running a race
					-- annotate(string.format("notifyHit.gap small.not start race %0.3f", gap))
					return
				end
			end
		end
		if shouldBlockHitDueToWarping(lastWarpTimes[userId], theHitTick) then
			return
		end

		--TODO is this necessary? -- 2022.04 still wonder this
		if endingDebouncers[player.UserId] then
			warn("incorrectly uncleared ending debouncers.")
			--check under warping, too
		end
		endingDebouncers[player.UserId] = false

		-- spawn(function()
		-- 	--2022.04 notify marathon client system that a hit occurred.
		-- 	hitSignEvent:FireClient(player, sign.Name, theHitTick)
		-- end)

		--setting status.
		playerStatuses[player.UserId] = {
			st = theHitTick,
			signId = signId,
		}

		local signPos = signInfo.getSignPosition(signId)

		local s, e = pcall(function()
			runStartEvent:FireClient(player, signId, signPos, theHitTick)
		end)
		if not s then
			error("startRun event error." .. e)
		else
			annotate("startRun.event okay.")
		end
		annotate("startRun." .. sign.Name .. " done.")
	end
end

return module
