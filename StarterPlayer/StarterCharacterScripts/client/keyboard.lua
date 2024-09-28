--!strict

-- keyboard.client.luaclient
-- client keyboard shortcuts

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}
local textHighlighting = require(game.ReplicatedStorage.gui.textHighlighting)
local tt = require(game.ReplicatedStorage.types.gametypes)

local remotes = require(game.ReplicatedStorage.util.remotes)
local settings = require(game.ReplicatedStorage.settings)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)

local warper = require(game.StarterPlayer.StarterPlayerScripts.warper)
local aet = require(game.ReplicatedStorage.avatarEventTypes)

local avatarEventFiring = require(game.StarterPlayer.StarterPlayerScripts.avatarEventFiring)
local fireEvent = avatarEventFiring.FireEvent

local PlayersService = game:GetService("Players")
local localPlayer = PlayersService.LocalPlayer
local AvatarEventBindableEvent: BindableEvent = remotes.getBindableEvent("AvatarEventBindableEvent")
local keyboardShortcutButton = require(game.StarterPlayer.StarterPlayerScripts.buttons.keyboardShortcutGui)
local particleExplanationGui = require(game.StarterPlayer.StarterPlayerScripts.buttons.particleExplanationGui)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local RunService = game:GetService("RunService")

local UserInputService = game:GetService("UserInputService")

---------------- GLOBALS ---------------------
------------------------- live-monitor this setting value. -------------
local userWantsHighlightingWhenWarpingWithKeyboard = false
local ignoreChatWhenHittingX = false
local showLB: boolean = true

--------------- "remember" the last runs they've worked on for '1'
local lastRunStartSignId = nil
local lastCompleteRunStart = nil
local lastCompleteRunEnd = nil

local function ToggleChat(intendedState: boolean)
	local ChatMain =
		require(game.Players.LocalPlayer.PlayerScripts:FindFirstChild("ChatScript"):WaitForChild("ChatMain"))
	ChatMain:SetVisible(intendedState)
end

local function ToggleServerEventScreenGui(intendedState: boolean)
	local items = { localPlayer:WaitForChild("PlayerGui"):FindFirstChild("ServerEventScreenGui") }
	if not items then
		_annotate("no server event screen gui found.")
		return
	end
	for _, el in ipairs(items) do
		el.Enabled = intendedState
	end
end

local function ToggleMarathonScreenGui(intendedState: boolean)
	local items = { localPlayer:WaitForChild("PlayerGui"):FindFirstChild("MarathonScreenGui") }
	if not items then
		_annotate("no marathon screen gui found.")
		return
	end
	for _, el in ipairs(items) do
		el.Enabled = intendedState
	end
end

local function ToggleLB(intendedState: boolean)
	local items = { localPlayer:WaitForChild("PlayerGui"):FindFirstChild("LeaderboardScreenGui") }
	if not items then
		_annotate("no leaderboard screen gui found.")
		return
	end
	for _, el in ipairs(items) do
		if el == nil then
			_annotate("bad item.")
			continue
		end
		el.Enabled = intendedState
	end
end

local function ToggleSettingsButton(intendedState: boolean)
	local items = { localPlayer:WaitForChild("PlayerGui"):FindFirstChild("HamburgerMenu") }
	if not items then
		_annotate("no leaderboard screen gui found.")
		return
	end
	for _, el in ipairs(items) do
		if el == nil then
			_annotate("bad item.")
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
		if string.sub(el.Name, 0, 14) == "SignProfileSgui" then
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
		if el.Name == "SignGrindUIScreenGui" then
			el:Destroy()
		end
	end
	if not ignoreChatWhenHittingX then
		ToggleChat(false)
	end
