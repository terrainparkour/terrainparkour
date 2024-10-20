--!strict

-- smallSign

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local specialSign = {}
local tt = require(game.ReplicatedStorage.types.gametypes)

local Players = game:GetService("Players")
local localPlayer: Player = Players.LocalPlayer
local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid

----------- GLOBALS -----------

-------------- MAIN --------------
specialSign.InformRunEnded = function()
	character:ScaleTo(1)
end

specialSign.InformRunStarting = function()
	_annotate("Player shranken.")
	character = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	character:ScaleTo(1 / 2)
end

specialSign.InformSawFloorDuringRunFrom = function(floorMaterial: Enum.Material?) end
specialSign.InformRetouch = function() end

specialSign.CanRunEnd = function(): tt.runEndExtraDataForRacing
	return {
		canRunEndNow = true,
	}
end
specialSign.GetName = function()
	return "Small"
end

local module: tt.SpecialSignInterface = specialSign
_annotate("end")
return module
