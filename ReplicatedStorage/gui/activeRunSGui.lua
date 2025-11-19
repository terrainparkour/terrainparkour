--!strict

-- activeRunSGui.lua
-- displays the current run time and effects. Things like speed are displayed by activeRunSGui

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local enums = require(game.ReplicatedStorage.util.enums)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local colors = require(game.ReplicatedStorage.util.colors)
local windowFunctions = require(game.StarterPlayer.StarterPlayerScripts.guis.windowFunctions)
local avatarEventFiring = require(game.StarterPlayer.StarterPlayerScripts.avatarEventFiring)
local fireEvent = avatarEventFiring.FireEvent
local movementEnums = require(game.StarterPlayer.StarterPlayerScripts.movementEnums)
local fonts = require(game.StarterPlayer.StarterPlayerScripts.guis.fonts)

--TYPES
local aet = require(game.ReplicatedStorage.avatarEventTypes)
local tt = require(game.ReplicatedStorage.types.gametypes)
local PlayersService = game:GetService("Players")
--HUMANOID
local localPlayer = PlayersService.LocalPlayer

-- local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
-- local humanoid: Humanoid = character:WaitForChild("Humanoid") :: Humanoid

-- GLOBALS
local currentRunStartTick: number = 0
local currentRunSignName: string = ""
local currentRunStartPosition: Vector3 = Vector3.new(0, 0, 0)
local theFont = Font.new("rbxasset://fonts/families/Arimo.json")

-- this is okay because a user is only running from one at a time.
local globalActiveRunSgui: ScreenGui | nil = nil

local optionalRaceDescription = ""
local movementDetails = ""
local lastActiveRunUpdateTime = ""
local renderSteppedConnection: RBXScriptConnection?

-- local playerGui
local activeRunSgui: ScreenGui?

local timeLabel: TextLabel?
local _signContainer: Frame?
local fromLabel: TextLabel?
local signNameLabel: TextLabel?
local distanceLabel: TextLabel?
local detailsLabel: TextLabel?
local speedLabel: TextLabel?
local speedModifierLabel: TextLabel?
local speedReasonLabel: TextLabel?

local leftPanel: Frame?
local rightPanel: Frame?
local contentFrame: Frame?

local settings = require(game.ReplicatedStorage.settings)

local currentRunUIConfiguration: tt.currentRunUIConfiguration = nil
local lastSpeedText = ""
local lastSpeedModifierText = ""
local lastSpeedReason = ""

----------------------- FOR SAVING LB CONFIGURATION -----------------

local lastSaveRequestCount = 0

local function _setPanelVisibility(panel: Frame, visible: boolean)
	if not panel then
		return
	end

	panel.Visible = true
	if visible then
		for _, child in ipairs(panel:GetChildren()) do
			if child:IsA("TextLabel") then
				local label = child :: TextLabel
				label.TextTransparency = 0
				label.BackgroundTransparency = 0.1
				local stroke = label:FindFirstChild("UIStroke")
				if stroke and stroke:IsA("UIStroke") then
					(stroke :: UIStroke).Transparency = 0.5
				end
			elseif child:IsA("TextButton") then
				local button = child :: TextButton
				button.TextTransparency = 0
				button.BackgroundTransparency = 0.1
				local stroke = button:FindFirstChild("UIStroke")
				if stroke and stroke:IsA("UIStroke") then
					(stroke :: UIStroke).Transparency = 0.7
				end
			elseif child:IsA("Frame") then
				local frame = child :: Frame
				for _, subChild in ipairs(frame:GetChildren()) do
					if subChild:IsA("TextLabel") then
						local subLabel = subChild :: TextLabel
						subLabel.TextTransparency = 0
					end
				end
			end
		end
	else
		for _, child in ipairs(panel:GetChildren()) do
			if child:IsA("TextLabel") then
				local label = child :: TextLabel
				label.TextTransparency = 1
				label.BackgroundTransparency = 1
				local stroke = label:FindFirstChild("UIStroke")
				if stroke and stroke:IsA("UIStroke") then
					(stroke :: UIStroke).Transparency = 1
				end
			elseif child:IsA("TextButton") then
				local button = child :: TextButton
				button.TextTransparency = 1
				button.BackgroundTransparency = 1
				local stroke = button:FindFirstChild("UIStroke")
				if stroke and stroke:IsA("UIStroke") then
					(stroke :: UIStroke).Transparency = 1
				end
			elseif child:IsA("Frame") then
				local frame = child :: Frame
				for _, subChild in ipairs(frame:GetChildren()) do
					if subChild:IsA("TextLabel") then
						local subLabel = subChild :: TextLabel
						subLabel.TextTransparency = 1
					end
				end
			end
		end
	end
end

local function saveActiveRunConfiguration()
	lastSaveRequestCount += 1
	local yourSaveRequestCount = lastSaveRequestCount

	task.spawn(function()
		task.wait(0.4) -- we delay so that we don't spam
		if yourSaveRequestCount ~= lastSaveRequestCount then
			return
		end

		local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
		local activeRunGui: ScreenGui = playerGui:FindFirstChild("ActiveRunGui") :: ScreenGui
		local outerFrame: Frame = activeRunGui:FindFirstChild("outer_activeRun") :: Frame
		if not outerFrame then
			_annotate("no active run frame in saveActiveRunConfiguration")
			return
		end
		_annotate("savinging ")

		local absoluteSize = outerFrame.AbsoluteSize
		local sizeInOffset = UDim2.new(0, absoluteSize.X, 0, absoluteSize.Y)
		local absolutePosition = outerFrame.AbsolutePosition

		-- Since IgnoreGuiInset = true, AbsolutePosition already accounts for the full screen
		-- Save position directly without adding topInset
		local positionInOffset = UDim2.new(0, absolutePosition.X, 0, absolutePosition.Y)
		currentRunUIConfiguration.size = sizeInOffset
		currentRunUIConfiguration.position = positionInOffset
		_annotate(
			"actually saving the run configuratino. size, pos=- "
				.. tostring(sizeInOffset)
				.. ", "
				.. tostring(positionInOffset)
		)

		local setting: tt.userSettingValue = {
			name = settingEnums.settingDefinitions.ACTIVE_RUN_CONFIGURATION.name,
			domain = settingEnums.settingDomains.USERSETTINGS,
			kind = settingEnums.settingKinds.LUA,
			luaValue = currentRunUIConfiguration,
		}
		settings.SetSetting(setting)
	end)
