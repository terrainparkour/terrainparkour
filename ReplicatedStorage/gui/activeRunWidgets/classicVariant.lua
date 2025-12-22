--!strict
-- classicVariant.lua (ReplicatedStorage/gui/activeRunWidgets/classicVariant.lua)
-- Classic active run UI: full-featured with time, speed, distance, acceleration, sign display.
-- This is the original design, now exposed as an ActiveRunUIVariant.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local tpUtil: typeof(require(game.ReplicatedStorage.util.tpUtil)) = require(game.ReplicatedStorage.util.tpUtil)
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

-- GLOBALS
local currentRunStartTick: number = 0
local currentRunSignName: string = ""
local currentRunStartPosition: Vector3 = Vector3.new(0, 0, 0)

-- this is okay because a user is only running from one at a time.
local globalActiveRunSgui: ScreenGui | nil = nil

local optionalRaceDescription = ""
local movementDetails = ""
local lastActiveRunUpdateTime = ""
local RunService = game:GetService("RunService")

local renderSteppedConnection: RBXScriptConnection?

-- Debug flag for showing borders on main panels
local showSolidUIBorders = false

local activeRunSgui: ScreenGui?
local timeLabel: TextLabel?
local _signContainer: Frame?
local fromLabel: TextLabel?
local signNameLabel: TextLabel?
local distanceLabel: TextLabel?
local detailsLabel: TextLabel?
local speedLabel: TextLabel?
local speedModifierLabel: TextLabel?
local accelerationLabel: TextLabel?
local speedReasonLabel: TextLabel?

local leftPanel: Frame?
local rightPanel: Frame?
local contentFrame: Frame?
local signViewportPart: Part?
local signRotationConnection: RBXScriptConnection?

local settings = require(game.ReplicatedStorage.settings)
local currentRunUIConfiguration: tt.currentRunUIConfiguration = nil
local lastSpeedText = ""
local lastSpeedModifierText = ""
local lastAccelerationText = ""
local lastSpeedReason = ""
local showAccelerationSetting = true

local function getLabelContainer(label: TextLabel?): TextLabel?
	if not label then
		return nil
	end

	local parent = label.Parent
	if parent and parent:IsA("TextLabel") then
		return parent
	end
	return nil
end

local function setLabelContainerSize(label: TextLabel?, size: UDim2)
	local container = getLabelContainer(label)
	if not container then
		return
	end

	container.Size = size
end

-- Apply horizontal-only padding to label containers (no vertical to keep rows compact)
local function applyLabelPadding(label: TextLabel?, paddingPixels: number)
	local container = getLabelContainer(label)
	if not container then
		return
	end

	local paddingInstance = container:FindFirstChild("CellPadding")
	local uiPadding: UIPadding
	if paddingInstance and paddingInstance:IsA("UIPadding") then
		uiPadding = paddingInstance
	else
		uiPadding = Instance.new("UIPadding")
		uiPadding.Name = "CellPadding"
		uiPadding.Parent = container
	end

	local pad = UDim.new(0, paddingPixels)
	uiPadding.PaddingLeft = pad
	uiPadding.PaddingRight = pad
	-- No vertical padding - keeps cells compact
	uiPadding.PaddingTop = UDim.new(0, 0)
	uiPadding.PaddingBottom = UDim.new(0, 0)
end

-- Apply layout based on current show acceleration setting (called on create and setting change)
local function applyAccelerationSettingLayout()
	if not speedModifierLabel or not speedReasonLabel or not accelerationLabel then
		return
	end

	if showAccelerationSetting then
		-- Full layout: all elements visible with standard proportions
		setLabelContainerSize(speedModifierLabel, UDim2.fromScale(0.24, 1))
		speedModifierLabel.Visible = true

		setLabelContainerSize(speedReasonLabel, UDim2.fromScale(0.28, 1))
		speedReasonLabel.Visible = true
		speedReasonLabel.Text = lastSpeedReason
		speedReasonLabel.TextTransparency = if lastSpeedReason ~= "" then 0 else 1

		setLabelContainerSize(accelerationLabel, UDim2.fromScale(0.26, 1))
		accelerationLabel.Visible = true
		accelerationLabel.Text = lastAccelerationText
		accelerationLabel.TextTransparency = if lastAccelerationText ~= "" then 0 else 1
	else
		-- Compact layout: only speed and modifier visible
		setLabelContainerSize(speedModifierLabel, UDim2.fromScale(0.54, 1))
		speedModifierLabel.Visible = true

		setLabelContainerSize(speedReasonLabel, UDim2.fromScale(0, 1))
		speedReasonLabel.Visible = false
		speedReasonLabel.Text = "\u{200B}"
		speedReasonLabel.TextTransparency = 1

		setLabelContainerSize(accelerationLabel, UDim2.fromScale(0, 1))
		accelerationLabel.Visible = false
		accelerationLabel.Text = "\u{200B}"
		accelerationLabel.TextTransparency = 1
	end
