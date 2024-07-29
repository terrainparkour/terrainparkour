--!strict

--2022.02.13 split it from main leaderboard code.
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

-- local enums = require(game.ReplicatedStorage.util.enums)
local colors = require(game.ReplicatedStorage.util.colors)
local avatarEventFiring = require(game.StarterPlayer.StarterPlayerScripts.avatarEventFiring)
local fireEvent = avatarEventFiring.FireEvent
local marathonstatic = require(game.StarterPlayer.StarterCharacterScripts.marathon["marathon.static"])

local lbMarathonRowY = 18
local remotes = require(game.ReplicatedStorage.util.remotes)

local marathonTypes = require(game.StarterPlayer.StarterCharacterScripts.marathon.marathonTypes)
local mt = require(game.ReplicatedStorage.avatarEventTypes)

local joinableMarathonKinds: { marathonTypes.marathonDescriptor } = {}

local marathonCompleteEvent = remotes.getRemoteEvent("MarathonCompleteEvent")
local ephemeralMarathonCompleteEvent = remotes.getRemoteEvent("EphemeralMarathonCompleteEvent")
local PlayersService = game:GetService("Players")

------------------------ GLOBALS ------------------------

local disabledMarathons = {}
--blocker to confirm the user has completed warp
local canDoMarathonStuff = true
local isMarathonBlockedByWarp = false

if marathonCompleteEvent == nil or ephemeralMarathonCompleteEvent == nil then
	warn("FAIL")
end

--just re-get the outer lbframe by name.
local function getLbFrame(): Frame
	local pl = PlayersService.LocalPlayer:WaitForChild("PlayerGui")
	local ret = pl:FindFirstChild("LeaderboardFrame", true)
	if ret == nil then
		warn("no lb")
	end
	return ret
end

local function startMarathonRunTimer(desc: marathonTypes.marathonDescriptor, baseTime: number)
	desc.startTime = baseTime
	if desc.runningTimeTileUpdater then
		-- _annotate("runtimer.not start for." .. desc.kind)
		return
	end

	--loop spawn to measure timing for a marathon
	task.spawn(function()
		-- _annotate("runtimer.start for." .. desc.kind)
		desc.runningTimeTileUpdater = true
		while true do
			if desc.killTimerSemaphore then
				-- _annotate("runtimer.break for." .. desc.kind)
				desc.killTimerSemaphore = false
				desc.runningTimeTileUpdater = false
				break
			end
			wait(1 / 3.1)
			local gap = tick() - baseTime
			desc.timeTile.Text = string.format("%0.0f", gap)
		end
	end)
end

local function stopTimerForKind(desc: marathonTypes.marathonDescriptor): boolean
	-- _annotate("stopTimerForKind.start." .. desc.kind)
	if not desc.runningTimeTileUpdater then
		-- _annotate("stopTimerForKind.was not running." .. desc.kind)
		return true
	end
	-- _annotate("stopTimerForKind.set semaphore." .. desc.kind)
	desc.killTimerSemaphore = true --wait til the timer catches this and dies.
	local ii = 0
	while true do
		ii += 1
		wait(1 / 25.1)
		if not desc.runningTimeTileUpdater then
			return true
		end
		if ii > 20 then --TODO this is a hack.
			desc.runningTimeTileUpdater = false
			return true
		end
	end
end

local function resetMarathonProgress(desc: marathonTypes.marathonDescriptor)
	stopTimerForKind(desc)
	module.InitMarathonVisually(desc)
	desc.startTime = nil
	desc.killTimerSemaphore = false
	desc.count = 0
	desc.finds = {}
	desc.addDebounce = {}

	-- _annotate("resetMarathon.end." .. desc.kind)
end