end

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
			_annotate("hit 1, doing warp to last completed run start.")
			local useLastRunEnd = nil
			if userWantsHighlightingWhenWarpingWithKeyboard then
				useLastRunEnd = lastCompleteRunEnd
			end
			if lastCompleteRunStart ~= nil and lastCompleteRunEnd ~= nil then
				warper.WarpToSignId(lastCompleteRunStart, useLastRunEnd)
			end
		elseif inputObject.KeyCode == Enum.KeyCode.Two then
			_annotate("hit 2, doing warp to last run start.")
			if lastRunStartSignId ~= nil then
				warper.WarpToSignId(lastRunStartSignId)
			end
		elseif inputObject.KeyCode == Enum.KeyCode.H then
			_annotate("hit h, killing highlights.")
			textHighlighting.KillAllExistingHighlights()
			_annotate("kill all highlights.")
		elseif inputObject.KeyCode == Enum.KeyCode.Tab then
			_annotate("hit tab, showing/hiding leaderboard.")
			showLB = not showLB
			ToggleLB(showLB)
			ToggleSettingsButton(showLB)
			ToggleChat(showLB)
			ToggleServerEventScreenGui(showLB)
			ToggleMarathonScreenGui(showLB)
		elseif inputObject.KeyCode == Enum.KeyCode.X then
			_annotate("kill all popups.")
			KillPopups()
		elseif inputObject.KeyCode == Enum.KeyCode.Z then
			_annotate("hit z, canceling run.")
			-- strangely, this key used to do a lot, even when you weren't running.
			-- because basically it kills the movementHistory store in movement, which can have effects on the player
			-- even when not running!
			fireEvent(aet.avatarEventTypes.RUN_CANCEL, { reason = "hit z on keyboard", sender = "keyboard" })
		elseif inputObject.KeyCode == Enum.KeyCode.K then
			keyboardShortcutButton.CreateShortcutGui()
			-- elseif inputObject.KeyCode == Enum.KeyCode.P then
			-- 	particleExplanationGui.CreateParticleGui()
		end
	end
end

local function handleUserSettingChanged(item: tt.userSettingValue): any
	if item.name == settingEnums.settingDefinitions.HIGHLIGHT_ON_KEYBOARD_1_TO_WARP.name then
		userWantsHighlightingWhenWarpingWithKeyboard = item.booleanValue
	elseif item.name == settingEnums.settingDefinitions.X_BUTTON_IGNORES_CHAT.name then
		ignoreChatWhenHittingX = item.booleanValue
	end
end

-- we track the last run start so that they can warp back there.
local debHandleAvatarEvent = false
local function handleAvatarEvent(ev: aet.avatarEvent)
	while debHandleAvatarEvent do
		_annotate("was locked while trying to set keyboard.")
		_annotate(avatarEventFiring.DescribeEvent(ev))
		return
	end
	debHandleAvatarEvent = true
	if ev.eventType == aet.avatarEventTypes.RUN_START then
		_annotate(
			string.format("run start, setting lastRunStartSignId=%s", tpUtil.signId2signName(ev.details.startSignId))
		)
		lastRunStartSignId = ev.details.startSignId
	elseif ev.eventType == aet.avatarEventTypes.RUN_COMPLETE then
		_annotate(
			string.format(
				"run complete, storing the last completed start and end: %s => %s",
				ev.details.startSignName,
				ev.details.endSignName
			)
		)

		lastCompleteRunStart = ev.details.startSignId
		lastCompleteRunEnd = ev.details.endSignId
	end
	debHandleAvatarEvent = false
end
local avatarEventConnection
module.Init = function()
	_annotate("init")
	debHandleAvatarEvent = false

	if avatarEventConnection then
		avatarEventConnection:Disconnect()
		avatarEventConnection = nil
	end
	avatarEventConnection = AvatarEventBindableEvent.Event:Connect(handleAvatarEvent)
	UserInputService.InputBegan:Connect(onInputBegin)

	settings.RegisterFunctionToListenForSettingName(
		handleUserSettingChanged,
		settingEnums.settingDefinitions.HIGHLIGHT_ON_KEYBOARD_1_TO_WARP.name
	)

	settings.RegisterFunctionToListenForSettingName(
		handleUserSettingChanged,
		settingEnums.settingDefinitions.X_BUTTON_IGNORES_CHAT.name
	)

	handleUserSettingChanged(
		settings.GetSettingByName(settingEnums.settingDefinitions.HIGHLIGHT_ON_KEYBOARD_1_TO_WARP.name)
	)
	handleUserSettingChanged(settings.GetSettingByName(settingEnums.settingDefinitions.X_BUTTON_IGNORES_CHAT.name))
	_annotate("init done")
end

_annotate("end")
return module
