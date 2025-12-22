--!strict

-- ElonSign

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local tt = require(game.ReplicatedStorage.types.gametypes)

local specialSign = {}

local activeRunSGui = require(game.ReplicatedStorage.gui.activeRunSGui)
local Players = game:GetService("Players")
local localPlayer: Player = Players.LocalPlayer
local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model

----------- GLOBALS -----------
local HasTouchedRed = false

local DESCRIPTION_NEED_SANDSTONE = "You must touch Sandstone of Mars to complete your run."
local DESCRIPTION_TOUCHED_SANDSTONE = "You have touched Sandstone so you may end the run now."

-------------- MAIN --------------

specialSign.InformRunEnded = function()
	localPlayer.CameraMode = Enum.CameraMode.Classic
end

specialSign.InformRunStarting = function()
	localPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
	HasTouchedRed = false
	activeRunSGui.UpdateExtraRaceDescription(DESCRIPTION_NEED_SANDSTONE)
end

specialSign.InformSawFloorDuringRunFrom = function(floorMaterial: Enum.Material?)
	if floorMaterial == Enum.Material.Sandstone then
		activeRunSGui.UpdateExtraRaceDescription(DESCRIPTION_TOUCHED_SANDSTONE)
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
	-- Re-set description after RestartRun clears it
	activeRunSGui.UpdateExtraRaceDescription(DESCRIPTION_NEED_SANDSTONE)
end

_annotate("end")

local module: tt.SpecialSignInterface = specialSign

return module
