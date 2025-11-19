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
-- local ReplicatedStorage = game:GetService("ReplicatedStorage")
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)

local UserInputService = game:GetService("UserInputService")

---------------- GLOBALS ---------------------
------------------------- live-monitor this setting value. -------------
local userWantsHighlightingWhenWarpingWithKeyboard = false
-- local showLB: boolean = true

--------------- "remember" the last runs they've worked on for '1'
local lastRunStartSignId = nil
local lastCompleteRunStart = nil
local lastCompleteRunEnd = nil

local function GetChatVisibility(): boolean
	local TextChatService = game:GetService("TextChatService")
	local chatWindowConfig = TextChatService:FindFirstChild("ChatWindowConfiguration")
	if chatWindowConfig then
		local ok, enabled = pcall(function()
			return (chatWindowConfig :: any).Enabled
		end)
		if ok then
			return enabled == true
		end
	end
	return true -- Default to visible if we can't determine
end

local function GetLeaderboardVisibility(): boolean
	local gui = localPlayer:WaitForChild("PlayerGui"):FindFirstChild("LeaderboardScreenGui")
	if gui and gui:IsA("ScreenGui") then
		return gui.Enabled
	end
	return false -- Default to hidden if not found
end

local function ToggleChat(intendedState: boolean)
	_annotate("toggle chat, intended: " .. tostring(intendedState))
	local TextChatService = game:GetService("TextChatService")

	-- Toggle chat window (message area)
	local chatWindowConfig = TextChatService:FindFirstChild("ChatWindowConfiguration")
	if chatWindowConfig then
		local ok, err = pcall(function()
			(chatWindowConfig :: any).Enabled = intendedState
		end)
		if not ok then
			_annotate(string.format("Warn: Failed to set ChatWindowConfiguration.Enabled (%s)", tostring(err)))
		end
	else
		_annotate("Warn: ChatWindowConfiguration not found")
	end

	-- Toggle chat input bar
	local chatInputBarConfig = TextChatService:FindFirstChild("ChatInputBarConfiguration")
	if chatInputBarConfig then
		local ok, err = pcall(function()
			(chatInputBarConfig :: any).Enabled = intendedState
		end)
		if not ok then
			_annotate(string.format("Warn: Failed to set ChatInputBarConfiguration.Enabled (%s)", tostring(err)))
		end
	else
		_annotate("Warn: ChatInputBarConfiguration not found")
	end

	-- Toggle channel tabs
	local channelTabsConfig = TextChatService:FindFirstChild("ChannelTabsConfiguration")
	if channelTabsConfig then
		local ok, err = pcall(function()
			(channelTabsConfig :: any).Enabled = intendedState
		end)
		if not ok then
			_annotate(string.format("Warn: Failed to set ChannelTabsConfiguration.Enabled (%s)", tostring(err)))
		end
	else
		_annotate("Warn: ChannelTabsConfiguration not found")
	end
end

local function HideChatIfVisible()
	-- X key: Always hide chat if visible, do nothing if already hidden
	local isVisible = GetChatVisibility()
	if isVisible then
		ToggleChat(false)
		_annotate("X key: Chat hidden")
	else
		_annotate("X key: Chat already hidden, doing nothing")
	end
end

local function _ToggleChatVisibility()
	-- Tab key: Toggle chat visibility
	local isVisible = GetChatVisibility()
	ToggleChat(not isVisible)
	_annotate(string.format("Tab key: Chat toggled to %s", tostring(not isVisible)))
end

local function EnableChatAndFocusInput()
	-- Slash key: Enable chat if disabled, then focus input bar with "/" pre-filled
	local isVisible = GetChatVisibility()
	if not isVisible then
		ToggleChat(true)
		_annotate("Slash key: Chat enabled")
	end

	-- Wait a brief moment for UI to update, then focus the input
	task.spawn(function()
		task.wait(0.1)
		local TextChatService = game:GetService("TextChatService")
		local chatInputBarConfig = TextChatService:FindFirstChild("ChatInputBarConfiguration")
		if chatInputBarConfig then
			local ok, err = pcall(function()
				local config = chatInputBarConfig :: any
				if config.TextBox then
					local textBox = config.TextBox :: TextBox
					textBox:CaptureFocus()
					textBox.Text = "/"
					_annotate("Slash key: Chat input focused with '/' pre-filled")
				else
					_annotate("Warn: ChatInputBarConfiguration.TextBox not found")
				end
			end)
			if not ok then
				_annotate(string.format("Warn: Failed to focus chat input (%s)", tostring(err)))
			end
		else
			_annotate("Warn: ChatInputBarConfiguration not found")
		end
	end)
