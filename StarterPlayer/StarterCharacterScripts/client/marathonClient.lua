--!strict

--2022.02.13 split it from main leaderboard code.
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local tt = require(game.ReplicatedStorage.types.gametypes)
local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)
local colors = require(game.ReplicatedStorage.util.colors)
local avatarEventFiring = require(game.StarterPlayer.StarterPlayerScripts.avatarEventFiring)
local fireEvent = avatarEventFiring.FireEvent
local marathonStatic = require(game.ReplicatedStorage.marathonStatic)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
-- local lbMarathonRowY = 18
local remotes = require(game.ReplicatedStorage.util.remotes)
local toolTip = require(game.ReplicatedStorage.gui.toolTip)
-- local marathonTypes = require(game.StarterPlayer.StarterPlayerScripts.marathonTypes)
local settings = require(game.ReplicatedStorage.settings)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)

local mt = require(game.ReplicatedStorage.avatarEventTypes)
local marathonTypes = require(game.StarterPlayer.StarterPlayerScripts.marathonTypes)
local mds = require(game.ReplicatedStorage.marathonDescriptors)

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
local joinableMarathonKinds: { marathonTypes.marathonDescriptor } = {}

-- warp monitoring
local isMarathonBlockedByWarp = false

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

	local theMarathons: { Frame } = {}
	for _, ch in pairs(marathonContentFrame:GetChildren()) do
		if ch.ClassName == "Frame" then
			table.insert(theMarathons, ch)
		end
	end
	for _, singleMarathonFrame: Frame in ipairs(theMarathons) do
		singleMarathonFrame.Size = UDim2.new(1, 0, 1 / #theMarathons, 0)
	end

	if #theMarathons == 0 then
		marathonContentFrame.Parent.Visible = false
	else
		if not marathonContentFrame.Parent.Visible then
			marathonContentFrame.Parent.Visible = true
			marathonContentFrame.Parent.Position = UDim2.new(0.7, 0, 0.5, 0)
		end
	end
end

----------------------FUNCTIONS -----------------------

local function startMarathonRunTimer(desc: marathonTypes.marathonDescriptor, baseTime: number)
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

local function stopTimerForKind(desc: marathonTypes.marathonDescriptor): boolean
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

local function resetMarathonProgress(desc: marathonTypes.marathonDescriptor)
	stopTimerForKind(desc)
	desc.startTime = nil
	desc.killTimerSemaphore = false
	desc.count = 0
	desc.finds = {}
	desc.addDebounce = {}

	_annotate("resetMarathon.end." .. desc.kind)
end

--get name, chips (for sub-achievements), timetile, canceltile.
module.getMarathonInnerTiles = function(desc: marathonTypes.marathonDescriptor, lbFrameSize: Vector2)
	local res = {}
	local sz = marathonStatic.marathonSizesByType[desc.highLevelType]

	local hh = Instance.new("UIListLayout")
	hh.FillDirection = Enum.FillDirection.Horizontal
	hh.Name = "MarathonInnerTiles.hh"
	hh.HorizontalFlex = Enum.UIFlexAlignment.Fill

	table.insert(res, hh)
	local fakeParent = Instance.new("Frame")
	local nameTile: TextLabel = guiUtil.getTl(
		"00-marathonNameFirstTile",
		UDim2.new(0, sz.nameRes, 1, 0),
		1,
		fakeParent,
		colors.defaultGrey,
		1,
		0,
		Enum.AutomaticSize.X
	)
	nameTile.Text = desc.humanName
	local par = nameTile.Parent :: TextLabel
	local fake: TextLabel = nil
	par.Parent = fake
	-- okay we insert the kid into here?
	table.insert(res, nameTile.Parent)

	toolTip.setupToolTip(nameTile, desc.hint, toolTip.enum.toolTipSize.NormalText)

	marathonStatic.getComponentTilesForKind(desc, res, lbFrameSize)

	return res
end

--get or create frame; swap out the tiles with new ones.
--does it do deduplication?
module.InitMarathonVisually = function(desc: marathonTypes.marathonDescriptor)
	_annotate("initMarathonVisually.start." .. desc.highLevelType .. "_" .. desc.sequenceNumber)
	local marathonContentFrame = getMarathonContentFrame()
	if not marathonContentFrame then
		return
	end
	local thisMarathonFrameName = marathonStatic.GetMarathonKindFrameName(desc)
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
	--swap out tiles
	local tiles = module.getMarathonInnerTiles(desc, thisMarathonFrame.AbsoluteSize)
	for _, tile in ipairs(tiles) do
		local exiTile = thisMarathonFrame:FindFirstChild(tile.Name)
		if exiTile ~= nil then
			exiTile:Destroy()
		end
		tile.Parent = thisMarathonFrame
	end
	local resetTile = marathonStatic.getMarathonResetTile(desc)
	local exiMarathonRow = thisMarathonFrame:FindFirstChild(resetTile.Name)
	if exiMarathonRow ~= nil then
		exiMarathonRow:Destroy()
	end
	resetTile.Activated:Connect(function()
		resetMarathonProgress(desc)
		module.InitMarathonVisually(desc)
	end)
	resetTile.Parent = thisMarathonFrame
	setMarathonSize()
	--reset marathonContentFrame size.
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
	stopTimerForKind(desc)
	updateTimeTileForKindToCompletion(runMilliseconds, desc.timeTile)
	_annotate("finishMarathonVisually.end." .. desc.kind)
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

	local frameName = marathonStatic.GetMarathonKindFrameName(desc)
	local marathonFrame = getMarathonContentFrame()
	if not marathonFrame then
		return
	end
	local marathonRow: Frame = marathonFrame:FindFirstChild(frameName)

	--marathon has been killed in UI.
	if marathonRow == nil then
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
	for _, desc: marathonTypes.marathonDescriptor in ipairs(joinableMarathonKinds) do
		innerReceiveHit(desc, signName, innerTick)
	end
end

--BOTH tell the system that the setting value is this, AND init it visually.
local deb = false
local initMarathon = function(desc: marathonTypes.marathonDescriptor)
	while deb do
		task.wait()
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
local disableMarathon = function(desc: marathonTypes.marathonDescriptor)
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
	local frameName = marathonStatic.GetMarathonKindFrameName(desc)
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

local avatarDebounger = false
local function handleAvatarEvent(ev: mt.avatarEvent)
	while avatarDebounger do
		_annotate("avatarDebounger")
		wait()
	end
	_annotate(avatarEventFiring.DescribeEvent(ev.eventType, ev.details))
	avatarDebounger = true
	if ev.eventType == mt.avatarEventTypes.GET_READY_FOR_WARP then
		_annotate("GET_READY_FOR_WARP")
		isMarathonBlockedByWarp = true
		for _, desc: marathonTypes.marathonDescriptor in ipairs(joinableMarathonKinds) do
			resetMarathonProgress(desc)
			module.InitMarathonVisually(desc)
		end
		fireEvent(mt.avatarEventTypes.MARATHON_WARPER_READY, {})
		avatarDebounger = false
		_annotate("GET_READY_FOR_WARP DONE")
		return
	elseif ev.eventType == mt.avatarEventTypes.WARP_DONE_RESTART_MARATHONS then
		_annotate("WARP_DONE_RESTART_MARATHONS")
		for _, desc: marathonTypes.marathonDescriptor in ipairs(joinableMarathonKinds) do
			resetMarathonProgress(desc)
		end
		isMarathonBlockedByWarp = false
		fireEvent(mt.avatarEventTypes.MARATHON_RESTARTED, {})
		avatarDebounger = false
		_annotate("WARP_DONE_RESTART_MARATHONS DONE")
		return
	end
	avatarDebounger = false
end

--ideally filter at the registration layer but whatever.
--also why is this being done here rather than in marathon client?
local function HandleMarathonSettingsChanged(setting: tt.userSettingValue)
	if setting.domain ~= settingEnums.settingDomains.MARATHONS then
		_annotate("wrong domain.")
		return
	end
	_annotate("Load initial marathon or setting changed: " .. setting.name)
	local key = string.split(setting.name, " ")[2]
	local targetMarathon: marathonTypes.marathonDescriptor = mds[key]
	if targetMarathon == nil then
		warn("bad setting probably legacy bad naming, shouldn't be many and no effect." .. key)
		return
	end
	if setting.value then
		initMarathon(targetMarathon)
	else
		disableMarathon(targetMarathon)
	end
end

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
	marathonOuterFrame.Size = UDim2.new(0.4, 0, 0.1, 0)

	marathonOuterFrame.Position = UDim2.new(0.6, 0, 0.35, 0)
	local hh = Instance.new("UIListLayout")
	hh.Name = "marathons-hh"
	hh.Parent = marathonContentFrame
	hh.FillDirection = Enum.FillDirection.Vertical
	hh.SortOrder = Enum.SortOrder.Name
	setMarathonSize()

	AvatarEventBindableEvent.Event:Connect(handleAvatarEvent)

	for _, userSetting in pairs(settings.getSettingByDomain(settingEnums.settingDomains.MARATHONS)) do
		HandleMarathonSettingsChanged(userSetting)
	end

	settings.RegisterFunctionToListenForDomain(function(item: tt.userSettingValue): any
		return HandleMarathonSettingsChanged(item)
	end, settingEnums.settingDomains.MARATHONS)
end

_annotate("end")

return module
