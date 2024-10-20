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
local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)

local avatarEventFiring = require(game.StarterPlayer.StarterPlayerScripts.avatarEventFiring)
local fireEvent = avatarEventFiring.FireEvent

--TYPES
local aet = require(game.ReplicatedStorage.avatarEventTypes)
local tt = require(game.ReplicatedStorage.types.gametypes)
local PlayersService = game:GetService("Players")
--HUMANOID
local localPlayer = PlayersService.LocalPlayer

local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
-- local humanoid: Humanoid = character:WaitForChild("Humanoid") :: Humanoid

-- GLOBALS
local currentRunStartTick: number = 0
local currentRunSignName: string = ""
local currentRunStartPosition: Vector3 = Vector3.new(0, 0, 0)
local theFont = Font.new("rbxasset://fonts/families/Arimo.json")

-- this is okay because a user is only running from one at a time.
local globalActiveRunSgui: ScreenGui | nil = nil
local activeRunFrame: Frame | nil = nil

local optionalRaceDescription = ""
local movementDetails = ""
local lastActiveRunUpdateTime = ""
local renderSteppedConnection: RBXScriptConnection?

-- local playerGui
local activeRunSgui

local timeLabel: TextButton
local sourceLabel: TextLabel
local distanceLabel: TextLabel
local detailsLabel: TextLabel

local settings = require(game.ReplicatedStorage.settings)

local currentRunUIConfiguration: tt.currentRunUIConfiguration = nil

----------------------- FOR SAVING LB CONFIGURATION -----------------

local lastSaveRequestCount = 0

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

		local topInset = game:GetService("GuiService"):GetGuiInset().Y
		local positionInOffset = UDim2.new(0, absolutePosition.X, 0, absolutePosition.Y + topInset)
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

-- when a user retouches a sign, we update the UI here.
module.UpdateStartTime = function(n: number)
	currentRunStartTick = n
end

-- the run ended, either cancelled or finished.
module.KillActiveRun = function()
	if activeRunFrame then
		activeRunFrame:Destroy()
	end
	currentRunStartTick = 0
	currentRunSignName = ""
	currentRunStartPosition = Vector3.new(0, 0, 0)
	optionalRaceDescription = ""
	movementDetails = ""
	lastActiveRunUpdateTime = ""
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

	timeLabel.Text = string.format("%s", formattedRuntime)
	distanceLabel.Text = string.format("%0.1fd", dist)
	sourceLabel.Text = string.format("From: %s%s", currentRunSignName, optionalSignAliasText)

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
	detailsLabel.BackgroundTransparency = 1

	if secondText ~= "" then
		detailsLabel.Text = secondText

		detailsLabel.Visible = true
	else
		detailsLabel.Text = ""
		detailsLabel.Visible = false
	end

	return true
end

