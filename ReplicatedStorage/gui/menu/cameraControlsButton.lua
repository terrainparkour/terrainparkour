--!strict

-- cameraControlsButton.lua :: ReplicatedStorage.gui.menu.cameraControlsButton
-- Hamburger menu button for camera controls. Provides presets and individual
-- settings for player position, FOV, zoom range, and sensitivity.
-- All settings persist and apply automatically on game load.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local colors = require(game.ReplicatedStorage.util.colors)
local gt = require(game.ReplicatedStorage.gui.guiTypes)
local settings = require(game.ReplicatedStorage.settings)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local tt = require(game.ReplicatedStorage.types.gametypes)
local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)
local wt = require(game.StarterPlayer.StarterPlayerScripts.guis.windowsTypes)

local module = {}

--------------------------------------------------------------------------------
-- Types
--------------------------------------------------------------------------------

export type CameraSettings = {
	cameraOffset: number,
	fov: number,
	zoomMin: number,
	zoomMax: number,
	sensitivity: number,
}

export type CameraPreset = {
	name: string,
	description: string,
	settings: CameraSettings,
	color: Color3,
}

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local DEFAULTS: CameraSettings = {
	cameraOffset = 0,
	fov = 70,
	zoomMin = 0.5,
	zoomMax = 128,
	sensitivity = 1.0,
}

-- Presets for common playstyles
local PRESETS: { CameraPreset } = {
	{
		name = "Default",
		description = "Standard Roblox camera",
		settings = {
			cameraOffset = 0,
			fov = 70,
			zoomMin = 0.5,
			zoomMax = 128,
			sensitivity = 1.0,
		},
		color = colors.defaultGrey,
	},
	{
		name = "Speedrun",
		description = "Wide FOV, player lower",
		settings = {
			cameraOffset = 4,
			fov = 90,
			zoomMin = 8,
			zoomMax = 24,
			sensitivity = 1.2,
		},
		color = colors.lightGreen,
	},
	{
		name = "Explorer",
		description = "See more terrain ahead",
		settings = {
			cameraOffset = 6,
			fov = 80,
			zoomMin = 12,
			zoomMax = 200,
			sensitivity = 0.8,
		},
		color = colors.hudCyan,
	},
	{
		name = "Cinematic",
		description = "Dramatic, lower FOV",
		settings = {
			cameraOffset = 2,
			fov = 55,
			zoomMin = 6,
			zoomMax = 64,
			sensitivity = 0.6,
		},
		color = colors.meColor,
	},
}

--------------------------------------------------------------------------------
-- Settings Management
--------------------------------------------------------------------------------

local function getCameraSettings(): CameraSettings
	local setting = settings.GetSettingByName(settingEnums.settingDefinitions.CAMERA_SETTINGS.name)
	if setting and setting.luaValue then
		local val = setting.luaValue :: { [string]: number? }
		return {
			cameraOffset = val.cameraOffset or DEFAULTS.cameraOffset,
			fov = val.fov or DEFAULTS.fov,
			zoomMin = val.zoomMin or DEFAULTS.zoomMin,
			zoomMax = val.zoomMax or DEFAULTS.zoomMax,
			sensitivity = val.sensitivity or DEFAULTS.sensitivity,
		}
	end
	return DEFAULTS
end

local function saveCameraSettings(s: CameraSettings)
	local newSetting: tt.userSettingValue = {
		name = settingEnums.settingDefinitions.CAMERA_SETTINGS.name,
		domain = settingEnums.settingDefinitions.CAMERA_SETTINGS.domain,
		kind = settingEnums.settingKinds.LUA,
		luaValue = {
			cameraOffset = s.cameraOffset,
			fov = s.fov,
			zoomMin = s.zoomMin,
			zoomMax = s.zoomMax,
			sensitivity = s.sensitivity,
		},
	}
	settings.SetSetting(newSetting)
	_annotate(string.format("Saved camera: offset=%.1f, fov=%d, zoom=%.1f-%.1f, sens=%.2f", s.cameraOffset, s.fov, s.zoomMin, s.zoomMax, s.sensitivity))
end

--------------------------------------------------------------------------------
-- Camera Application
--------------------------------------------------------------------------------

