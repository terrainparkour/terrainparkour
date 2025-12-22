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
local tpUtil: typeof(require(game.ReplicatedStorage.util.tpUtil)) = require(game.ReplicatedStorage.util.tpUtil)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local settings = require(game.ReplicatedStorage.settings)
local tt = require(game.ReplicatedStorage.types.gametypes)
local dynamicRunningEnums = require(game.ReplicatedStorage.dynamicRunningEnums)

local PlayersService = game:GetService("Players")
local RunService = game:GetService("RunService")

local drawDynamicGui = require(game.StarterPlayer.StarterPlayerScripts.drawDynamicGui)
local localPlayer = PlayersService.LocalPlayer
local remotes = require(game.ReplicatedStorage.util.remotes)
local dynamicRunningEvent = remotes.getRemoteEvent("DynamicRunningEvent") :: RemoteEvent

local settingName = settingEnums.settingDefinitions.ENABLE_DYNAMIC_RUNNING.name
local settingSourceId = "dynamicRunning"

-------------- GLOBALS ----------------------
--control settings, default start. modifiable by a setting.
local dynamicRunningEnabled = false
local bbguiMaxDist = 150

--global for tracking
local dynamicStartTick: number = 0
-- local debounce = false
local dynamicRunFrames: { tt.DynamicRunFrame } = {}

--target sign name => TL;
local textLabelStore: { [string]: TextLabel } = {}

local startDynamicDebounce = false
local renderStepped: RBXScriptConnection? = nil
local dynamicRunEventConnection: RBXScriptConnection? = nil
local avatarEventConnection: RBXScriptConnection? = nil
local lastupdates = {}
local hasReset = false

-------------------- HELPERS ----------------------

--called once per active run + target; after setup, self-runs.
--(also, self-destroys when you leave the area?)
--also, needs dynamic runtime.

--get or create bbgui above sign
local function getOrCreateUI(from: string, to: string): TextLabel?
	if not textLabelStore[to] then
		local ui = drawDynamicGui.DrawDynamicMouseover(from, to)
		if not ui then
			return nil
		end
		textLabelStore[to] = ui
	end
	return textLabelStore[to]
end

local function addSignToDynamicLabelStore(dynamicRunFrame: tt.DynamicRunFrame, from: string)
	_annotate(string.format("adding sign to dynamic label store: %s", dynamicRunFrame.targetSignName))
	table.insert(dynamicRunFrames, dynamicRunFrame)
	getOrCreateUI(from, dynamicRunFrame.targetSignName)
end

local function handleOneDynamicFrameTarget(dynamicRunFrame: tt.DynamicRunFrame)
	local textLabel: TextLabel = textLabelStore[dynamicRunFrame.targetSignName]

	if dynamicStartTick == 0 then
		_annotate("dynamicStartTick == 0")
		return
	end

	local bbguiInstance: Instance? = textLabel:FindFirstAncestorOfClass("BillboardGui")
	if not bbguiInstance or not bbguiInstance:IsA("BillboardGui") then
		_annotate(string.format("no bbgui, %s", dynamicRunFrame.targetSignName))
		return
	end
	local bbgui: BillboardGui = bbguiInstance :: BillboardGui

	local character = localPlayer.Character
	if not character then
		return
	end
	local rootPartInstance = character:FindFirstChild("HumanoidRootPart")
	if not rootPartInstance or not rootPartInstance:IsA("BasePart") then
		return
	end
	local rootPart: BasePart = rootPartInstance :: BasePart

	local pos = rootPart.Position
	local parInstance = bbgui.Parent
	if not parInstance or not parInstance:IsA("BasePart") then
		return
	end
	local par: BasePart = parInstance :: BasePart

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
	for _, item in pairs(textLabelStore) do
		-- item is TextLabel. Parent is Frame. Parent.Parent is BillboardGui.
		if item.Parent and item.Parent.Parent then
			item.Parent.Parent:Destroy()
		end
	end
	textLabelStore = {}
	dynamicRunFrames = {}
end

local function internalStartDynamic(player: Player, signName: string, startTick: number)
	if not dynamicRunningEnabled then
		return
	end

	-- Debounce: if already trying to start this specific run, ignore.
	-- Or if very recent start.
	if startDynamicDebounce then
		return
	end

	local signId = tpUtil.signName2SignId(signName)

	task.spawn(function()
		startDynamicDebounce = true
		dynamicStartTick = startTick

		local data: tt.dynamicRunningControlType = {
			action = dynamicRunningEnums.ACTIONS.DYNAMIC_START,
			fromSignId = signId,
			userId = player.UserId,
		}

		dynamicRunningEvent:FireServer(data)
		task.wait(0.5)
		startDynamicDebounce = false
	end)
end

local function internalResetDynamicTiming(startTick: number)
	if not dynamicRunningEnabled then
		return
	end
	_annotate("resetDynamicTiming")
	dynamicStartTick = startTick
end

