--!strict

-- slugSign

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local warper = require(game.StarterPlayer.StarterPlayerScripts.warper)
local activeRunSGui = require(game.ReplicatedStorage.gui.activeRunSGui)
local movementEnums = require(game.StarterPlayer.StarterPlayerScripts.movementEnums)
local Players = game:GetService("Players")
local localPlayer: Player = Players.LocalPlayer
local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid

----------- GLOBALS -----------
local signId = tpUtil.signName2SignId("🗯")
local originalTexture
local lastTerrain: Enum.Material? = nil
local loopRunning = false
local killLoop = false

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
