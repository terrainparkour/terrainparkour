--!strict

-- shiftLock.lua at StarterPlayer.StarterCharacterScripts.client
-- Creates and manages ShiftLock GUI and functionality programmatically, bypassing StarterGui entirely.
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

type Config = {
	CAMERA_OFFSET: Vector3,
	BUTTON_IMAGE_LOCKED: string,
	BUTTON_IMAGE_UNLOCKED: string,
	BUTTON_POSITION_DESKTOP: UDim2,
	BUTTON_POSITION_MOBILE: UDim2,
	BUTTON_SIZE: UDim2,
	BUTTON_ANCHOR: Vector2,
}

type Module = {
	Init: () -> (),
}

-- Module internals
local CONFIG: Config = {
	CAMERA_OFFSET = Vector3.new(1.7, 0, 0),
	BUTTON_IMAGE_LOCKED = "rbxasset://textures/ui/mouseLock_on@2x.png",
	BUTTON_IMAGE_UNLOCKED = "rbxasset://textures/ui/mouseLock_off@2x.png",
	BUTTON_POSITION_DESKTOP = UDim2.new(1, -70, 0.5, -25),
	BUTTON_POSITION_MOBILE = UDim2.new(1, -70, 0.5, 80),
	BUTTON_SIZE = UDim2.new(0, 50, 0, 50),
	BUTTON_ANCHOR = Vector2.new(1, 0.5),
}

local localPlayer: Player
local button: ImageButton
local screenGui: ScreenGui
local isShiftLocked = false
local character: Model
local humanoid: Humanoid
local root: BasePart
local isMobile = false

local function detectPlatform(): boolean
	local touchEnabled = UserInputService.TouchEnabled
	local mouseEnabled = UserInputService.MouseEnabled
	local keyboardEnabled = UserInputService.KeyboardEnabled
	if touchEnabled and not mouseEnabled and not keyboardEnabled then
		return true
	end
	if touchEnabled and mouseEnabled then
		return false
	end
	return false
end

local function createGui()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ShiftLockGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	button = Instance.new("ImageButton")
	button.Name = "ShiftLockButton"
	button.Image = CONFIG.BUTTON_IMAGE_UNLOCKED
	button.ImageTransparency = isMobile and 0 or 0.4
	button.Size = CONFIG.BUTTON_SIZE
	button.AnchorPoint = CONFIG.BUTTON_ANCHOR
	button.Position = isMobile and CONFIG.BUTTON_POSITION_MOBILE or CONFIG.BUTTON_POSITION_DESKTOP
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.Visible = isMobile
	button.Parent = screenGui

	screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
	_annotate("shift lock gui created programmatically")
end

local function updateCharacterReferences()
	character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	root = character:WaitForChild("HumanoidRootPart") :: BasePart
end

local function enableShiftLock()
	if not humanoid or not root then
		return
	end
	humanoid.AutoRotate = false
	humanoid.CameraOffset = CONFIG.CAMERA_OFFSET
	if not isMobile then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	end
	button.Image = CONFIG.BUTTON_IMAGE_LOCKED
	button.ImageTransparency = 0
	button.Visible = true
end

local function disableShiftLock()
	if not humanoid then
		return
	end
	humanoid.AutoRotate = true
	humanoid.CameraOffset = Vector3.zero
	if not isMobile then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
	button.Image = CONFIG.BUTTON_IMAGE_UNLOCKED
	button.ImageTransparency = isMobile and 0 or 0.4
	button.Visible = isMobile
end

local function updateShiftLock()
	if isShiftLocked then
		RunService:BindToRenderStep("ShiftLock", Enum.RenderPriority.Character.Value, function()
			if root and humanoid and humanoid.Health > 0 then
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
	localPlayer:SetAttribute("ShiftLockEnabled", isShiftLocked)
	_annotate(string.format("shift lock toggled: %s", tostring(isShiftLocked)))
end

local function setupShiftLock()
	updateCharacterReferences()
	button.MouseButton1Click:Connect(onShiftLockToggled)

	if not isMobile then
		UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
			if not gameProcessedEvent and input.KeyCode == Enum.KeyCode.LeftShift then
				onShiftLockToggled()
			end
		end)
	end

	disableShiftLock()
end

local function onCharacterAdded()
	updateCharacterReferences()
	if isShiftLocked then
		updateShiftLock()
	end
end

local module: Module = {
	Init = function()
		localPlayer = Players.LocalPlayer
		isMobile = detectPlatform()
		_annotate(string.format("platform detected - mobile: %s", tostring(isMobile)))
		createGui()
		setupShiftLock()
		localPlayer.CharacterAdded:Connect(onCharacterAdded)
		_annotate("shift lock module initialized")
	end,
}

_annotate("end")
return module