local function applyCameraSettings(s: CameraSettings)
	local localPlayer = Players.LocalPlayer
	local character = localPlayer.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			-- Only set Y offset (preserve X for shift lock)
			local currentOffset = humanoid.CameraOffset
			humanoid.CameraOffset = Vector3.new(currentOffset.X, s.cameraOffset, currentOffset.Z)
		end
	end

	local camera = workspace.CurrentCamera
	if camera then
		camera.FieldOfView = s.fov
	end

	-- Zoom limits
	localPlayer.CameraMinZoomDistance = s.zoomMin
	localPlayer.CameraMaxZoomDistance = s.zoomMax

	-- Sensitivity (affects mouse/touch rotation speed)
	local gameSettings = UserInputService:GetPropertyChangedSignal("MouseDeltaSensitivity") and UserInputService or nil
	if gameSettings then
		-- Note: MouseDeltaSensitivity is read-only in Roblox, but we can use GameSettings
		-- The workaround is to modify the camera script behavior via attributes
		localPlayer:SetAttribute("CameraSensitivity", s.sensitivity)
	end

	_annotate(string.format("Applied camera: offset=%.1f, fov=%d, zoom=%.1f-%.1f, sens=%.2f", s.cameraOffset, s.fov, s.zoomMin, s.zoomMax, s.sensitivity))
end

--------------------------------------------------------------------------------
-- UI Helpers
--------------------------------------------------------------------------------

local function createRow(name: string, order: number, height: number, tileSpecs: { wt.tileSpec }): wt.rowSpec
	return {
		name = name,
		order = order,
		height = UDim.new(0, height),
		tileSpecs = tileSpecs,
	}
end

local function createLabel(text: string, bgColor: Color3?, bold: boolean?): wt.textTileSpec
	return {
		type = "text",
		text = text,
		isMonospaced = false,
		isBold = bold or false,
		backgroundColor = bgColor or colors.defaultGrey,
		textColor = colors.black,
		textXAlignment = Enum.TextXAlignment.Center,
	}
end

local function createValueButton(
	text: string,
	isActive: boolean,
	onClick: () -> ()
): wt.buttonTileSpec
	return {
		type = "button",
		text = text,
		isMonospaced = false,
		isBold = false,
		backgroundColor = if isActive then colors.lightGreen else colors.defaultGrey,
		hoverBackgroundColor = if isActive then colors.lightGreen else colors.lightGrey,
		textColor = colors.black,
		textXAlignment = Enum.TextXAlignment.Center,
		onClick = function()
			onClick()
		end,
	}
end

--------------------------------------------------------------------------------
-- UI Builder
--------------------------------------------------------------------------------