end

local function ToggleServerEventScreenGui(intendedState: boolean)
	_annotate("toggle server event screen gui, intended: " .. tostring(intendedState))
	local gui = localPlayer:WaitForChild("PlayerGui"):FindFirstChild("ServerEventScreenGui")
	if gui and gui:IsA("ScreenGui") then
		(gui :: ScreenGui).Enabled = intendedState
	else
		_annotate("no server event screen gui found.")
	end
end

local function ToggleMarathonScreenGui(intendedState: boolean)
	_annotate("toggle marathon screen gui, intended: " .. tostring(intendedState))
	local gui = localPlayer:WaitForChild("PlayerGui"):FindFirstChild("MarathonScreenGui")
	if gui and gui:IsA("ScreenGui") then
		(gui :: ScreenGui).Enabled = intendedState
	else
		_annotate("no marathon screen gui found.")
	end
end

local function ToggleLB(intendedState: boolean)
	_annotate("toggle leaderboard screen gui, intended: " .. tostring(intendedState))
	local gui = localPlayer:WaitForChild("PlayerGui"):FindFirstChild("LeaderboardScreenGui")
	if gui and gui:IsA("ScreenGui") then
		(gui :: ScreenGui).Enabled = intendedState
	else
		_annotate("no leaderboard screen gui found.")
	end
end

local function ToggleSettingsButton(intendedState: boolean)
	_annotate("toggle settings button, intended: " .. tostring(intendedState))
	local gui = localPlayer:WaitForChild("PlayerGui"):FindFirstChild("HamburgerMenu")
	if gui and gui:IsA("ScreenGui") then
		(gui :: ScreenGui).Enabled = intendedState
	else
		_annotate("no settings button found.")
	end
end

local function ToggleChatAndLeaderboardTogether()
	-- Tab key: Keep chat and leaderboard in sync
	-- If out of sync (one shown, one hidden), hide both
	-- If in sync (both shown or both hidden), toggle both
	local chatVisible = GetChatVisibility()
	local lbVisible = GetLeaderboardVisibility()
	
	local areInSync = chatVisible == lbVisible
	
	if areInSync then
		-- Both are in sync, toggle both
		local newState = not chatVisible
		ToggleLB(newState)
		ToggleSettingsButton(newState)
		ToggleChat(newState)
		ToggleServerEventScreenGui(newState)
		ToggleMarathonScreenGui(newState)
		_annotate(string.format("Tab key: Chat and leaderboard toggled together to %s", tostring(newState)))
	else
		-- Out of sync, hide both
		ToggleLB(false)
		ToggleSettingsButton(false)
		ToggleChat(false)
		ToggleServerEventScreenGui(false)
		ToggleMarathonScreenGui(false)
		_annotate("Tab key: Chat and leaderboard out of sync, hiding both")
	end
end