end

local function monitorActiveRunSGui()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local activeRunGui = playerGui:FindFirstChild("ActiveRunGui") :: ScreenGui
	local outerFrame: Frame = activeRunGui:FindFirstChild("outer_activeRun") :: Frame
	if not outerFrame then
		_annotate("No lbOuterFrame in monitorLeaderboardFrame")
		return
	end

	-- these are changes that are made directly by windows.
	-- other changes, like those of the sort data, are made in here and direclty save when changed.
	outerFrame:GetPropertyChangedSignal("Position"):Connect(function()
		currentRunUIConfiguration.position = outerFrame.Position
		saveActiveRunConfiguration()
	end)

	outerFrame:GetPropertyChangedSignal("Size"):Connect(function()
		currentRunUIConfiguration.size = outerFrame.Size
		saveActiveRunConfiguration()
	end)
end

--receive updates to these items. otherwise I am independent
module.UpdateExtraRaceDescription = function(outerRaceDescription: string): boolean
	optionalRaceDescription = outerRaceDescription
	return globalActiveRunSgui ~= nil
end

module.UpdateMovementDetails = function(outerMovementDetails: string): boolean
	movementDetails = outerMovementDetails
	return globalActiveRunSgui ~= nil
end

module.UpdateSpeedReason = function(reason: string)
	if not speedReasonLabel then
		return
	end

	if reason ~= "" and reason ~= lastSpeedReason then
		lastSpeedReason = reason
		speedReasonLabel.Text = reason
		speedReasonLabel.TextTransparency = 0
	elseif reason == "" and lastSpeedReason ~= "" then
		lastSpeedReason = ""
		speedReasonLabel.Text = "\u{200B}"
		speedReasonLabel.TextTransparency = 1
	end
end

module.UpdateSpeed = function(speed: number)
	if not speedLabel or not speedModifierLabel then
		return
	end

	local character = localPlayer.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
	if not humanoid then
		return
	end

	local moveDirection = humanoid.MoveDirection
	local isMoving = moveDirection.Magnitude > 0.01
	local displaySpeed = if isMoving then speed else 0

	local speedText = string.format("%0.1fd/s", displaySpeed)
	if speedText == lastSpeedText then
		return
	end
	lastSpeedText = speedText
	speedLabel.Text = speedText

	local mult = humanoid.WalkSpeed / movementEnums.constants.globalDefaultRunSpeed
	if mult ~= 1 then
		local multOptionalPlusText = "+"
		if mult < 1 then
			multOptionalPlusText = ""
		end
		local gain = (mult - 1) * 100
		local modText = string.format("%s%0.1f%%", multOptionalPlusText, gain)
		if modText ~= lastSpeedModifierText then
			lastSpeedModifierText = modText
			speedModifierLabel.Text = modText
			speedModifierLabel.TextTransparency = 0

			local modStroke = speedModifierLabel:FindFirstChild("UIStroke") :: UIStroke?
			if mult > 1 then
				speedModifierLabel.TextColor3 = Color3.fromRGB(120, 255, 140)
				if modStroke then
					modStroke.Color = Color3.fromRGB(120, 255, 140)
					modStroke.Transparency = 0.6
				end
			else
				speedModifierLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
				if modStroke then
					modStroke.Color = Color3.fromRGB(255, 120, 120)
					modStroke.Transparency = 0.6
				end
			end
		end
	else
		if lastSpeedModifierText ~= "" then
			lastSpeedModifierText = ""
			speedModifierLabel.Text = "\u{200B}"
			speedModifierLabel.TextTransparency = 1
			local modStroke = speedModifierLabel:FindFirstChild("UIStroke") :: UIStroke?
			if modStroke then
				modStroke.Transparency = 1
			end
		end
	end
end

-- when a user retouches a sign, we update the UI here.
module.UpdateStartTime = function(n: number)
	currentRunStartTick = n
end

-- the run ended, either cancelled or finished.
module.KillActiveRun = function()
	if renderSteppedConnection then
		renderSteppedConnection:Disconnect()
		renderSteppedConnection = nil
	end

	currentRunStartTick = 0
	currentRunSignName = ""
	currentRunStartPosition = Vector3.new(0, 0, 0)
	optionalRaceDescription = ""
	movementDetails = ""
	lastActiveRunUpdateTime = ""

	if rightPanel then
		rightPanel:Destroy()
		rightPanel = nil
		timeLabel = nil
		_signContainer = nil
		fromLabel = nil
		signNameLabel = nil
		distanceLabel = nil
		detailsLabel = nil
	end

	-- Reset speed UI state unconditionally so UpdateSpeed works correctly after cancellation
	lastSpeedText = ""
	lastSpeedModifierText = ""
	
	if speedLabel then
		speedLabel.Text = "0.0d/s"
		lastSpeedText = "0.0d/s"
	end
	if speedModifierLabel then
		speedModifierLabel.Text = "\u{200B}"
		speedModifierLabel.TextTransparency = 1
		local modStroke = speedModifierLabel:FindFirstChild("UIStroke") :: UIStroke?
		if modStroke then
			modStroke.Transparency = 1
		end
	end
