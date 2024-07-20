--!strict

-- 4.29.2022 redo to trust client
-- completely locally track times and then just hit the endpoint with what they are
-- What is this: the guy who does local tracking of the time for a run.

--2024 this should be more just about RUNs not about character setup.
-- and it can relate to other code via just having local bindable events
-- 2024.08 rename.
-- the function of this is to manage sign touches for the purpose of starting and ending races
-- it also relays signals on to marathon clients.

local localPlayer: Player = game.Players.LocalPlayer

---------ANNOTATION----------------
local doAnnotation = false
	or localPlayer.Name == "TerrainParkour"
	or localPlayer.Name == "Player2"
	or localPlayer.Name == "Player1"
doAnnotation = true
doAnnotation = false
local annotationStart = tick()
local annotate = function(s: string | any)
	if doAnnotation then
		if typeof(s) == "string" then
			print("raceRunner.: " .. string.format("%.0f", tick() - annotationStart) .. " : " .. s)
		else
			print("raceRunner.object. " .. string.format("%.0f", tick() - annotationStart) .. " : ")
			print(s)
		end
	end
end

local enums = require(game.ReplicatedStorage.util.enums)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local remotes = require(game.ReplicatedStorage.util.remotes)
local marathonClient = require(game.StarterPlayer.StarterCharacterScripts.marathon.marathonClient)

local dynamicRunning = require(game.ReplicatedStorage.dynamicRunning)
local signMovementEnums = require(game.ReplicatedStorage.enums.signMovementEnums)
local textUtil = require(game.ReplicatedStorage.util.textUtil)

local playerGui = localPlayer:WaitForChild("PlayerGui")
local runProgressSgui = require(game.StarterPlayer.StarterPlayerScripts.guis.runProgressSgui)

local warper = require(game.StarterPlayer.StarterPlayerScripts.util.warperClient)

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

local modeChanger = require(game.StarterPlayer.StarterPlayerScripts.modeChanger)

-- local cancelRunRemoteFunction = remotes.getRemoteFunction("CancelRunRemoteFunction")
local clientControlledRunEndEvent = remotes.getRemoteEvent("ClientControlledRunEndEvent")
local movementManipulationBindableEvent = remotes.getBindableEvent("MovementManipulationBindableEvent")

local specialMovementTypeTextForPlayer = ""
local specialMovementDetails = ""
local activeMovementData

--ordered i{} of names of terrain we've seen.
local inputSeenTerrainTypes: { [number]: Enum.Material } = {}

--one chain is warp => localTimer => this sends to localMovement3 so it finds out there was a warp.
--for some reason this gets called a bunch.
local function ResetAllMovement(reason: string)
	annotate("ResetAllMovement." .. reason)

	--Input for newMovement.
	local data: signMovementEnums.movementModeMessage =
		{ action = signMovementEnums.movementModes.RESTORE, reason = reason }
	movementManipulationBindableEvent:Fire(data)
	specialMovementTypeTextForPlayer = ""
end

--if you were tracking ground, then start a touch, you may inadvertently not send an update.  set this to force one.
local function handleSpecialSignStartTouches(signName: string)
	if signName == "Hypergravity" then
		local data: signMovementEnums.movementModeMessage =
			{ action = signMovementEnums.movementModes.NOJUMP, reason = "specialSign" }
		activeMovementData = data
		specialMovementTypeTextForPlayer = "No Jump"
		movementManipulationBindableEvent:Fire(data)
	elseif signName == "Bolt" then
		local data: signMovementEnums.movementModeMessage =
			{ action = signMovementEnums.movementModes.FASTER, reason = "specialSign" }
		activeMovementData = data
		specialMovementTypeTextForPlayer = "Fast"
		movementManipulationBindableEvent:Fire(data)
	elseif signName == "Triple" then
		local data: signMovementEnums.movementModeMessage =
			{ action = signMovementEnums.movementModes.THREETERRAIN, reason = "specialSign" }
		activeMovementData = data
		specialMovementTypeTextForPlayer = "Limited to 3 terrain types:"
		movementManipulationBindableEvent:Fire(data)
	elseif signName == "cOld mOld on a sLate pLate" then
		local data: signMovementEnums.movementModeMessage =
			{ action = signMovementEnums.movementModes.COLD_MOLD, reason = "specialSign" }
		activeMovementData = data
		specialMovementTypeTextForPlayer = "Touch each terrain type only once."
		movementManipulationBindableEvent:Fire(data)
	elseif signName == "Quadruple" then
		local data: signMovementEnums.movementModeMessage =
			{ action = signMovementEnums.movementModes.FOURTERRAIN, reason = "specialSign" }
		activeMovementData = data
		specialMovementTypeTextForPlayer = "Limited to 4 terrain types:"
		movementManipulationBindableEvent:Fire(data)
	elseif signName == "Fosbury" then
		local data: signMovementEnums.movementModeMessage =
			{ action = signMovementEnums.movementModes.HIGHJUMP, reason = "specialSign" }
		activeMovementData = data
		specialMovementTypeTextForPlayer = "High Jump"
		movementManipulationBindableEvent:Fire(data)
	elseif signName == "Keep Off the Grass" then
		local data: signMovementEnums.movementModeMessage =
			{ action = signMovementEnums.movementModes.NOGRASS, reason = "specialSign" }
		activeMovementData = data
		specialMovementTypeTextForPlayer = "Don't touch Grass"
		movementManipulationBindableEvent:Fire(data)
	elseif signName == "Salekhard" then
		local data: signMovementEnums.movementModeMessage =
			{ action = signMovementEnums.movementModes.SLIPPERY, reason = "specialSign" }
		activeMovementData = data
		specialMovementTypeTextForPlayer = "Slip"
		movementManipulationBindableEvent:Fire(data)
	elseif signName == "Pulse" then
		--1. complete the race to here
		--2. touch this sign conceptually (todo still)
		--3. fire the user on a large random vector.
		local data: signMovementEnums.movementModeMessage =
			{ action = signMovementEnums.movementModes.PULSED, reason = "specialSign" }
		activeMovementData = data
		specialMovementTypeTextForPlayer = "Pulse"
		movementManipulationBindableEvent:Fire(data)
	elseif signName == "Small" then
		local data: signMovementEnums.movementModeMessage =
			{ action = signMovementEnums.movementModes.SHRINK, reason = "specialSign" }
		activeMovementData = data
		specialMovementTypeTextForPlayer = "Small"
		movementManipulationBindableEvent:Fire(data)
	elseif signName == "Big" then
		local data: signMovementEnums.movementModeMessage =
			{ action = signMovementEnums.movementModes.ENLARGE, reason = "specialSign" }
		activeMovementData = data
		specialMovementTypeTextForPlayer = "Big"
		movementManipulationBindableEvent:Fire(data)
	elseif signName == "👻" then
		local data: signMovementEnums.movementModeMessage =
			{ action = signMovementEnums.movementModes.GHOST, reason = "specialSign" }
		activeMovementData = data
		specialMovementTypeTextForPlayer = "Ghost"
		movementManipulationBindableEvent:Fire(data)
	end
