--!strict

-- smallSign

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local runProgressSgui = require(game.ReplicatedStorage.gui.runProgressSgui)

local Players = game:GetService("Players")
local localPlayer: Player = Players.LocalPlayer
local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid

----------- GLOBALS -----------
-- local originalScale = 1
-- local activeScaleMultiplerAbsolute = originalScale

-------------- MAIN --------------
module.Kill = function()
	character:ScaleTo(1)
	-- activeScaleMultiplerAbsolute = 1
end

module.Init = function()
	-- originalScale = 1
	-- activeScaleMultiplerAbsolute = originalScale
	--_annotate("Player shranken.")
	-- local newMultipler = originalScale / activeScaleMultiplerAbsolute / 2
	character = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	character:ScaleTo(1 / 2)
	-- activeScaleMultiplerAbsolute = originalScale / 2
end

module.SawFloor = function(floorMaterial: Enum.Material?) end

_annotate("end")
return module
