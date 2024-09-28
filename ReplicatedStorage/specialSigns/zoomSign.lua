--!strict

-- zoomSign

--[[
about signs in general:
https://github.com/terrainparkour/terrainparkour/blob/master/StarterPlayer/StarterCharacterScripts/specialSigns/pulseSign.lua this is fairly simple.

]]

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local Players = game:GetService("Players")
local localPlayer: Player = Players.LocalPlayer
local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model

-------------- MAIN --------------
module.InformRunEnded = function()
	localPlayer.CameraMode = Enum.CameraMode.Classic
end

module.InformRunStarting = function()
	localPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
end

module.InformSawFloorDuringRunFrom = function(floorMaterial: Enum.Material?) end
module.InformRetouch = function() end

_annotate("end")
return module