end

----------------------- ACTIVE RUN SPECIFIC EXTENSIONS -----------------

-- Scale constants for proportional resizing (based on default 300px width)
local SCALE_PADDING = 0.005 -- Minimal horizontal padding for compact layout

-- Debug color palette for visualizing layout
local DEBUG_COLORS = {
	outerFrame = Color3.fromRGB(255, 0, 0), -- Red
	contentFrame = Color3.fromRGB(255, 100, 0), -- Orange
	leftPanel = Color3.fromRGB(0, 255, 0), -- Green
	rightPanel = Color3.fromRGB(0, 100, 255), -- Blue
	speedLabel = Color3.fromRGB(255, 255, 0), -- Yellow
	speedModifierLabel = Color3.fromRGB(255, 0, 255), -- Magenta
	speedReasonLabel = Color3.fromRGB(0, 255, 255), -- Cyan
	["00_TimeLabel"] = Color3.fromRGB(255, 128, 0), -- Orange
	signContainer = Color3.fromRGB(128, 255, 0), -- Lime
	fromLabel = Color3.fromRGB(255, 0, 128), -- Pink
	signNameLabel = Color3.fromRGB(128, 0, 255), -- Purple
	distanceLabel = Color3.fromRGB(0, 255, 128), -- Spring Green
	detailsLabel = Color3.fromRGB(255, 192, 0), -- Gold
}

-- Extended guiUtil functions for activeRun-specific requirements
-- For numeric displays: use fixedTextSize to prevent text shrinking/growing with content
local function createActiveRunLabel(
	config: {
		name: string,
		size: UDim2,
		parent: Instance,
		text: string?,
		textColor3: Color3?,
		fontFace: Font?, -- Support for monospaced fonts
		textXAlignment: Enum.TextXAlignment?,
		richText: boolean?, -- Support for disabling RichText
		active: boolean?, -- Support for input passthrough
		fixedTextSize: boolean?, -- Use fixed TextSize instead of TextScaled (for numeric stability)
	}
): TextLabel
	-- Create outer container label
	local outerLabel = Instance.new("TextLabel")
	outerLabel.Name = config.name
	outerLabel.Size = config.size
	outerLabel.BackgroundColor3 = colors.black
	outerLabel.BackgroundTransparency = 1
	outerLabel.BorderSizePixel = 0
	outerLabel.TextTransparency = 1 -- Outer is just container
	outerLabel.Parent = config.parent

	-- Create inner label for actual text display
	local innerLabel = Instance.new("TextLabel")
	innerLabel.Name = "Inner"
	innerLabel.Size = UDim2.fromScale(1, 1)
	innerLabel.Position = UDim2.fromScale(0, 0)
	innerLabel.BackgroundColor3 = colors.black
	innerLabel.BackgroundTransparency = 1
	innerLabel.BorderSizePixel = 0
	innerLabel.TextColor3 = config.textColor3 or colors.yellow
	innerLabel.Text = config.text or ""
	innerLabel.FontFace = config.fontFace or Font.new("rbxasset://fonts/families/Arimo.json")
	innerLabel.TextXAlignment = config.textXAlignment or Enum.TextXAlignment.Center
	innerLabel.TextYAlignment = Enum.TextYAlignment.Center
	innerLabel.Parent = outerLabel

	if config.richText ~= nil then
		innerLabel.RichText = config.richText
	end
	if config.active ~= nil then
		innerLabel.Active = config.active
	end

	-- For numeric displays: use fixed TextSize instead of TextScaled
	-- This prevents text from shrinking/growing as numbers change (e.g., 0.0 vs 68.0)
	if config.fixedTextSize then
		innerLabel.TextScaled = false
		-- Calculate TextSize based on container height (85% for compact layout)
		-- We'll update this dynamically when the parent resizes
		local function updateTextSize()
			local height = outerLabel.AbsoluteSize.Y
			-- Use ~85% of container height for text in compact layout, with reasonable min/max
			local calculatedSize = math.clamp(height * 0.85, 8, 48)
			innerLabel.TextSize = calculatedSize
		end

		-- Initial calculation
		task.defer(updateTextSize)

		-- Update on resize
		outerLabel:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateTextSize)
	else
		innerLabel.TextScaled = true
		-- Add text size constraint for non-fixed labels
		local sizeConstraint = Instance.new("UITextSizeConstraint")
		sizeConstraint.MaxTextSize = 48
		sizeConstraint.Parent = innerLabel
	end

	-- Apply debug styling if enabled
	if showSolidUIBorders and DEBUG_COLORS[config.name] then
		outerLabel.BackgroundTransparency = 0.3
		outerLabel.BackgroundColor3 = DEBUG_COLORS[config.name]

		local debugStroke = Instance.new("UIStroke")
		debugStroke.Color = Color3.new(1, 0, 0)
		debugStroke.Thickness = 2
		debugStroke.Transparency = 0
		debugStroke.Parent = outerLabel
	end

	return innerLabel
