--!strict

-- slugSign

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local tt = require(game.ReplicatedStorage.types.gametypes)

local specialSign = {}

local tpUtil: typeof(require(game.ReplicatedStorage.util.tpUtil)) = require(game.ReplicatedStorage.util.tpUtil)
local Players = game:GetService("Players")
local localPlayer: Player = Players.LocalPlayer

----------- GLOBALS -----------
local _signId = tpUtil.signName2SignId("🗯")

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
