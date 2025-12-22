--!strict
-- marathonClient.lua @ StarterCharacterScripts.client.marathonClient
-- Manages client-side marathon tracking, UI, and warp coordination.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local Players = game:GetService("Players")
local PlayersService = game:GetService("Players")

local aet = require(game.ReplicatedStorage.avatarEventTypes)
local avatarEventFiring = require(game.StarterPlayer.StarterPlayerScripts.avatarEventFiring)
local colors = require(game.ReplicatedStorage.util.colors)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local marathonStatic = require(game.ReplicatedStorage.marathon.marathonStatic)
local mds = require(game.ReplicatedStorage.marathon.marathonDescriptors)
local mt = require(game.StarterPlayer.StarterPlayerScripts.marathon.marathonTypes)
local _fonts = require(game.StarterPlayer.StarterPlayerScripts.guis.fonts)
local remotes = require(game.ReplicatedStorage.util.remotes)
local settings = require(game.ReplicatedStorage.settings)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local textUtil = require(game.ReplicatedStorage.util.textUtil)
local toolTip = require(game.ReplicatedStorage.gui.toolTip)
local tt = require(game.ReplicatedStorage.types.gametypes)
local windowFunctions = require(game.StarterPlayer.StarterPlayerScripts.guis.windowFunctions)

local fireEvent = avatarEventFiring.FireEvent
local localPlayer: Player = Players.LocalPlayer

local marathonCompleteEvent = remotes.getRemoteEvent("MarathonCompleteEvent")
local ephemeralMarathonCompleteEvent = remotes.getRemoteEvent("EphemeralMarathonCompleteEvent")
local AvatarEventBindableEvent: BindableEvent = remotes.getBindableEvent("AvatarEventBindableEvent")

type Module = {
	Init: () -> (),
	Reset: (string?) -> (),
	InitMarathonVisually: (mt.marathonDescriptor) -> (),
	receiveHit: (string, number) -> (),
	CloseAllMarathons: () -> (),
}

local module: Module = {} :: Module

-- Module state
local joinableMarathonKinds: { mt.marathonDescriptor } = {}
local isMarathonBlockedByWarp = false
local marathonClientReceiveAvatarEventDebouncer = false
local avatarEventConnection: RBXScriptConnection? = nil

local MARATHON_ROW_HEIGHT_PIXELS = 18