local debounceCreateRunProgressSgui = false
module.StartActiveRunGui = function(startTimeTick, signName, signPosition)
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
	activeRunSgui = Instance.new("ScreenGui") :: ScreenGui
	activeRunSgui.IgnoreGuiInset = true
	activeRunSgui.Parent = playerGui
	activeRunSgui.Name = "ActiveRunGui"
	activeRunSgui.Enabled = true
	globalActiveRunSgui = activeRunSgui
	if debounceCreateRunProgressSgui then
		_annotate("debounceCreateRunProgressSgui.")
		return
	end
	debounceCreateRunProgressSgui = true
	module.KillActiveRun()

	local guiSystemFrames = windows.SetupFrame("activeRun", true, true, false)

	local outerFrame = guiSystemFrames.outerFrame
	activeRunFrame = outerFrame
	local contentFrame = guiSystemFrames.contentFrame
	outerFrame.Parent = activeRunSgui
	contentFrame.Parent = outerFrame

	currentRunSignName = signName
	currentRunStartTick = startTimeTick
	currentRunStartPosition = signPosition

	outerFrame.Size = currentRunUIConfiguration.size
	outerFrame.Position = currentRunUIConfiguration.position
	outerFrame.BackgroundTransparency = 1.0
	outerFrame.BorderSizePixel = 0
	outerFrame.BorderColor3 = colors.meColor
	outerFrame.BorderMode = Enum.BorderMode.Outline

	contentFrame.BackgroundTransparency = 1
	contentFrame.BorderSizePixel = 2
	contentFrame.BorderColor3 = colors.meColor
	contentFrame.BorderMode = Enum.BorderMode.Outline
	-- contentFrame.Name = "ActiveRunContentFrame"

	local hh = Instance.new("UIListLayout")
	hh.Parent = contentFrame
	hh.Name = "ActiveRun_hh"
	hh.HorizontalFlex = Enum.UIFlexAlignment.Fill

	hh.HorizontalAlignment = Enum.HorizontalAlignment.Left
	hh.VerticalAlignment = Enum.VerticalAlignment.Top
	hh.FillDirection = Enum.FillDirection.Horizontal
	hh.SortOrder = Enum.SortOrder.Name
	hh.HorizontalAlignment = Enum.HorizontalAlignment.Left
	hh.SortOrder = Enum.SortOrder.Name

	-- three parts: big for current runtime and source.
	-- optional for race desc etc.
	timeLabel = Instance.new("TextButton")
	timeLabel.Size = UDim2.new(0.33, 0, 1, 0)
	-- timeLabel.Position = UDim2.new(0, 0, 0, 0)
	timeLabel.TextTransparency = 0
	timeLabel.BackgroundColor3 = colors.black
	timeLabel.BackgroundTransparency = currentRunUIConfiguration.transparency
	timeLabel.TextScaled = true
	timeLabel.TextColor3 = colors.yellow
	timeLabel.Name = "01_ActiveRunGui_Time"
	timeLabel.Text = ""
	timeLabel.FontFace = theFont
	timeLabel.TextXAlignment = Enum.TextXAlignment.Left
	timeLabel.TextYAlignment = Enum.TextYAlignment.Top
	timeLabel.Parent = contentFrame
	timeLabel.Activated:Connect(function()
		local details: aet.avatarEventDetails = {
			reason = "clicked on timeSourceLabel in active run SGui",
			sender = "activeRunSGui",
		}
		fireEvent(aet.avatarEventTypes.RUN_CANCEL, details)
	end)

	sourceLabel = Instance.new("TextLabel")
	sourceLabel.Size = UDim2.new(0.33, 0, 1, 0)
	-- timeLabel.Position = UDim2.new(0, 0, 0, 0)
	sourceLabel.TextTransparency = 0
	sourceLabel.BackgroundColor3 = colors.black
	sourceLabel.BackgroundTransparency = currentRunUIConfiguration.transparency
	sourceLabel.TextScaled = true
	sourceLabel.TextColor3 = colors.yellow
	sourceLabel.Name = "02_ActiveRunGui_Source"
	sourceLabel.Text = ""
	sourceLabel.FontFace = theFont
	sourceLabel.TextXAlignment = Enum.TextXAlignment.Left
	sourceLabel.TextYAlignment = Enum.TextYAlignment.Top
	sourceLabel.Parent = contentFrame

	distanceLabel = Instance.new("TextLabel")
	distanceLabel.Size = UDim2.new(0.33, 0, 1, 0)
	distanceLabel.Position = UDim2.new(0, 0, 0, 0)
	distanceLabel.TextTransparency = 0
	distanceLabel.BackgroundColor3 = colors.black
	distanceLabel.BackgroundTransparency = currentRunUIConfiguration.transparency
	distanceLabel.TextScaled = true
	distanceLabel.TextColor3 = colors.yellow
	distanceLabel.Name = "02_ActiveRunGui_DistanceLabel"
	distanceLabel.Text = "Distance: 0m"
	distanceLabel.FontFace = theFont
	distanceLabel.TextXAlignment = Enum.TextXAlignment.Left
	distanceLabel.TextYAlignment = Enum.TextYAlignment.Top
	distanceLabel.Parent = contentFrame

	detailsLabel = Instance.new("TextLabel")
	detailsLabel.Size = UDim2.new(0.4, 0, 1, 0)
	detailsLabel.Position = UDim2.new(0.6, 0, 0, 0)
	detailsLabel.TextTransparency = 0
	detailsLabel.BackgroundColor3 = colors.black
	detailsLabel.BackgroundTransparency = currentRunUIConfiguration.transparency
	detailsLabel.TextScaled = true
	detailsLabel.TextColor3 = colors.yellow
	detailsLabel.Name = "03_ActiveRunGui_DetailsLabel"
	detailsLabel.Text = ""
	detailsLabel.FontFace = theFont
	detailsLabel.TextXAlignment = Enum.TextXAlignment.Left
	detailsLabel.TextYAlignment = Enum.TextYAlignment.Top
	detailsLabel.Parent = contentFrame

	local function onActiveRunSGuiDestroyed()
		if renderSteppedConnection then
			renderSteppedConnection:Disconnect()
			renderSteppedConnection = nil
		end
	end

	-- Connect the onActiveRunSGuiDestroyed function to the Destroying event of activeRunSGui
	if globalActiveRunSgui then
		globalActiveRunSgui.Destroying:Connect(onActiveRunSGuiDestroyed)
	end

	debounceCreateRunProgressSgui = false
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

	monitorActiveRunSGui()
end

_annotate("end")
return module