--get or create frame; swap out the tiles with new ones.
--does it do deduplication?
module.InitMarathonVisually = function(desc: marathonTypes.marathonDescriptor)
	_annotate("initMarathonVisually.start." .. desc.highLevelType .. "_" .. desc.sequenceNumber)

	local frameName = marathonstatic.getMarathonKindFrameName(desc)
	_annotate("init visual marathon: " .. frameName)
	local exi: Frame = getLbFrame():FindFirstChild(frameName)
	if exi == nil then
		--this happens the first time you start a marathon from client-side.
		exi = Instance.new("Frame")
		exi.BorderMode = Enum.BorderMode.Inset
		exi.BorderSizePixel = 0
		exi.Name = frameName
		exi.Size = UDim2.new(1, 0, 0, lbMarathonRowY)
		exi.Parent = getLbFrame()
	end
	--swap out tiles
	local tiles = marathonstatic.getMarathonInnerTiles(desc, getLbFrame().AbsoluteSize)
	for _, tile in ipairs(tiles) do
		local exiTile = exi:FindFirstChild(tile.Name)
		if exiTile ~= nil then
			exiTile:Destroy()
		end
		tile.Parent = exi
	end
	local resetTile = marathonstatic.getMarathonResetTile(desc)
	local exiTile = exi:FindFirstChild(resetTile.Name)
	if exiTile ~= nil then
		exiTile:Destroy()
	end
	resetTile.Activated:Connect(function()
		-- _annotate("resetTile.clicked.")
		resetMarathonProgress(desc)
		-- _annotate("resetTile.done")
	end)
	resetTile.Parent = exi

	exi.Parent = getLbFrame()
end

--restore tile to marathon finish time.
local function updateTimeTileForKindToCompletion(runMilliseconds: number, timeTile: TextLabel)
	timeTile.Text = string.format("%0.3f", runMilliseconds / 1000.0)
	timeTile.BackgroundColor3 = colors.blueDone
end

--kill the ongoing update timer.  set  the final time and background blue.
local function finishMarathonVisually(
	desc: marathonTypes.marathonDescriptor,
	runMilliseconds: number,
	marathonRow: Frame
)
	-- _annotate("finishMarathonVisually.start." .. desc.kind)
	stopTimerForKind(desc)
	updateTimeTileForKindToCompletion(runMilliseconds, desc.timeTile)
	-- _annotate("finishMarathonVisually.end." .. desc.kind)
end

--handle the juggling of marathonKindFinds keys and stuff.
local function tellDescAboutFind(
	desc: marathonTypes.marathonDescriptor,
	signName: string
): marathonTypes.userFoundSignResult
	if desc.addDebounce[signName] then
		return { added = false, marathonDone = false, started = false }
	end
	desc.addDebounce[signName] = true
	--special exclusion case:
	--if the timer is NOT running but we are done.
	if not desc.runningTimeTileUpdater then --not being updated atm.
		if desc.count ~= nil and desc.count > 0 then
			--note that this will spam logs for hitting sign 20 times while first one is being processed
			-- _annotate("dofind.skipping find due to marathon being done. kind" .. desc.kind)
			return { added = false, marathonDone = false, started = false }
		end
	end

	if desc.count == nil then
		desc.count = 0
	end

	local ret = desc.EvaluateFind(desc, signName)
	desc.addDebounce[signName] = false
	return ret
end

local function reportEphemeralMarathonResults(desc: marathonTypes.marathonDescriptor, runMilliseconds)
	local orderedSignIds = desc.SummarizeResults(desc)
	local joined = table.concat(orderedSignIds, ",")
	local s, e = pcall(function()
		ephemeralMarathonCompleteEvent:FireServer(desc.kind, joined, runMilliseconds)
	end)
	if not s then
		warn(e)
	end
end

--look in the datastores and figure out something to upload to the endpoint.
--can require munging aound
local function reportMarathonResults(desc: marathonTypes.marathonDescriptor, runMilliseconds)
	local reportingSignIds = desc.SummarizeResults(desc)
	local joined = table.concat(reportingSignIds, ",")
	local s, e = pcall(function()
		marathonCompleteEvent:FireServer(desc.kind, joined, runMilliseconds)
	end)
	if not s then
		warn(e)
	end
end

--receive a touch on a sign for a given marathon.
local function innerReceiveHit(desc: marathonTypes.marathonDescriptor, signName: string, innerTick: number)
	local res = tellDescAboutFind(desc, signName)
	if res == nil then
		warn("NIL")
		return
	end
	if not res.added then
		return
	end
	-- _annotate("innerReceiveHit.signName=" .. signName .. " kind=" .. desc.kind)
	-- _annotate("innerReceiveHit.added?" .. tostring(res.added))
	-- _annotate("innerReceiveHit.marathonDone?" .. tostring(res.marathonDone))
	-- _annotate("innerReceiveHit.started?" .. tostring(res.started))

	local frameName = marathonstatic.getMarathonKindFrameName(desc)
	local marathonRow: Frame = getLbFrame():FindFirstChild(frameName)

	--marathon has been killed in UI.
	if marathonRow == nil then
		return
	end

	--NOTE: Why do this here, separated, not above in evaluateFind?
	desc.UpdateRow(desc, marathonRow, signName)
	--previously this also initialized them visually.

	if res.started then
		-- _annotate("innerReceiveHit.res-started.start")
		startMarathonRunTimer(desc, innerTick)
		-- _annotate("innerReceiveHit.res-started.end")
	end

	if res.marathonDone then
		-- _annotate("innerReceiveHit.marathonDone.start")
		local completionTime = innerTick - desc.startTime
		local runMilliseconds = math.round(completionTime * 1000)
		finishMarathonVisually(desc, runMilliseconds, marathonRow)
		if desc.highLevelType == "randomrace" then
			reportEphemeralMarathonResults(desc, runMilliseconds)
		else
			reportMarathonResults(desc, runMilliseconds)
		end
		-- _annotate("innerReceiveHit.marathonDone.end")
	end
	-- _annotate("innerReceiveHit.end")
