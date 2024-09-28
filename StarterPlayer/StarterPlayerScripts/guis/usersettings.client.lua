--!strict

-- 2024: not sure this does anything at all?

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local us: UserSettings = UserSettings()

local GameSettings: UserGameSettings = us:GetService("UserGameSettings")

local function onGameSettingChanged(nameOfSetting: string)
	local canGetSetting, setting = pcall(function()
		return GameSettings[nameOfSetting]
	end)
end

GameSettings.Changed:Connect(onGameSettingChanged)

local LocalizationService = game:GetService("LocalizationService")
local success, translator = pcall(function()
	return LocalizationService:GetTranslatorForPlayerAsync(game.Players.LocalPlayer)
end)

if success then
	local id = translator.LocaleId
end

_annotate("end")
