--!strict

--this is about server-wide events particularly FIND and RUNs

local tt = require(game.ReplicatedStorage.types.gametypes)
local enums = require(game.ReplicatedStorage.util.enums)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local remotes = require(game.ReplicatedStorage.util.remotes)
local rdb = require(game.ServerScriptService.rdb)
local serverEventEnums = require(game.ReplicatedStorage.enums.serverEventEnums)
local config = require(game.ReplicatedStorage.config)
local vscdebug = require(game.ReplicatedStorage.vscdebug)
local rdb = require(game.ServerScriptService.rdb)
local PlayersService = game:GetService("Players")
local lbupdater = require(game.ServerScriptService.lbupdater)
local badgeCheckers = require(game.ServerScriptService.badgeCheckersSecret)

local serverEventRemoteEvent = remotes.getRemoteEvent("ServerEventRemoteEvent")
local serverEventRemoteFunction = remotes.getRemoteFunction("ServerEventRemoteFunction")
local serverEventLimitCount = 3

local desc = [[
  serverEvents are:
  anyone clicks a button which creates a random race serverside
  there's a UI which allows warping to start
	which shows time left til serverevent
	which shows rewards amount
  	below/mouseover it it shows CURRENT time interval best times by person
  serverevents die out if nobody interacts for serverEventIdleTimeout
  serverevents are net profitable for users in terms of tix
  the more users participate in an serverevent, the more tix
	tix reward increases for warpers
	and for runners
	and for runcount
  single people doing events is okay, but it gets more profitable if many people do it.
  we track event earnings (in tix) in BE and display it as a new toplevel score metric
]]

--PARAMETERS
local serverEventMaxLength = 750
if config.isInStudio() then
	serverEventMaxLength = 645
end

--STATE TRACKING GLOBALS

local serverEventNumberCounter = 1
local activeRunningServerEvents: { tt.runningServerEvent } = {}

---------ANNOTATION----------------
local doAnnotation = false
doAnnotation = false
local annotationStart = tick()
local function annotate(s: string | any)
	if doAnnotation then
		if typeof(s) == "string" then
			print("serverEvents.: " .. string.format("%.0f", tick() - annotationStart) .. " : " .. s)
		else
			print("serverEvents.object. " .. string.format("%.0f", tick() - annotationStart) .. " : ")
			print(s)
		end
	end
end

--called every 5 seconds, polling on server.
local function shouldEndServerEvent(event: tt.runningServerEvent): boolean
	-- annotate("should end event?: " .. serverEventGuis.replServerEvent(event))
	event.remainingTick = event.startedTick + serverEventMaxLength - tick()

	if event.remainingTick < 0 then
		return true
	end

	return false
end

--used for removing and reating events
local debounceEventUpdater = false
local function endServerEvent(serverEvent: tt.runningServerEvent): boolean
	while debounceEventUpdater do
		wait(1)
		print("waitng to end event.")
	end
	debounceEventUpdater = true
	local pos = nil
	for ii, ev in ipairs(activeRunningServerEvents) do
		if ev.name == serverEvent.name then
			pos = ii
		end
	end
	if pos == nil then
		return false
	end
	table.remove(activeRunningServerEvents, pos)
	debounceEventUpdater = false
	annotate("senidng end from server for: " .. serverEvent.name)
	serverEventRemoteEvent:FireAllClients(serverEventEnums.messageTypes.END, serverEvent)
	local allocations = serverEventEnums.getTixAllocation(serverEvent)

	badgeCheckers.CheckServerEventAllocations(allocations, serverEvent.distance)

	local res = rdb.reportServerEventEnd(serverEvent, allocations)

	if res.userLbStats then
		for _, otherPlayer in ipairs(PlayersService:GetPlayers()) do
			local otherStats = res.userLbStats[tostring(otherPlayer.UserId)]
			if not otherStats then
				continue
			end
			lbupdater.updateLeaderboardForServerEventCompletionRun(otherPlayer, otherStats)
		end
	end
	return true