end

-- an internal loop calls this periodically to update the UI.
local updateRunProgress = function()
	if localPlayer.Character == nil or localPlayer.Character.PrimaryPart == nil then
		_annotate("nil char or nil primary part in runProgressSgui, kllin.")
		module.KillActiveRun()
		return false
	end
	if not currentRunStartPosition then
		_annotate("no currentRunStartPosition in runProgressSgui, kllin.")
		return false
	end
	local characterPosition = localPlayer.Character.PrimaryPart.Position
	local dist = tpUtil.getDist(characterPosition, currentRunStartPosition)

	local formattedRuntime = ""
	if currentRunUIConfiguration.digitsInTime == 0 then
		formattedRuntime = string.format("%.0fs", tick() - currentRunStartTick)
	elseif currentRunUIConfiguration.digitsInTime == 1 then
		formattedRuntime = string.format("%.1fs", tick() - currentRunStartTick)
	elseif currentRunUIConfiguration.digitsInTime == 2 then
		formattedRuntime = string.format("%.2fs", tick() - currentRunStartTick)
	elseif currentRunUIConfiguration.digitsInTime == 3 then
		formattedRuntime = string.format("%.3fs", tick() - currentRunStartTick)
	else
		_annotate("what didigs ya got?")
		formattedRuntime = string.format("%.2fs", tick() - currentRunStartTick)
	end

	if lastActiveRunUpdateTime == formattedRuntime then
		return true
	end
	lastActiveRunUpdateTime = formattedRuntime

	local optionalSignAliasText = ""
	local alias = enums.signName2Alias[currentRunSignName]
	if alias ~= nil then
		if not enums.aliasesWhichAreVeryCloseSoDontNeedToBeShown[currentRunSignName] then
			optionalSignAliasText = " (" .. alias .. ")"
		end
	end

	if timeLabel then
		timeLabel.Text = string.format("%s", formattedRuntime)
	end
	if distanceLabel then
		distanceLabel.Text = string.format("%0.1fd", dist)
	end

	if fromLabel then
		fromLabel.Text = "from "
	end
	if signNameLabel then
		signNameLabel.Text = currentRunSignName .. optionalSignAliasText
	end

	local secondText = ""
	if optionalRaceDescription ~= "" and movementDetails ~= "" then
		secondText = optionalRaceDescription .. "\n" .. movementDetails
	elseif optionalRaceDescription ~= "" then
		secondText = optionalRaceDescription
	elseif movementDetails ~= "" then
		secondText = movementDetails
	else
		secondText = ""
	end

	local hasDetails = secondText ~= ""

	if detailsLabel then
		if hasDetails then
			detailsLabel.Text = secondText
			detailsLabel.TextTransparency = 0
			detailsLabel.Visible = true
		else
			detailsLabel.Text = ""
			detailsLabel.TextTransparency = 1
			detailsLabel.Visible = false
		end
	end

	-- All number displays use fixed pixel widths to prevent jumping
	-- Time, distance, and details maintain their fixed widths set at creation
	-- Only details visibility changes, not size

	return true
end

local isGuiInitialized = false

local function destroyGui()
	if globalActiveRunSgui then
		globalActiveRunSgui:Destroy()
		globalActiveRunSgui = nil
	end
	if activeRunSgui then
		activeRunSgui:Destroy()
		activeRunSgui = nil
	end
	if leftPanel then
		leftPanel = nil
	end
	if rightPanel then
		rightPanel = nil
	end
	if contentFrame then
		contentFrame = nil
	end
	if speedLabel then
		speedLabel = nil
	end
	if speedModifierLabel then
		speedModifierLabel = nil
	end
	if speedReasonLabel then
		speedReasonLabel = nil
	end
	if timeLabel then
		timeLabel = nil
	end
	if _signContainer then
		_signContainer = nil
	end
	if fromLabel then
		fromLabel = nil
	end
	if signNameLabel then
		signNameLabel = nil
	end
	if distanceLabel then
		distanceLabel = nil
	end
	if detailsLabel then
		detailsLabel = nil
	end
	
	settings.UnregisterFunctionToListenForSettingName(settingEnums.settingDefinitions.RESET_ACTIVE_RUN_POSITION.name, "activeRunSGui")
	
	isGuiInitialized = false
	lastSpeedText = ""
	lastSpeedModifierText = ""
	lastSpeedReason = ""
	if renderSteppedConnection then
		renderSteppedConnection:Disconnect()
		renderSteppedConnection = nil
	end
end