local function KillPopups()
	_annotate("kill popups")
	for _, el in ipairs(localPlayer:WaitForChild("PlayerGui"):GetChildren()) do
		local attr = el:FindFirstChild("DismissableWithX")
		if attr and attr:IsA("BoolValue") then
			if attr.Value then
				el:Destroy()
			end
			continue
		end
		if string.sub(el.Name, 0, 11) == "RaceResults" then
			el:Destroy()
		elseif string.sub(el.Name, 0, 14) == "SignProfileSgui" then
			el:Destroy()
		elseif el.Name == "EphemeralNotificationSgui" then
			el:Destroy()
		elseif el.Name == "ToolTipGui" then
			el:Destroy()
		elseif el.Name == "NewFindSgui" then
			el:Destroy()
		elseif el.Name == "EphemeralTooltip" then
			el:Destroy()
		end
	end
	-- Note: Chat hiding is now handled by HideChatIfVisible() in X key handler
	-- This setting (ignoreChatWhenHittingX) is kept for backward compatibility
	-- but chat hiding is now always done via HideChatIfVisible()
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
		elseif inputObject.KeyCode == Enum.KeyCode.Two or inputObject.KeyCode == Enum.KeyCode.R then
			_annotate("hit 2, doing warp to last run start.")
			if lastRunStartSignId ~= nil then
				warper.WarpToSignId(lastRunStartSignId)
			end
		elseif inputObject.KeyCode == Enum.KeyCode.H then
			_annotate("hit h, killing highlights.")
			textHighlighting.KillAllExistingHighlights()
			_annotate("kill all highlights.")
		elseif inputObject.KeyCode == Enum.KeyCode.Tab then
			_annotate("hit tab, syncing chat and leaderboard visibility.")
			ToggleChatAndLeaderboardTogether()
		elseif inputObject.KeyCode == Enum.KeyCode.X then
			_annotate("kill all popups and hide chat.")
			KillPopups()
			HideChatIfVisible() -- Always hide chat if visible (independent of ignoreChatWhenHittingX)
		elseif inputObject.KeyCode == Enum.KeyCode.Z then
			_annotate("hit z, canceling run.")
			-- strangely, this key used to do a lot, even when you weren't running.
			-- because basically it kills the movementHistory store in movement, which can have effects on the player
			-- even when not running!
			fireEvent(aet.avatarEventTypes.RUN_CANCEL, { reason = "hit z on keyboard", sender = "keyboard" })
		elseif inputObject.KeyCode == Enum.KeyCode.Slash then
			_annotate("hit slash, enabling chat and focusing input if needed.")
			EnableChatAndFocusInput()
		elseif inputObject.KeyCode == Enum.KeyCode.K then
			keyboardShortcutButton.CreateShortcutGui()
			-- elseif inputObject.KeyCode == Enum.KeyCode.P then
			-- 	particleExplanationGui.CreateParticleGui()
		end
	end
end

local function handleUserSettingChanged(item: tt.userSettingValue): any
	if item.name == settingEnums.settingDefinitions.HIGHLIGHT_ON_KEYBOARD_1_TO_WARP.name then
		userWantsHighlightingWhenWarpingWithKeyboard = item.booleanValue or false
	end
	-- Note: X_BUTTON_IGNORES_CHAT setting is no longer used - X always hides chat if visible
	return nil
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
		local startSignId = ev.details and ev.details.startSignId
		if startSignId then
			_annotate(string.format("run start, setting lastRunStartSignId=%s", tpUtil.signId2signName(startSignId)))
			lastRunStartSignId = startSignId
		end
	elseif ev.eventType == aet.avatarEventTypes.RUN_COMPLETE then
		local details = ev.details
		if details then
			local startSignName = details.startSignName or "unknown"
			local endSignName = details.endSignName or "unknown"
			_annotate(
				string.format(
					"run complete, storing the last completed start and end: %s => %s",
					startSignName,
					endSignName
				)
			)
			if details.startSignId then
				lastCompleteRunStart = details.startSignId
			end
			if details.endSignId then
				lastCompleteRunEnd = details.endSignId
			end
		end
	end
	debHandleAvatarEvent = false
end
local avatarEventConnection: RBXScriptConnection?
module.Init = function()
	_annotate("init")
	debHandleAvatarEvent = false

	if avatarEventConnection then
		avatarEventConnection:Disconnect()
		avatarEventConnection = nil
	end
	avatarEventConnection = AvatarEventBindableEvent.Event:Connect(handleAvatarEvent) :: RBXScriptConnection
	UserInputService.InputBegan:Connect(onInputBegin)

	settings.RegisterFunctionToListenForSettingName(
		handleUserSettingChanged,
		settingEnums.settingDefinitions.HIGHLIGHT_ON_KEYBOARD_1_TO_WARP.name,
		"keyboard"
	)

	handleUserSettingChanged(
		settings.GetSettingByName(settingEnums.settingDefinitions.HIGHLIGHT_ON_KEYBOARD_1_TO_WARP.name)
	)
	_annotate("init done")
end

_annotate("end")
return module
