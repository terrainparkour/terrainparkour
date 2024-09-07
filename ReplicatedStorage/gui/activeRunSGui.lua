--!strict

-- activeRunSGui.lua
-- displays the current run time and effects. Things like speed are displayed by activeRunSGui

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

-- local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local enums = require(game.ReplicatedStorage.util.enums)
local colors = require(game.ReplicatedStorage.util.colors)

local avatarEventFiring = require(game.StarterPlayer.StarterPlayerScripts.avatarEventFiring)
local fireEvent = avatarEventFiring.FireEvent

--TYPES
local mt = require(game.ReplicatedStorage.avatarEventTypes)

--HUMANOID
local localPlayer: Player = game.Players.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid: Humanoid = character:WaitForChild("Humanoid") :: Humanoid

-- GLOBALS
local currentRunStartTick: number = 0
local currentRunSignName: string = ""

-- this is okay because a user is only running from one at a time.
local globalActiveRunSgui: ScreenGui = nil
local activeRunFrame: Frame = nil

local optionalRaceDescription = ""
local movementDetails = ""
local lastActiveRunUpdateTime = ""
local renderSteppedConnection: RBXScriptConnection?

local playerGui
local activeRunSgui
local raceGuiTransparency = 0.7
local timeSourceLabel: TextButton
local detailsLabel: TextButton

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
	-- currentRunStartPosition = Vector3.zero
	optionalRaceDescription = ""
	movementDetails = ""
	lastActiveRunUpdateTime = ""
end

-- an internal loop calls this periodically to update the UI.
updateRunProgress = function()
	if localPlayer.Character == nil or localPlayer.Character.PrimaryPart == nil then
		_annotate("nil char or nil primary part in runProgressSgui, kllin.")
		module.KillActiveRun()
		return false
	end

	local formattedRuntime = string.format("%.2fs", tick() - currentRunStartTick)
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

	timeSourceLabel.Text = string.format("%s\nFrom: %s%s", formattedRuntime, currentRunSignName, optionalSignAliasText)

	local secondText = ""
	-- _annotate(
	-- 	string.format("optionalRaceDescription: '%s', movementDetails: '%s'", optionalRaceDescription, movementDetails)
	-- )
	if optionalRaceDescription ~= "" and movementDetails ~= "" then
		secondText = optionalRaceDescription .. "\n" .. movementDetails
	elseif optionalRaceDescription ~= "" then
		secondText = optionalRaceDescription
	elseif movementDetails ~= "" then
		secondText = movementDetails
	else
		secondText = ""
	end

	if secondText ~= "" then
		detailsLabel.Text = secondText
		detailsLabel.BackgroundTransparency = raceGuiTransparency
	else
		detailsLabel.Text = ""
		detailsLabel.BackgroundTransparency = 1
	end

	return true
end

local debounceCreateRunProgressSgui = false
module.StartActiveRunGui = function(startTimeTick, signName, pos)
	playerGui = localPlayer:WaitForChild("PlayerGui")
	local ex = playerGui:FindFirstChild("ActiveRunGui")
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
	currentRunSignName = signName
	-- currentRunStartPosition = pos

	currentRunStartTick = startTimeTick

	-- make a new frame
	activeRunFrame = Instance.new("Frame")

	activeRunFrame.Parent = activeRunSgui
	activeRunFrame.Size = UDim2.new(0.6, 0, 0.1, 0)
	activeRunFrame.Position = UDim2.new(0.3, 0, 0.81, 0)
	activeRunFrame.Transparency = 1
	activeRunFrame.BorderSizePixel = 2
	activeRunFrame.BorderColor3 = colors.meColor
	activeRunFrame.BorderMode = Enum.BorderMode.Outline
	activeRunFrame.Name = "ActiveRunFrame"

	local hh = Instance.new("UIListLayout")
	hh.Parent = activeRunFrame
	hh.Name = "ActiveRunFrameLayout"
	hh.FillDirection = Enum.FillDirection.Horizontal
	hh.VerticalAlignment = Enum.VerticalAlignment.Top
	hh.HorizontalAlignment = Enum.HorizontalAlignment.Left
	hh.SortOrder = Enum.SortOrder.Name

	-- three parts: big for current runtime and source.
	-- optional for race desc etc.
	timeSourceLabel = Instance.new("TextButton")
	timeSourceLabel.Size = UDim2.new(0.5, 0, 1, 0)
	timeSourceLabel.Position = UDim2.new(0, 0, 0, 0)
	timeSourceLabel.TextTransparency = 0
	timeSourceLabel.BackgroundColor3 = colors.black
	timeSourceLabel.BackgroundTransparency = raceGuiTransparency
	timeSourceLabel.TextScaled = true
	timeSourceLabel.TextColor3 = colors.yellow
	timeSourceLabel.Name = "1TimeSourceLabel"
	timeSourceLabel.Text = ""
	timeSourceLabel.FontFace = Font.new("rbxasset://fonts/families/DenkOne.json")
	timeSourceLabel.TextXAlignment = Enum.TextXAlignment.Left
	timeSourceLabel.TextYAlignment = Enum.TextYAlignment.Top
	timeSourceLabel.Parent = activeRunFrame
	timeSourceLabel.Activated:Connect(function()
		local details: mt.avatarEventDetails = {
			reason = "clicked on timeSourceLabel in active run SGui",
		}
		fireEvent(mt.avatarEventTypes.RUN_CANCEL, details)
	end)

	detailsLabel = Instance.new("TextButton")
	detailsLabel.Size = UDim2.new(0.4, 0, 1, 0)
	detailsLabel.Position = UDim2.new(0.6, 0, 0, 0)
	detailsLabel.TextTransparency = 0
	detailsLabel.BackgroundColor3 = colors.black
	detailsLabel.BackgroundTransparency = raceGuiTransparency
	detailsLabel.TextScaled = true
	detailsLabel.TextColor3 = colors.yellow
	detailsLabel.Name = "2DetailsLabel"
	detailsLabel.Text = ""
	detailsLabel.FontFace = Font.new("rbxasset://fonts/families/DenkOne.json")
	detailsLabel.TextXAlignment = Enum.TextXAlignment.Left
	detailsLabel.TextYAlignment = Enum.TextYAlignment.Top
	detailsLabel.Parent = activeRunFrame
	detailsLabel.Activated:Connect(function()
		local details: mt.avatarEventDetails = {
			reason = "clicked on detailsLabel in active run SGui",
		}
		fireEvent(mt.avatarEventTypes.RUN_CANCEL, details)
	end)

	local function onActiveRunSGuiDestroyed()
		if renderSteppedConnection then
			renderSteppedConnection:Disconnect()
			renderSteppedConnection = nil
		end
	end

	-- Connect the onActiveRunSGuiDestroyed function to the Destroying event of activeRunSGui
	globalActiveRunSgui.Destroying:Connect(onActiveRunSGuiDestroyed)

	debounceCreateRunProgressSgui = false
	if renderSteppedConnection then
		renderSteppedConnection:Disconnect()
	end

	renderSteppedConnection = game:GetService("RunService").RenderStepped:Connect(function(deltaTime)
		-- if deltaTime < 0.01 then
		-- 	_annotate(string.format("too fast delta for a fraem: %0.5f", deltaTime))
		-- 	return
		-- end
		-- _annotate(string.format("Delta was: %0.5f", deltaTime))
		if not updateRunProgress() then
			if renderSteppedConnection ~= nil then
				renderSteppedConnection:Disconnect()
			end
			renderSteppedConnection = nil
		end
	end)
end

_annotate("end")
return module
