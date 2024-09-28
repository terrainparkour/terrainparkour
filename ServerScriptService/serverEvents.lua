--!strict

-- serverEvents.lua server-side listening for the random races feature.
-- they're stored in memory of the game server.
-- this is about server-wide events particularly FIND and RUNs

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local tt = require(game.ReplicatedStorage.types.gametypes)
local enums = require(game.ReplicatedStorage.util.enums)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local remotes = require(game.ReplicatedStorage.util.remotes)
local serverEventEnums = require(game.ReplicatedStorage.enums.serverEventEnums)
local config = require(game.ReplicatedStorage.config)
local rdb = require(game.ServerScriptService.rdb)

local playerData2 = require(game.ServerScriptService.playerData2)
local lbUpdaterServer = require(game.ServerScriptService.lbUpdaterServer)
local badgeCheckers = require(game.ServerScriptService.badgeCheckersSecret)

local PlayersService = game:GetService("Players")

local ServerEventRemoteEvent = remotes.getRemoteEvent("ServerEventRemoteEvent")
local ServerEventRemoteFunction = remotes.getRemoteFunction("ServerEventRemoteFunction")

--------------------- STATICS -------------------
local serverEventLimitCount = 3

--------------- GLOBALS ----------------------
local debounceEventUpdater = false
local serverEventMaxLength = 750
if config.isInStudio() then
	serverEventMaxLength = 645
end
local serverEventNumberCounter = 1
local activeRunningServerEvents: { tt.runningServerEvent } = {}

local _desc = [[
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

  QUESTION: how do clients find out about server events? we send events to them.
	Update 2024: we need to modify them so that when a user gets the event, we also
	tell them if they have found the target sign
	SO that we can temporarily highlight it in their UI. Users are going to love this!
	more generally, we are adding that capacity to warper generally, so that when you warp,
	there can be an optional highlight target signId.
]]

-- called every 5 seconds, polling on server.
local function shouldEndServerEvent(event: tt.runningServerEvent): boolean
	event.remainingTick = event.startedTick + serverEventMaxLength - tick()

	if event.remainingTick < 0 then
		return true
	end

	return false
end

local reportServerEventEnd = function(ev: tt.runningServerEvent, allocations)
	local request: tt.postRequest = {
		remoteActionName = "reportServerEventEnd",
		data = { ev = ev, allocations = allocations },
	}
	local res = rdb.MakePostRequest(request)
	return res
end

local function endServerEvent(serverEvent: tt.runningServerEvent): boolean
	while debounceEventUpdater do
		wait(1)
		_annotate("waitng to end event.")
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
	_annotate("senidng end from server for: " .. serverEvent.name)
	ServerEventRemoteEvent:FireAllClients(serverEventEnums.messageTypes.END, serverEvent)
	local allocations = serverEventEnums.getTixAllocation(serverEvent)

	badgeCheckers.CheckServerEventAllocations(allocations, serverEvent.distance)

	local res = reportServerEventEnd(serverEvent, allocations)
	return true
end

local function setupRunningServerEventKiller()
	--event killer monitor
	task.spawn(function()
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
						_annotate("failure to end even.t")
						warn(e)
					end
				end
			end
			wait(5)
		end
	end)
end

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
	_annotate("new tix value of event. " .. tostring(res), ev)
	return res
end

local function startServerEvent(data: tt.ServerEventCreateType): tt.runningServerEvent | nil
	--pick a random start and randome end, set it up dumbly as possible.
	_annotate("startevent " .. tostring(data.userId))
	if #activeRunningServerEvents >= serverEventLimitCount then
		_annotate("startevent.over the limit")
		return
	end

	--can only make random runs TO signs which at least one player in the server has found.
	local allFoundSignIds = {}
	local foundSigns = {}
	for _, player in ipairs(PlayersService:GetPlayers()) do
		local finds = playerData2.GetUserSignFinds(player.UserId, "startServerEvent")
		for signId, _ in pairs(finds) do
			if not foundSigns[signId] then
				foundSigns[signId] = true
				table.insert(allFoundSignIds, signId)
				--ah at least we just do each one once, not all finds by all players.
			end
		end
	end

	local st = tick()

	--for local, and sanity, ALSO filter input signids by existence in the game
	-- AND by cancollide and canX
	local signsFolder: Folder = game.Workspace:FindFirstChild("Signs") :: Folder
	local allSigns: { Part } = {}
	for _, sign: Instance in ipairs(signsFolder:GetChildren()) do
		if not tpUtil.SignCanBeHighlighted(sign) then
			continue
		end
		table.insert(allSigns, sign)
	end

	local existingAllFoundSignIds: { number } = {}
	for _, signId in ipairs(allFoundSignIds) do
		local sn = enums.signId2name[signId]
		if sn == nil then
			continue
		end
		local exi = signsFolder:FindFirstChild(sn)
		if exi == nil then
			continue
		end
		if not tpUtil.SignCanBeHighlighted(exi) then
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
		local startSign: Part? = nil
		local endSign: Part? = nil
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
			local canSign = signsFolder:FindFirstChild(canSignName) :: Part
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
		if startSign == nil or endSign == nil then
			continue
		end
		dist = tpUtil.getDist(startSign.Position, endSign.Position)

		--if we need short and it is, keep it.
		if not hasShort then
			if dist < shortDistance or config.isTestGame() then
				break
			else
				continue
			end
		end

		--if we need med and it's not med, skip
		if not hasMed then
			if (dist > shortDistance and dist < medDistance) or config.isTestGame() then
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
local function serverReceiveFunction(player: Player, message: string, data: tt.ServerEventCreateType)
	_annotate("receive event " .. message, data)
	--hhmm maybe overkill here, but why not just periodally

	if message == serverEventEnums.messageTypes.CREATE then
		local serverEvent = startServerEvent(data)
		if serverEvent == nil then
			return { message = "Didn't Start Server Event, probably 3 is the max." }
		else
			ServerEventRemoteEvent:FireAllClients(serverEventEnums.messageTypes.UPDATE, { serverEvent })
			return { message = "Started Server Event" }
		end
	elseif message == serverEventEnums.messageTypes.CONNECT then
		ServerEventRemoteEvent:FireClient(player, serverEventEnums.messageTypes.UPDATE, activeRunningServerEvents)
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
		_annotate("waint for debouncEventUpdater")
	end
	debounceEventUpdater = true
	for _, serverEvent in ipairs(activeRunningServerEvents) do
		if serverEvent.startSignId == data.startSignId and serverEvent.endSignId == data.endSignId then
			local anythingChanged = integrateRun(serverEvent, data)
			if anythingChanged then
				--just send out full ev again.
				--TODO this is highly non-optimized.
				--not only do we send full serverEvent info again, we send it even when top8 or whatever doesn't change.
				--but, given tix updating maybe that's okay.
				ServerEventRemoteEvent:FireAllClients(serverEventEnums.messageTypes.UPDATE, { serverEvent })
			end
			--splice it in.
			--if anything changed,
		end
	end
	debounceEventUpdater = false
end

module.Init = function()
	_annotate("setup serverEvents")
	setupRunningServerEventKiller()
	ServerEventRemoteFunction.OnServerInvoke = function(player: Player, message: string, data: any): any
		return serverReceiveFunction(player, message, data)
	end
	local ServerEventBindableEvent = remotes.getBindableEvent("ServerEventBindableEvent")
	ServerEventBindableEvent.Event:Connect(receiveRunFinishFromServer)
	_annotate("setup serverEvents.done")
end

_annotate("end")
return module