local function createPersistentGui()
	if isGuiInitialized then
		return
	end

	local configSetting = settings.GetSettingByName(settingEnums.settingDefinitions.ACTIVE_RUN_CONFIGURATION.name)
	if configSetting.luaValue == nil then
		annotater.Error("no config setting for active run gui")
		return
	end
	currentRunUIConfiguration = configSetting.luaValue

	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local ex = playerGui:FindFirstChild("ActiveRunGui") :: ScreenGui?
	if ex then
		ex:Destroy()
	end
	local newSgui = Instance.new("ScreenGui")
	newSgui.IgnoreGuiInset = true
	newSgui.Parent = playerGui
	newSgui.Name = "ActiveRunGui"
	newSgui.Enabled = true
	activeRunSgui = newSgui
	globalActiveRunSgui = newSgui

	-- Determine initial size for aspect ratio calculation
	-- Use saved size if available, otherwise default to 300x60 (5:1 ratio)
	local initialSize = currentRunUIConfiguration.size
	local defaultSize = UDim2.new(0, 300, 0, 60)
	local sizeForSetup = if initialSize.X.Offset > 0 and initialSize.Y.Offset > 0 then initialSize else defaultSize

	-- Setup frame with aspect ratio maintenance (prevents distortion)
	-- Aspect ratio is calculated from the size passed here, which matches the saved size
	local guiSystemFrames = windowFunctions.SetupFrame("activeRun", true, true, false, true, sizeForSetup, true)

	local outerFrame = guiSystemFrames.outerFrame
	local _activeRunFrame = outerFrame
	contentFrame = guiSystemFrames.contentFrame
	if not outerFrame or not contentFrame then
		annotater.Error("Failed to create outerFrame or contentFrame in createPersistentGui")
		return
	end
	outerFrame.Parent = activeRunSgui
	contentFrame.Parent = outerFrame

	-- Force aspect ratio to 5:1 (width:height) regardless of saved size
	outerFrame:SetAttribute("AspectRatio", 5)

	-- Set the actual saved size and position (should match sizeForSetup if saved size was valid)
	outerFrame.Size = currentRunUIConfiguration.size
	outerFrame.Position = currentRunUIConfiguration.position
	
	-- Check saved size directly to catch it before AbsoluteSize updates
	-- If the current size is roughly square or too tall (aspect ratio < 4), force it to 300x60
	-- This fixes users who have old saved configurations
	local savedWidth = currentRunUIConfiguration.size.X.Offset
	local savedHeight = currentRunUIConfiguration.size.Y.Offset
	if savedWidth > 0 and savedHeight > 0 then
		local savedRatio = savedWidth / savedHeight
		if savedRatio < 4 then
			outerFrame.Size = UDim2.new(0, 300, 0, 60)
			currentRunUIConfiguration.size = outerFrame.Size
			saveActiveRunConfiguration()
		end
	end
	
	-- Fix right-click eating: Active property on frames blocks input
	outerFrame.Active = false
	contentFrame.Active = false
	
	local function resetPosition()
		local newPos = UDim2.new(0.5, -150, 0.8, 0)
		outerFrame.Position = newPos
		currentRunUIConfiguration.position = newPos
		saveActiveRunConfiguration()
		_annotate("Reset active run GUI position.")
	end

	-- Check if off-screen and reset if needed
	task.defer(function()
		task.wait(0.1) -- Wait for layout
		local onScreen, _ = windowFunctions.isFrameOnScreen(outerFrame)
		if not onScreen then
			_annotate("Active run GUI off-screen, resetting position.")
			resetPosition()
		end
	end)

	-- Listen for reset setting
	settings.RegisterFunctionToListenForSettingName(function(setting)
		if setting.booleanValue == true then
			resetPosition()
			-- Reset the toggle back to false
			setting.booleanValue = false
			settings.SetSetting(setting)
		end
	end, settingEnums.settingDefinitions.RESET_ACTIVE_RUN_POSITION.name, "activeRunSGui")

	outerFrame.BackgroundTransparency = 1
	outerFrame.BackgroundColor3 = colors.black
	outerFrame.ZIndex = 1
	
	-- Debug border using UIStroke (works with BackgroundTransparency = 1)
	local outerStroke = Instance.new("UIStroke")
	outerStroke.Color = Color3.new(1, 0, 0)
	outerStroke.Thickness = 2
	outerStroke.Transparency = 0
	outerStroke.Parent = outerFrame

	contentFrame.BackgroundTransparency = 1
	
	-- Debug border using UIStroke (works with BackgroundTransparency = 1)
	local contentStroke = Instance.new("UIStroke")
	contentStroke.Color = Color3.new(1, 0, 0)
	contentStroke.Thickness = 2
	contentStroke.Transparency = 0
	contentStroke.Parent = contentFrame
	-- Scale-based border spacing for proportional resizing: at default 300px width, 4px = 0.013 scale
	-- Size is parent size minus border spacing on all sides
	contentFrame.Size = UDim2.new(1 - 0.013 * 2, 0, 1 - 0.013 * 2, 0)
	-- Scale-based border offset for proportional resizing: at default 300px width, 2px = 0.007 scale
	contentFrame.Position = UDim2.new(0.007, 0, 0.007, 0)
	contentFrame.Active = true

	local newLeftPanel: Frame = Instance.new("Frame")
	newLeftPanel.Name = "02_MovementPanel"
	-- Speed panel: 50% height, second row (bottom)
	newLeftPanel.Size = UDim2.new(1, 0, 0.5, 0)
	newLeftPanel.Position = UDim2.new(0, 0, 0.5, 0)
	newLeftPanel.BackgroundTransparency = 1
	newLeftPanel.Parent = contentFrame
	leftPanel = newLeftPanel
	
	-- Debug border using UIStroke (works with BackgroundTransparency = 1)
	local leftPanelStroke = Instance.new("UIStroke")
	leftPanelStroke.Color = Color3.new(1, 0, 0)
	leftPanelStroke.Thickness = 2
	leftPanelStroke.Transparency = 0
	leftPanelStroke.Parent = newLeftPanel

	local leftLayout = Instance.new("UIListLayout")
	leftLayout.Parent = newLeftPanel
	leftLayout.FillDirection = Enum.FillDirection.Horizontal
	leftLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	leftLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	leftLayout.SortOrder = Enum.SortOrder.Name
	-- Scale-based padding for proportional resizing: at default 300px width, 8px = 0.027 scale
	leftLayout.Padding = UDim.new(0.027, 0)

	local leftPadding = Instance.new("UIPadding")
	-- Scale-based padding for proportional resizing: at default 300px width, 4px = 0.013 scale
	leftPadding.PaddingLeft = UDim.new(0.013, 0)
	leftPadding.PaddingRight = UDim.new(0.013, 0)
	leftPadding.PaddingTop = UDim.new(0.013, 0)
	leftPadding.PaddingBottom = UDim.new(0.013, 0)
	leftPadding.Parent = newLeftPanel

	-- LEFT PANEL (Movement Info)
	-- Speed label: fixed proportional width on the left, matching timeLabel layout
	-- Scale-based width for proportional resizing: matches timeLabel width (0.25)
	local newSpeedLabel: TextLabel = Instance.new("TextLabel")
	newSpeedLabel.Name = "01_Speed"
	newSpeedLabel.Size = UDim2.new(0.25, 0, 1, 0)
	newSpeedLabel.AutomaticSize = Enum.AutomaticSize.None
	newSpeedLabel.BackgroundColor3 = Color3.fromRGB(20, 28, 35)
	newSpeedLabel.BackgroundTransparency = 0.15
	newSpeedLabel.TextScaled = true
	newSpeedLabel.TextColor3 = colors.yellow
	newSpeedLabel.Text = "0.0d/s"
	newSpeedLabel.FontFace = theFont
	-- Right aligned so it doesn't jump around as speed changes
	newSpeedLabel.TextXAlignment = Enum.TextXAlignment.Right
	newSpeedLabel.TextYAlignment = Enum.TextYAlignment.Center
	newSpeedLabel.Visible = true
	newSpeedLabel.Active = false
	newSpeedLabel.Parent = newLeftPanel
	speedLabel = newSpeedLabel

	local speedCorner = Instance.new("UICorner")
	-- Scale-based corner radius for proportional resizing: at default 300px width, 6px = 0.02 scale
	speedCorner.CornerRadius = UDim.new(0.02, 0)
	-- speedCorner.Parent = newSpeedLabel -- Disabled for debug borders

	-- Debug border using UIStroke (works with BackgroundTransparency = 1)
	local speedDebugStroke = Instance.new("UIStroke")
	speedDebugStroke.Color = Color3.new(1, 0, 0)
	speedDebugStroke.Thickness = 2
	speedDebugStroke.Transparency = 0
	speedDebugStroke.Parent = newSpeedLabel

	local speedStroke = Instance.new("UIStroke")
	speedStroke.Color = colors.yellow
	speedStroke.Thickness = 1.5
	speedStroke.Transparency = 0.6
	speedStroke.Parent = newSpeedLabel

	local newSpeedModifierLabel: TextLabel = Instance.new("TextLabel")
	newSpeedModifierLabel.Name = "02_SpeedModifier"
	-- Scale-based width for proportional resizing: takes remaining space after speed (0.35)
	-- Adjusted to fit with speed (0.35) and reason (0.3)
	newSpeedModifierLabel.Size = UDim2.new(0.3, 0, 1, 0)
	newSpeedModifierLabel.AutomaticSize = Enum.AutomaticSize.None
	newSpeedModifierLabel.BackgroundColor3 = Color3.fromRGB(20, 28, 35)
	newSpeedModifierLabel.BackgroundTransparency = 0.15
	newSpeedModifierLabel.TextScaled = true
	newSpeedModifierLabel.TextColor3 = Color3.fromRGB(120, 255, 140)
	newSpeedModifierLabel.Text = "\u{200B}"
	newSpeedModifierLabel.FontFace = theFont
	newSpeedModifierLabel.TextXAlignment = Enum.TextXAlignment.Right
	newSpeedModifierLabel.TextYAlignment = Enum.TextYAlignment.Center
	newSpeedModifierLabel.Visible = true
	newSpeedModifierLabel.Parent = newLeftPanel
	speedModifierLabel = newSpeedModifierLabel

	local modCorner = Instance.new("UICorner")
	-- Scale-based corner radius for proportional resizing: at default 300px width, 6px = 0.02 scale
	modCorner.CornerRadius = UDim.new(0.02, 0)
	-- modCorner.Parent = newSpeedModifierLabel -- Disabled for debug borders

	-- Debug border using UIStroke (works with BackgroundTransparency = 1)
	local modDebugStroke = Instance.new("UIStroke")
	modDebugStroke.Color = Color3.new(1, 0, 0)
	modDebugStroke.Thickness = 2
	modDebugStroke.Transparency = 0
	modDebugStroke.Parent = newSpeedModifierLabel

	local modStroke = Instance.new("UIStroke")
	modStroke.Color = Color3.fromRGB(120, 255, 140)
	modStroke.Thickness = 1.5
	modStroke.Transparency = 0.6
	modStroke.Parent = newSpeedModifierLabel

	local newSpeedReasonLabel: TextLabel = Instance.new("TextLabel")
	newSpeedReasonLabel.Name = "03_SpeedReason"
	-- Scale-based width for proportional resizing: takes remaining space after speed (0.35) and modifier (0.3)
	-- Remaining: 1 - 0.35 - 0.3 = 0.35, but accounting for padding, use 0.3
	newSpeedReasonLabel.Size = UDim2.new(0.3, 0, 1, 0)
	newSpeedReasonLabel.AutomaticSize = Enum.AutomaticSize.None
	newSpeedReasonLabel.BackgroundColor3 = Color3.fromRGB(20, 28, 35)
	newSpeedReasonLabel.BackgroundTransparency = 0.15
	newSpeedReasonLabel.TextScaled = true
	newSpeedReasonLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
	newSpeedReasonLabel.Text = "\u{200B}"
	newSpeedReasonLabel.FontFace = theFont
	newSpeedReasonLabel.TextXAlignment = Enum.TextXAlignment.Left
	newSpeedReasonLabel.TextYAlignment = Enum.TextYAlignment.Center
	newSpeedReasonLabel.Visible = true
	newSpeedReasonLabel.Parent = newLeftPanel
	speedReasonLabel = newSpeedReasonLabel

	local reasonCorner = Instance.new("UICorner")
	-- Scale-based corner radius for proportional resizing: at default 300px width, 6px = 0.02 scale
	reasonCorner.CornerRadius = UDim.new(0.02, 0)
	-- reasonCorner.Parent = newSpeedReasonLabel -- Disabled for debug borders

	-- Debug border using UIStroke (works with BackgroundTransparency = 1)
	local reasonDebugStroke = Instance.new("UIStroke")
	reasonDebugStroke.Color = Color3.new(1, 0, 0)
	reasonDebugStroke.Thickness = 2
	reasonDebugStroke.Transparency = 0
	reasonDebugStroke.Parent = newSpeedReasonLabel

	local reasonStroke = Instance.new("UIStroke")
	reasonStroke.Color = Color3.fromRGB(255, 220, 120)
	reasonStroke.Thickness = 1.5
	reasonStroke.Transparency = 0.6
	reasonStroke.Parent = newSpeedReasonLabel

	newLeftPanel.Visible = true
	newSpeedLabel.BackgroundTransparency = 1
	newSpeedModifierLabel.BackgroundTransparency = 1
	newSpeedReasonLabel.BackgroundTransparency = 1

	local function onActiveRunSGuiDestroyed()
		if renderSteppedConnection then
			renderSteppedConnection:Disconnect()
			renderSteppedConnection = nil
		end
	end

	if globalActiveRunSgui then
		globalActiveRunSgui.Destroying:Connect(onActiveRunSGuiDestroyed)
	end

	monitorActiveRunSGui()
	isGuiInitialized = true
