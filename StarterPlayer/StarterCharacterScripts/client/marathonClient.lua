--!strict

--2022.02.13 split it from main leaderboard code.
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local tt = require(game.ReplicatedStorage.types.gametypes)
local aet = require(game.ReplicatedStorage.avatarEventTypes)
local mt = require(game.StarterPlayer.StarterPlayerScripts.marathon.marathonTypes)
local mds = require(game.ReplicatedStorage.marathon.marathonDescriptors)

local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)
local colors = require(game.ReplicatedStorage.util.colors)
local avatarEventFiring = require(game.StarterPlayer.StarterPlayerScripts.avatarEventFiring)
local fireEvent = avatarEventFiring.FireEvent
local marathonStatic = require(game.ReplicatedStorage.marathon.marathonStatic)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local textUtil = require(game.ReplicatedStorage.util.textUtil)

-- local lbMarathonRowY = 18
local remotes = require(game.ReplicatedStorage.util.remotes)
local toolTip = require(game.ReplicatedStorage.gui.toolTip)
local settings = require(game.ReplicatedStorage.settings)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)

local marathonCompleteEvent = remotes.getRemoteEvent("MarathonCompleteEvent")
local ephemeralMarathonCompleteEvent = remotes.getRemoteEvent("EphemeralMarathonCompleteEvent")
local PlayersService = game:GetService("Players")
local Players = game:GetService("Players")
local localPlayer: Player = Players.LocalPlayer
local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid

----------------- EVENTS ----------------
local AvatarEventBindableEvent: BindableEvent = remotes.getBindableEvent("AvatarEventBindableEvent")

------------------ GLOBAL STATE VARIABLES -----------------------
local joinableMarathonKinds: { mt.marathonDescriptor } = {}

-- warp monitoring
local isMarathonBlockedByWarp = false

local getMarathonKindFrameName = function(desc: mt.marathonDescriptor): string
	local targetName = "MarathonFrame_" .. desc.highLevelType .. "_" .. desc.sequenceNumber
	return targetName
end

------------------ UTIL ,  SIZING -----------------

--just re-get the outer lbframe by name.
local function getMarathonContentFrame(): Frame
	local pl = PlayersService.LocalPlayer:WaitForChild("PlayerGui")
	return pl:FindFirstChild("content_marathons", true)
end