local function isMarathonRowFrame(frame: Frame): boolean
	return string.sub(frame.Name, 1, #"MarathonFrame_") == "MarathonFrame_"
end

local function getVisibleMarathonRowFrames(marathonContentFrame: Frame): { Frame }
	local frames: { Frame } = {}
	for _, child in ipairs(marathonContentFrame:GetChildren()) do
		if child:IsA("Frame") then
			local frame = child :: Frame
			if isMarathonRowFrame(frame) and frame.Visible then
				table.insert(frames, frame)
			end
		end
	end
	return frames
end

-- State logging
local function describeMarathonState(): string
	return string.format(
		"marathon state { isMarathonBlockedByWarp=%s marathonCount=%d debouncer=%s }",
		tostring(isMarathonBlockedByWarp),
		#joinableMarathonKinds,
		tostring(marathonClientReceiveAvatarEventDebouncer)
	)
end

local function logMarathonState(context: string)
	_annotate(string.format("%s %s", context, describeMarathonState()))
end

local function logRedundantStateRequest(fieldName: string, attemptedValue: any, context: string)
	_annotate(string.format("redundant state request: %s already %s (%s)", fieldName, tostring(attemptedValue), context), nil, false)
end

local function setIsMarathonBlockedByWarp(nextValue: boolean, context: string)
	if isMarathonBlockedByWarp == nextValue then
		logRedundantStateRequest("isMarathonBlockedByWarp", nextValue, context)
		return
	end
	isMarathonBlockedByWarp = nextValue
	logMarathonState(string.format("isMarathonBlockedByWarp -> %s (%s)", tostring(nextValue), context))
end

-- Utility functions
local function getMarathonKindFrameName(desc: mt.marathonDescriptor): string
	local targetName = "MarathonFrame_" .. desc.highLevelType .. "_" .. desc.sequenceNumber
	return targetName
end

local function getMarathonContentFrame(): Frame?
	local plInstance: Instance = PlayersService.LocalPlayer:WaitForChild("PlayerGui")
	if not plInstance:IsA("PlayerGui") then
		return nil
	end
	local pl: PlayerGui = plInstance :: PlayerGui
	local foundInstance: Instance? = pl:FindFirstChild("content_marathons", true)
	if foundInstance and foundInstance:IsA("Frame") then
		local found: Frame = foundInstance :: Frame
		return found
	end
	return nil
end

local function setMarathonSize()
	local marathonContentFrame = getMarathonContentFrame()
	if not marathonContentFrame then
		return
	end
	local marathonOuterFrameInstance: Instance? = marathonContentFrame.Parent
	if not marathonOuterFrameInstance or not marathonOuterFrameInstance:IsA("Frame") then
		return
	end
	local marathonOuterFrame: Frame = marathonOuterFrameInstance :: Frame

	local visibleMarathonFrames = getVisibleMarathonRowFrames(marathonContentFrame)
	local anyMarathons = #visibleMarathonFrames > 0

	-- Fixed-height rows so filtering doesn't distort proportions.
	for _, child in ipairs(marathonContentFrame:GetChildren()) do
		if child:IsA("Frame") then
			local frame = child :: Frame
			if isMarathonRowFrame(frame) then
				frame.Size = UDim2.new(1, 0, 0, MARATHON_ROW_HEIGHT_PIXELS)
			end
		end
	end

	local totalHeightPixels = MARATHON_ROW_HEIGHT_PIXELS * #visibleMarathonFrames

	marathonOuterFrame.Size = UDim2.new(marathonOuterFrame.Size.Width.Scale, marathonOuterFrame.Size.Width.Offset, 0, totalHeightPixels)

	local parInstance = marathonContentFrame.Parent
	if parInstance and parInstance:IsA("Frame") then
		local par: Frame = parInstance
		par.Visible = anyMarathons
		if par.Visible then
			par.Position = UDim2.new(0.60, 0, 0.5, 0)
		end
	end
end

-- Marathon timer functions
local function startMarathonRunTimer(desc: mt.marathonDescriptor, baseTime: number)
	desc.startTime = baseTime
	if desc.runningTimeTileUpdater then
		return
	end

	task.spawn(function()
		desc.runningTimeTileUpdater = true
		while true do
			if desc.killTimerSemaphore then
				desc.killTimerSemaphore = false
				desc.runningTimeTileUpdater = false
				break
			end
			task.wait(1 / 3.1)
			local gap = tick() - baseTime
			local timeTileValue: TextLabel? = desc.timeTile
			if timeTileValue then
				timeTileValue.Text = string.format("%0.0f", gap)
			end
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
	desc.killTimerSemaphore = true
	local ii = 0
	while true do
		ii += 1
		task.wait(1 / 25.1)
		if not desc.runningTimeTileUpdater then
			return true
		end
		if ii > 20 then
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

-- UI tile creation functions
local function getMarathonHH(): UIListLayout
	local hh: UIListLayout = Instance.new("UIListLayout")
	hh.FillDirection = Enum.FillDirection.Horizontal
	hh.Name = "MarathonInnerTiles.hh"
	hh.HorizontalFlex = Enum.UIFlexAlignment.Fill
	return hh
end

local function getNameTileWidth(name: string): number
	return 220
end

local function getNameTile(name: string): Frame
	local namePixX = getNameTileWidth(name)

	local wrapper = Instance.new("Frame")
	wrapper.Name = "00-marathonNameWrapper"
	wrapper.Size = UDim2.new(0, namePixX, 1, 0)
	wrapper.BackgroundTransparency = 1
	wrapper.BorderSizePixel = 0

	local nameTileInstance =
		guiUtil.getTl("00-marathonName", UDim2.new(1, 0, 1, 0), 1, wrapper, colors.defaultGrey, 1, 0, Enum.AutomaticSize.None)
	if not nameTileInstance or not nameTileInstance:IsA("TextLabel") then
		error("getNameTile: getTl did not return TextLabel")
	end

	local nameTile: TextLabel = nameTileInstance
	nameTile.Text = name
	return wrapper
end

local function getTimeTile(kind: string): TextLabel
	local timeTile: TextLabel = Instance.new("TextLabel")
	timeTile.Name = "03-TimeTile" .. kind
	timeTile.Text = ""
	timeTile.AutomaticSize = Enum.AutomaticSize.None
	timeTile.BackgroundColor3 = colors.meColor
	timeTile.TextScaled = true
	timeTile.Size = UDim2.new(0, 40, 1, 0)
	timeTile.Font = Enum.Font.Gotham
	return timeTile
end

local function getResetTile(kind: string): TextButton
	local resetTile: TextButton = Instance.new("TextButton")
	resetTile.Name = "99-resetTile" .. kind
	resetTile.Text = "R"
	resetTile.TextScaled = true
	resetTile.BackgroundColor3 = colors.redStop
	resetTile.Size = UDim2.new(0, 30, 1, 0)
	return resetTile
end

module.InitMarathonVisually = function(desc: mt.marathonDescriptor)
	_annotate("initMarathonVisually.start." .. desc.highLevelType .. "_" .. desc.sequenceNumber)
	local marathonContentFrame = getMarathonContentFrame()
	if not marathonContentFrame then
		_annotate("no content frame??")
		return
	end
	local thisMarathonFrameName = getMarathonKindFrameName(desc)
	local foundFrameInstance: Instance? = marathonContentFrame:FindFirstChild(thisMarathonFrameName)
	local thisMarathonFrame: Frame
	if foundFrameInstance and foundFrameInstance:IsA("Frame") then
		thisMarathonFrame = foundFrameInstance :: Frame
	else
		_annotate("init visual marathon: " .. desc.humanName)
		local newFrame = Instance.new("Frame")
		newFrame.BorderMode = Enum.BorderMode.Inset
		newFrame.BorderSizePixel = 0
		newFrame.Name = thisMarathonFrameName
		newFrame.Parent = marathonContentFrame
		thisMarathonFrame = newFrame
	end

	for _, oldTile in pairs(thisMarathonFrame:GetChildren()) do
		oldTile:Destroy()
	end

	local nameTile = getNameTile(desc.humanName)
	local hintTextValue: string? = desc.hint
	if hintTextValue and hintTextValue ~= "" then
		toolTip.setupToolTip(nameTile, hintTextValue, toolTip.enum.toolTipSize.NormalText)
	end
	nameTile.Parent = thisMarathonFrame

	local chipFrame = marathonStatic.getChipFrame(desc)
	chipFrame.Parent = thisMarathonFrame

	local timeTileInstance = getTimeTile(desc.kind)
	if timeTileInstance and timeTileInstance:IsA("TextLabel") then
		desc.timeTile = timeTileInstance :: TextLabel
		timeTileInstance.Parent = thisMarathonFrame
	end

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

local function updateTimeTileForKindToCompletion(runMilliseconds: number, timeTile: TextLabel)
	timeTile.Text = string.format("%0.3f", runMilliseconds / 1000.0)
	timeTile.BackgroundColor3 = colors.blueDone
end

local function finishMarathonVisually(desc: mt.marathonDescriptor, runMilliseconds: number, marathonRow: Frame)
	stopTimerForKind(desc)
	local timeTileValue: TextLabel? = desc.timeTile
	if timeTileValue then
		updateTimeTileForKindToCompletion(runMilliseconds, timeTileValue)
	end
	_annotate("finishMarathonVisually.end." .. desc.kind)
end

local function tellDescAboutFind(desc: mt.marathonDescriptor, signName: string): mt.userFoundSignResult
	if desc.addDebounce[signName] then
		return { added = false, marathonDone = false, started = false }
	end
	desc.addDebounce[signName] = true
	if not desc.runningTimeTileUpdater then
		if desc.count ~= nil and desc.count > 0 then
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

local function innerReceiveHit(desc: mt.marathonDescriptor, signName: string, innerTick: number)
	local resValue: mt.userFoundSignResult? = tellDescAboutFind(desc, signName)
	if not resValue then
		warn("NIL")
		return
	end
	local res: mt.userFoundSignResult = resValue
	if not res.added then
		return
	end

	local frameName = getMarathonKindFrameName(desc)
	local marathonFrame = getMarathonContentFrame()
	if not marathonFrame then
		_annotate("no marathon Frame.")
		return
	end
	local foundRowInstance: Instance? = marathonFrame:FindFirstChild(frameName)
	if not foundRowInstance or not foundRowInstance:IsA("Frame") then
		_annotate("no row?")
		return
	end
	local marathonRow: Frame = foundRowInstance :: Frame

	desc.UpdateRow(desc, marathonRow, signName)

	if res.started then
		startMarathonRunTimer(desc, innerTick)
	end

	if res.marathonDone then
		local startTimeValue: number? = desc.startTime
		if not startTimeValue then
			warn("marathonDone but startTime is nil")
			return
		end
		local startTime: number = startTimeValue
		local completionTime = innerTick - startTime
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

local deb = false
local initMarathon = function(desc: mt.marathonDescriptor): any
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

	if not intable then
		table.insert(joinableMarathonKinds, desc)
		resetMarathonProgress(desc)
		module.InitMarathonVisually(desc)
	end
	deb = false
	return nil
end

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
	while not marathonContentFrame do
		marathonContentFrame = getMarathonContentFrame()
		task.wait(1)
		_annotate("W")
	end
	local foundExiInstance: Instance? = marathonContentFrame and marathonContentFrame:FindFirstChild(frameName)
	if foundExiInstance and foundExiInstance:IsA("Frame") then
		foundExiInstance:Destroy()
	end

	table.remove(joinableMarathonKinds, target)
	setMarathonSize()
	_annotate(string.format("marathon.disabled:%s", desc.kind))
end

module.CloseAllMarathons = function()
	while #joinableMarathonKinds > 0 do
		local item = joinableMarathonKinds[1]
		disableMarathon(item)
	end
end

local eventsWeCareAbout = {
	aet.avatarEventTypes.GET_READY_FOR_WARP,
	aet.avatarEventTypes.WARP_DONE_RESTART_MARATHONS,
	aet.avatarEventTypes.AVATAR_DIED,
	aet.avatarEventTypes.AVATAR_RESET,
}

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
		setIsMarathonBlockedByWarp(true, "GET_READY_FOR_WARP event")
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
		setIsMarathonBlockedByWarp(false, "WARP_DONE_RESTART_MARATHONS event")
		fireEvent(aet.avatarEventTypes.MARATHON_RESTARTED, { sender = "marathonClient" })
		marathonClientReceiveAvatarEventDebouncer = false
		_annotate("WARP_DONE_RESTART_MARATHONS DONE")
		return
	elseif ev.eventType == aet.avatarEventTypes.AVATAR_DIED or ev.eventType == aet.avatarEventTypes.AVATAR_RESET then
		_annotate(string.format("resetting marathons due to %s", aet.avatarEventTypesReverse[ev.eventType]))
		setIsMarathonBlockedByWarp(false, string.format("%s event", aet.avatarEventTypesReverse[ev.eventType]))
		for _, desc: mt.marathonDescriptor in ipairs(joinableMarathonKinds) do
			resetMarathonProgress(desc)
			module.InitMarathonVisually(desc)
		end
		marathonClientReceiveAvatarEventDebouncer = false
		return
	else
		warn("received unhandled event: " .. avatarEventFiring.DescribeEvent(ev))
	end
	marathonClientReceiveAvatarEventDebouncer = false
end

local function HandleMarathonSettingsChanged(setting: tt.userSettingValue): any
	if setting.domain ~= settingEnums.settingDomains.MARATHONS then
		_annotate("wrong domain.")
		return nil
	end
	_annotate("Load initial marathon or setting changed: " .. setting.name)
	local sp = string.split(setting.name, " ")
	local remainder = textUtil.coalesceFrom(sp, 2)
	local key = remainder:gsub(" ", "")
	local targetMarathon: mt.marathonDescriptor = mds.marathons[key]
	if targetMarathon == nil then
		warn("bad setting probably legacy bad naming, shouldn't be many and no effect." .. key)
		return nil
	end
	if setting.booleanValue then
		initMarathon(targetMarathon)
	else
		disableMarathon(targetMarathon)
	end
	return nil
end

module.Reset = function(context: string?)
	local resetContext = context or "module.Reset"
	_annotate(string.format("Reset (%s)", resetContext))
	setIsMarathonBlockedByWarp(false, string.format("%s (Reset isMarathonBlockedByWarp)", resetContext))
	marathonClientReceiveAvatarEventDebouncer = false
	logMarathonState(string.format("Reset (%s) complete", resetContext))
end

module.Init = function()
	_annotate("MARATHON CLIENT init")

	module.Reset("module.Init")

	if avatarEventConnection then
		_annotate("disconnecting existing avatarEventConnection")
		avatarEventConnection:Disconnect()
		avatarEventConnection = nil
	else
		_annotate("no existing avatarEventConnection")
	end

	avatarEventConnection = AvatarEventBindableEvent.Event:Connect(handleAvatarEvent)

	settings.RegisterFunctionToListenForDomain(function(item: tt.userSettingValue): any
		return HandleMarathonSettingsChanged(item)
	end, settingEnums.settingDomains.MARATHONS)

	for _, userSetting in pairs(settings.GetSettingByDomain(settingEnums.settingDomains.MARATHONS)) do
		HandleMarathonSettingsChanged(userSetting)
	end

	local pguiInstance: Instance = localPlayer:WaitForChild("PlayerGui")
	if not pguiInstance:IsA("PlayerGui") then
		error("PlayerGui not found")
	end
	local pgui: PlayerGui = pguiInstance :: PlayerGui
	local existingMarathonScreenGui = pgui:FindFirstChild("MarathonScreenGui")
	if existingMarathonScreenGui then
		existingMarathonScreenGui:Destroy()
	end
	local marathonScreenGui: ScreenGui = Instance.new("ScreenGui")
	marathonScreenGui.Name = "MarathonScreenGui"
	marathonScreenGui.Parent = pgui
	marathonScreenGui.IgnoreGuiInset = true

	-- Marathon frame: draggable but NOT resizable - rows use fixed pixel heights that don't scale
	-- Content auto-sizes based on visible marathons via setMarathonSize()
	local marathonFrames = windowFunctions.SetupFrame("marathons", true, false, false, false, UDim2.new(0, 200, 0, 200))
	local marathonOuterFrame = marathonFrames.outerFrame
	local marathonContentFrame = marathonFrames.contentFrame
	marathonOuterFrame.Parent = marathonScreenGui
	marathonOuterFrame.Size = UDim2.new(0.4, 0, 0, 0)
	marathonOuterFrame.Position = UDim2.new(0.6, 0, 0.35, 0)
	local hh = Instance.new("UIListLayout")
	hh.Name = "marathons-hh"
	hh.Parent = marathonContentFrame
	hh.FillDirection = Enum.FillDirection.Vertical
	hh.SortOrder = Enum.SortOrder.Name
	setMarathonSize()

	for _, desc in ipairs(joinableMarathonKinds) do
		module.InitMarathonVisually(desc)
	end

	_annotate("init done")
end

_annotate("end")

return module
