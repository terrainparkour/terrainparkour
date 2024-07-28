--!strict

-- hide chat window and leaderboard when the user hits tab.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local UserInputService = game:GetService("UserInputService")
local showLB: boolean = true
local showChat: boolean = true

local PlayersService = game:GetService("Players")

local localPlayer = PlayersService.LocalPlayer
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local localFunctions = require(game.ReplicatedStorage.localFunctions)
local tt = require(game.ReplicatedStorage.types.gametypes)
local ignoreChatWhenHittingX = false

local function ToggleChat(intendedState: boolean)
	local ChatMain =
		require(game.Players.LocalPlayer.PlayerScripts:FindFirstChild("ChatScript"):WaitForChild("ChatMain"))
	ChatMain:SetVisible(intendedState)
end

local function ToggleLB(intendedState: boolean)
	local items = { localPlayer.PlayerGui:FindFirstChild("LeaderboardScreenGui") }
	for _, el in ipairs(items) do
		if el == nil then
			print("bad item.")
			continue
		end
		el.Enabled = intendedState
	end
end

--2023.03 also kill cwrs UI
local function KillPopups()
	for _, el in ipairs(localPlayer.PlayerGui:GetChildren()) do
		if string.sub(el.Name, 0, 14) == "RaceResultSgui" then
			el:Destroy()
		end
		if string.sub(el.Name, 0, 16) == "SignStatusSgui" then
			el:Destroy()
		end

		if el.Name == "EphemeralNotificationSgui" then
			el:Destroy()
		end
		if el.Name == "ToolTipGui" then
			el:Destroy()
		end
		if el.Name == "NewFindSgui" then
			el:Destroy()
		end
		if el.Name == "EphemeralTooltip" then
			el:Destroy()
		end
	end
	if ignoreChatWhenHittingX then
	else
		ToggleChat(false)
	end
end

local function onInputBegin(inputObject, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end

	if inputObject.UserInputType == Enum.UserInputType.Keyboard then
		if inputObject.KeyCode == Enum.KeyCode.Tab then
			showLB = not showLB
			ToggleLB(showLB)
		end

		if inputObject.KeyCode == Enum.KeyCode.X then
			KillPopups()
		end
	end
end

UserInputService.InputBegan:Connect(onInputBegin)

local handleUserSettingChanged = function(item: tt.userSettingValue)
	if ignoreChatWhenHittingX ~= item.value then
		ignoreChatWhenHittingX = item.value
		-- print("changed x button ignore chat to " .. tostring(item.value))
	end
end

localFunctions.registerLocalSettingChangeReceiver(function(item: tt.userSettingValue): any
	return handleUserSettingChanged(item)
end, "handleXButtonEffectSettingChanged")

local sval = localFunctions.getSettingByName(settingEnums.settingNames.X_BUTTON_IGNORES_CHAT)
handleUserSettingChanged(sval)
_annotate("end")
