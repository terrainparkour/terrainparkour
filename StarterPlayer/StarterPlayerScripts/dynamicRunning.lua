--!strict

-- dynamicRunning
-- draw a ui which appends uis on nearby found sign statuses

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local colors = require(game.ReplicatedStorage.util.colors)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local settings = require(game.ReplicatedStorage.settings)
local tt = require(game.ReplicatedStorage.types.gametypes)
local dynamicRunningEnums = require(game.ReplicatedStorage.dynamicRunningEnums)
local textHighlighting = require(game.ReplicatedStorage.gui.textHighlighting)

local PlayersService = game:GetService("Players")
local RunService = game:GetService("RunService")
local localPlayer = PlayersService.LocalPlayer
local remotes = require(game.ReplicatedStorage.util.remotes)
local dynamicRunningEvent = remotes.getRemoteEvent("DynamicRunningEvent") :: RemoteEvent

---------------- CONSTANTS--------------
--max visualization (CAMERA, not PLAYER) range.
local bbguiMaxDist = 150

-- for chunking size jumps within the dynamic runnig popup
local divver = 120
-- number of pixels per letter.
local perWidth = 9

-------------- GLOBALS ----------------------

--control settings, default start. modifiable by a setting.
local dynamicRunningEnabled = false

--global for tracking
local dynamicStartTick: number = 0

local debounce = false
local dynamicRunFrames: { tt.DynamicRunFrame } = {}

--target sign name => TL;
local textLabelStore: { [string]: TextLabel } = {}

--signName => ui outer frame
local targetSignUis: { [string]: TextLabel } = {}

local startDynamicDebounce = false
local renderStepped: RBXScriptConnection? = nil
local lastupdates = {}
local hasReset = false

-------------------- FUNCTIONS ----------------------

--destroy all UIs and nuke the pointer dict to them
module.endDynamic = function(force: boolean?)
	_annotate("endDynamic, force:" .. tostring(force))
	if not (force or dynamicRunningEnabled) then
		return
	end

	_annotate("endDynamic, real")
	startDynamicDebounce = true

	for k, v in pairs(targetSignUis) do
		local par = v.Parent
		if par then
			par = par.Parent
			if par then
				par:Destroy()
			end
		end
	end
	targetSignUis = {}
	dynamicStartTick = 0
	local data: tt.dynamicRunningControlType = {
		action = dynamicRunningEnums.ACTIONS.DYNAMIC_STOP,
		fromSignId = 0,
		userId = localPlayer.UserId,
	}
	dynamicRunningEvent:FireServer(data)
	startDynamicDebounce = false
end

--called when a player re-touches a sign to reser timer
module.resetDynamicTiming = function(startTick: number)
	if not dynamicRunningEnabled then
		return
	end
	_annotate("resetDynamicTiming")
	dynamicStartTick = startTick
end

--do everything on the server and just monitor it on the client
module.startDynamic = function(player: Player, signName: string, startTick: number)
	if not dynamicRunningEnabled then
		return
	end

	task.spawn(function()
		while startDynamicDebounce do
			wait(0.1)
			_annotate("waited for dynamic start debounce")
		end
		startDynamicDebounce = true
		dynamicStartTick = startTick
		local signId = tpUtil.signName2SignId(signName)
		local data: tt.dynamicRunningControlType = {
			action = dynamicRunningEnums.ACTIONS.DYNAMIC_START,
			fromSignId = signId,
			userId = player.UserId,
		}
		dynamicRunningEvent:FireServer(data)
		startDynamicDebounce = false
	end)
end

local function makeDynamicSignMouseoverUI(from: string, to: string): TextLabel?
	if not tpUtil.SignNameCanBeHighlighted(to) then
		--if a sign isn't touchable we don't route. This conveniently also hides hidden time-based signs.
		return
	end
	local bbgui = Instance.new("BillboardGui")
	local width = 15 * #from + 30
	bbgui.Size = UDim2.new(0, width, 0, 80)
	bbgui.StudsOffset = Vector3.new(0, 5, 0)
	bbgui.MaxDistance = bbguiMaxDist
	bbgui.AlwaysOnTop = false
	bbgui.Name = "For_" .. from .. "_to_" .. to
	local frame: Frame = Instance.new("Frame")
	frame.Parent = bbgui
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundTransparency = 1

	local textLabel: TextLabel = Instance.new("TextLabel")
	textLabel.Parent = frame
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.Text = ""
	textLabel.TextTransparency = 0.0
	textLabel.BackgroundTransparency = 1
	textLabel.BackgroundColor3 = colors.white
	textLabel.TextColor3 = colors.white
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.FontSize = Enum.FontSize.Size24
	textLabel.TextScaled = false
	local sign = tpUtil.signName2Sign(to)
	bbgui.Parent = sign

	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = colors.black
	uiStroke.Thickness = 6
	uiStroke.Parent = textLabel

	return textLabel