end

local function updateFloorTouchedTracking(inputSeenTerrainTypesInput: { [number]: Enum.Material })
	modeChanger.getModeChangeLock("update floor.")
	annotate("timer was told about new floor tracking.")
	inputSeenTerrainTypes = inputSeenTerrainTypesInput
	if
		activeMovementData
		and (
			activeMovementData.action == signMovementEnums.movementModes.THREETERRAIN
			or activeMovementData.action == signMovementEnums.movementModes.FOURTERRAIN
		)
	then --only calc this for display if it's a type which limits
		-- annotate("we are in one of the managed types.")
		local t = {}
		for _, k in ipairs(inputSeenTerrainTypes) do
			table.insert(t, k.Name)
		end

		specialMovementDetails = textUtil.stringJoin(", ", t)
		-- annotate("specialMovementDetails: " .. specialMovementDetails)
	end
	if activeMovementData and activeMovementData.action == signMovementEnums.movementModes.COLD_MOLD then
		local t: { [number]: string } = {}
		for ii, k in ipairs(inputSeenTerrainTypes) do
			if ii == #inputSeenTerrainTypes then
				break
			end
			table.insert(t, k.Name)
		end
		if inputSeenTerrainTypes[#inputSeenTerrainTypes].Name == "Slate" then
			specialMovementDetails = string.format("Forbidden from touching:%s", textUtil.stringJoin(", ", t))
		else
			specialMovementDetails = string.format(
				"Now: %s Forbidden from touching:%s",
				inputSeenTerrainTypes[#inputSeenTerrainTypes].Name,
				textUtil.stringJoin(", ", t)
			)
		end
	end
	modeChanger.freeModeChangeLock("update floor")
end

--based on various interactions, locally kill the run
--also tell server it's done
--also tell movement client to restore natural player movement which may have been modified by sign.
local function killClientRun(context: string)
	modeChanger.getModeChangeLock("killClientRun")
	annotate("killClientRun." .. context)
	ResetAllMovement("calling ResetAllMovement via killClientRun." .. context)
	currentRunStartTick = 0
	currentRunSignName = ""
	local sgui = playerGui:FindFirstChild("RunningRunSgui")
	if sgui ~= nil then
		sgui:Destroy()
	end
	dynamicRunning.endDynamic()
	specialMovementTypeTextForPlayer = ""
	specialMovementDetails = ""
	activeMovementData = nil
	modeChanger.freeModeChangeLock("killClientRun")
end

--what to display on the 'race active' label in LL
--this is continuously queried (while the user is in a run)
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
	if localPlayer.Character == nil or localPlayer.Character.PrimaryPart == nil or currentRunSignName == "" then
		return ""
	end

	local pos = localPlayer.Character.PrimaryPart.Position
	local distance = tpUtil.getDist(pos, currentRunStartPosition)
	local specialRaceDescriptor = ""
	if specialMovementTypeTextForPlayer ~= "" then
		specialRaceDescriptor = "\n" .. specialMovementTypeTextForPlayer
	end
	if specialMovementDetails ~= "" then
		specialRaceDescriptor = specialRaceDescriptor .. " " .. specialMovementDetails
	end

	--figure out consistent terrain speed percentage increase. Anchor this at default runspeed (68) which I v. slightly incorrectly hardcode here.
	local hum = localPlayer.Character:WaitForChild("Humanoid") :: Humanoid
	local mult = hum.WalkSpeed / 68
	local multDescriptor = "+"
	if mult < 1 then
		multDescriptor = ""
	end

	local speedupDescriptor = ""
	if mult ~= 1 then
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
		"%.1fs %s%s\nFrom: %s%s (%.1fd)",
		useRunTimeS,
		speedupDescriptor,
		specialRaceDescriptor,
		currentRunSignName,
		optionalSignAliasText,
		distance
	)

	return text
end

local function clientTouchedSign(humanoid: Humanoid, sign: BasePart)
	annotate("got touch with mode: ", modeChanger.getReason())
	if not canDoAnything then
		annotate("blocked til warp done.")
		return
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
		--debounce so they can try this method again.
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

	-----------------NEW RACE or RESTART CURRENT RACE BY TOUCHING SIGN AGAIN-----------------------------
	--NOTE we do not FIND signs from the client.-------
	if currentRunSignName == "" or currentRunSignName == sign.Name then -------START RACE
		--this tells the movement module to get ready to send me floor updates.

		--TODO what is this?

		if modeChanger.getReason() == "starting run from " .. sign.Name then
			--if the first try to start hasn't even done yet, just end.
			print(
				"NEVER GET HERE ACTUALLY IF SO INVESTIGATE AND MAKE IT SAVE AND RESEND THE MILLISECOND GAP IMPROVEMENT."
			)
			return
		end
		--this is for things we check in both cases.
		if warper.isAlreadyWarping() then
			--reset this otherwise they'll be permanently blocked from running.
			--since we return early here.
			clientTouchDebounce[pn] = false
			annotate("blocked due to iswarping.")
			modeChanger.freeModeChangeLock("starting run from " .. sign.Name)
			return false
		end

		currentRunStartTick = touchTimeTick
		if currentRunSignName == sign.Name then
			--the lock is already taken by the first time we starrted the run to here.
			--so, we just update the time
			--so really, we just have to remember that after that one is done (the actual setup one)
			--we just replay the request again and update the start time,
			--but we don't have to do all the modification stuff.
			dynamicRunning.resetDynamicTiming(touchTimeTick)
		else
			--this block is for actual new unique setup.
			modeChanger.getModeChangeLock("starting run from " .. sign.Name)
			annotate("starting.run from " .. currentRunSignName)
			--we are the real race start and have to set up everything.
			ResetAllMovement("start race.")
			currentRunSignName = sign.Name
			handleSpecialSignStartTouches(sign.Name)
			currentRunStartPosition = sign.Position
			runProgressSgui.CreateRunProgressSgui(killClientRun, playerGui)
			dynamicRunning.startDynamic(localPlayer, sign.Name, touchTimeTick)
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
						killClientRun("RunningRunSgui label was destroyed.")
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
			modeChanger.freeModeChangeLock("starting run from " .. sign.Name)
		end
		clientTouchDebounce[pn] = false
		return
	end

	---------------------------------END RACE---------------------------------------
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
	ResetAllMovement("completed run.")
	clientTouchDebounce[pn] = false
end

local function setupInputSignals()
	------------ listen to warp calls, if one happens, kll run  -----------
	local warpStartingBindableEvent = remotes.getBindableEvent("warpStartingBindableEvent")
	warpStartingBindableEvent.Event:Connect(function(msg: string)
		killClientRun("warp happened so killing run. " .. msg)
		canDoAnything = false
	end)

	local warpDoneBindableEvent = remotes.getBindableEvent("warpDoneBindableEvent")
	warpDoneBindableEvent.Event:Connect(function(msg: string)
		canDoAnything = true
	end)

	----set up my listening so that other people can kill runs-----
	local killClientRunBindableEvent = remotes.getBindableEvent("KillClientRunBindableEvent")
	killClientRunBindableEvent.Event:Connect(function(a: string)
		killClientRun("bindable " .. a)
		canDoAnything = false
	end)

	local updateTerrainSeenBindableEvent = remotes.getBindableEvent("UpdateTerrainSeenBindableEvent")
	updateTerrainSeenBindableEvent.Event:Connect(updateFloorTouchedTracking)
end

local function setupCharacter()
	local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid

	---if you die, end the run.
	humanoid.Died:Connect(function()
		killClientRun("player died so end run.")
		canDoAnything = false
	end)

	--if you hit a part or something like a sign, let's go.
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
end

local function init()
	annotate("init start")
	setupInputSignals()

	localPlayer.CharacterRemoving:Connect(function()
		local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
		-- local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		killClientRun("Char removing so end run.")
		canDoAnything = false
	end)

	localPlayer.CharacterAdded:Connect(setupCharacter)
	setupCharacter()
end

init()
