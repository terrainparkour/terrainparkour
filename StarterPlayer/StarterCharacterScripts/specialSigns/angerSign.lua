--!strict

-- angerSign

--[[
about signs in general:
https://github.com/terrainparkour/terrainparkour/blob/master/StarterPlayer/StarterCharacterScripts/specialSigns/pulseSign.lua this is fairly simple.

When the player touches the sign for the first time, .Init() is called. In this case it does nothing.

If the player steps on a new floor, SawFloor is called. And then when the run ends (either player dies, cancels, completes it, quits etc) then .Kill() will be called to clean up. The next time they start a run from this sign, the same process will occur, so the methods have to clean up after themselves.

This sign uses more things. runProgressSgui is a singleton which controls the active running sign gui (in the lower left)
You can send extra strings to it to display more information.
Obviously I want to be able to do more there, not just text but full UIs etc.
]]

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local warper = require(game.StarterPlayer.StarterPlayerScripts.warper)
local runProgressSgui = require(game.ReplicatedStorage.gui.runProgressSgui)
local movementEnums = require(game.StarterPlayer.StarterPlayerScripts.movementEnums)
local Players = game:GetService("Players")
local localPlayer: Player = Players.LocalPlayer
local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid

----------- GLOBALS -----------

local runOver = true
local brokenOut = true
local originalTexture
local lastTerrain: Enum.Material? = nil

-------------- MAIN --------------
module.Kill = function()
	--_annotate("killing")
	humanoid.Health = 100
	local head = character:FindFirstChild("Head")
	if head then
		local face: Decal = head:FindFirstChild("face") :: Decal
		if originalTexture and face and face:IsA("Decal") then
			face.Texture = originalTexture
		end
	end
	if not runOver then
		runOver = true
	end
	brokenOut = false
	lastTerrain = nil

	--_annotate("killed")
end

local startDescriptionLoopingUpdate = function()
	runOver = false
	runProgressSgui.UpdateExtraRaceDescription("-40 if you hit a new terrain.")
	task.spawn(function()
		--_annotate("spawning")
		local lastHealthText = ""
		while true do
			if runOver then
				brokenOut = true
				break
			end
			local terrainText = lastTerrain and lastTerrain.Name or ""
			if terrainText ~= "" then
				terrainText = string.format(" On: %s", terrainText)
			end
			local healthText = string.format("\nYour health is: %d%s", humanoid.Health, terrainText)
			if healthText ~= lastHealthText then
				lastHealthText = healthText
				local ok1 = runProgressSgui.UpdateMovementDetails(healthText)
				if not ok1 then
					runOver = true
					brokenOut = true
					break
				end
			end
			wait(0.05)
			--_annotate("update text tight loop.")
		end
		--_annotate("update text tight loop. done")
	end)
end

module.Init = function()
	--_annotate("init")
	character = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	if not brokenOut then
		runOver = true
		while not brokenOut do
			--_annotate("wait breakout")
			wait(0.1)
		end
	end

	local head = character:FindFirstChild("Head")
	if head then
		local face: Decal = head:FindFirstChild("face") :: Decal
		if face and face:IsA("Decal") then
			--_annotate("face found")
			originalTexture = face.Texture
			face.Texture = "rbxassetid://26618794" -- Angry face texture
		end
	end

	runProgressSgui.UpdateExtraRaceDescription("You take 40 damage from switching terrain!")
	lastTerrain = nil
	humanoid.Health = 100
	startDescriptionLoopingUpdate()
end

module.SawFloor = function(floorMaterial: Enum.Material?)
	if not floorMaterial then
		return
	end
	if not movementEnums.EnumIsTerrain(floorMaterial) then
		return
	end
	if floorMaterial ~= lastTerrain then
		--_annotate("floorMaterial ~= lastFloor so taking damage.")
		lastTerrain = floorMaterial

		if humanoid.Health <= 40 then
			local signId = tpUtil.signName2SignId("🗯")
			humanoid.Health = 100
			warper.WarpToSign(signId)
			humanoid.Health = 100
			return
		end
		humanoid.Health -= 40
		local theText = string.format(
			"Ouch, you touched: %s so took 40 damage. Your health is: %d",
			floorMaterial.Name,
			humanoid.Health
		)
		runProgressSgui.UpdateMovementDetails(theText)
		--_annotate("damage taken")
	end
end

_annotate("end")
return module
