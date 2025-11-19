--!strict

-- usersettings.client.lua @ rojo/StarterPlayer/StarterPlayerScripts/guis
-- Monitors Roblox native UserSettings for potential future integration with TerrainParkour custom settings system.
-- Currently observational only; does not affect game behavior or custom settings stored in Django backend.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
annotater.Init()

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

-- Module internals

local robloxUserSettings: UserSettings = UserSettings()
local gameSettings: UserGameSettings = robloxUserSettings:GetService("UserGameSettings")
local localPlayer: Player = Players.LocalPlayer

-- Track whether we have logged initial state to avoid spam
local hasLoggedInitialState: boolean = false

-- Monitor Roblox native UserGameSettings changes
-- Future work: could sync certain Roblox settings with our Django-backed custom settings
local function onRobloxGameSettingChanged(propertyName: string)
	if not hasLoggedInitialState then
		return
	end
	local success, value = pcall(function()
		return (gameSettings :: any)[propertyName]
	end)
	if success then
		_annotate(string.format("roblox.setting.changed|%s=%s", propertyName, tostring(value)))
	end
end

-- Capture player locale for potential future localization
local function capturePlayerLocale()
	task.spawn(function()
		local LocalizationService = game:GetService("LocalizationService")
		local success, translator = pcall(function()
			return LocalizationService:GetTranslatorForPlayerAsync(localPlayer)
		end)
		if success and translator then
			_annotate(string.format("player.locale|%s|%d", translator.LocaleId, localPlayer.UserId))
		end
	end)
end

-- Log initial Roblox settings state for debugging/telemetry
local function logInitialRobloxSettings()
	local touchEnabled = UserInputService.TouchEnabled
	local mouseEnabled = UserInputService.MouseEnabled
	local keyboardEnabled = UserInputService.KeyboardEnabled
	local gamepadEnabled = UserInputService.GamepadEnabled
	
	_annotate(
		string.format(
			"roblox.settings.initial|touch=%s|mouse=%s|keyboard=%s|gamepad=%s",
			tostring(touchEnabled),
			tostring(mouseEnabled),
			tostring(keyboardEnabled),
			tostring(gamepadEnabled)
		)
	)
	
	hasLoggedInitialState = true
end

-- Setup monitoring
gameSettings.Changed:Connect(onRobloxGameSettingChanged)
logInitialRobloxSettings()
capturePlayerLocale()

_annotate("end")