local function showCameraControlsPopup(): ScreenGui
	local localPlayer = Players.LocalPlayer
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		local dummyGui = Instance.new("ScreenGui")
		dummyGui.Name = "CameraControlsDummy"
		dummyGui.Enabled = false
		return dummyGui
	end

	local activeGui: ScreenGui? = nil
	local currentSettings = getCameraSettings()

	local function rebuildPanel()
		if activeGui then
			activeGui:Destroy()
			activeGui = nil
		end

		currentSettings = getCameraSettings()
		local rowSpecs: { wt.rowSpec } = {}
		local order = 1

		-- Title
		table.insert(rowSpecs, createRow("Title", order, 28, {
			{
				name = "TitleText",
				order = 1,
				width = UDim.new(1, 0),
				spec = createLabel("Camera Settings", colors.signColor, true),
			},
		}))
		order += 1

		-- Experimental note
		table.insert(rowSpecs, createRow("Note", order, 32, {
			{
				name = "NoteText",
				order = 1,
				width = UDim.new(1, 0),
				spec = {
					type = "text",
					text = "Note: these are experimental and may not always be here. I wanted to get you guys feedback on this.",
					isMonospaced = false,
					isBold = false,
					backgroundColor = colors.meColor,
					textColor = colors.black,
					textXAlignment = Enum.TextXAlignment.Center,
					textWrapped = true,
				} :: wt.textTileSpec,
			},
		}))
		order += 1

		-- Current values display
		table.insert(rowSpecs, createRow("CurrentValues", order, 22, {
			{
				name = "Values",
				order = 1,
				width = UDim.new(1, 0),
				spec = createLabel(
					string.format(
						"Offset: %.0f | FOV: %d | Zoom: %.0f-%.0f | Sens: %.1fx",
						currentSettings.cameraOffset,
						currentSettings.fov,
						currentSettings.zoomMin,
						currentSettings.zoomMax,
						currentSettings.sensitivity
					),
					colors.lightGrey,
					false
				),
			},
		}))
		order += 1

		-- Presets section
		table.insert(rowSpecs, createRow("PresetsHeader", order, 24, {
			{
				name = "Header",
				order = 1,
				width = UDim.new(1, 0),
				spec = createLabel("Quick Presets", colors.blueDone, true),
			},
		}))
		order += 1

		-- Preset buttons (2 per row)
		for i = 1, #PRESETS, 2 do
			local tiles: { wt.tileSpec } = {}
			for j = 0, 1 do
				local preset = PRESETS[i + j]
				if preset then
					table.insert(tiles, {
						name = preset.name,
						order = j + 1,
						width = UDim.new(0.5, 0),
						spec = {
							type = "button",
							text = preset.name,
							isMonospaced = false,
							isBold = false,
							backgroundColor = preset.color,
							hoverBackgroundColor = colors.lightGrey,
							textColor = colors.black,
							textXAlignment = Enum.TextXAlignment.Center,
							onClick = function()
								currentSettings = {
									cameraOffset = preset.settings.cameraOffset,
									fov = preset.settings.fov,
									zoomMin = preset.settings.zoomMin,
									zoomMax = preset.settings.zoomMax,
									sensitivity = preset.settings.sensitivity,
								}
								saveCameraSettings(currentSettings)
								applyCameraSettings(currentSettings)
								rebuildPanel()
							end,
						} :: wt.buttonTileSpec,
					})
				end
			end
			table.insert(rowSpecs, createRow(string.format("PresetRow%d", i), order, 30, tiles))
			order += 1
		end

		-- Player Position (Camera Offset) section
		table.insert(rowSpecs, createRow("OffsetHeader", order, 24, {
			{
				name = "Header",
				order = 1,
				width = UDim.new(1, 0),
				spec = createLabel("Player Position (higher = player lower on screen)", colors.blueDone, true),
			},
		}))
		order += 1

		local offsetValues = { 0, 2, 4, 6, 8, 10 }
		local offsetTiles: { wt.tileSpec } = {}
		for i, val in ipairs(offsetValues) do
			table.insert(offsetTiles, {
				name = string.format("Off%d", val),
				order = i,
				width = UDim.new(1 / #offsetValues, 0),
				spec = createValueButton(tostring(val), currentSettings.cameraOffset == val, function()
					currentSettings.cameraOffset = val
					saveCameraSettings(currentSettings)
					applyCameraSettings(currentSettings)
					rebuildPanel()
				end),
			})
		end
		table.insert(rowSpecs, createRow("OffsetButtons", order, 28, offsetTiles))
		order += 1

		-- FOV section
		table.insert(rowSpecs, createRow("FOVHeader", order, 24, {
			{
				name = "Header",
				order = 1,
				width = UDim.new(1, 0),
				spec = createLabel("Field of View (wider = see more)", colors.blueDone, true),
			},
		}))
		order += 1

		local fovValues = { 55, 70, 80, 90, 100, 110 }
		local fovTiles: { wt.tileSpec } = {}
		for i, val in ipairs(fovValues) do
			table.insert(fovTiles, {
				name = string.format("FOV%d", val),
				order = i,
				width = UDim.new(1 / #fovValues, 0),
				spec = createValueButton(tostring(val), currentSettings.fov == val, function()
					currentSettings.fov = val
					saveCameraSettings(currentSettings)
					applyCameraSettings(currentSettings)
					rebuildPanel()
				end),
			})
		end
		table.insert(rowSpecs, createRow("FOVButtons", order, 28, fovTiles))
		order += 1

		-- Zoom Range section
		table.insert(rowSpecs, createRow("ZoomHeader", order, 24, {
			{
				name = "Header",
				order = 1,
				width = UDim.new(1, 0),
				spec = createLabel("Zoom Range", colors.blueDone, true),
			},
		}))
		order += 1

		-- Zoom presets as combined min-max pairs
		local zoomPresets = {
			{ label = "Close", min = 4, max = 16 },
			{ label = "Medium", min = 8, max = 32 },
			{ label = "Far", min = 12, max = 64 },
			{ label = "Ultra", min = 0.5, max = 200 },
		}
		local zoomTiles: { wt.tileSpec } = {}
		for i, preset in ipairs(zoomPresets) do
			local isActive = currentSettings.zoomMin == preset.min and currentSettings.zoomMax == preset.max
			table.insert(zoomTiles, {
				name = preset.label,
				order = i,
				width = UDim.new(1 / #zoomPresets, 0),
				spec = createValueButton(preset.label, isActive, function()
					currentSettings.zoomMin = preset.min
					currentSettings.zoomMax = preset.max
					saveCameraSettings(currentSettings)
					applyCameraSettings(currentSettings)
					rebuildPanel()
				end),
			})
		end
		table.insert(rowSpecs, createRow("ZoomButtons", order, 28, zoomTiles))
		order += 1

		-- Sensitivity section
		table.insert(rowSpecs, createRow("SensHeader", order, 24, {
			{
				name = "Header",
				order = 1,
				width = UDim.new(1, 0),
				spec = createLabel("Camera Sensitivity", colors.blueDone, true),
			},
		}))
		order += 1

		local sensValues = { 0.5, 0.8, 1.0, 1.2, 1.5, 2.0 }
		local sensTiles: { wt.tileSpec } = {}
		for i, val in ipairs(sensValues) do
			local label = if val == 1.0 then "1x" else string.format("%.1fx", val)
			table.insert(sensTiles, {
				name = string.format("Sens%.1f", val),
				order = i,
				width = UDim.new(1 / #sensValues, 0),
				spec = createValueButton(label, math.abs(currentSettings.sensitivity - val) < 0.01, function()
					currentSettings.sensitivity = val
					saveCameraSettings(currentSettings)
					applyCameraSettings(currentSettings)
					rebuildPanel()
				end),
			})
		end
		table.insert(rowSpecs, createRow("SensButtons", order, 28, sensTiles))
		order += 1

		-- Reset button
		table.insert(rowSpecs, createRow("ResetRow", order, 28, {
			{
				name = "Reset",
				order = 1,
				width = UDim.new(1, 0),
				spec = {
					type = "button",
					text = "Reset to Defaults",
					isMonospaced = false,
					isBold = false,
					backgroundColor = colors.lightRed,
					hoverBackgroundColor = colors.red,
					textColor = colors.black,
					textXAlignment = Enum.TextXAlignment.Center,
					onClick = function()
						currentSettings = {
							cameraOffset = DEFAULTS.cameraOffset,
							fov = DEFAULTS.fov,
							zoomMin = DEFAULTS.zoomMin,
							zoomMax = DEFAULTS.zoomMax,
							sensitivity = DEFAULTS.sensitivity,
						}
						saveCameraSettings(currentSettings)
						applyCameraSettings(currentSettings)
						rebuildPanel()
					end,
				} :: wt.buttonTileSpec,
			},
		}))
		order += 1

		-- Close button
		table.insert(rowSpecs, createRow("CloseRow", order, 28, { windows.StandardCloseButton }))

		local guiSpec: wt.guiSpec = {
			name = "CameraSettings",
			rowSpecs = rowSpecs,
		}

		local totalHeight = 0
		for _, rowSpec in ipairs(rowSpecs) do
			totalHeight = totalHeight + rowSpec.height.Offset
		end

		local popupResult = windows.CreatePopup(
			guiSpec,
			"CameraSettingsPopup",
			true, -- draggable
			true, -- resizable
			false, -- minimizable
			false, -- pinnable
			true, -- dismissableWithX
			false, -- dismissableByClick
			UDim2.fromOffset(340, totalHeight),
			nil,
			{
				settingName = "CAMERA_CONTROLS_GUI_LAYOUT",
				settingKey = "position",
				saveSize = true,
				sizeKey = "size",
				clampOnLoad = true,
				defaultPosition = UDim2.fromScale(0.35, 0.25),
			}
		)

		activeGui = popupResult.sgui
		activeGui.Parent = playerGui
	end

	rebuildPanel()
	return activeGui or Instance.new("ScreenGui")
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

-- Apply saved camera settings (called on game load)
function module.ApplySavedSettings()
	local s = getCameraSettings()
	applyCameraSettings(s)
	_annotate(string.format("Applied saved camera on load: offset=%.1f, fov=%d", s.cameraOffset, s.fov))
end

-- Button definition for hamburger menu
local cameraControlsButton: gt.button = {
	name = "Camera",
	contentsGetter = function(_player: Player): ScreenGui
		return showCameraControlsPopup()
	end,
}

module.cameraControlsButton = cameraControlsButton

_annotate("end")
return module
