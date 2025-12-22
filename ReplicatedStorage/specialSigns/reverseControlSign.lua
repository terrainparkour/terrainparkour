--!strict

-- reverseControlSign

--

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local specialSign = {}
local tt = require(game.ReplicatedStorage.types.gametypes)

local Players = game:GetService("Players")
local _localPlayer: Player = Players.LocalPlayer

----------- GLOBALS -----------

local function _reverseControls()
	-- ContextActionService:UnbindAction("moveForwardAction")
	-- ContextActionService:UnbindAction("moveBackwardAction")
	-- ContextActionService:UnbindAction("moveLeftAction")
	-- ContextActionService:UnbindAction("moveRightAction")

	-- ContextActionService:BindAction("moveForwardAction", reverseControls, true, Enum.UserInputState.Begin)
	-- ContextActionService:BindAction("moveBackwardAction", reverseControls, true, Enum.UserInputState.Begin)
	-- ContextActionService:BindAction("moveLeftAction", reverseControls, true, Enum.UserInputState.Begin)
	-- ContextActionService:BindAction("moveRightAction", reverseControls, true, Enum.UserInputState.Begin)
	-- local input = ""
	-- local keyCode = input.KeyCode
	local _oppositeKey = ""

	-- if keyCode == Enum.KeyCode.W then
	-- 	oppositeKey = Enum.KeyCode.S
	-- elseif keyCode == Enum.KeyCode.S then
	-- 	oppositeKey = Enum.KeyCode.W
	-- elseif keyCode == Enum.KeyCode.A then
	-- 	oppositeKey = Enum.KeyCode.D
	-- elseif keyCode == Enum.KeyCode.D then
	-- 	oppositeKey = Enum.KeyCode.A
	-- else
	-- 	return
	-- end

	-- if input.UserInputState == Enum.UserInputState.Begin then
	-- 	UserInputService:SimulateKeyPress(oppositeKey)
	-- elseif input.UserInputState == Enum.UserInputState.End then
	-- 	UserInputService:SimulateKeyRelease(oppositeKey)
	-- end
end

-------------- MAIN --------------

specialSign.InformRunStarting = function()
	_annotate("init")
	_annotate("init done")
end

specialSign.InformSawFloorDuringRunFrom = function(floorMaterial: Enum.Material)
	-- Implementation here if needed
end

specialSign.InformRetouch = function() end
specialSign.CanRunEnd = function(): tt.runEndExtraDataForRacing
	return {
		canRunEndNow = true,
	}
end

specialSign.GetName = function(): string
	return "Reverse"
end

specialSign.InformRunEnded = function() end

local module: tt.SpecialSignInterface = specialSign
_annotate("end")
return module
