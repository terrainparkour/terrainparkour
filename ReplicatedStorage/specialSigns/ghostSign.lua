--!strict

-- pulseSign

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local specialSign = {}
local tt = require(game.ReplicatedStorage.types.gametypes)

local avatarManipulation = require(game.ReplicatedStorage.avatarManipulation)

local Players = game:GetService("Players")
local localPlayer: Player = Players.LocalPlayer
local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid

----------- GLOBALS -----------

-------------- MAIN --------------
specialSign.InformRunEnded = function()
	_annotate("ghostSign.Kill")
	avatarManipulation.SetCharacterTransparency(localPlayer, 0)
end

specialSign.InformRunStarting = function()
	_annotate("ghostSign.Init")
	character = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	avatarManipulation.SetCharacterTransparency(localPlayer, 0.9)
end

specialSign.InformRetouch = function() end

specialSign.InformSawFloorDuringRunFrom = function(floorMaterial: Enum.Material?)
	-- avatarManipulation.SetCharacterTransparency(localPlayer, 0)
end

specialSign.CanRunEnd = function(): tt.runEndExtraDataForRacing
	return {
		canRunEndNow = true,
	}
end

specialSign.GetName = function()
	return "Ghost"
end

local module: tt.ScriptInterface = specialSign
_annotate("end")
return module
