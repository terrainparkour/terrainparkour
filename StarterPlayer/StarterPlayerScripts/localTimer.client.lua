--!strict

-- 4.29.2022 redo to trust client
-- completely locally track times and then just hit the endpoint with what they are
-- What is this: the guy who does local tracking of the time for a run.

local enums = require(game.ReplicatedStorage.util.enums)
local colors = require(game.ReplicatedStorage.util.colors)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local remotes = require(game.ReplicatedStorage.util.remotes)
local marathonClient = require(game.StarterPlayer.StarterCharacterScripts.marathon.marathonClient)
local movementEnums = require(game.StarterPlayer.StarterCharacterScripts.movementEnums)
local speedEvents = require(game.StarterPlayer.StarterCharacterScripts.speedEvents)
local dynamicRunning = require(game.ReplicatedStorage.dynamicRunning)
local signMovementEnums = require(game.ReplicatedStorage.enums.signMovementEnums)
local ContextActionService = game:GetService("ContextActionService")
local vscdebug = require(game.ReplicatedStorage.vscdebug)
local doNotCheckInGameIdentifier = require(game.ReplicatedStorage:FindFirstChild("doNotCheckInGameIdentifier"))
local newMovement = doNotCheckInGameIdentifier.useNewMovement()
local textUtil = require(game.ReplicatedStorage.util.textUtil)

local PlayersService = game:GetService("Players")
local localPlayer: Player = PlayersService.LocalPlayer

local playerGui = localPlayer:WaitForChild("PlayerGui")
local warper = require(game.ReplicatedStorage.warper)

--script globals - directly set with updated info when messages come over the wire.
local currentRunStartTick: number = 0
local currentRunSignName: string = ""

local clientTouchDebounce: { [string]: boolean } = {}
local lastRunCompleteTime = 0

--can user touch signs at all (or are they in the middle of a warp)
local canDoAnything = true

--the start position of the initial sign in a race.
local currentRunStartPosition = nil

--some kinda debouncer
local runShouldEndSemaphore = false

-- local cancelRunRemoteFunction = remotes.getRemoteFunction("CancelRunRemoteFunction")
local clientControlledRunEndEvent = remotes.getRemoteEvent("ClientControlledRunEndEvent")
local movementManipulationBindableEvent = remotes.getBindableEvent("MovementManipulationBindableEvent")

---------ANNOTATION----------------
local doAnnotation = false
	or localPlayer.Name == "TerrainParkour"
	or localPlayer.Name == "Player2"
	or localPlayer.Name == "Player1"
doAnnotation = true
doAnnotation = false
local annotationStart = tick()
local function annotate(s: string | any)
	if doAnnotation then
		if typeof(s) == "string" then
			print("localTimer.: " .. string.format("%.0f", tick() - annotationStart) .. " : " .. s)
		else
			print("localTimer.object. " .. string.format("%.0f", tick() - annotationStart) .. " : ")
			print(s)
		end
	end
end

local specialMovementType = ""
local specialMovementDetails = ""

local modeChangeDebounce = false

local function getModeChangeLock(kind: string)
	while modeChangeDebounce do
		wait(0.05)
		annotate("wait for mode lok." .. kind)
	end
	modeChangeDebounce = true
	annotate("locked for " .. kind)
end

local function tellLocalMovementToRestore()
	annotate("tellLocalMovementToRestore")
	local data: signMovementEnums.movementModeMessage = { action = signMovementEnums.movementModes.RESTORE }
	movementManipulationBindableEvent:Fire(data)
	specialMovementType = ""
end

local activeMovementData

--if you were tracking ground, then start a touch, you may inadvertently not send an update.  set this to force one.

