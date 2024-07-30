--!strict

-- bigSign

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local Players = game:GetService("Players")
local localPlayer: Player = Players.LocalPlayer
local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid

----------- GLOBALS -----------

-------------- MAIN --------------
module.Kill = function()
	character:ScaleTo(1)
end

module.Init = function()
	character = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	character:ScaleTo(2)
end

module.SawFloor = function(floorMaterial: Enum.Material?) end

_annotate("end")
return module