end

module.receiveHit = function(signName: string, innerTick: number)
	if not canDoMarathonStuff or isMarathonBlockedByWarp then
		return
	end
	for _, desc: marathonTypes.marathonDescriptor in ipairs(joinableMarathonKinds) do
		innerReceiveHit(desc, signName, innerTick)
	end
end

--BOTH tell the system that the setting value is this, AND init it visually.
module.InitMarathon = function(desc: marathonTypes.marathonDescriptor, forceDisplay: boolean)
	local intable = false
	for _, joinable in ipairs(joinableMarathonKinds) do
		if joinable.humanName == desc.humanName then
			intable = true
			break
		end
	end
	-- _annotate("marathon.init.start")
	resetMarathonProgress(desc)
	if not intable then
		table.insert(joinableMarathonKinds, desc)
	end
	-- _annotate("marathon.init.end" .. desc.kind)
	if forceDisplay then
		module.InitMarathonVisually(desc)
	end
end

--disable from the UI
module.DisableMarathon = function(desc: marathonTypes.marathonDescriptor)
	local target = 0
	for ii, d in pairs(joinableMarathonKinds) do
		if d.humanName == desc.humanName then
			target = ii
			break
		end
	end
	if target == 0 then
		-- _annotate(string.format("marathon.disable: could not find %s %s", desc.kind, desc.humanName))
		return
	end
	resetMarathonProgress(desc)
	local frameName = marathonstatic.getMarathonKindFrameName(desc)
	local exi: Frame = getLbFrame():FindFirstChild(frameName)
	if exi ~= nil then
		exi:Destroy()
	end
	_annotate(string.format("marathon.disabled:%s", desc.kind))
	table.remove(joinableMarathonKinds, target)
end

module.CloseAllMarathons = function()
	while #joinableMarathonKinds > 0 do
		local item = joinableMarathonKinds[1]
		module.DisableMarathon(item)
		table.insert(disabledMarathons, item)
		--hold marathons enabled from settings in here, so that when lb is reenabled, they show up again.
	end
end

--this should reinit marathons based on active current settings.
module.ReInitActiveMarathons = function()
	--restore the holder from settings
	joinableMarathonKinds = disabledMarathons
	disabledMarathons = {}
	for _, joinable in ipairs(joinableMarathonKinds) do
		module.InitMarathonVisually(joinable)
	end
end

local function receiveAvatarEvent(ev: mt.avatarEvent)
	if ev.eventType == mt.avatarEventTypes.GET_READY_FOR_WARP then
		isMarathonBlockedByWarp = true
		for _, desc: marathonTypes.marathonDescriptor in ipairs(joinableMarathonKinds) do
			resetMarathonProgress(desc)
		end
		fireEvent(mt.avatarEventTypes.MARATHON_WARPER_READY, {})
		return
	elseif ev.eventType == mt.avatarEventTypes.WARP_DONE then
		for _, desc: marathonTypes.marathonDescriptor in ipairs(joinableMarathonKinds) do
			resetMarathonProgress(desc)
		end
		isMarathonBlockedByWarp = false
		return
	elseif ev.eventType == mt.avatarEventTypes.CHARACTER_REMOVING then
		canDoMarathonStuff = false
	end
end

-- when user warps, kill outstanding marathons.
module.Init = function()
	disabledMarathons = {}
	--blocker to confirm the user has completed warp
	canDoMarathonStuff = true
	isMarathonBlockedByWarp = false
	local AvatarEventBindableEvent: BindableEvent = remotes.getBindableEvent("AvatarEventBindableEvent")
	AvatarEventBindableEvent.Event:Connect(receiveAvatarEvent)
end

_annotate("end")

return module