end

--get or create bbgui above sign
local function getOrCreateUI(from: string, to: string): TextLabel?
	if not targetSignUis[to] then
		local ui = makeDynamicSignMouseoverUI(from, to)
		if not ui then
			return
		end
		targetSignUis[to] = ui
	end
	return targetSignUis[to]
end

local function calculateTextForDynamic(frame: tt.DynamicRunFrame): (string, Color3)
	local currentRunElapsedMs = (tick() - dynamicStartTick) * 1000

	--cutout early if its a new run entirely or you haven't found it.
	if #frame.places == 0 then
		if not frame.myfound then
			return "New Race for you\nNew Find for you", colors.lightGreen
		end
		return "New Race", colors.lightGreen
	end

	--interleave user's time, AND don't forget to include find status

	local comparatorPlace = 0
	local comparatorTimeImprovement = 0

	--or if you're worse than the last recorded, you get this.
	--and if this is 11th, you don't place at all
	local newNth = 0
	local lastSeenPlace = 0

	--you can't compare to a run after your own place
	--determine comparator, that's why this makes sense.
	for _, exipl in ipairs(frame.places) do
		lastSeenPlace = exipl.place
		if currentRunElapsedMs < exipl.timeMs then
			comparatorPlace = exipl.place
			comparatorTimeImprovement = (exipl.timeMs - currentRunElapsedMs) / 1000
			break
		end
		if frame.myplace and frame.myplace.place and frame.myplace.place <= exipl.place then
			break
		end
	end
	if comparatorPlace == 0 then
		newNth = lastSeenPlace + 1
	end

	------------Determine hover color--------------
	local useColor = colors.defaultGrey
	if comparatorPlace == 1 then
		if frame.myplace and frame.myplace.place == 1 then
			useColor = colors.lightBlue --just improve your 1st place.
		else
			useColor = colors.greenGo
		end
	else
		if frame.myplace and frame.myplace.place == comparatorPlace then
			useColor = colors.lightOrange
		else
			useColor = colors.lightBlue
		end
	end

	-----------the actual text.----------------
	local text = ""
	if comparatorPlace > 0 then
		if frame.myplace and comparatorPlace == frame.myplace.place then
			text = string.format(
				"improve your %s by %0.1fs",
				tpUtil.getCardinal(comparatorPlace),
				comparatorTimeImprovement
			)
		else
			text = string.format(
				"on track for %s by %0.1fs",
				tpUtil.getCardinal(comparatorPlace),
				comparatorTimeImprovement
			)
		end
	else
		if frame.myplace then
			text = string.format("no improvement by %0.1fs", (currentRunElapsedMs - frame.myplace.timeMs) / 1000)
			useColor = colors.lightRed
		else
			if newNth <= 10 then
				text = "Would get new " .. tpUtil.getCardinal(newNth)
			else
				text = "Would not place"
				useColor = colors.lightRed
			end
		end
	end

	local yourlast = ""
	if frame.myplace and frame.myplace.place then
		if frame.myplace.place <= 10 then
			yourlast = "(prev " .. tpUtil.getCardinal(frame.myplace.place) .. ")"
		else
			yourlast = ""
		end
	else
		yourlast = "new run for you"
	end

	return text .. "\n" .. yourlast, useColor
end

--called once per active run + target; after setup, self-runs.
--(also, self-destroys when you leave the area?)
--also, needs dynamic runtime.

local function lock(src: string?)
	if not src then
		src = ""
	end
	while debounce do
		_annotate("debounce lock. " .. src)
		wait(0.05)
	end
	debounce = true
end

local function unlock()
	debounce = false
end

local function addSignToDynamicLabelStore(dynamicRunFrame: tt.DynamicRunFrame, from)
	table.insert(dynamicRunFrames, dynamicRunFrame)
	local tl = getOrCreateUI(from, dynamicRunFrame.targetSignName)

	--this can happen sometimes - the client doesn't have the full DM yet somehow
	if not tl then
		return
	end
	textLabelStore[dynamicRunFrame.targetSignName] = tl
