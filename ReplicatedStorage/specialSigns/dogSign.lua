-- --!strict

-- -- angerSign

-- --[[
-- about signs in general:
-- https://github.com/terrainparkour/terrainparkour/blob/master/StarterPlayer/StarterCharacterScripts/specialSigns/pulseSign.lua this is fairly simple.

-- When the player touches the sign for the first time, .Init() is called. In this case it does nothing.

-- If the player steps on a new floor, SawFloor is called. And then when the run ends (either player dies, cancels, completes it, quits etc) then .Kill() will be called to clean up. The next time they start a run from this sign, the same process will occur, so the methods have to clean up after themselves.

-- This sign uses more things. activeRunSGui is a singleton which controls the active running sign gui (in the lower left)
-- You can send extra strings to it to display more information.
-- Obviously I want to be able to do more there, not just text but full UIs etc.
-- ]]

-- local annotater = require(game.ReplicatedStorage.util.annotater)
-- local _annotate = annotater.getAnnotater(script)

-- local module = {}

-- ----------- GLOBALS -----------

-- local originalTexture
-- local lastTerrain: Enum.Material? = nil
-- local loopRunning = false
-- local killLoop = false

-- local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- local PathfindingService = game:GetService("PathfindingService")
-- local Players = game:GetService("Players")

-- local dog = script.Parent
-- -- Sounds
-- local barkSound: Sound = dog:WaitForChild("BarkSound")

-- -- Emotions and characteristics
-- local emotions = { "Happy", "Sad", "Excited", "Tired" }
-- local currentEmotion = "Happy"
-- local master: Player

-- -- Dog configuration
-- local DOG_SPEED = 16
-- local JUMP_POWER = 50
-- local BARK_COOLDOWN = 5
-- local EMOTION_CHANGE_INTERVAL = 10
-- local WANDER_CHANCE = 0.2
-- local MAX_DISTANCE_TO_PLAYER = 100

-- -- Create the dog model
-- local dog = script.Parent
-- local humanoid: Humanoid = dog:WaitForChild("Humanoid")
-- local rootPart: Part = dog:WaitForChild("HumanoidRootPart")

-- -- Function to find the nearest player
-- local function findNearestPlayer()
-- 	return master
-- end

-- -- Function to make the dog bark
-- local function bark()
-- 	if not barkSound.IsPlaying then
-- 		barkSound:Play()
-- 		task.wait(BARK_COOLDOWN)
-- 	end
-- end

