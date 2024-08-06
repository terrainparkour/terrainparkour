--!strict

-- client keyboard shortcuts
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}
local textHighlighting = require(game.ReplicatedStorage.gui.textHighlighting)

local remotes = require(game.ReplicatedStorage.util.remotes)
local settings = require(game.ReplicatedStorage.settings)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)

local warper = require(game.StarterPlayer.StarterPlayerScripts.warper)
local mt = require(game.ReplicatedStorage.avatarEventTypes)

local avatarEventFiring = require(game.StarterPlayer.StarterPlayerScripts.avatarEventFiring)
local fireEvent = avatarEventFiring.FireEvent

local PlayersService = game:GetService("Players")
local localPlayer = PlayersService.LocalPlayer
local AvatarEventBindableEvent: BindableEvent = remotes.getBindableEvent("AvatarEventBindableEvent")

local tt = require(game.ReplicatedStorage.types.gametypes)
local UserInputService = game:GetService("UserInputService")

---------------- GLOBALS ---------------------
------------------------- live-monitor this setting value. -------------
local userWantsHighlightingWhenWarpingWithKeyboard = false
local ignoreChatWhenHittingX = false
local showLB: boolean = true

--------------- "remember" the last runs they've worked on for '1'
local lastRunStart = nil
local lastRunEnd = nil

local function ToggleChat(intendedState: boolean)
	local ChatMain =
		require(game.Players.LocalPlayer.PlayerScripts:FindFirstChild("ChatScript"):WaitForChild("ChatMain"))
	ChatMain:SetVisible(intendedState)
end

local function ToggleLB(intendedState: boolean)
	local items = { localPlayer:WaitForChild("PlayerGui"):FindFirstChild("LeaderboardScreenGui") }
	if not items then
		--_annotate("no leaderboard screen gui found.")
		return
	end
	for _, el in ipairs(items) do
		if el == nil then
			--_annotate("bad item.")
			continue
		end
		el.Enabled = intendedState
	end
end

local function KillPopups()
	for _, el in ipairs(localPlayer:WaitForChild("PlayerGui"):GetChildren()) do
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
	if not ignoreChatWhenHittingX then
		ToggleChat(false)
	end
end

local keyboardShortcutButton = require(game.StarterPlayer.StarterPlayerScripts.buttons.keyboardShortcutGui)

-------------- all the shortcuts are here. ----------------
local function onInputBegin(inputObject, gameProcessedEvent)
	if not inputObject.KeyCode then
		return
	end

	if gameProcessedEvent then
		return
	end

	if inputObject.UserInputType == Enum.UserInputType.Keyboard then
		if inputObject.KeyCode == Enum.KeyCode.One then
			local useLastRunEnd = nil
			if userWantsHighlightingWhenWarpingWithKeyboard then
				useLastRunEnd = lastRunEnd
			end
			if lastRunStart ~= nil and lastRunEnd ~= nil then
				warper.WarpToSign(lastRunStart, useLastRunEnd)
			end
		elseif inputObject.KeyCode == Enum.KeyCode.H then
			textHighlighting.KillAllExistingHighlights()
			print("kill all highlights.")
		elseif inputObject.KeyCode == Enum.KeyCode.Tab then
			showLB = not showLB
			ToggleLB(showLB)
		elseif inputObject.KeyCode == Enum.KeyCode.X then
			KillPopups()
		elseif inputObject.KeyCode == Enum.KeyCode.Z then
			fireEvent(mt.avatarEventTypes.RUN_KILL, { reason = "hit c on keyboard" })
		elseif inputObject.KeyCode == Enum.KeyCode.K then
			keyboardShortcutButton.CreateShortcutGui()
		end
	end
end

local function handleUserSettingChanged(item: tt.userSettingValue): any
	if item.name == settingEnums.settingNames.HIGHLIGHT_ON_KEYBOARD_1_TO_WARP then
		userWantsHighlightingWhenWarpingWithKeyboard = item.value
	elseif item.name == settingEnums.settingNames.X_BUTTON_IGNORES_CHAT then
		ignoreChatWhenHittingX = item.value
	end
end

local deb = false
local function handleAvatarEvent(ev: mt.avatarEvent)
	if deb then
		--_annotate("deb, waiting in handleAvatarEvent")
		task.wait()
	end
	deb = true
	if ev.eventType == mt.avatarEventTypes.RUN_START then
		--_annotate(string.format("run start, setting lastRunStart to %d", ev.details.relatedSignId))
		lastRunStart = ev.details.relatedSignId
	elseif ev.eventType == mt.avatarEventTypes.RUN_COMPLETE then
		--_annotate(string.format("run complete, setting lastRunEnd to %d", ev.details.relatedSignId))
		lastRunEnd = ev.details.relatedSignId
	end
	deb = false
end

module.Init = function()
	deb = false
	AvatarEventBindableEvent.Event:Connect(handleAvatarEvent)
	UserInputService.InputBegan:Connect(onInputBegin)

	settings.RegisterFunctionToListenForSettingName(
		handleUserSettingChanged,
		settingEnums.settingNames.HIGHLIGHT_ON_KEYBOARD_1_TO_WARP
	)

	settings.RegisterFunctionToListenForSettingName(
		handleUserSettingChanged,
		settingEnums.settingNames.X_BUTTON_IGNORES_CHAT
	)

	handleUserSettingChanged(settings.getSettingByName(settingEnums.settingNames.HIGHLIGHT_ON_KEYBOARD_1_TO_WARP))
	handleUserSettingChanged(settings.getSettingByName(settingEnums.settingNames.X_BUTTON_IGNORES_CHAT))
end

_annotate("end")
return module
