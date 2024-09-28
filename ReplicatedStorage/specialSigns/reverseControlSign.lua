--!strict

-- reverseControlSign

--

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
local UserInputService = game:GetService("UserInputService")

----------- GLOBALS -----------
local ContextActionService = game:GetService("ContextActionService")

local function reverseControls()
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
	local oppositeKey = ""

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
module.Kill = function() end

module.Init = function()
	_annotate("init")
	character = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	_annotate("init done")
end

module.SawFloor = function(floorMaterial: Enum.Material?) end

_annotate("end")
return module