end

local function setupKiller()
	--event killer monitor
	spawn(function()
		while true do
			for _, serverEvent in ipairs(activeRunningServerEvents) do
				if shouldEndServerEvent(serverEvent) then
					local s, e = pcall(function()
						local res = endServerEvent(serverEvent)
						if not res then
							endServerEvent(serverEvent)
						end
					end)
					if not s then
						print("failure to end even.t")
						warn(e)
					end
				end
			end
			wait(5)
		end
	end)
end

local module = {}

type ServerEventCreateType = { userId: number }

--factors: repeated runs, distance, number of runners.
local function getTixValueOfServerEvent(ev: tt.runningServerEvent): number
	local w1 = 0
	local seenUsers = 0
	for _, bestRunData in pairs(ev.userBests) do
		w1 += math.sqrt(bestRunData.runCount) + 1
		seenUsers += 1
	end
	local distmultipler = 1
	if ev.distance > 1000 then
		distmultipler = math.sqrt(ev.distance / 1000)
	end
	local res = math.floor(w1 * math.sqrt(seenUsers) * distmultipler)
	annotate("new tix value of event. " .. tostring(res))
	annotate(ev)
	return res
end

local function startServerEvent(data: ServerEventCreateType): (tt.runningServerEvent)?
	--pick a random start and randome end, set it up dumbly as possible.
	annotate("startevent " .. tostring(data.userId))
	if #activeRunningServerEvents >= serverEventLimitCount then
		annotate("startevent.over the limit")
		return
	end

	--can only make random runs TO signs which at least one player in the server has found.
	local allFoundSignIds = {}
	local foundSigns = {}
	for _, player in ipairs(PlayersService:GetPlayers()) do
		local finds = rdb.getUserSignFinds(player.UserId)
		for signId, _ in pairs(finds) do
			if not foundSigns[signId] then
				foundSigns[signId] = true
				table.insert(allFoundSignIds, signId)
			end
		end
	end

	local st = tick()

	--for local, and sanity, ALSO filter input signids by existence in the game.
	local signsFolder: Folder = game.Workspace:FindFirstChild("Signs")
	local allSigns: Array<Part> = signsFolder:GetChildren()

	local existingAllFoundSignIds: { number } = {}
	for _, signId in ipairs(allFoundSignIds) do
		local sn = enums.signId2name[signId]
		local exi = signsFolder:FindFirstChild(sn)
		if exi == nil then
			continue
		end
		table.insert(existingAllFoundSignIds, signId)
	end

	local hasShort = false
	local hasMed = false
	local shortDistance = 1150
	local medDistance = 1800

	for _, ev in ipairs(activeRunningServerEvents) do
		if ev.distance < shortDistance then
			hasShort = true
		end
		if ev.distance < medDistance and ev.distance > shortDistance then
			hasMed = true
		end
	end
	local startSignId
	local endSignId
	local dist

	local tries = 0
	--pick among candidates based on length criteria.
	while true do
		tries += 1
		if tries > 100 then
			return nil
		end
		local startSign = nil
		local endSign = nil
		startSignId = 0
		endSignId = 0

		-- pick candidates
		while true do
			local candidateSignId = existingAllFoundSignIds[math.random(1, #existingAllFoundSignIds)]
			if enums.SignIdIsExcludedFromStart[candidateSignId] then
				continue
			end

			startSignId = candidateSignId
			local canSignName = enums.signId2name[startSignId]
			local canSign = signsFolder:FindFirstChild(canSignName)
			startSign = canSign
			break
		end
		while true do
			local canSign = allSigns[math.random(1, #allSigns)]
			local candidateSignId = enums.name2signId[canSign.Name]

			if candidateSignId == startSignId then
				continue
			end

			if enums.SignIdIsExcludedFromEnd[candidateSignId] then
				continue
			end

			endSignId = candidateSignId
			endSign = canSign
			break
		end

		dist = tpUtil.getDist(startSign.Position, endSign.Position)

		--if we need short and it is, keep it.
		if not hasShort then
			if dist < shortDistance then
				break
			else
				continue
			end
		end

		--if we need med and it's not med, skip
		if not hasMed then
			if dist > shortDistance and dist < medDistance then
				break
			else
				continue
			end
		end

		break
	end

	local startSignName = tpUtil.signId2signName(startSignId)
	local endSignName = tpUtil.signId2signName(endSignId)

	local raceName = string.format("xxx%s-%s", startSignName, endSignName)

	local ev: tt.runningServerEvent = {
		name = raceName,
		serverEventNumber = serverEventNumberCounter,
		startedTick = st,
		remainingTick = st + serverEventMaxLength - tick(),
		startSignId = startSignId,
		endSignId = endSignId,
		userBests = {},
		tixValue = 0,
		distance = dist,
	}

	ev.tixValue = getTixValueOfServerEvent(ev)

	table.insert(activeRunningServerEvents, ev)
	serverEventNumberCounter += 1
	return ev
end

--version which returns.
local function serverReceiveFunction(player: Player, message: string, data: any): any
	annotate("receive event " .. message)
	annotate(data)
	if message == serverEventEnums.messageTypes.CREATE then
		data = data :: ServerEventCreateType
		local serverEvent = startServerEvent(data)

		if serverEvent == nil then
			return { message = "Didn't Start Server Event, probably 3 is the max." }
		else
			serverEventRemoteEvent:FireAllClients(serverEventEnums.messageTypes.UPDATE, serverEvent)
			return { message = "Started Server Event" }
		end
	end
end

local function integrateRun(ev: tt.runningServerEvent, data: tt.serverFinishRunNotifierType): boolean
	local changed = false
	--figure out if we need to add or update userbests
	if ev.userBests[data.userId] == nil then
		ev.userBests[data.userId] = {
			userId = data.userId,
			username = data.username,
			timeMs = data.timeMs,
			runCount = 1,
		}
		changed = true
	else
		changed = true
		ev.userBests[data.userId].runCount += 1
		if ev.userBests[data.userId].timeMs > data.timeMs then
			ev.userBests[data.userId].timeMs = data.timeMs
		end
	end
	local newTixValue = getTixValueOfServerEvent(ev)
	if newTixValue > ev.tixValue then
		ev.tixValue = newTixValue
		changed = true
	end
	ev.remainingTick = ev.startedTick + serverEventMaxLength - tick()
	return changed
end

local function receiveRunFinishFromServer(data: tt.serverFinishRunNotifierType)
	while debounceEventUpdater do
		wait(1)
		print("waint for debouncEventUpdater")
	end
	debounceEventUpdater = true
	for _, ev in ipairs(activeRunningServerEvents) do
		if ev.startSignId == data.startSignId and ev.endSignId == data.endSignId then
			local anythingChanged = integrateRun(ev, data)
			if anythingChanged then
				--just send out full ev again.
				--TODO this is highly non-optimized.
				--not only do we send full serverEvent info again, we send it even when top8 or whatever doesn't change.
				--but, given tix updating maybe that's okay.
				serverEventRemoteEvent:FireAllClients(serverEventEnums.messageTypes.UPDATE, ev)
			end
			--splice it in.
			--if anything changed,
		end
	end
	-- print(data)
	debounceEventUpdater = false
end

module.init = function()
	annotate("setup serverEvents")
	setupKiller()
	--listen to client events
	--set up events to talk to client

	--using generic event names with a router here.

	serverEventRemoteFunction.OnServerInvoke = serverReceiveFunction

	--TEMP disable
	local serverEventBindableEvent = remotes.getBindableEvent("ServerEventBindableEvent")
	serverEventBindableEvent.Event:Connect(receiveRunFinishFromServer)
	annotate("setup serverEvents.done")
end

return module
