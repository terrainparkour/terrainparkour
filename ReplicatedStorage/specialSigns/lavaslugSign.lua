--!strict

-- slugSign

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local tt = require(game.ReplicatedStorage.types.gametypes)

local specialSign = {}

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

specialSign.InformRunEnded = function()
	localPlayer.CameraMode = Enum.CameraMode.Classic
end

specialSign.InformRunStarting = function()
	localPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
end

specialSign.InformSawFloorDuringRunFrom = function(floorMaterial: Enum.Material?) end

specialSign.InformRetouch = function() end
specialSign.CanRunEnd = function(): tt.runEndExtraDataForRacing
	return {
		canRunEndNow = true,
	}
end

specialSign.GetName = function()
	return "Lavaslug"
end

local module: tt.SpecialSignInterface = specialSign
_annotate("end")
return module