end

local function createRaceRow()
	if not contentFrame then
		return
	end
	local contentFrameNonNull: Frame = contentFrame

	-- Destroy existing race row if it exists
	if rightPanel then
		rightPanel:Destroy()
		rightPanel = nil
	end

	local newRightPanel: Frame = Instance.new("Frame")
	newRightPanel.Name = "01_RacePanel"
	-- Run panel: 50% height, first row (top)
	newRightPanel.Size = UDim2.new(1, 0, 0.5, 0)
	newRightPanel.Position = UDim2.new(0, 0, 0, 0)
	newRightPanel.BackgroundTransparency = 1
	newRightPanel.Parent = contentFrameNonNull
	newRightPanel.Visible = true
	rightPanel = newRightPanel
	
	-- Debug border using UIStroke (works with BackgroundTransparency = 1)
	local rightPanelStroke = Instance.new("UIStroke")
	rightPanelStroke.Color = Color3.new(1, 0, 0)
	rightPanelStroke.Thickness = 2
	rightPanelStroke.Transparency = 0
	rightPanelStroke.Parent = newRightPanel

	local rightLayout = Instance.new("UIListLayout")
	rightLayout.Parent = newRightPanel
	rightLayout.FillDirection = Enum.FillDirection.Horizontal
	rightLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	rightLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rightLayout.SortOrder = Enum.SortOrder.Name
	-- Scale-based padding for proportional resizing: at default 300px width, 8px = 0.027 scale
	rightLayout.Padding = UDim.new(0.027, 0)

	local rightPadding = Instance.new("UIPadding")
	-- Scale-based padding for proportional resizing: at default 300px width, 4px = 0.013 scale
	rightPadding.PaddingLeft = UDim.new(0.013, 0)
	rightPadding.PaddingRight = UDim.new(0.013, 0)
	rightPadding.PaddingTop = UDim.new(0.013, 0)
	rightPadding.PaddingBottom = UDim.new(0.013, 0)
	rightPadding.Parent = newRightPanel

	-- RIGHT PANEL (Racing Info)
	-- Scale-based width for proportional resizing: accommodates "999.9s" (6 chars)
	-- Adjusted to fit with signContainer (0.325), distanceLabel (0.175), details (0.2275)
	-- Total used: 0.325 + 0.175 + 0.2275 = 0.7275. Remaining: 0.2725.
	-- Set TimeLabel to 0.25 to fit comfortably.
	local newTimeLabel: TextLabel = Instance.new("TextLabel")
	newTimeLabel.Name = "01_Time"
	newTimeLabel.Size = UDim2.new(0.25, 0, 1, 0)
	newTimeLabel.AutomaticSize = Enum.AutomaticSize.None
	newTimeLabel.BackgroundColor3 = colors.black
	newTimeLabel.BackgroundTransparency = 1
	newTimeLabel.TextScaled = true
	newTimeLabel.TextColor3 = colors.yellow
	newTimeLabel.Text = ""
	newTimeLabel.FontFace = fonts.GetFont(true, false)
	newTimeLabel.TextXAlignment = Enum.TextXAlignment.Center
	newTimeLabel.TextYAlignment = Enum.TextYAlignment.Center
	newTimeLabel.Active = false -- Allow right-click pass-through
	newTimeLabel.Parent = newRightPanel
	timeLabel = newTimeLabel

	local timeCorner = Instance.new("UICorner")
	-- Scale-based corner radius for proportional resizing: at default 300px width, 6px = 0.02 scale
	timeCorner.CornerRadius = UDim.new(0.02, 0)
	-- timeCorner.Parent = newTimeLabel -- Disabled for debug borders

	-- Debug border using UIStroke (works with BackgroundTransparency = 1)
	local timeDebugStroke = Instance.new("UIStroke")
	timeDebugStroke.Color = Color3.new(1, 0, 0)
	timeDebugStroke.Thickness = 2
	timeDebugStroke.Transparency = 0
	timeDebugStroke.Parent = newTimeLabel

	local timeStroke = Instance.new("UIStroke")
	timeStroke.Color = colors.yellow
	timeStroke.Thickness = 1.5
	timeStroke.Transparency = 0.6
	timeStroke.Parent = newTimeLabel

	newTimeLabel.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local details: aet.avatarEventDetails = {
				reason = "clicked on timeLabel in active run SGui",
				sender = "activeRunSGui",
			}
			fireEvent(aet.avatarEventTypes.RUN_CANCEL, details)
		end
	end)

	local newSignContainer: Frame = Instance.new("Frame")
	newSignContainer.Name = "02_SignContainer"
	-- Scale-based width for proportional resizing: sign container gets 32.5% of panel width (1.3x of 0.25)
	newSignContainer.Size = UDim2.new(0.325, 0, 1, 0)
	newSignContainer.AutomaticSize = Enum.AutomaticSize.None
	newSignContainer.BackgroundTransparency = 1
	newSignContainer.Parent = newRightPanel
	_signContainer = newSignContainer
	
	-- Debug border using UIStroke (works with BackgroundTransparency = 1)
	local signContainerDebugStroke = Instance.new("UIStroke")
	signContainerDebugStroke.Color = Color3.new(1, 0, 0)
	signContainerDebugStroke.Thickness = 2
	signContainerDebugStroke.Transparency = 0
	signContainerDebugStroke.Parent = newSignContainer

	local signContainerLayout = Instance.new("UIListLayout")
	signContainerLayout.Parent = newSignContainer
	signContainerLayout.FillDirection = Enum.FillDirection.Horizontal
	signContainerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	signContainerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	signContainerLayout.SortOrder = Enum.SortOrder.Name
	-- Scale-based padding for proportional resizing: at default 300px width, 4px = 0.013 scale
	signContainerLayout.Padding = UDim.new(0.013, 0)

	local newFromLabel: TextLabel = Instance.new("TextLabel")
	newFromLabel.Name = "00_From"
	-- Scale-based width for proportional resizing: "from " text gets 30% of signContainer width
	newFromLabel.Size = UDim2.new(0.3, 0, 1, 0)
	newFromLabel.AutomaticSize = Enum.AutomaticSize.None
	newFromLabel.BackgroundColor3 = Color3.fromRGB(20, 28, 35)
	newFromLabel.BackgroundTransparency = 1
	newFromLabel.TextScaled = true
	newFromLabel.RichText = false
	newFromLabel.TextColor3 = colors.white
	newFromLabel.Text = "from "
	newFromLabel.FontFace = fonts.GetFont(false, false)
	newFromLabel.TextXAlignment = Enum.TextXAlignment.Left
	newFromLabel.TextYAlignment = Enum.TextYAlignment.Center
	newFromLabel.Parent = newSignContainer
	fromLabel = newFromLabel

	local fromCorner = Instance.new("UICorner")
	-- Scale-based corner radius for proportional resizing: at default 300px width, 6px = 0.02 scale
	fromCorner.CornerRadius = UDim.new(0.02, 0)
	-- fromCorner.Parent = newFromLabel -- Disabled for debug borders

	-- Debug border using UIStroke (works with BackgroundTransparency = 1)
	local fromDebugStroke = Instance.new("UIStroke")
	fromDebugStroke.Color = Color3.new(1, 0, 0)
	fromDebugStroke.Thickness = 2
	fromDebugStroke.Transparency = 0
	fromDebugStroke.Parent = newFromLabel

	local newSignNameLabel: TextLabel = Instance.new("TextLabel")
	newSignNameLabel.Name = "01_SignName"
	-- Scale-based width for proportional resizing: sign name gets 70% of signContainer width
	newSignNameLabel.Size = UDim2.new(0.7, 0, 1, 0)
	newSignNameLabel.AutomaticSize = Enum.AutomaticSize.None
	newSignNameLabel.BackgroundColor3 = colors.signColor
	newSignNameLabel.BackgroundTransparency = 0
	newSignNameLabel.TextScaled = true
	newSignNameLabel.RichText = false
	newSignNameLabel.TextColor3 = colors.white
	newSignNameLabel.Text = ""
	newSignNameLabel.FontFace = fonts.GetFont(false, true)
	newSignNameLabel.TextXAlignment = Enum.TextXAlignment.Center
	newSignNameLabel.TextYAlignment = Enum.TextYAlignment.Center
	newSignNameLabel.Parent = newSignContainer
	signNameLabel = newSignNameLabel

	local signNameCorner = Instance.new("UICorner")
	-- Scale-based corner radius for proportional resizing: at default 300px width, 6px = 0.02 scale
	signNameCorner.CornerRadius = UDim.new(0.02, 0)
	-- signNameCorner.Parent = newSignNameLabel -- Disabled for debug borders

	-- Debug border using UIStroke (works with BackgroundTransparency = 1)
	local signNameDebugStroke = Instance.new("UIStroke")
	signNameDebugStroke.Color = Color3.new(1, 0, 0)
	signNameDebugStroke.Thickness = 2
	signNameDebugStroke.Transparency = 0
	signNameDebugStroke.Parent = newSignNameLabel


	local newDistanceLabel: TextLabel = Instance.new("TextLabel")
	newDistanceLabel.Name = "03_Distance"
	-- Scale-based width for proportional resizing: 50% of previous 0.35 = 0.175
	newDistanceLabel.Size = UDim2.new(0.175, 0, 1, 0)
	newDistanceLabel.AutomaticSize = Enum.AutomaticSize.None
	newDistanceLabel.BackgroundColor3 = colors.black
	newDistanceLabel.BackgroundTransparency = 1
	newDistanceLabel.TextScaled = true
	newDistanceLabel.TextColor3 = colors.yellow
	newDistanceLabel.Text = "0.0d"
	newDistanceLabel.FontFace = theFont
	newDistanceLabel.TextXAlignment = Enum.TextXAlignment.Center
	newDistanceLabel.TextYAlignment = Enum.TextYAlignment.Center
	newDistanceLabel.Parent = newRightPanel
	distanceLabel = newDistanceLabel

	local distanceCorner = Instance.new("UICorner")
	-- Scale-based corner radius for proportional resizing: at default 300px width, 6px = 0.02 scale
	distanceCorner.CornerRadius = UDim.new(0.02, 0)
	-- distanceCorner.Parent = newDistanceLabel -- Disabled for debug borders

	-- Debug border using UIStroke (works with BackgroundTransparency = 1)
	local distanceDebugStroke = Instance.new("UIStroke")
	distanceDebugStroke.Color = Color3.new(1, 0, 0)
	distanceDebugStroke.Thickness = 2
	distanceDebugStroke.Transparency = 0
	distanceDebugStroke.Parent = newDistanceLabel

	local distanceStroke = Instance.new("UIStroke")
	distanceStroke.Color = colors.yellow
	distanceStroke.Thickness = 1.5
	distanceStroke.Transparency = 0.6
	distanceStroke.Parent = newDistanceLabel

	local newDetailsLabel: TextLabel = Instance.new("TextLabel")
	newDetailsLabel.Name = "04_Details"
	-- Description zone width matches signname width (0.7 of signContainer which is 0.325 of total)
	-- 0.7 * 0.325 = 0.2275. Let's just give it the remaining space or a specific width?
	-- User asked: "Make the description zone be as wide as the current signname is."
	-- Current signname is 0.7 of signContainer (0.325) -> 0.2275 total width
	newDetailsLabel.Size = UDim2.new(0.2275, 0, 1, 0)
	newDetailsLabel.AutomaticSize = Enum.AutomaticSize.None
	newDetailsLabel.BackgroundColor3 = colors.black
	newDetailsLabel.BackgroundTransparency = 0.15
	newDetailsLabel.TextScaled = true
	newDetailsLabel.TextColor3 = colors.yellow
	newDetailsLabel.Text = "\u{200B}"
	newDetailsLabel.FontFace = theFont
	newDetailsLabel.TextXAlignment = Enum.TextXAlignment.Left
	newDetailsLabel.TextYAlignment = Enum.TextYAlignment.Center
	newDetailsLabel.Visible = true
	newDetailsLabel.TextTransparency = 1
	newDetailsLabel.Parent = newRightPanel
	detailsLabel = newDetailsLabel

	local detailsCorner = Instance.new("UICorner")
	-- Scale-based corner radius for proportional resizing: at default 300px width, 6px = 0.02 scale
	detailsCorner.CornerRadius = UDim.new(0.02, 0)
	-- detailsCorner.Parent = newDetailsLabel -- Disabled for debug borders

	-- Debug border using UIStroke (works with BackgroundTransparency = 1)
	local detailsDebugStroke = Instance.new("UIStroke")
	detailsDebugStroke.Color = Color3.new(1, 0, 0)
	detailsDebugStroke.Thickness = 2
	detailsDebugStroke.Transparency = 0
	detailsDebugStroke.Parent = newDetailsLabel

	local detailsStroke = Instance.new("UIStroke")
	detailsStroke.Color = colors.yellow
	detailsStroke.Thickness = 1.5
	detailsStroke.Transparency = 0.6
	detailsStroke.Parent = newDetailsLabel