-- destroy all UIs and nuke the pointer dict to them
local function internalEndDynamic(force: boolean?)
	_annotate("endDynamic, force:" .. tostring(force))
	if not (force or dynamicRunningEnabled) then
		return
	end

	_annotate("endDynamic, real")

	fullReset()

	dynamicStartTick = 0
	local data: tt.dynamicRunningControlType = {
		action = dynamicRunningEnums.ACTIONS.DYNAMIC_STOP,
		fromSignId = 0,
		userId = localPlayer.UserId,
	}
	dynamicRunningEvent:FireServer(data)
end

-------------------- MODULE FUNCTIONS ----------------------

-- Listen for events instead of being called directly
local avatarEventFiring = require(game.StarterPlayer.StarterPlayerScripts:WaitForChild("avatarEventFiring"))
local aet = require(game.ReplicatedStorage.avatarEventTypes)
local AvatarEventBindableEvent = remotes.getBindableEvent("AvatarEventBindableEvent")

local eventsWeCareAbout = {
	aet.avatarEventTypes.RUN_START,
	aet.avatarEventTypes.RUN_COMPLETE,
	aet.avatarEventTypes.RUN_CANCEL,
	aet.avatarEventTypes.RETOUCH_SIGN,
	aet.avatarEventTypes.AVATAR_DIED,
	aet.avatarEventTypes.AVATAR_RESET,
}

local function handleAvatarEvent(ev: aet.avatarEvent)
	if not avatarEventFiring.EventIsATypeWeCareAbout(ev, eventsWeCareAbout) then
		return
	end

	if ev.eventType == aet.avatarEventTypes.RUN_START then
		if ev.details and ev.details.startSignName then
			internalStartDynamic(localPlayer, ev.details.startSignName, ev.timestamp)
		end
	elseif ev.eventType == aet.avatarEventTypes.RETOUCH_SIGN then
		internalResetDynamicTiming(ev.timestamp)
	elseif
		ev.eventType == aet.avatarEventTypes.RUN_COMPLETE
		or ev.eventType == aet.avatarEventTypes.RUN_CANCEL
		or ev.eventType == aet.avatarEventTypes.AVATAR_DIED
		or ev.eventType == aet.avatarEventTypes.AVATAR_RESET
	then
		internalEndDynamic()
	end
end

-- Public API (reduced surface area)
-- Still exposed for settings changes, but not for racing logic
module.endDynamic = internalEndDynamic

local function receiveDynamicRunData(updates: tt.dynamicRunFromData)
	if not dynamicRunningEnabled then
		_annotate("received but dynamic running disabled")
		return
	end
	_annotate(string.format("Apply dynamicRunning %d %s", #updates.frames, updates.fromSignName))

	-- Since drawDynamicGui calls signName2Sign which calls WaitForChild, this MIGHT yield.
	-- However, we are running on the client, and signs are streamed.
	-- If it yields, we want to make sure we don't have a race condition.
	-- But since we removed the reset/locking logic, we just add.
	-- If a reset happened in the meantime, textLabelStore was cleared.
	-- If we add now, we add to the new store.
	-- The only risk is adding a label for an OLD run to a NEW run.
	-- We can check dynamicStartTick.

	local capturedStartTick = dynamicStartTick

	for _, dynamicRunFrame: tt.DynamicRunFrame in ipairs(updates.frames) do
		if dynamicRunFrame.targetSignName == "👻" then
			continue
		end

		-- If the run has reset or changed while we were processing (unlikely but possible if yields occur), abort.
		if dynamicStartTick ~= capturedStartTick or dynamicStartTick == 0 then
			return
		end

		addSignToDynamicLabelStore(dynamicRunFrame, updates.fromSignName)
	end
end

local function setupRenderStepped()
	if renderStepped then
		return
	end
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

local function teardownRenderStepped()
	if not renderStepped then
		return
	end
	renderStepped:Disconnect()
	renderStepped = nil
	_annotate("kill renderstepped")
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
				_annotate("disabling dynamic running")
				dynamicRunningEnabled = false
				teardownRenderStepped()
				module.endDynamic(true)
			end
		end
	end
	return nil
end

module.Init = function()
	_annotate("init")
	if dynamicStartTick == 0 then
		dynamicStartTick = 0
		dynamicRunFrames = {}
		textLabelStore = {}
		lastupdates = {}
		hasReset = false
		startDynamicDebounce = false
	end

	if not dynamicRunEventConnection then
		dynamicRunEventConnection = dynamicRunningEvent.OnClientEvent:Connect(receiveDynamicRunData)
	end

	settings.UnregisterFunctionToListenForSettingName(settingName, settingSourceId)
	settings.RegisterFunctionToListenForSettingName(function(item)
		return handleUserSettingChanged(item)
	end, settingName, settingSourceId)

	local dynset = settings.GetSettingByName(settingName)
	if dynset then
		handleUserSettingChanged(dynset)
	else
		_annotate("dynamic running setting missing; defaulting to disabled")
		dynamicRunningEnabled = false
	end

	if not avatarEventConnection then
		avatarEventConnection = AvatarEventBindableEvent.Event:Connect(handleAvatarEvent)
	end

	_annotate("init done")
end

_annotate("end")
return module
