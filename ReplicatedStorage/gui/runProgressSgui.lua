local colors = require(game.ReplicatedStorage.util.colors)

--the one in the lower left, where you can cancel out of a race.
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local localPlayer: Player = game.Players.LocalPlayer
local enums = require(game.ReplicatedStorage.util.enums)
local movementEnums = require(game.StarterPlayer.StarterPlayerScripts.movementEnums)

local avatarEventFiring = require(game.StarterPlayer.StarterPlayerScripts.avatarEventFiring)
local fireEvent = avatarEventFiring.FireEvent
local mt = require(game.ReplicatedStorage.avatarEventTypes)

local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid: Humanoid = character:WaitForChild("Humanoid") :: Humanoid

local module = {}

local runShouldEndSemaphore: boolean = false
local currentRunStartTick: number = 0
local currentRunSignName: string = ""
local currentRunStartPosition: Vector3 = Vector3.zero
local theSgui: ScreenGui = nil
local theTextButton: TextButton = nil
local specialMovementTypeTextForPlayer = ""
local specialMovementDetails = ""

--receive updates to these items. otherwise I am independent
module.UpdateMovementDetails = function(outerMovementDetails: string)
	specialMovementDetails = outerMovementDetails
end

module.UpdateOverallDescription = function(outerOverallDescription: string)
	specialMovementTypeTextForPlayer = outerOverallDescription
end

module.UpdateStartTime = function(n: number)
	currentRunStartTick = n
end

module.Kill = function()
	runShouldEndSemaphore = true
	-- hard to communicate to the inside of the thing.
	-- again, bindingEvents are the solution.
	wait()
	_annotate("Waiting in kill semaphore")
end

local lastUpdate = ""
local function Update()
	local formattedRuntime = string.format("%.1fs", tick() - currentRunStartTick)
	if lastUpdate == formattedRuntime then
		-- _annotate("skipping early update.")
		return true
	end
	lastUpdate = formattedRuntime
	if localPlayer.Character == nil or localPlayer.Character.PrimaryPart == nil then
		_annotate("well this happened.")
		module.Kill()
		return false
	end
	local pos = localPlayer.Character.PrimaryPart.Position
	local distance = tpUtil.getDist(pos, currentRunStartPosition)

	-- special race descriptors for weird limit runs. ----
	local specialRaceDescriptor = ""
	if specialMovementTypeTextForPlayer and specialMovementTypeTextForPlayer ~= "" then
		specialRaceDescriptor = "\n" .. specialMovementTypeTextForPlayer
	end
	if specialMovementDetails and specialMovementDetails ~= "" then
		specialRaceDescriptor = specialRaceDescriptor .. " " .. specialMovementDetails
	end

	--- bit weird to calculate this here but whatever. --
	local mult = humanoid.WalkSpeed / movementEnums.constants.globalDefaultRunSpeed
	local speedupDescriptor = ""

	if mult ~= 1 then
		local multDescriptor = "+"
		if mult < 1 then
			multDescriptor = ""
		end
		speedupDescriptor = string.format("%s%0.1f%%", multDescriptor, (mult - 1) * 100)
	end

	local optionalSignAliasText = ""
	local alias = enums.signName2Alias[currentRunSignName]
	if alias ~= nil then
		if not enums.aliasesWhichAreVeryCloseSoDontNeedToBeShown[currentRunSignName] then
			optionalSignAliasText = " (" .. alias .. ")"
		end
	end

	local text = string.format(
		"%s %s%s\nFrom: %s%s (%.1fd)",
		formattedRuntime,
		speedupDescriptor,
		specialRaceDescriptor,
		currentRunSignName,
		optionalSignAliasText,
		distance
	)
	theTextButton.Text = text
	return true
end

-- this is the lower-right GUI which continuously updates the time. ------
-- why don't we try to have it only update like, when it'd be different? duh. -------------
local debounceCreateRunProgressSgui = false
module.CreateRunProgressSgui = function(playerGui, startTimeTick, signName, pos)
	-- store run const variables
	-- non-const variables (such as the dynamic race text, etc.) will be updated via above.
	currentRunSignName = signName
	currentRunStartPosition = pos
	module.Kill()
	runShouldEndSemaphore = false
	currentRunStartTick = startTimeTick
	if debounceCreateRunProgressSgui then
		warn("deb progress.")
		return
	end
	debounceCreateRunProgressSgui = true
	local sgui: ScreenGui = playerGui:FindFirstChild("ActiveRunSGui") :: ScreenGui
	if not sgui then
		sgui = Instance.new("ScreenGui") :: ScreenGui
		if sgui == nil then
			return
		end
		sgui.Parent = playerGui
		sgui.Name = "ActiveRunSGui"
		sgui.Enabled = true
	end
	theSgui = sgui

	local tb = Instance.new("TextButton")
	tb.Parent = sgui
	tb.Name = "RaceRunningButton"
	tb.Size = UDim2.new(0.57, 0, 0.1, 0)
	tb.Position = UDim2.new(0.0, 0, 0.9, 0)
	tb.TextTransparency = 0
	tb.BackgroundTransparency = 1
	tb.TextScaled = true
	tb.TextColor3 = colors.yellow
	tb.TextXAlignment = Enum.TextXAlignment.Left
	tb.Text = ""
	tb.Font = Enum.Font.RobotoCondensed
	tb.TextTransparency = 0
	theTextButton = tb

	tb.Activated:Connect(function()
		fireEvent(mt.avatarEventTypes.RUN_KILL, { reason = "clicked on raceRunningSgui" })
	end)

	-- no create an updater which continuously runs.
	-- it partially bases its functions on the global variables received from outer.
	task.spawn(function()
		while true do
			if runShouldEndSemaphore then
				break
			end
			local res = Update()
			if not res then
				warn("broke cause fail to update sgui text.")
				break
			end
			wait(0.001)
		end
		runShouldEndSemaphore = false
		debounceCreateRunProgressSgui = false
		theSgui:Destroy()
	end)
end

_annotate("end")
return module
