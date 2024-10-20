--!strict

-- angerSign

--[[
about signs in general:
https://github.com/terrainparkour/terrainparkour/blob/master/StarterPlayer/StarterCharacterScripts/specialSigns/pulseSign.lua this is fairly simple.

When the player touches the sign for the first time, .Init() is called. In this case it does nothing.

If the player steps on a new floor, SawFloor is called. And then when the run ends (either player dies, cancels, completes it, quits etc) then .Kill() will be called to clean up. The next time they start a run from this sign, the same process will occur, so the methods have to clean up after themselves.

This sign uses more things. activeRunSGui is a singleton which controls the active running sign gui (in the lower left)
You can send extra strings to it to display more information.
Obviously I want to be able to do more there, not just text but full UIs etc.
]]

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local specialSign = {}
local tt = require(game.ReplicatedStorage.types.gametypes)

local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local warper = require(game.StarterPlayer.StarterPlayerScripts.warper)
local activeRunSGui = require(game.ReplicatedStorage.gui.activeRunSGui)
local movementEnums = require(game.StarterPlayer.StarterPlayerScripts.movementEnums)
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local localPlayer: Player = Players.LocalPlayer
local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid

----------- GLOBALS -----------
-- local signId = tpUtil.signName2SignId("🗯")
local originalTexture
local lastTerrain: Enum.Material? = nil
local loopRunning = false
local killLoop = false

-------------- MAIN --------------
specialSign.InformRunEnded = function()
	_annotate("telling sign the run ended.")
	if loopRunning then
		killLoop = true
	end
	task.spawn(function()
		while loopRunning do
			_annotate("wait loop die.")
			task.wait(0.1)
		end

		humanoid.Health = 100
		local head = character:FindFirstChild("Head")
		if head then
			local face: Decal = head:FindFirstChild("face") :: Decal
			if originalTexture and face and face:IsA("Decal") then
				face.Texture = originalTexture
			end
		end

		lastTerrain = nil
		_annotate("-------------ENDED----------------")
	end)
end

local startDescriptionLoopingUpdate = function()
	activeRunSGui.UpdateExtraRaceDescription("-40 if you hit a new terrain.")
	task.spawn(function()
		_annotate("spawning desc updater.")
		local lastHealthText = ""
		loopRunning = true
		while true do
			if killLoop then
				loopRunning = false
				killLoop = false
				break
			end
			local terrainText = lastTerrain and lastTerrain.Name or ""
			if terrainText ~= "" then
				terrainText = string.format(" On: %s", terrainText)
			end
			local healthText = string.format("\nYour health is: %d%s", humanoid.Health, terrainText)
			if healthText ~= lastHealthText then
				lastHealthText = healthText
				local ok1 = activeRunSGui.UpdateMovementDetails(healthText)
				if not ok1 then
					specialSign.InformRunEnded()
					loopRunning = false
					killLoop = false
					break
				end
			end
			wait(1 / 30)
		end
		_annotate("update text tight loop. done")
	end)
end

specialSign.InformRunStarting = function()
	_annotate("init")
	character = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
	humanoid = character:WaitForChild("Humanoid") :: Humanoid

	local head = character:FindFirstChild("Head")
	if head then
		local face: Decal = head:FindFirstChild("face") :: Decal
		if face and face:IsA("Decal") then
			_annotate("face found")
			originalTexture = face.Texture
			face.Texture = "rbxassetid://26618794" -- Angry face texture
		end
	end

	activeRunSGui.UpdateExtraRaceDescription("You take 40 damage from switching terrain!")
	lastTerrain = nil
	humanoid.Health = 100
	assert(not loopRunning, "loop running?")
	startDescriptionLoopingUpdate()
	assert(loopRunning, "loop running?")
	assert(not killLoop, "killLoop running?")
end

specialSign.InformSawFloorDuringRunFrom = function(floorMaterial: Enum.Material?)
	if not floorMaterial then
		return
	end
	if not movementEnums.EnumIsTerrain(floorMaterial) then
		return
	end
	if floorMaterial ~= lastTerrain then
		_annotate("floorMaterial ~= lastFloor so taking damage.")
		lastTerrain = floorMaterial

		if humanoid.Health <= 40 then
			local signId = tpUtil.signName2SignId("🗯")
			humanoid.Health = 100
			specialSign.InformRunEnded()
			warper.WarpToSignId(signId)
			humanoid.Health = 100
			return
		end
		humanoid.Health -= 40
		local theText = string.format(
			"Ouch, you touched: %s so took 40 damage. Your health is: %d",
			floorMaterial.Name,
			humanoid.Health
		)
		activeRunSGui.UpdateMovementDetails(theText)
		_annotate("damage taken")
	end
end

specialSign.InformRetouch = function() end

specialSign.CanRunEnd = function(): tt.runEndExtraDataForRacing
	return {
		canRunEndNow = true,
	}
end

specialSign.GetName = function()
	return "🗯"
end

local module: tt.SpecialSignInterface = specialSign

_annotate("end")
return module
