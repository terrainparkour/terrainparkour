--!strict

--

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local specialSign = {}
local tt = require(game.ReplicatedStorage.types.gametypes)
local activeRunSGui = require(game.ReplicatedStorage.gui.activeRunSGui)
local movementEnums = require(game.StarterPlayer.StarterPlayerScripts.movementEnums)

local Players = game:GetService("Players")
local localPlayer: Player = Players.LocalPlayer
local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid

---- GLOBALS ------------
local lastSeenTerrainType: Enum.Material? = nil
local changeTerrainTypeCount = 0

local reset = function()
	changeTerrainTypeCount = 0
	lastSeenTerrainType = nil
end

-------------- MAIN --------------
specialSign.InformRunEnded = function()
	reset()
end

specialSign.InformRunStarting = function()
	reset()
	activeRunSGui.UpdateExtraRaceDescription(
		string.format(
			"Your time is: actual time + 1 second per time you change terrain type touched. (+%ds)",
			changeTerrainTypeCount
		)
	)
end

specialSign.InformSawFloorDuringRunFrom = function(floorMaterial: Enum.Material?)
	if lastSeenTerrainType == floorMaterial then
		return
	end
	if not movementEnums.EnumIsTerrain(floorMaterial) then
		return
	end
	changeTerrainTypeCount += 1
	lastSeenTerrainType = floorMaterial
	activeRunSGui.UpdateExtraRaceDescription(
		string.format(
			"Your time is: actual time + 1 second per time you change terrain type touched. (+%ds)",
			changeTerrainTypeCount
		)
	)
end

specialSign.InformRetouch = function()
	reset()
	activeRunSGui.UpdateExtraRaceDescription(
		string.format(
			"Your time is: actual time + 1 second per time you change terrain type touched. (+%ds)",
			changeTerrainTypeCount
		)
	)
end

specialSign.CanRunEnd = function(): tt.runEndExtraDataForRacing
	return {
		canRunEndNow = true,
		extraTimeS = changeTerrainTypeCount,
	}
end

specialSign.GetName = function()
	return "Society"
end

local module: tt.SpecialSignInterface = specialSign

_annotate("end")
return module
