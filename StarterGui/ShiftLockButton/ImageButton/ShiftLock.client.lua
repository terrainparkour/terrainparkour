--!strict

-- shiftLock.client.lua
-- This script manages the Shift Lock functionality for PC and mobile users
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

if script.Parent.ClassName == "Folder" then
	return
end
_annotate("Doing shiftlock setup")

local states: { [boolean]: string } = {
	[true] = "rbxasset://textures/ui/mouseLock_off@2x.png",
	[false] = "rbxasset://textures/ui/mouseLock_on@2x.png",
}
local ContextActionService = game:GetService("ContextActionService")


local LocalPlayer = Players.LocalPlayer
local button = script.Parent

local isShiftLocked = false
local character, humanoid, root

-- Configuration
local CONFIG = {
	CAMERA_OFFSET = CFrame.new(1.7, 0, 0),
	CAMERA_OFFSET_INVERSE = CFrame.new(-1.7, 0, 0),
	BUTTON_IMAGE_ON = "rbxasset://textures/ui/mouseLock_on@2x.png",
	BUTTON_IMAGE_OFF = "rbxasset://textures/ui/mouseLock_off@2x.png",
}

local function updateCharacterReferences()
	character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	humanoid = character:WaitForChild("Humanoid")
	root = character:WaitForChild("HumanoidRootPart")
end

local function enableShiftLock()
	humanoid.AutoRotate = false
	workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame * CONFIG.CAMERA_OFFSET
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	button.Image = CONFIG.BUTTON_IMAGE_ON
end

local function disableShiftLock()
	humanoid.AutoRotate = true
	workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame * CONFIG.CAMERA_OFFSET_INVERSE
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	button.Image = CONFIG.BUTTON_IMAGE_OFF
end

local function updateShiftLock()
	if isShiftLocked then
		RunService:BindToRenderStep("ShiftLock", Enum.RenderPriority.Character.Value, function()
			if root and humanoid then
				local _, y = workspace.CurrentCamera.CFrame.Rotation:ToEulerAnglesYXZ()
				root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, y, 0)
			end
		end)
		enableShiftLock()
	else
		RunService:UnbindFromRenderStep("ShiftLock")
		disableShiftLock()
	end
end

local function onShiftLockToggled()
	isShiftLocked = not isShiftLocked
	updateShiftLock()
	LocalPlayer:SetAttribute("ShiftLockEnabled", isShiftLocked)
end

local function setupShiftLock()
	updateCharacterReferences()
	
	if UserInputService.TouchEnabled then
		button.Visible = true
		button.MouseButton1Click:Connect(onShiftLockToggled)
	else
		button.Visible = false
		UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
			if not gameProcessedEvent and input.KeyCode == Enum.KeyCode.LeftShift then
				onShiftLockToggled()
			end
		end)
	end
end

LocalPlayer.CharacterAdded:Connect(function()
	updateCharacterReferences()
	updateShiftLock()
end)

setupShiftLock()
