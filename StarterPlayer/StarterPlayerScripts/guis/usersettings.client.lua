--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local us: UserSettings = UserSettings()
local GameSettings = us.GameSettings

local function onGameSettingChanged(nameOfSetting)
	local canGetSetting, setting = pcall(function()
		return GameSettings[nameOfSetting]
	end)

	if canGetSetting then
		-- print("Your " .. nameOfSetting .. " has changed to: " .. tostring(setting))
	end
end

GameSettings.Changed:Connect(onGameSettingChanged)

local LocalizationService = game:GetService("LocalizationService")
local success, translator = pcall(function()
	return LocalizationService:GetTranslatorForPlayerAsync(game.Players.LocalPlayer)
end)

if success then
	local id = translator.LocaleId
end