local function setMarathonSize()
	local marathonContentFrame: Frame = getMarathonContentFrame()
	if marathonContentFrame == nil then
		return
	end
	local marathonOuterFrame: Frame = marathonContentFrame.Parent
	marathonOuterFrame.Size = UDim2.new(
		marathonOuterFrame.Size.Width.Scale,
		marathonOuterFrame.Size.Width.Offset,
		0,
		18 * #joinableMarathonKinds
	)

	-- Use GetChildren() instead of manually iterating through children
	local anyMarathons = false
	local theMarathons = {}
	for _, singleMarathonFrame: Frame in ipairs(marathonContentFrame:GetChildren()) do
		if singleMarathonFrame:IsA("Frame") then
			table.insert(theMarathons, singleMarathonFrame)
		end
	end

	for _, singleMarathonFrame: Frame in pairs(theMarathons) do
		singleMarathonFrame.Size = UDim2.new(1, 0, 1 / #theMarathons, 0)
		anyMarathons = true
	end

	local par = marathonContentFrame.Parent :: Frame
	par.Visible = anyMarathons
	if par.Visible then
		par.Position = UDim2.new(0.60, 0, 0.5, 0)
	end
end

----------------------FUNCTIONS -----------------------

local function startMarathonRunTimer(desc: mt.marathonDescriptor, baseTime: number)
	desc.startTime = baseTime
	if desc.runningTimeTileUpdater then
		return
	end

	--loop spawn to measure timing for a marathon
	task.spawn(function()
		desc.runningTimeTileUpdater = true
		while true do
			if desc.killTimerSemaphore then
				desc.killTimerSemaphore = false
				desc.runningTimeTileUpdater = false
				break
			end
			wait(1 / 3.1)
			local gap = tick() - baseTime
			desc.timeTile.Text = string.format("%0.0f", gap)
			_annotate("stuck in startMarathonRunTimer")
		end
	end)
end

local function stopTimerForKind(desc: mt.marathonDescriptor): boolean
	if not desc.runningTimeTileUpdater then
		_annotate("stopTimerForKind.was not running." .. desc.kind)
		return true
	end
	_annotate("stopTimerForKind.start." .. desc.kind)
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
		_annotate("stuck in stopTimerForKind")
	end
end

local function resetMarathonProgress(desc: mt.marathonDescriptor)
	stopTimerForKind(desc)
	desc.startTime = nil
	desc.killTimerSemaphore = false
	desc.count = 0
	desc.finds = {}
	desc.addDebounce = {}

	_annotate("resetMarathon.end." .. desc.kind)
end

local function getMarathonHH()
	local hh = Instance.new("UIListLayout")
	hh.FillDirection = Enum.FillDirection.Horizontal
	hh.Name = "MarathonInnerTiles.hh"
	hh.HorizontalFlex = Enum.UIFlexAlignment.Fill
	return hh
end

local function getNameTileWidth(name: string): number
	local nameChars = string.len(name)
	local expect = 8 * nameChars
	return math.max(10 * 22)
end

local function getNameTile(name: string): TextLabel
	local fakeParent = Instance.new("Frame")

	local namePixX = getNameTileWidth(name)
	local nameTile: TextLabel = guiUtil.getTl(
		"00-marathonName",
		UDim2.new(0, namePixX, 1, 0),
		1,
		fakeParent,
		colors.defaultGrey,
		1,
		0,
		Enum.AutomaticSize.None
	)
	nameTile.Text = name
	return nameTile.Parent
end

local function getTimeTile(kind: string)
	--moved this to inside here.
	local timeTile = Instance.new("TextLabel")
	timeTile.Name = "03-TimeTile" .. kind
	timeTile.Text = ""
	timeTile.AutomaticSize = Enum.AutomaticSize.None
	timeTile.BackgroundColor3 = colors.meColor
	timeTile.TextScaled = true
	timeTile.Size = UDim2.new(0, 40, 1, 0)
	timeTile.Font = Enum.Font.Gotham
	return timeTile
end

local function getResetTile(kind: string)
	local resetTile = Instance.new("TextButton")
	resetTile.Name = "99-resetTile" .. kind
	resetTile.Text = "R"
	resetTile.TextScaled = true
	resetTile.BackgroundColor3 = colors.redStop
	resetTile.Size = UDim2.new(0, 30, 1, 0)
	return resetTile
end

--get or create frame; swap out the tiles with new ones.
--does it do deduplication?
module.InitMarathonVisually = function(desc: mt.marathonDescriptor)
	_annotate("initMarathonVisually.start." .. desc.highLevelType .. "_" .. desc.sequenceNumber)
	local marathonContentFrame = getMarathonContentFrame()
	if not marathonContentFrame then
		_annotate("no content frame??")
		return
	end
	local thisMarathonFrameName = getMarathonKindFrameName(desc)
	local thisMarathonFrame = marathonContentFrame:FindFirstChild(thisMarathonFrameName)

	if thisMarathonFrame == nil then
		_annotate("init visual marathon: " .. desc.humanName)
		--this happens the first time you start a marathon from client-side.
		thisMarathonFrame = Instance.new("Frame")
		thisMarathonFrame.BorderMode = Enum.BorderMode.Inset
		thisMarathonFrame.BorderSizePixel = 0
		thisMarathonFrame.Name = thisMarathonFrameName
		thisMarathonFrame.Parent = marathonContentFrame
	end
	for _, oldTile in pairs(thisMarathonFrame:GetChildren()) do
		oldTile:Destroy()
	end

	local nameTile = getNameTile(desc.humanName)
	toolTip.setupToolTip(nameTile, desc.hint, toolTip.enum.toolTipSize.NormalText)
	nameTile.Parent = thisMarathonFrame

	local chipFrame = marathonStatic.getChipFrame(desc)
	chipFrame.Parent = thisMarathonFrame

	local timeTile = getTimeTile(desc.kind)
	desc.timeTile = timeTile
	timeTile.Parent = thisMarathonFrame

	local resetTile = getResetTile(desc.kind)
	resetTile.Activated:Connect(function()
		resetMarathonProgress(desc)
		module.InitMarathonVisually(desc)
	end)
	resetTile.Parent = thisMarathonFrame

	local hh = getMarathonHH()
	hh.Parent = thisMarathonFrame

	setMarathonSize()
end

--restore tile to marathon finish time.
local function updateTimeTileForKindToCompletion(runMilliseconds: number, timeTile: TextLabel)
	timeTile.Text = string.format("%0.3f", runMilliseconds / 1000.0)
	timeTile.BackgroundColor3 = colors.blueDone
end

--kill the ongoing update timer.  set  the final time and background blue.
local function finishMarathonVisually(desc: mt.marathonDescriptor, runMilliseconds: number, marathonRow: Frame)
	stopTimerForKind(desc)
	updateTimeTileForKindToCompletion(runMilliseconds, desc.timeTile)
	_annotate("finishMarathonVisually.end." .. desc.kind)
end

--handle the juggling of marathonKindFinds keys and stuff.
local function tellDescAboutFind(desc: mt.marathonDescriptor, signName: string): mt.userFoundSignResult
	if desc.addDebounce[signName] then
		return { added = false, marathonDone = false, started = false }
	end
	desc.addDebounce[signName] = true
	--special exclusion case:
	--if the timer is NOT running but we are done.
	if not desc.runningTimeTileUpdater then --not being updated atm.
		if desc.count ~= nil and desc.count > 0 then
			--note that this will spam logs for hitting sign 20 times while first one is being processed
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

local function reportEphemeralMarathonResults(desc: mt.marathonDescriptor, runMilliseconds)
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
local function reportMarathonResults(desc: mt.marathonDescriptor, runMilliseconds)
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
local function innerReceiveHit(desc: mt.marathonDescriptor, signName: string, innerTick: number)
	local res = tellDescAboutFind(desc, signName)
	if res == nil then
		warn("NIL")
		return
	end
	if not res.added then
		return
	end

	local frameName = getMarathonKindFrameName(desc)
	local marathonFrame = getMarathonContentFrame()
	if not marathonFrame then
		_annotate("no marathon Frame.")
		return
	end
	local marathonRow: Frame = marathonFrame:FindFirstChild(frameName)

	--marathon has been killed in UI.
	if marathonRow == nil then
		_annotate("no row?")
		return
	end

	--NOTE: Why do this here, separated, not above in evaluateFind?
	desc.UpdateRow(desc, marathonRow, signName)
	--previously this also initialized them visually.

	if res.started then
		startMarathonRunTimer(desc, innerTick)
	end

	if res.marathonDone then
		local completionTime = innerTick - desc.startTime
		local runMilliseconds = math.round(completionTime * 1000)
		finishMarathonVisually(desc, runMilliseconds, marathonRow)
		if desc.highLevelType == "randomrace" then
			reportEphemeralMarathonResults(desc, runMilliseconds)
		else
			reportMarathonResults(desc, runMilliseconds)
		end
	end
end

module.receiveHit = function(signName: string, innerTick: number)
	if isMarathonBlockedByWarp then
		return
	end
	for _, desc: mt.marathonDescriptor in ipairs(joinableMarathonKinds) do
		task.spawn(function()
			innerReceiveHit(desc, signName, innerTick)
		end)
	end
end

--BOTH tell the system that the setting value is this, AND init it visually.
local deb = false
local initMarathon = function(desc: mt.marathonDescriptor)
	while deb do
		_annotate("initMarathon debouncer wait.")
		task.wait(0.1)
	end
	deb = true
	local intable = false
	for _, joinable in ipairs(joinableMarathonKinds) do
		if joinable.humanName == desc.humanName then
			intable = true
			break
		end
	end

	--only if its not already initialized.
	if not intable then
		table.insert(joinableMarathonKinds, desc)
		resetMarathonProgress(desc)
		module.InitMarathonVisually(desc)
	end
	deb = false
end

--disable from the UI
local disableMarathon = function(desc: mt.marathonDescriptor)
	local target = 0
	for ii, d in pairs(joinableMarathonKinds) do
		if d.humanName == desc.humanName then
			target = ii
			break
		end
	end
	if target == 0 then
		return
	end
	resetMarathonProgress(desc)
	local frameName = getMarathonKindFrameName(desc)
	local marathonContentFrame = getMarathonContentFrame()
	while true do
		if marathonContentFrame ~= nil then
			break
		end
		marathonContentFrame = getMarathonContentFrame()
		task.wait(1)
		_annotate("W")
	end
	local exi: Frame = marathonContentFrame:FindFirstChild(frameName)
	if exi ~= nil then
		exi:Destroy()
	end

	table.remove(joinableMarathonKinds, target)
	setMarathonSize()
	_annotate(string.format("marathon.disabled:%s", desc.kind))
end

module.CloseAllMarathons = function()
	while #joinableMarathonKinds > 0 do
		local item = joinableMarathonKinds[1]
		disableMarathon(item)
		--hold marathons enabled from settings in here, so that when lb is reenabled, they show up again.
	end
end

local eventsWeCareAbout = {
	aet.avatarEventTypes.GET_READY_FOR_WARP,
	aet.avatarEventTypes.WARP_DONE_RESTART_MARATHONS,
}

local marathonClientReceiveAvatarEventDebouncer = false
local function handleAvatarEvent(ev: aet.avatarEvent)
	if not avatarEventFiring.EventIsATypeWeCareAbout(ev, eventsWeCareAbout) then
		return
	end
	_annotate("received " .. avatarEventFiring.DescribeEvent(ev))
	while marathonClientReceiveAvatarEventDebouncer do
		_annotate("event debouncer for: " .. avatarEventFiring.DescribeEvent(ev))
		task.wait(0.1)
	end
	marathonClientReceiveAvatarEventDebouncer = true
	if ev.eventType == aet.avatarEventTypes.GET_READY_FOR_WARP then
		isMarathonBlockedByWarp = true
		for _, desc: mt.marathonDescriptor in ipairs(joinableMarathonKinds) do
			resetMarathonProgress(desc)
			module.InitMarathonVisually(desc)
		end
		_annotate("sending: MARATHON_WARPER_READY")
		fireEvent(aet.avatarEventTypes.MARATHON_WARPER_READY, { sender = "marathonClient" })
		marathonClientReceiveAvatarEventDebouncer = false
		return
	elseif ev.eventType == aet.avatarEventTypes.WARP_DONE_RESTART_MARATHONS then
		for _, desc: mt.marathonDescriptor in ipairs(joinableMarathonKinds) do
			resetMarathonProgress(desc)
		end
		isMarathonBlockedByWarp = false
		fireEvent(aet.avatarEventTypes.MARATHON_RESTARTED, { sender = "marathonClient" })
		marathonClientReceiveAvatarEventDebouncer = false
		_annotate("WARP_DONE_RESTART_MARATHONS DONE")
		return
	else
		warn("received unhandled event: " .. avatarEventFiring.DescribeEvent(ev))
	end
	marathonClientReceiveAvatarEventDebouncer = false
end

--ideally filter at the registration layer but whatever.
--also why is this being done here rather than in marathon client?
local function HandleMarathonSettingsChanged(setting: tt.userSettingValue)
	if setting.domain ~= settingEnums.settingDomains.MARATHONS then
		_annotate("wrong domain.")
		return
	end
	_annotate("Load initial marathon or setting changed: " .. setting.name)
	local sp = string.split(setting.name, " ")
	local remainder = textUtil.coalesceFrom(sp, 2)
	local key = remainder:gsub(" ", "")
	-- local key = string.split(setting.name, " ")[2]
	local targetMarathon: mt.marathonDescriptor = mds.marathons[key]
	if targetMarathon == nil then
		warn("bad setting probably legacy bad naming, shouldn't be many and no effect." .. key)
		return
	end
	if setting.booleanValue then
		initMarathon(targetMarathon)
	else
		disableMarathon(targetMarathon)
	end
end

local avatarEventConnection

-- when user warps, kill outstanding marathons.
module.Init = function()
	joinableMarathonKinds = {}
	--blocker to confirm the user has completed warp
	isMarathonBlockedByWarp = false

	local pgui: PlayerGui = localPlayer:WaitForChild("PlayerGui")
	local existingMarathonScreenGui = pgui:FindFirstChild("MarathonScreenGui")
	if existingMarathonScreenGui then
		existingMarathonScreenGui:Destroy()
	end
	local marathonScreenGui: ScreenGui = Instance.new("ScreenGui")
	marathonScreenGui.Name = "MarathonScreenGui"
	marathonScreenGui.Parent = pgui
	marathonScreenGui.IgnoreGuiInset = true

	local marathonFrames = windows.SetupFrame("marathons", true, true, true)
	local marathonOuterFrame = marathonFrames.outerFrame
	local marathonContentFrame = marathonFrames.contentFrame
	marathonOuterFrame.Parent = marathonScreenGui
	marathonOuterFrame.Size = UDim2.new(0.4, 0, 0, 0) -- Set height to 0 initially
	marathonOuterFrame.Position = UDim2.new(0.6, 0, 0.35, 0)
	local hh = Instance.new("UIListLayout")
	hh.Name = "marathons-hh"
	hh.Parent = marathonContentFrame
	hh.FillDirection = Enum.FillDirection.Vertical
	hh.SortOrder = Enum.SortOrder.Name
	setMarathonSize()
	if avatarEventConnection then
		avatarEventConnection:Disconnect()
		avatarEventConnection = nil
	end

	avatarEventConnection = AvatarEventBindableEvent.Event:Connect(handleAvatarEvent)

	for _, userSetting in pairs(settings.GetSettingByDomain(settingEnums.settingDomains.MARATHONS)) do
		HandleMarathonSettingsChanged(userSetting)
	end

	settings.RegisterFunctionToListenForDomain(function(item: tt.userSettingValue): any
		return HandleMarathonSettingsChanged(item)
	end, settingEnums.settingDomains.MARATHONS)
	_annotate("init done")
end

_annotate("end")

return module
