--!strict

--[[
    dynamicRunning.lua - Client-side script
    
    Functionality:
    - Creates and manages floating UI elements above signs during speedruns
    - Shows real-time progress comparison against existing records
    - Updates every 0.1 seconds when within 150 studs of relevant signs
    
    Display behavior:
    - Shows "New Race" if no previous runs of this race exist
    - For existing records:
        * Shows projected placement (e.g., "on track for 1st by 2.3s")
        * Shows previous personal best placement
        * Color coding:
            - Green: On track for new 1st place
            - Light Blue: Improving existing time
            - Light Orange: On track for placement but not 1st
            - Light Red: No improvement/won't place
    
    Technical details:
    - Toggleable via user settings (ENABLE_DYNAMIC_RUNNING)
    - Auto-cleans up when player leaves range or ends run
    - Uses server-provided data to prevent cheating
    - Performance optimized with distance checks and update throttling
]]

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local tpPlacementLogic = require(game.ReplicatedStorage.product.tpPlacementLogic)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local settings = require(game.ReplicatedStorage.settings)
local tt = require(game.ReplicatedStorage.types.gametypes)
local dynamicRunningEnums = require(game.ReplicatedStorage.dynamicRunningEnums)

local PlayersService = game:GetService("Players")
local RunService = game:GetService("RunService")

local drawDynamicGui = require(script.Parent.drawDynamicGui)
local localPlayer = PlayersService.LocalPlayer
local remotes = require(game.ReplicatedStorage.util.remotes)
local dynamicRunningEvent = remotes.getRemoteEvent("DynamicRunningEvent") :: RemoteEvent

-------------- GLOBALS ----------------------
--control settings, default start. modifiable by a setting.
local dynamicRunningEnabled = false
local bbguiMaxDist = 150

-- for chunking size jumps within the dynamic runnig popup
local divver = 120
-- number of pixels per letter.
local perWidth = 9

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

-- destroy all UIs and nuke the pointer dict to them
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

-- do everything on the server and just monitor it on the client
module.startDynamic = function(player: Player, signName: string, startTick: number)
	if not dynamicRunningEnabled then
		return
	end

	local signId = tpUtil.signName2SignId(signName)

	task.spawn(function()
		while startDynamicDebounce do
			wait(0.1)
			_annotate("waited for dynamic start debounce")
		end

		startDynamicDebounce = true
		dynamicStartTick = startTick

		local data: tt.dynamicRunningControlType = {
			action = dynamicRunningEnums.ACTIONS.DYNAMIC_START,
			fromSignId = signId,
			userId = player.UserId,
		}

		dynamicRunningEvent:FireServer(data)
		startDynamicDebounce = false
	end)
end

--get or create bbgui above sign
local function getOrCreateUI(from: string, to: string): TextLabel?
	if not targetSignUis[to] then
		local ui = drawDynamicGui.DrawDynamicMouseover(from, to)
		if not ui then
			return
		end
		targetSignUis[to] = ui
	end
	return targetSignUis[to]
end

--called once per active run + target; after setup, self-runs.
--(also, self-destroys when you leave the area?)
--also, needs dynamic runtime.

local function lock(src: string)
	if not src then
		src = ""
	end
	while debounce do
		_annotate(string.format("debounce lock. %s", src))
		wait(0.05)
	end
	debounce = true
end

local function unlock()
	debounce = false
end

local function addSignToDynamicLabelStore(dynamicRunFrame: tt.DynamicRunFrame, from: string)
	_annotate(string.format("adding sign to dynamic label store: %s", dynamicRunFrame.targetSignName))
	table.insert(dynamicRunFrames, dynamicRunFrame)
	local tl = getOrCreateUI(from, dynamicRunFrame.targetSignName)

	--this can happen sometimes - the client doesn't have the full DM yet somehow
	if not tl then
		_annotate(string.format("failed to create TL for: %s", dynamicRunFrame.targetSignName))
		return
	end
	textLabelStore[dynamicRunFrame.targetSignName] = tl
end

local function handleOneDynamicFrameTarget(dynamicRunFrame: tt.DynamicRunFrame)
	local textLabel: TextLabel = textLabelStore[dynamicRunFrame.targetSignName]

	if dynamicStartTick == 0 then
		_annotate("dynamicStartTick == 0")
		return
	end

	local bbgui: BillboardGui = textLabel:FindFirstAncestorOfClass("BillboardGui")
	if not bbgui then
		_annotate(string.format("no bbgui, %s", dynamicRunFrame.targetSignName))
		return
	end

	local rootPart = localPlayer.Character:WaitForChild("HumanoidRootPart")
	local pos = rootPart.Position
	local par = bbgui.Parent :: Part
	local dist = tpUtil.getDist(par.Position, pos)
	-- _annotate(string.format("dist to: %s is: %0.1f", dynamicRunFrame.targetSignName, dist))

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
	local gapTick = tick() - dynamicStartTick
	local gapTickMs = gapTick * 1000

	-- if dynamicRunFrame.targetSignName == "Crater" then
	-- 	local interleavedResult2 = module.GetPlacementAmongRuns(dynamicRunFrame, userId, timeMs)
	-- 	local a = 4
	-- end
	local interleavedResult = tpPlacementLogic.GetPlacementAmongRuns(dynamicRunFrame, localPlayer.UserId, gapTickMs)
	local text, color = tpPlacementLogic.InterleavedToText(interleavedResult)

	if textLabel.Text ~= text or textLabel.TextColor3 ~= color then
		textLabel.Text = text
		textLabel.TextColor3 = color
	end
end

local function fullReset()
	_annotate("full dynamic running reset")
	lock("fullReset")
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
	lock("receive")
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
				handleOneDynamicFrameTarget(item)

				local theGap = tick() - st
				lastupdates[item.targetSignName] = tick()

				if theGap > 0.01 then
					_annotate(string.format("I was handling but broke cause of some speed thing? %0.3f", theGap))
					break
				end
			else
			end
		end
	end)
end

local function handleUserSettingChanged(setting: tt.userSettingValue)
	if setting.name == settingEnums.settingDefinitions.ENABLE_DYNAMIC_RUNNING.name then
		if setting.booleanValue == true then
			if not dynamicRunningEnabled then
				_annotate("enabling dynamic running")
				dynamicRunningEnabled = true
				setupRenderStepped()
			end
		elseif setting.booleanValue == false then
			if dynamicRunningEnabled then
				--also destroy them all.
				_annotate("disabling dynamic running")
				dynamicRunningEnabled = false
				renderStepped:Disconnect()
				_annotate("kill renderstepped")
				module.endDynamic(true)
			end
		end
	end
end

module.Init = function()
	_annotate("init")
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
	end, settingEnums.settingDefinitions.ENABLE_DYNAMIC_RUNNING.name, "dynamicRunning")

	local dynset = settings.GetSettingByName(settingEnums.settingDefinitions.ENABLE_DYNAMIC_RUNNING.name)
	handleUserSettingChanged(dynset)
	_annotate("init done")
end

_annotate("end")
return module