local function handleSpecialSignTouches(signName: string)
	getModeChangeLock("handleSpecialSignTouches")
	annotate("handleSpecialSignTouches:" .. signName)
	if signName == "Hypergravity" then
		local data: signMovementEnums.movementModeMessage = { action = signMovementEnums.movementModes.NOJUMP }
		activeMovementData = data
		specialMovementType = "No Jump"
		movementManipulationBindableEvent:Fire(data)
	elseif signName == "Bolt" then
		local data: signMovementEnums.movementModeMessage = { action = signMovementEnums.movementModes.FASTER }
		activeMovementData = data
		specialMovementType = "Fast"
		movementManipulationBindableEvent:Fire(data)
	elseif signName == "Triple" then
		local data: signMovementEnums.movementModeMessage = { action = signMovementEnums.movementModes.THREETERRAIN }
		activeMovementData = data
		specialMovementType = "Limited to 3 terrain types:"
		movementManipulationBindableEvent:Fire(data)
	elseif signName == "cOld mOld on a sLate pLate" then
		local data: signMovementEnums.movementModeMessage = { action = signMovementEnums.movementModes.COLDMOLD }
		activeMovementData = data
		specialMovementType = "Touch terrain only once."
		movementManipulationBindableEvent:Fire(data)
	elseif signName == "Quadruple" then
		local data: signMovementEnums.movementModeMessage = { action = signMovementEnums.movementModes.FOURTERRAIN }
		activeMovementData = data
		specialMovementType = "Limited to 4 terrain types:"
		movementManipulationBindableEvent:Fire(data)
	elseif signName == "Fosbury" then
		local data: signMovementEnums.movementModeMessage = { action = signMovementEnums.movementModes.HIGHJUMP }
		activeMovementData = data
		specialMovementType = "High Jump"
		movementManipulationBindableEvent:Fire(data)
	elseif signName == "Keep Off the Grass" then
		local data: signMovementEnums.movementModeMessage = { action = signMovementEnums.movementModes.NOGRASS }
		activeMovementData = data
		specialMovementType = "Don't touch Grass"
		movementManipulationBindableEvent:Fire(data)
	end
	modeChangeDebounce = false
end

--ordered i{} of names of terrain we've seen.
local inputSeenTerrainTypes: { [number]: string } = {}

