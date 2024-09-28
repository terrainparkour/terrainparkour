--!strict

-- growthSign

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local tpUtil = require(game.ReplicatedStorage.util.tpUtil)

local activeRunSGui = require(game.ReplicatedStorage.gui.activeRunSGui)
local movementEnums = require(game.StarterPlayer.StarterPlayerScripts.movementEnums)
local Players = game:GetService("Players")
local localPlayer: Player = Players.LocalPlayer
local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local warper = require(game.StarterPlayer.StarterPlayerScripts.warper)
----------- GLOBALS -----------

local signId = tpUtil.signName2SignId("Cow")
local totalSizeGain = 0
local loopRunning = false
local killLoop = false

-------------- MAIN --------------
module.InformRunEnded = function()
	character:ScaleTo(1)
	if loopRunning then
		killLoop = true
	end

	task.spawn(function()
		while loopRunning do
			_annotate("wait loop die.")
			wait(0.1)
		end
		totalSizeGain = 0
		_annotate("-------------ENDED----------------")
	end)
end

local startDescriptionLoopingUpdate = function()
	activeRunSGui.UpdateExtraRaceDescription("Moo")
	task.spawn(function()
		local lastChecked = tick()
		loopRunning = true
		while true do
			_annotate("loop")
			if killLoop then
				killLoop = false
				loopRunning = false
				break
			end
			task.wait(0.1)
			local now = tick()
			local gap = now - lastChecked
			lastChecked = now
			local lastText = ""
			local mat = humanoid.FloorMaterial
			if mat == Enum.Material.LeafyGrass then
				totalSizeGain += gap * 1.1
				lastText = "mmm, grass"
			elseif mat == Enum.Material.Grass then
				totalSizeGain += gap * 0.5
				lastText = "mmm, leafy grass"
			elseif mat == Enum.Material.CrackedLava then
				lastText = "noooo, cracked lava"
				warper.WarpToSignId(signId)
				break
			elseif mat == Enum.Material.Ground then
				lastText = "ground isn't bad"
				totalSizeGain += gap
			elseif mat == Enum.Material.Sand or mat == Enum.Material.Limestone then
				lastText = "not good!"
				totalSizeGain -= gap * 1
			elseif mat == Enum.Material.Snow or mat == Enum.Material.Glass then
				lastText = "I'm freezing!"
				totalSizeGain -= gap * 3
			end

			local usingMult = 1 + totalSizeGain / 17

			if usingMult > 2.65 or usingMult < 0.31 then
				warper.WarpToSignId(signId)
				loopRunning = false
				killLoop = false
				break
			end

			_annotate(string.format("Scaling to: %0.3f", usingMult))
			character:ScaleTo(usingMult)

			local text = string.format("%0.2f size\n%s", usingMult, lastText)
			local ok1 = activeRunSGui.UpdateMovementDetails(text)
			if not ok1 then
				module.InformRunEnded()
				loopRunning = false
				killLoop = false
				break
			end
		end
		_annotate("update text tight loop. done")
	end)
end

module.InformRunStarting = function()
	_annotate("init")
	character:ScaleTo(1)
	character = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	while loopRunning do
		killLoop = true
		_annotate("wait loop die.")
		wait(0.1)
	end
	killLoop = false
	activeRunSGui.UpdateExtraRaceDescription("Moo")
	assert(not loopRunning, "loop running?")
	startDescriptionLoopingUpdate()
	assert(loopRunning, "loop running?")
	assert(not killLoop, "killLoop running?")
end

module.InformSawFloorDuringRunFrom = function(floorMaterial: Enum.Material?) end
module.InformRetouch = function() end

_annotate("end")
return module
