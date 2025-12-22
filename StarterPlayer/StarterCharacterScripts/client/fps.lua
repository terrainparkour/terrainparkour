--!strict

-- fps.lua :: StarterPlayer.StarterCharacterScripts.client.fps
-- Displays current FPS in a small draggable overlay on screen.
-- Controlled by user setting, off by default.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local annotater = require(ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local colors = require(ReplicatedStorage.util.colors)
local settings = require(ReplicatedStorage.settings)
local settingEnums = require(ReplicatedStorage.UserSettings.settingEnums)
local windowFunctions = require(game.StarterPlayer.StarterPlayerScripts.guis.windowFunctions)
local tt = require(ReplicatedStorage.types.gametypes)

type Module = {
	Init: () -> (),
}

local module: Module = {} :: Module

-- Module internals
local initialized = false
local localPlayer: Player = Players.LocalPlayer
local playerGui: PlayerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
local renderConnection: RBXScriptConnection? = nil
local fpsLabel: TextLabel? = nil
local screenGui: ScreenGui? = nil
local fpsEnabled = false

local settingName = settingEnums.settingDefinitions.SHOW_FPS_DISPLAY.name
local settingSourceId = "fps.lua"

-- Smoothing: average over recent frames for stable display
local frameTimeBuffer: { number } = {}
local bufferSize = 30

local function createGui(): (ScreenGui, Frame, TextLabel)
	local existingGui = playerGui:FindFirstChild("FPSDisplay")
	if existingGui then
		existingGui:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "FPSDisplay"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 9998
	gui.Parent = playerGui

	local windowsTypes = require(game.StarterPlayer.StarterPlayerScripts.guis.windowsTypes)

	-- Create guiSpec for FPS display
	local fpsGuiSpec: windowsTypes.guiSpec = {
		name = "FPSDisplay",
		rowSpecs = {
			{
				name = "FPSRow",
				order = 1,
				height = UDim.new(0, 28),
				tileSpecs = {
					{
						name = "FPSLabel",
						order = 1,
						width = UDim.new(1, 0),
						spec = {
							type = "text",
							text = "-- FPS",
							isMonospaced = true,
							isBold = false,
							backgroundColor = nil, -- Transparent - outerFrame background shows through
							textColor = colors.textSoft,
							textXAlignment = Enum.TextXAlignment.Left,
							textYAlignment = Enum.TextYAlignment.Center,
							textWrapped = false,
							textScaled = false,
							textSize = 14,
							leftPadding = 6,
							rightPadding = 6,
						},
					},
				},
			},
		},
	}

	-- Use windowFunctions.SetupFrame with guiSpec
	local frameSetup = windowFunctions.SetupFrame(
		"FPSDisplay",
		true, -- draggable
		false, -- resizable
		false, -- minimizable
		false, -- pinnable
		UDim2.new(0, 70, 0, 28),
		false, -- maintainAspectRatio
		{
			settingName = "FPS_GUI_LAYOUT",
			settingKey = "position",
			saveSize = false,
			clampOnLoad = true,
		},
		nil, -- resizeConfig
		fpsGuiSpec, -- guiSpec
		nil, -- contentOptions
		nil -- popupOptions
	)

	local frame = frameSetup.outerFrame
	-- TPian styling: no rounded corners, use border
	frame.BackgroundColor3 = colors.panelDark
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel = 1
	frame.BorderMode = Enum.BorderMode.Outline
	frame.BorderColor3 = colors.defaultGrey
	frame.Parent = gui

	-- Set default position if not loaded from settings
	if frame.Position.X.Scale == 0 and frame.Position.X.Offset == 0 and frame.Position.Y.Scale == 0 and frame.Position.Y.Offset == 0 then
		frame.Position = UDim2.new(1, -80, 0, 10)
	end

	-- Get label reference from builtContent (captured at creation time, no fallback)
	local label = if frameSetup.builtContent and frameSetup.builtContent["FPSLabel"] then frameSetup.builtContent["FPSLabel"] :: TextLabel else nil
	if not label then
		error("FPSLabel not found in builtContent - this indicates a bug in buildContentFromGuiSpec")
	end

	-- Make label background transparent so outerFrame background shows through
	label.BackgroundTransparency = 1

	return gui, frame, label
end

local function calculateSmoothedFps(deltaTime: number): number
	table.insert(frameTimeBuffer, deltaTime)
	if #frameTimeBuffer > bufferSize then
		table.remove(frameTimeBuffer, 1)
	end

	local sum = 0
	for _, dt in ipairs(frameTimeBuffer) do
		sum = sum + dt
	end

	local avgDelta = sum / #frameTimeBuffer
	return math.floor(1 / avgDelta + 0.5)
end

local function startRendering()
	if renderConnection then
		return
	end

	local lastUpdate = 0
	renderConnection = RunService.RenderStepped:Connect(function(deltaTime: number)
		local fps = calculateSmoothedFps(deltaTime)

		-- Update display every ~0.1 seconds to avoid excessive updates
		local now = tick()
		if now - lastUpdate >= 0.1 then
			lastUpdate = now
			if fpsLabel then
				fpsLabel.Text = string.format("%d FPS", fps)

				-- Color code based on performance
				if fps >= 55 then
					fpsLabel.TextColor3 = colors.dataPositive
				elseif fps >= 30 then
					fpsLabel.TextColor3 = colors.dataHighlight
				else
					fpsLabel.TextColor3 = colors.dataNegative
				end
			end
		end
	end)
end

local function stopRendering()
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	frameTimeBuffer = {}
end

local function enableFpsDisplay()
	if fpsEnabled then
		return
	end
	fpsEnabled = true

	if not screenGui then
		local gui, _frame, label = createGui()
		screenGui = gui
		fpsLabel = label
	end

	if screenGui then
		screenGui.Enabled = true
	end
	startRendering()
	_annotate("FPS display enabled")
end

local function disableFpsDisplay()
	if not fpsEnabled then
		return
	end
	fpsEnabled = false

	stopRendering()
	if screenGui then
		screenGui.Enabled = false
	end
	_annotate("FPS display disabled")
end

local function handleUserSettingChanged(setting: tt.userSettingValue)
	if setting.name == settingName then
		if setting.booleanValue == true then
			enableFpsDisplay()
		else
			disableFpsDisplay()
		end
	end
	return nil
end

function module.Init()
	if initialized then
		return
	end
	initialized = true

	-- Register for setting changes
	settings.UnregisterFunctionToListenForSettingName(settingName, settingSourceId)
	settings.RegisterFunctionToListenForSettingName(function(item)
		return handleUserSettingChanged(item)
	end, settingName, settingSourceId)

	-- Check current setting value
	local currentSetting = settings.GetSettingByName(settingName)
	if currentSetting then
		handleUserSettingChanged(currentSetting)
	else
		_annotate("FPS display setting not found; defaulting to disabled")
		disableFpsDisplay()
	end

	_annotate("initialized")
end

_annotate("end")
return module