local function updateFloorTouchedTracking(inputSeenTerrainTypesInput: { [number]: string })
	getModeChangeLock("update floor.")
	annotate("timer was told about new floor tracking.")
	inputSeenTerrainTypes = inputSeenTerrainTypesInput
	if
		activeMovementData
		and (
			activeMovementData.action == signMovementEnums.movementModes.THREETERRAIN
			or activeMovementData.action == signMovementEnums.movementModes.FOURTERRAIN
		)
	then --only calc this for display if it's a type which limits
		annotate("we are in one of the managed types.")
		local t = {}
		for _, k in ipairs(inputSeenTerrainTypes) do
			table.insert(t, k)
		end

		specialMovementDetails = textUtil.stringJoin(", ", t)
		annotate("specialMovementDetails: " .. specialMovementDetails)
	end
	if activeMovementData and activeMovementData.action == signMovementEnums.movementModes.COLDMOLD then
		local t = {}
		for ii, k in ipairs(inputSeenTerrainTypes) do
			if ii == #inputSeenTerrainTypes then
				break
			end
			table.insert(t, k)
		end
		specialMovementDetails = string.format(
			"Now: %s Forbidden from touching:%s",
			inputSeenTerrainTypes[#inputSeenTerrainTypes],
			textUtil.stringJoin(", ", t)
		)
	end
	modeChangeDebounce = false
end

local updateTerrainSeenBindableEvent = remotes.getBindableEvent("UpdateTerrainSeenBindableEvent")
updateTerrainSeenBindableEvent.Event:Connect(updateFloorTouchedTracking)

--based on various interactions, locally kill the run
--also tell server it's done
--also tell movement client to restore natural player movement which may have been modified by sign.
local function killClientRun(context: string)
	getModeChangeLock("killClientRun")
	annotate("killClientRun." .. context)
	tellLocalMovementToRestore()
	currentRunStartTick = 0
	currentRunSignName = ""
	local sgui = playerGui:FindFirstChild("RunningRunSgui")
	if sgui ~= nil then
		sgui:Destroy()
	end
	dynamicRunning.endDynamic()
	specialMovementType = ""
	specialMovementDetails = ""
	activeMovementData = nil
	modeChangeDebounce = false
end

--the one in the lower left, where you can cancel out of a race.
local debounceCreateRunProgressSgui = false
local function createRunProgressSgui()
	if debounceCreateRunProgressSgui then
		return
	end
	debounceCreateRunProgressSgui = true
	local sgui: ScreenGui = playerGui:FindFirstChild("RunningRunSgui") :: ScreenGui
	if not sgui then
		sgui = Instance.new("ScreenGui")
		sgui.Parent = playerGui
		sgui.Name = "RunningRunSgui"
		sgui.Enabled = true
	end

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
	tb.Font = Enum.Font.GothamBlack
	tb.TextTransparency = 0
	tb.Activated:Connect(function()
		killClientRun("unclick progress")
	end)
	debounceCreateRunProgressSgui = false
end

--what to display on the 'race active' label in LL
local function getRacingText()
	local useRunTimeS = 0
	if currentRunStartTick == 0 then
		return ""
	end
	if currentRunStartTick ~= 0 then
		useRunTimeS = tick() - currentRunStartTick
	end
	if currentRunSignName == "" then
		return ""
	end
	if
		localPlayer == nil
		or localPlayer.Character == nil
		or localPlayer.Character.PrimaryPart == nil
		or currentRunSignName == ""
	then
		return ""
	end

	local pos = localPlayer.Character.PrimaryPart.Position
	local distance = tpUtil.getDist(pos, currentRunStartPosition)
	local useDescriptor = ""
	if specialMovementType ~= "" then
		useDescriptor = "\n" .. specialMovementType
	end
	if specialMovementDetails ~= "" then
		useDescriptor = useDescriptor .. " " .. specialMovementDetails
	end
	local text = string.format("%.1f%s\nFrom: %s (%.1fd)", useRunTimeS, useDescriptor, currentRunSignName, distance)
	return text
end

local function clientTouchedSign(humanoid: Humanoid, sign: BasePart)
	if not canDoAnything then
		annotate("blocked til warp done.")
		return
	end
	if newMovement then
		speedEvents.addEvent({ timems = tick(), type = movementEnums.SpeedEventName2Id.TOUCHSIGN })
	end
	local par = humanoid.Parent :: Instance
	local pn = par.Name
	if clientTouchDebounce[pn] then
		return
	end
	clientTouchDebounce[pn] = true
	local touchTimeTick = tick()
	local gapSinceLastRun = touchTimeTick - lastRunCompleteTime
	if gapSinceLastRun < 0.8 then
		clientTouchDebounce[pn] = false
		return false
	end

	if pn ~= localPlayer.Name then
		--i set up global hit monitoring for all signs by anyone, and other players are in my local DM, so of course when they hit, I notice
		annotate("somehow got a note for other players hit.")
		return
	end
	--hit is valid.

	--notify marathon ui
	marathonClient.receiveHit(sign.Name, touchTimeTick)

	----NEW HIT AREA START, RETURNED--------
	--NOTE we do not FIND signs from the client.-------
	if currentRunSignName == "" then -------START RACE
		--this tells the movement module to get ready to send me floor updates.

		--this lock is here so that
		-- getModeChangeLock("starting run")
		tellLocalMovementToRestore()
		if warper.isWarping() then
			clientTouchDebounce[pn] = false
			annotate("blocked due to iswarping.")
			-- modeChangeDebounce=false
			return false
		end
		currentRunSignName = sign.Name

		--this will reset movement and then set to target type, then reflect back currently touched floor if needed.
		handleSpecialSignTouches(sign.Name)
		annotate("starting.run from " .. currentRunSignName)
		currentRunStartTick = touchTimeTick
		currentRunStartPosition = sign.Position
		createRunProgressSgui()

		--spin up something monitoring progress
		spawn(function()
			while true do
				if runShouldEndSemaphore then
					killClientRun("semaphore1")
					runShouldEndSemaphore = false
					break
				end
				--TODO this should be renderstepped.
				wait(1 / 60)
				if runShouldEndSemaphore then
					killClientRun("semaphore2")
					runShouldEndSemaphore = false
					break
				end
				local sgui = playerGui:FindFirstChild("RunningRunSgui") :: ScreenGui?
				if sgui == nil then
					killClientRun("nil label")
					break
				end
				local nnsgui = sgui :: ScreenGui
				local racingText = getRacingText()
				if racingText == "" then
					killClientRun("notext")
					break
				end

				local tl = nnsgui:FindFirstChild("RaceRunningButton") :: TextLabel
				tl.Text = racingText
			end
		end)
		dynamicRunning.startDynamic(localPlayer, sign.Name, touchTimeTick)
		clientTouchDebounce[pn] = false
		annotate("started.run from " .. currentRunSignName)
		modeChangeDebounce = false
		return
	end
	if sign.Name == currentRunSignName then --------RESET CURRENT RACE START TIMER
		-- annotate(string.format("reset time by %0.4f", touchTimeTick - currentRunStartTick))
		currentRunStartTick = touchTimeTick
		clientTouchDebounce[pn] = false
		dynamicRunning.resetDynamicTiming(touchTimeTick)
		return
	end

	------END RACE-------------
	--locally calculated actual racing time.
	local gapTick = touchTimeTick - currentRunStartTick

	local floorSeen = #inputSeenTerrainTypes
	annotate(string.format("telling server user finished %s %s in %0.3f", currentRunSignName, sign.Name, gapTick))
	dynamicRunning.endDynamic()
	clientControlledRunEndEvent:FireServer(currentRunSignName, sign.Name, math.floor(gapTick * 1000), floorSeen)
	currentRunSignName = ""
	currentRunStartTick = 0
	runShouldEndSemaphore = true
	--set this to debounce new run starts immediately.
	lastRunCompleteTime = tick()
	tellLocalMovementToRestore()
	clientTouchDebounce[pn] = false
end

local function setupCharacter()
	annotate("localtimer init start CA")
	canDoAnything = true

	local character: Model = localPlayer.Character
	local humanoid: Humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid

	humanoid.Died:Connect(function()
		warper.blockWarping("died")
	end)

	humanoid.Touched:Connect(function(hit)
		if hit.ClassName == "Terrain" then
			return
		end
		if hit.ClassName == "SpawnLocation" then
			return
		end
		if hit.ClassName == "Part" or hit.ClassName == "MeshPart" or hit.ClassName == "UnionOperation" then
			local signId = enums.name2signId[hit.Name]
			if signId == nil then
				return
			end
			clientTouchedSign(humanoid, hit)
		end
	end)
	warper.unblockWarping("new char unblock")
end

local function init()
	--client-side setup touch listening for this player.
	--assume this sees all signs.
	annotate("localtimer init start")
	local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()

	setupCharacter()
	localPlayer.CharacterAdded:Connect(setupCharacter)
	localPlayer.CharacterRemoving:Connect(function(character)
		warper.blockWarping("char removing")
	end)

	--when the user warps, kill active runs
	warper.addCallbackToWarpStart(function()
		-- annotate("locked run due to warping")
		canDoAnything = false
		killClientRun("warping event received.")
	end)

	warper.addCallbackToWarpEnd(function()
		canDoAnything = true
	end)
	if character == nil then
		killClientRun("no char")
		error("no char")
	end

	local hum: Humanoid = character:WaitForChild("Humanoid")
	if hum == nil then
		killClientRun("no hum")
		error("no hum")
	end
	hum.Died:Connect(function()
		canDoAnything = false
		killClientRun("Died")
	end)

	local killer = remotes.getBindableEvent("KillClientRunBindableEvent")
	killer.Event:Connect(function(a: string)
		killClientRun("bindable " .. a)
	end)
end

init()