-- -- Function to change the dog's emotion
-- local function changeEmotion()
-- 	currentEmotion = emotions[math.random(1, #emotions)]
-- 	print("Dog's current emotion: " .. currentEmotion)
-- 	-- Here you can add visual cues or behavior changes based on the emotion
-- end

-- -- Function to make the dog wander
-- local function wander()
-- 	local wanderPoint = rootPart.Position + Vector3.new(math.random(-10, 10), 0, math.random(-10, 10))
-- 	humanoid:MoveTo(wanderPoint)
-- end

-- -- Main loop for dog behavior
-- while true do
-- 	local nearestPlayer = findNearestPlayer()

-- 	if nearestPlayer then
-- 		local character = nearestPlayer.Character
-- 		if character and character:FindFirstChild("HumanoidRootPart") then
-- 			local targetPosition = character.HumanoidRootPart.Position

-- 			-- Use PathfindingService to find a path to the player
-- 			local path = PathfindingService:CreatePath()
-- 			path:ComputeAsync(rootPart.Position, targetPosition)

-- 			if path.Status == Enum.PathStatus.Success then
-- 				local waypoints = path:GetWaypoints()

-- 				for _, waypoint in ipairs(waypoints) do
-- 					humanoid:MoveTo(waypoint.Position)

-- 					if waypoint.Action == Enum.PathWaypointAction.Jump then
-- 						humanoid.Jump = true
-- 					end

-- 					-- Check if we've reached the waypoint
-- 					local reachedWaypoint = false
-- 					while not reachedWaypoint do
-- 						if (rootPart.Position - waypoint.Position).Magnitude < 5 then
-- 							reachedWaypoint = true
-- 						end
-- 						wait(0.1)
-- 					end
-- 				end
-- 			else
-- 				-- Path not found, bark and wander
-- 				bark()
-- 				wander()
-- 			end
-- 		end
-- 	else
-- 		-- No player nearby, wander around
-- 		if math.random() < WANDER_CHANCE then
-- 			wander()
-- 		end
-- 	end

-- 	-- Change emotion periodically
-- 	if math.random() < 1 / EMOTION_CHANGE_INTERVAL then
-- 		changeEmotion()
-- 	end

-- 	wait(0.1)
-- end

-- -------------- MAIN --------------
-- module.InformRunEnded = function()
-- 	_annotate("telling sign the run ended.")
-- 	if loopRunning then
-- 		killLoop = true
-- 	end
-- 	task.spawn(function()
-- 		while loopRunning do
-- 			_annotate("wait loop die.")
-- 			wait(0.1)
-- 		end

-- 		humanoid.Health = 100
-- 		local head = character:FindFirstChild("Head")
-- 		if head then
-- 			local face: Decal = head:FindFirstChild("face") :: Decal
-- 			if originalTexture and face and face:IsA("Decal") then
-- 				face.Texture = originalTexture
-- 			end
-- 		end

-- 		lastTerrain = nil
-- 		_annotate("-------------ENDED----------------")
-- 	end)
-- end

-- local startDescriptionLoopingUpdate = function()
-- 	activeRunSGui.UpdateExtraRaceDescription("-40 if you hit a new terrain.")
-- 	task.spawn(function()
-- 		_annotate("spawning desc updater.")
-- 		local lastHealthText = ""
-- 		loopRunning = true
-- 		while true do
-- 			if killLoop then
-- 				loopRunning = false
-- 				killLoop = false
-- 				break
-- 			end
-- 			local terrainText = lastTerrain and lastTerrain.Name or ""
-- 			if terrainText ~= "" then
-- 				terrainText = string.format(" On: %s", terrainText)
-- 			end
-- 			local healthText = string.format("\nYour health is: %d%s", humanoid.Health, terrainText)
-- 			if healthText ~= lastHealthText then
-- 				lastHealthText = healthText
-- 				local ok1 = activeRunSGui.UpdateMovementDetails(healthText)
-- 				if not ok1 then
-- 					module.InformRunEnded()
-- 					loopRunning = false
-- 					killLoop = false
-- 					break
-- 				end
-- 			end
-- 			wait(1 / 30)
-- 		end
-- 		_annotate("update text tight loop. done")
-- 	end)
-- end

-- module.InformRunStarting = function()
-- 	_annotate("init")
-- 	character = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
-- 	humanoid = character:WaitForChild("Humanoid") :: Humanoid

-- 	local head = character:FindFirstChild("Head")
-- 	if head then
-- 		local face: Decal = head:FindFirstChild("face") :: Decal
-- 		if face and face:IsA("Decal") then
-- 			_annotate("face found")
-- 			originalTexture = face.Texture
-- 			face.Texture = "rbxassetid://26618794" -- Angry face texture
-- 		end
-- 	end

-- 	activeRunSGui.UpdateExtraRaceDescription("You take 40 damage from switching terrain!")
-- 	lastTerrain = nil
-- 	humanoid.Health = 100
-- 	assert(not loopRunning, "loop running?")
-- 	startDescriptionLoopingUpdate()
-- 	assert(loopRunning, "loop running?")
-- 	assert(not killLoop, "killLoop running?")
-- end

-- module.InformSawFloorDuringRunFrom = function(floorMaterial: Enum.Material?)
-- 	if not floorMaterial then
-- 		return
-- 	end
-- 	if not movementEnums.EnumIsTerrain(floorMaterial) then
-- 		return
-- 	end
-- 	if floorMaterial ~= lastTerrain then
-- 		_annotate("floorMaterial ~= lastFloor so taking damage.")
-- 		lastTerrain = floorMaterial

-- 		if humanoid.Health <= 40 then
-- 			local signId = tpUtil.signName2SignId("🗯")
-- 			humanoid.Health = 100
-- 			module.InformRunEnded()
-- 			warper.WarpToSignId(signId)
-- 			humanoid.Health = 100
-- 			return
-- 		end
-- 		humanoid.Health -= 40
-- 		local theText = string.format(
-- 			"Ouch, you touched: %s so took 40 damage. Your health is: %d",
-- 			floorMaterial.Name,
-- 			humanoid.Health
-- 		)
-- 		activeRunSGui.UpdateMovementDetails(theText)
-- 		_annotate("damage taken")
-- 	end
-- end

-- _annotate("end")
-- return module