end

module.Init = function()
	createPersistentGui()
end

module.DestroyGui = function()
	destroyGui()
	isGuiInitialized = false
end

local debounceCreateRunProgressSgui = false
module.StartActiveRunGui = function(startTimeTick, signName, signPosition)
	if not isGuiInitialized then
		createPersistentGui()
	end

	if debounceCreateRunProgressSgui then
		_annotate("debounceCreateRunProgressSgui.")
		return
	end
	debounceCreateRunProgressSgui = true

	currentRunSignName = signName
	currentRunStartTick = startTimeTick
	currentRunStartPosition = signPosition

	createRaceRow()
	
	if leftPanel then
		leftPanel.Visible = true
	end
	if speedLabel then
		speedLabel.BackgroundTransparency = 1
	end
	if speedModifierLabel then
		speedModifierLabel.BackgroundTransparency = 1
	end
	if speedReasonLabel then
		speedReasonLabel.BackgroundTransparency = 1
	end

	if renderSteppedConnection then
		renderSteppedConnection:Disconnect()
	end

	renderSteppedConnection = game:GetService("RunService").RenderStepped:Connect(function(_deltaTime)
		if not updateRunProgress() then
			if renderSteppedConnection ~= nil then
				renderSteppedConnection:Disconnect()
			end
			renderSteppedConnection = nil
		end
	end)

	debounceCreateRunProgressSgui = false
end

_annotate("end")
return module