end

-- Add horizontal-only padding to panels (no vertical to keep rows compact)
local function addPadding(parent: Frame, padding: number?): UIPadding
	local uiPadding = Instance.new("UIPadding")
	local padValue = padding or SCALE_PADDING
	uiPadding.PaddingLeft = UDim.new(padValue, 0)
	uiPadding.PaddingRight = UDim.new(padValue, 0)
	-- No vertical padding - keeps rows compact
	uiPadding.PaddingTop = UDim.new(0, 0)
	uiPadding.PaddingBottom = UDim.new(0, 0)
	uiPadding.Parent = parent
	return uiPadding
end

local function addStroke(parent: GuiObject, color: Color3, thickness: number?, transparency: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 1.5
	stroke.Transparency = transparency or 0.6
	stroke.Parent = parent
	return stroke
end

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

		local absoluteSize = outerFrame.AbsoluteSize
		local sizeInOffset = UDim2.new(0, absoluteSize.X, 0, absoluteSize.Y)
		local absolutePosition = outerFrame.AbsolutePosition

		-- Since IgnoreGuiInset = true, AbsolutePosition already accounts for the full screen
		-- Save position directly without adding topInset
		local positionInOffset = UDim2.new(0, absolutePosition.X, 0, absolutePosition.Y)
		currentRunUIConfiguration.size = sizeInOffset
		currentRunUIConfiguration.position = positionInOffset
		_annotate("actually saving the run configuratino. size, pos=- " .. tostring(sizeInOffset) .. ", " .. tostring(positionInOffset))

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

module.UpdateAcceleration = function(accelerationRate: number)
	if not accelerationLabel or not showAccelerationSetting then
		return
	end

	-- Format as studs/s² with appropriate sign
	local accText = ""
	if math.abs(accelerationRate) < 0.01 then
		-- Near zero acceleration, hide the label
		if lastAccelerationText ~= "" then
			lastAccelerationText = ""
			accelerationLabel.Text = "\u{200B}"
			accelerationLabel.TextTransparency = 1
			local accStroke = accelerationLabel:FindFirstChild("UIStroke") :: UIStroke?
			if accStroke then
				accStroke.Transparency = 1
			end
		end
		return
	end

	local accSignPrefix = if accelerationRate > 0 then "+" else ""
	accText = string.format("%s%0.2fd/s²", accSignPrefix, accelerationRate)

	if accText == lastAccelerationText then
		return
	end

	lastAccelerationText = accText
	accelerationLabel.Text = accText
	accelerationLabel.TextTransparency = 0

	-- Calculate color intensity based on acceleration magnitude
	-- Scale: 0.01-0.6 studs/s² maps to intensity 0.3-1.0
	local intensity = math.clamp((math.abs(accelerationRate) - 0.01) / 0.6, 0.3, 1.0)

	local accStroke = accelerationLabel:FindFirstChild("UIStroke") :: UIStroke?
	if accelerationRate > 0 then
		-- Positive: cyan to bright blue gradient
		local r = math.floor(100 * (1 - intensity * 0.5))
		local g = math.floor(180 + 75 * intensity)
		local b = 255
		accelerationLabel.TextColor3 = Color3.fromRGB(r, g, b)
		if accStroke then
			accStroke.Color = Color3.fromRGB(r, g, b)
			accStroke.Transparency = 0.7 - intensity * 0.2
		end
	elseif accelerationRate < 0 then
		-- Negative: purple to magenta gradient
		local r = math.floor(200 + 55 * intensity)
		local g = math.floor(100 * (1 - intensity * 0.5))
		local b = math.floor(200 + 55 * intensity)
		accelerationLabel.TextColor3 = Color3.fromRGB(r, g, b)
		if accStroke then
			accStroke.Color = Color3.fromRGB(r, g, b)
			accStroke.Transparency = 0.7 - intensity * 0.2
		end
	end
end

module.UpdateSpeedReason = function(reason: string)
	if not speedReasonLabel or not showAccelerationSetting then
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

	-- Always show WalkSpeed (runspeed), even when standing still
	local speedText = string.format("%0.1fd/s", speed)
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

	if signRotationConnection then
		signRotationConnection:Disconnect()
		signRotationConnection = nil
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

	signViewportPart = nil

	-- Reset speed UI state unconditionally so UpdateSpeed works correctly after cancellation
	lastSpeedText = ""
	lastSpeedModifierText = ""
	lastAccelerationText = ""

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
	if accelerationLabel then
		accelerationLabel.Text = "\u{200B}"
		accelerationLabel.TextTransparency = 1
		local accStroke = accelerationLabel:FindFirstChild("UIStroke") :: UIStroke?
		if accStroke then
			accStroke.Transparency = 1
		end
	end
end

-- an internal loop calls this periodically to update the UI.
local updateRunProgress = function()
	if localPlayer.Character == nil or localPlayer.Character.PrimaryPart == nil then
		-- _annotate("nil char or nil primary part in runProgressSgui, kllin.")
		-- module.KillActiveRun()
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

	-- Alias not shown here; users discover aliases via tooltip on run results title
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
		signNameLabel.Text = currentRunSignName
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
		else
			-- Keep Visible=true to maintain stable layout; use transparency to hide content
			detailsLabel.Text = "\u{200B}" -- Zero-width space to maintain layout
			detailsLabel.TextTransparency = 1
		end
		-- Always keep visible to prevent UIListLayout from shifting other elements
		detailsLabel.Visible = true
	end

	-- All number displays use fixed pixel widths to prevent jumping
	-- Time, distance, and details maintain fixed widths; only text content changes

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
	if accelerationLabel then
		accelerationLabel = nil
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
	lastAccelerationText = ""
	lastSpeedReason = ""

	settings.UnregisterFunctionToListenForSettingName(settingEnums.settingDefinitions.SHOW_ACCELERATION.name, "activeRunSGui")

	if renderSteppedConnection then
		renderSteppedConnection:Disconnect()
		renderSteppedConnection = nil
	end
	if signRotationConnection then
		signRotationConnection:Disconnect()
		signRotationConnection = nil
	end
	signViewportPart = nil
end

local function createPersistentGui()
	if isGuiInitialized then
		if activeRunSgui and activeRunSgui.Parent then
			return
		else
			_annotate("isGuiInitialized was true but GUI is missing or parentless. Recreating.")
			isGuiInitialized = false
		end
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
	-- newSgui.ResetOnSpawn = false -- Reverted as per request for cleanup on respawn
	newSgui.Parent = playerGui
	newSgui.Name = "ActiveRunGui"
	newSgui.Enabled = true
	activeRunSgui = newSgui
	globalActiveRunSgui = newSgui

	-- Determine initial size for aspect ratio calculation
	-- Use saved size if available, otherwise default to 300x30 (10:1 ratio - compact)
	local initialSize = currentRunUIConfiguration.size
	local defaultSize = UDim2.new(0, 300, 0, 30)
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

	-- Force aspect ratio to 10:1 (width:height) - compact horizontal bar
	outerFrame:SetAttribute("AspectRatio", 10)

	-- Set the actual saved size and position (should match sizeForSetup if saved size was valid)
	outerFrame.Size = currentRunUIConfiguration.size
	outerFrame.Position = currentRunUIConfiguration.position

	-- Check saved size directly to catch it before AbsoluteSize updates
	-- If the current size is too tall (aspect ratio < 8), force it to 300x30
	-- This fixes users who have old saved configurations from before the compact layout
	local savedWidth = currentRunUIConfiguration.size.X.Offset
	local savedHeight = currentRunUIConfiguration.size.Y.Offset
	if savedWidth > 0 and savedHeight > 0 then
		local savedRatio = savedWidth / savedHeight
		if savedRatio < 8 then
			outerFrame.Size = UDim2.new(0, 300, 0, 30)
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

	-- Listen for show acceleration setting changes
	settings.RegisterFunctionToListenForSettingName(function(setting)
		showAccelerationSetting = setting.booleanValue == true
		applyAccelerationSettingLayout()
	end, settingEnums.settingDefinitions.SHOW_ACCELERATION.name, "activeRunSGui")

	outerFrame.BackgroundTransparency = 1
	outerFrame.BackgroundColor3 = colors.black
	outerFrame.ZIndex = 1
	if showSolidUIBorders then
		outerFrame.BackgroundTransparency = 0.3
		outerFrame.BackgroundColor3 = DEBUG_COLORS.outerFrame
		local outerStroke = Instance.new("UIStroke")
		outerStroke.Color = Color3.new(1, 0, 0)
		outerStroke.Thickness = 2
		outerStroke.Transparency = 0
		outerStroke.Parent = outerFrame
	end

	contentFrame.BackgroundTransparency = 1
	if showSolidUIBorders then
		contentFrame.BackgroundTransparency = 0.3
		contentFrame.BackgroundColor3 = DEBUG_COLORS.contentFrame
		local contentStroke = Instance.new("UIStroke")
		contentStroke.Color = Color3.new(1, 0, 0)
		contentStroke.Thickness = 2
		contentStroke.Transparency = 0
		contentStroke.Parent = contentFrame
	end
	-- Minimal border spacing for compact layout
	contentFrame.Size = UDim2.new(1 - 0.005 * 2, 0, 1, 0) -- Tiny horizontal margin, no vertical
	contentFrame.Position = UDim2.new(0.005, 0, 0, 0)
	contentFrame.Active = true

	local newLeftPanel: Frame = Instance.new("Frame")
	newLeftPanel.Name = "02_MovementPanel"
	newLeftPanel.Size = UDim2.new(1, 0, 0.5, 0)
	newLeftPanel.Position = UDim2.new(0, 0, 0.5, 0)
	newLeftPanel.BackgroundTransparency = 1
	newLeftPanel.Parent = contentFrame
	leftPanel = newLeftPanel

	-- Debug border on speed panel
	if showSolidUIBorders then
		local leftPanelStroke = Instance.new("UIStroke")
		leftPanelStroke.Color = Color3.new(1, 0, 0)
		leftPanelStroke.Thickness = 2
		leftPanelStroke.Transparency = 0
		leftPanelStroke.Parent = newLeftPanel
		newLeftPanel.BackgroundTransparency = 0.3
		newLeftPanel.BackgroundColor3 = DEBUG_COLORS.leftPanel
	end

	-- Use tighter layout with minimal padding for no gaps
	local leftLayout = Instance.new("UIListLayout")
	leftLayout.Parent = newLeftPanel
	leftLayout.FillDirection = Enum.FillDirection.Horizontal
	leftLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	leftLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	leftLayout.SortOrder = Enum.SortOrder.Name
	leftLayout.Padding = UDim.new(0, 0) -- No padding between elements

	addPadding(newLeftPanel)

	-- LEFT PANEL (Movement Info)
	-- Speed label: monospaced font with fixed text size for stable display as numbers change
	local newSpeedLabel = createActiveRunLabel({
		name = "speedLabel",
		size = UDim2.new(0.22, 0, 1, 0),
		parent = newLeftPanel,
		text = "0.0d/s",
		textColor3 = colors.yellow,
		fontFace = fonts.GetFont(true, false), -- Monospaced for numeric stability
		textXAlignment = Enum.TextXAlignment.Right,
		active = false,
		fixedTextSize = true, -- Prevents text shrinking when numbers grow
	})
	speedLabel = newSpeedLabel
	addStroke(newSpeedLabel, colors.yellow)

	local newSpeedModifierLabel = createActiveRunLabel({
		name = "speedModifierLabel",
		size = UDim2.new(0.24, 0, 1, 0),
		parent = newLeftPanel,
		text = "\u{200B}",
		textColor3 = Color3.fromRGB(120, 255, 140),
		fontFace = fonts.GetFont(true, false), -- Monospaced for numeric stability
		textXAlignment = Enum.TextXAlignment.Center,
		fixedTextSize = true, -- Prevents text shrinking when numbers grow
	})
	speedModifierLabel = newSpeedModifierLabel
	addStroke(newSpeedModifierLabel, Color3.fromRGB(120, 255, 140))
	applyLabelPadding(newSpeedModifierLabel, 2)

	local newSpeedReasonLabel = createActiveRunLabel({
		name = "speedReasonLabel",
		size = UDim2.new(0.28, 0, 1, 0),
		parent = newLeftPanel,
		text = "\u{200B}",
		textColor3 = Color3.fromRGB(255, 220, 120),
		textXAlignment = Enum.TextXAlignment.Center,
	})
	speedReasonLabel = newSpeedReasonLabel
	addStroke(newSpeedReasonLabel, Color3.fromRGB(255, 220, 120))
	applyLabelPadding(newSpeedReasonLabel, 2)

	local newAccelerationLabel = createActiveRunLabel({
		name = "zz_accelerationLabel",
		size = UDim2.new(0.26, 0, 1, 0),
		parent = newLeftPanel,
		text = "\u{200B}",
		textColor3 = Color3.fromRGB(100, 180, 255),
		fontFace = fonts.GetFont(true, false), -- Monospaced for numeric stability
		textXAlignment = Enum.TextXAlignment.Right,
		fixedTextSize = true, -- Prevents text shrinking when numbers grow
	})
	accelerationLabel = newAccelerationLabel
	addStroke(newAccelerationLabel, Color3.fromRGB(100, 180, 255))
	applyLabelPadding(newAccelerationLabel, 2)

	-- Apply initial layout based on current setting value
	local showAccSetting = settings.GetSettingByName(settingEnums.settingDefinitions.SHOW_ACCELERATION.name)
	showAccelerationSetting = showAccSetting.booleanValue == true
	applyAccelerationSettingLayout()

	newLeftPanel.Visible = true
	if not showSolidUIBorders then
		newSpeedLabel.BackgroundTransparency = 1
		newSpeedModifierLabel.BackgroundTransparency = 1
		newAccelerationLabel.BackgroundTransparency = 1
		newSpeedReasonLabel.BackgroundTransparency = 1
	end

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
	newRightPanel.Size = UDim2.new(1, 0, 0.5, 0)
	newRightPanel.Position = UDim2.new(0, 0, 0, 0)
	newRightPanel.BackgroundTransparency = 1
	newRightPanel.Parent = contentFrameNonNull
	newRightPanel.Visible = true
	rightPanel = newRightPanel

	-- Debug border on race panel
	if showSolidUIBorders then
		local rightPanelStroke = Instance.new("UIStroke")
		rightPanelStroke.Color = Color3.new(1, 0, 0)
		rightPanelStroke.Thickness = 2
		rightPanelStroke.Transparency = 0
		rightPanelStroke.Parent = newRightPanel
		newRightPanel.BackgroundTransparency = 0.3
		newRightPanel.BackgroundColor3 = DEBUG_COLORS.rightPanel
	end

	-- Use tighter layout with minimal padding for no gaps
	local rightLayout = Instance.new("UIListLayout")
	rightLayout.Parent = newRightPanel
	rightLayout.FillDirection = Enum.FillDirection.Horizontal
	rightLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	rightLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rightLayout.SortOrder = Enum.SortOrder.Name
	rightLayout.Padding = UDim.new(0, 0) -- No padding between elements

	addPadding(newRightPanel)

	-- Time label: monospaced + fixed size + right-align (sized for ~3 digit times like 8.98s)
	local newTimeLabel = createActiveRunLabel({
		name = "00_TimeLabel",
		size = UDim2.new(0.14, 0, 1, 0), -- Compact: fits "99.99s"
		parent = newRightPanel,
		text = "",
		textColor3 = colors.yellow,
		fontFace = fonts.GetFont(true, false), -- Monospaced for numeric stability
		active = false,
		textXAlignment = Enum.TextXAlignment.Right, -- Right align so numbers grow to the left
		fixedTextSize = true, -- Prevents text shrinking when numbers grow
	})
	timeLabel = newTimeLabel
	addStroke(newTimeLabel, colors.yellow)
	applyLabelPadding(newTimeLabel, 2)

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
	newSignContainer.Size = UDim2.new(0.54, 0, 1, 0) -- Expanded for sign display
	newSignContainer.AutomaticSize = Enum.AutomaticSize.None
	newSignContainer.BackgroundTransparency = 1
	newSignContainer.Parent = newRightPanel
	_signContainer = newSignContainer

	-- Debug border on sign container
	if showSolidUIBorders then
		local signContainerStroke = Instance.new("UIStroke")
		signContainerStroke.Color = Color3.new(1, 0, 0)
		signContainerStroke.Thickness = 2
		signContainerStroke.Transparency = 0
		signContainerStroke.Parent = newSignContainer
		newSignContainer.BackgroundTransparency = 0.3
		newSignContainer.BackgroundColor3 = DEBUG_COLORS.signContainer
	end

	-- Tight layout for sign container with no gaps
	local signLayout = Instance.new("UIListLayout")
	signLayout.Parent = newSignContainer
	signLayout.FillDirection = Enum.FillDirection.Horizontal
	signLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	signLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	signLayout.SortOrder = Enum.SortOrder.Name
	signLayout.Padding = UDim.new(0, 0) -- No padding between "from" and sign name

	local newFromLabel = createActiveRunLabel({
		name = "01_fromLabel",
		size = UDim2.new(0.18, 0, 1, 0), -- Compact: just enough for "from "
		parent = newSignContainer,
		text = "from ",
		textColor3 = colors.white,
		fontFace = fonts.GetFont(false, false),
		textXAlignment = Enum.TextXAlignment.Right, -- Right-align to sit close to sign
		richText = false,
	})
	fromLabel = newFromLabel
	-- Add small left margin (5px) as requested, minimal right margin
	local fromPadding = Instance.new("UIPadding")
	fromPadding.PaddingLeft = UDim.new(0, 5)
	fromPadding.PaddingRight = UDim.new(0, 2)
	fromPadding.Parent = newFromLabel

	-- Create ViewportFrame to render 3D sign with actual Granite material
	local viewportFrame = Instance.new("ViewportFrame")
	viewportFrame.Name = "02_SignViewport"
	viewportFrame.Size = UDim2.fromScale(0.82, 1) -- Expanded to fill freed space from fromLabel
	viewportFrame.BackgroundTransparency = 1
	viewportFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	viewportFrame.ImageTransparency = 0
	viewportFrame.LightDirection = Vector3.new(1, -1, -1).Unit
	viewportFrame.Ambient = Color3.fromRGB(255, 255, 255)
	viewportFrame.LightColor = Color3.fromRGB(255, 255, 255)
	viewportFrame.Parent = newSignContainer

	-- Create WorldModel (proper container for ViewportFrame content)
	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewportFrame

	-- Create a Part with Granite material to match real signs
	-- Large and flat to completely fill the viewport background
	local signPart = Instance.new("Part")
	signPart.Name = "SignPart"
	signPart.Size = Vector3.new(20, 0.5, 10)
	signPart.Position = Vector3.new(0, 0, 0)
	signPart.Orientation = Vector3.new(0, 0, 0)
	signPart.CFrame = CFrame.new(0, 0, 0)
	signPart.Material = Enum.Material.Granite
	signPart.Color = colors.signColor
	signPart.Anchored = true
	signPart.CanCollide = false
	signPart.TopSurface = Enum.SurfaceType.Smooth
	signPart.BottomSurface = Enum.SurfaceType.Smooth
	signPart.LeftSurface = Enum.SurfaceType.Smooth
	signPart.RightSurface = Enum.SurfaceType.Smooth
	signPart.FrontSurface = Enum.SurfaceType.Smooth
	signPart.BackSurface = Enum.SurfaceType.Smooth
	signPart.Transparency = 0
	signPart.Parent = worldModel
	signViewportPart = signPart

	-- Helper function to create a SurfaceGui EXACTLY like real signs
	local function createRealSignSurfaceGui(face: Enum.NormalId, faceName: string): (SurfaceGui, TextLabel)
		local gui = Instance.new("SurfaceGui")
		gui.Name = faceName .. "SurfaceGui"
		gui.Face = face
		-- Calculate canvas size like real signs: Size.Z * 30, Size.X * 30 for Top
		-- For our part: 10 x 0.5 x 3, so Top = (3*30, 10*30) = (90, 300)
		if face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then
			gui.CanvasSize = Vector2.new(signPart.Size.Z * 30, signPart.Size.X * 30)
		elseif face == Enum.NormalId.Front or face == Enum.NormalId.Back then
			gui.CanvasSize = Vector2.new(signPart.Size.X * 30, signPart.Size.Y * 30)
		else
			gui.CanvasSize = Vector2.new(signPart.Size.Z * 30, signPart.Size.Y * 30)
		end
		gui.Brightness = 1.5
		gui.LightInfluence = 1
		gui.Parent = signPart

		local label = Instance.new("TextLabel")
		label.Name = faceName .. "Label"
		label.AutoLocalize = true
		label.Text = faceName
		label.Font = Enum.Font.Gotham
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 1, 0)
		label.TextScaled = true
		label.RichText = true
		label.TextColor3 = colors.signTextColor
		label.TextStrokeTransparency = 0.5
		label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		label.Parent = gui

		return gui, label
	end

	-- Add SurfaceGuis to all 6 faces using real sign setup
	createRealSignSurfaceGui(Enum.NormalId.Top, "TOP")
	createRealSignSurfaceGui(Enum.NormalId.Bottom, "BOTTOM")
	createRealSignSurfaceGui(Enum.NormalId.Front, "FRONT")
	createRealSignSurfaceGui(Enum.NormalId.Back, "BACK")
	createRealSignSurfaceGui(Enum.NormalId.Left, "LEFT")
	createRealSignSurfaceGui(Enum.NormalId.Right, "RIGHT")

	-- SurfaceGuis do NOT render inside ViewportFrames (confirmed Roblox limitation)
	-- Solution: Overlay a TextLabel ON TOP of the ViewportFrame in the UI

	-- Create a container to clip the text within sign bounds
	local textContainer = Instance.new("Frame")
	textContainer.Name = "SignTextContainer"
	textContainer.Size = UDim2.fromScale(0.85, 0.85) -- Inset from edges to stay within sign
	textContainer.Position = UDim2.fromScale(0.5, 0.5)
	textContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	textContainer.BackgroundTransparency = 1
	textContainer.ClipsDescendants = true -- Clip any overflow
	textContainer.ZIndex = 10
	textContainer.Parent = viewportFrame

	-- Create a TextLabel that sits inside the container
	local textOverlay = Instance.new("TextLabel")
	textOverlay.Name = "SignNameOverlay"
	textOverlay.Size = UDim2.fromScale(1, 1)
	textOverlay.Position = UDim2.fromScale(0, 0)
	textOverlay.BackgroundTransparency = 1
	textOverlay.Text = "Test Sign"
	textOverlay.TextColor3 = colors.signTextColor
	textOverlay.Font = Enum.Font.Gotham
	textOverlay.TextScaled = true
	textOverlay.TextXAlignment = Enum.TextXAlignment.Center
	textOverlay.TextYAlignment = Enum.TextYAlignment.Center
	textOverlay.TextStrokeTransparency = 1
	textOverlay.TextTruncate = Enum.TextTruncate.AtEnd -- Truncate very long names
	textOverlay.ZIndex = 11
	textOverlay.Parent = textContainer

	-- Limit text size so it doesn't get too large on big screens
	local textSizeConstraint = Instance.new("UITextSizeConstraint")
	textSizeConstraint.MaxTextSize = 24
	textSizeConstraint.Parent = textOverlay

	signNameLabel = textOverlay

	-- Create Camera for ViewportFrame - looking straight down at the sign to fill viewport
	local camera = Instance.new("Camera")
	camera.Name = "ViewportCamera"
	-- Position close above, look straight down, wide FOV to fill entire background
	camera.CFrame = CFrame.new(0, 3, 0) * CFrame.Angles(math.rad(-90), 0, 0)
	camera.FieldOfView = 90
	camera.Parent = worldModel
	viewportFrame.CurrentCamera = camera

	-- Add corner to viewport frame for rounded edges
	local viewportCorner = Instance.new("UICorner")
	viewportCorner.CornerRadius = UDim.new(0.02, 0)
	viewportCorner.Parent = viewportFrame

	-- Static positioning - no rotation needed
	if signRotationConnection then
		signRotationConnection:Disconnect()
		signRotationConnection = nil
	end

	-- Static sign - no rotation, positioned to fill the viewport
	if signRotationConnection then
		signRotationConnection:Disconnect()
		signRotationConnection = nil
	end

	-- Orient sign so the top face is directly facing the camera (flat, like a floor tile)
	if signViewportPart then
		signViewportPart.CFrame = CFrame.new(0, 0, 0)
	end

	-- Distance label: monospaced + fixed size + left-align to sit close to sign
	local newDistanceLabel = createActiveRunLabel({
		name = "distanceLabel",
		size = UDim2.new(0.10, 0, 1, 0), -- Compact: fits "1000d" max
		parent = newRightPanel,
		text = "0.0d",
		textColor3 = colors.yellow,
		fontFace = fonts.GetFont(true, false), -- Monospaced for numeric stability
		textXAlignment = Enum.TextXAlignment.Left, -- Left align to sit close to sign
		fixedTextSize = true, -- Prevents text shrinking when numbers grow
	})
	distanceLabel = newDistanceLabel
	addStroke(newDistanceLabel, colors.yellow)
	applyLabelPadding(newDistanceLabel, 2)

	-- Details label: handles empty state or long text descriptions
	-- Always visible to maintain stable layout; content hidden via transparency when empty
	local newDetailsLabel = createActiveRunLabel({
		name = "detailsLabel",
		size = UDim2.new(0.22, 0, 1, 0), -- Compact to bring distance closer
		parent = newRightPanel,
		text = "\u{200B}", -- Zero-width space maintains layout when empty
		textColor3 = colors.yellow,
		textXAlignment = Enum.TextXAlignment.Left,
	})
	newDetailsLabel.Visible = true -- Always visible for stable layout
	newDetailsLabel.TextTransparency = 1 -- Start hidden
	detailsLabel = newDetailsLabel
	applyLabelPadding(newDetailsLabel, 2)

	-- Add corner to details label
	local detailsCorner = Instance.new("UICorner")
	detailsCorner.CornerRadius = UDim.new(0.02, 0)
	detailsCorner.Parent = newDetailsLabel

	addStroke(newDetailsLabel, colors.yellow)
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
	if accelerationLabel then
		accelerationLabel.BackgroundTransparency = 1
	end
	if speedReasonLabel then
		speedReasonLabel.BackgroundTransparency = 1
	end

	if renderSteppedConnection then
		renderSteppedConnection:Disconnect()
	end

	renderSteppedConnection = RunService.RenderStepped:Connect(function(_deltaTime)
		if not updateRunProgress() then
			if renderSteppedConnection ~= nil then
				renderSteppedConnection:Disconnect()
			end
			renderSteppedConnection = nil
		end
	end)

	debounceCreateRunProgressSgui = false
end

-- Interface aliases for ActiveRunUIVariant compatibility
-- These allow the Classic variant to be used through the dispatcher
module.CreateGui = function()
	createPersistentGui()
end

module.StartActiveRun = module.StartActiveRunGui

_annotate("end")
return module
