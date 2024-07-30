--!strict

-- pulseSign

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local avatarManipulation = require(game.StarterPlayer.StarterPlayerScripts.avatarManipulation)

local Players = game:GetService("Players")
local localPlayer: Player = Players.LocalPlayer
local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid

----------- GLOBALS -----------

-------------- MAIN --------------
module.Kill = function()
	avatarManipulation.SetCharacterTransparency(localPlayer, 0)
end

module.Init = function()
	character = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	avatarManipulation.SetCharacterTransparency(localPlayer, 0.9)
end

module.SawFloor = function(floorMaterial: Enum.Material?) end

_annotate("end")
return module