end

local function handleOne(dynamicRunFrame: tt.DynamicRunFrame)
	local textLabel: TextLabel = textLabelStore[dynamicRunFrame.targetSignName]

	local s, e = pcall(function()
		if dynamicStartTick == 0 then
			return
		end

		local bbgui: BillboardGui = textLabel.Parent.Parent
		if not bbgui then
			return
		end

		local pos = localPlayer.Character.HumanoidRootPart.Position
		local par = bbgui.Parent :: Part
		local dist = tpUtil.getDist(par.Position, pos)

		if dist > bbguiMaxDist then
			--far away
			if bbgui.Enabled then
				bbgui.Enabled = false
				return
			end
			return
		else
			--within region
			if not bbgui.Enabled then
				bbgui.Enabled = true
			end
		end

		local text, color = calculateTextForDynamic(dynamicRunFrame)
		if textLabel.Text ~= text then
			textLabel.Text = text
			textLabel.TextColor3 = color

			local width = math.floor(math.floor(#text * perWidth / divver) * divver)
			textLabel.Size = UDim2.new(0, width, 0, 80)
		end
	end)
end

local function fullReset()
	_annotate("full dynamic running reset")
	lock()
	for _, item in ipairs(textLabelStore) do
		item.Parent.Parent:Destroy()
	end
	textLabelStore = {}
	dynamicRunFrames = {}
	unlock()
end

local function receiveDynamicRunData(updates: tt.dynamicRunFromData)
	if not dynamicRunningEnabled then
		_annotate("received but dynamic running disabled")
		return
	end
	_annotate(string.format("Apply dynamicRunning %d %s", #updates.frames, updates.fromSignName))
	lock()
	for _, dynamicRunFrame: tt.DynamicRunFrame in ipairs(updates.frames) do
		if dynamicRunFrame.targetSignName == "👻" then
			--we just magically don't do dynamic running at all TO ghost.
			continue
		end
		addSignToDynamicLabelStore(dynamicRunFrame, updates.fromSignName)
	end
	unlock()
end

local function setupRenderStepped()
	_annotate("starting render stepped")

	renderStepped = RunService.RenderStepped:Connect(function()
		local st = tick()
		if dynamicStartTick == 0 then
			if not hasReset then
				fullReset()
				hasReset = true
			end
			return
		end
		hasReset = false
		if #dynamicRunFrames == 0 then
			return
		end

		for ii, item in ipairs(dynamicRunFrames) do
			if not lastupdates[item.targetSignName] then
				lastupdates[item.targetSignName] = tick()
			end
			if tick() - lastupdates[item.targetSignName] >= 0.1 then
				handleOne(item)
				lastupdates[item.targetSignName] = tick()
				if tick() - st > 0.001 then
					break
				end
			else
			end
		end
	end)
end

local function handleUserSettingChanged(setting: tt.userSettingValue)
	if setting.name == settingEnums.settingDefinitions.ENABLE_DYNAMIC_RUNNING.name then
		if setting.booleanValue then
			if not dynamicRunningEnabled then
				dynamicRunningEnabled = true
				setupRenderStepped()
			end
		elseif setting.booleanValue == false then
			if dynamicRunningEnabled then
				--also destroy them all.
				dynamicRunningEnabled = false
				renderStepped:Disconnect()
				_annotate("kill renderstepped")
				module.endDynamic(true)
			end
		end
	end
end

module.Init = function()
	dynamicRunningEnabled = false
	dynamicStartTick = 0
	debounce = false
	dynamicRunFrames = {}
	textLabelStore = {}
	targetSignUis = {}
	renderStepped = nil
	lastupdates = {}
	hasReset = false
	startDynamicDebounce = false
	dynamicRunningEvent.OnClientEvent:Connect(receiveDynamicRunData)

	--in addition to this, needs to get the original setting to set it locally too.
	settings.RegisterFunctionToListenForSettingName(function(item)
		return handleUserSettingChanged(item)
	end, settingEnums.settingDefinitions.ENABLE_DYNAMIC_RUNNING.name)

	local dynset = settings.getSettingByName(settingEnums.settingDefinitions.ENABLE_DYNAMIC_RUNNING.name)
	handleUserSettingChanged(dynset)
end

_annotate("end")
return module
