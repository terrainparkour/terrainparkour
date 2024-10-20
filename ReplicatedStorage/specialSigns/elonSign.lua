--!strict

-- ElonSign

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
local HasTouchedRed = false

-------------- MAIN --------------

specialSign.InformRunEnded = function()
	localPlayer.CameraMode = Enum.CameraMode.Classic
end

specialSign.InformRunStarting = function()
	localPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
	HasTouchedRed = false
	activeRunSGui.UpdateExtraRaceDescription("You must touch Sandstone of Mars")
end

specialSign.InformSawFloorDuringRunFrom = function(floorMaterial: Enum.Material?)
	if floorMaterial == Enum.Material.Sandstone then
		activeRunSGui.UpdateExtraRaceDescription("You have touched Sandstone so you may end the race now.")
		HasTouchedRed = true
	end
end

specialSign.CanRunEnd = function(): tt.runEndExtraDataForRacing
	return {
		canRunEndNow = HasTouchedRed,
	}
end

specialSign.GetName = function()
	return "Elon"
end

specialSign.InformRetouch = function()
	HasTouchedRed = false
end

_annotate("end")

local module: tt.SpecialSignInterface = specialSign

return module
