--!strict

-- firstPersonSign

--[[
about signs in general:
https://github.com/terrainparkour/terrainparkour/blob/master/StarterPlayer/StarterCharacterScripts/specialSigns/pulseSign.lua this is fairly simple.

]]

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local specialSign = {}
local tt = require(game.ReplicatedStorage.types.gametypes)

local Players = game:GetService("Players")
local localPlayer: Player = Players.LocalPlayer

----------- GLOBALS -----------
-------------- MAIN --------------
specialSign.InformRunEnded = function()
	localPlayer.CameraMode = Enum.CameraMode.Classic
end

specialSign.InformRunStarting = function()
	localPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
end
specialSign.InformRetouch = function() end

specialSign.InformSawFloorDuringRunFrom = function(floorMaterial: Enum.Material?) end

specialSign.CanRunEnd = function(): tt.runEndExtraDataForRacing
	return {
		canRunEndNow = true,
	}
end

specialSign.GetName = function()
	return "FPS"
end

local module: tt.SpecialSignInterface = specialSign
_annotate("end")
return module
