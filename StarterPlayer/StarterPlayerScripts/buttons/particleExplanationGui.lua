--!strict

-- particleExplanationUI
-- what each one means.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local colors = require(game.ReplicatedStorage.util.colors)
local particleEnums = require(game.StarterPlayer.StarterPlayerScripts.particleEnums)
local scrollingFrameUtils = require(game.ReplicatedStorage.gui.scrollingFrameUtils)
local standardButton = require(game.ReplicatedStorage.gui.standardButton)
local windowFunctions = require(game.StarterPlayer.StarterPlayerScripts.guis.windowFunctions)

local PlayersService = game:GetService("Players")
local localPlayer = PlayersService.LocalPlayer

module.CreateParticleGui = function()
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local existingGui = playerGui:FindFirstChild("KeyboardShortcutsGui")

	if existingGui and existingGui:IsA("ScreenGui") then
		(existingGui :: ScreenGui).Enabled = true
		return
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ParticleExplanationGui"
	screenGui.ResetOnSpawn = true
	screenGui.Parent = playerGui
	screenGui.IgnoreGuiInset = true
	screenGui.Enabled = true

	local s = windowFunctions.SetupFrame("keyboardShortcutsGui", true, true, false, true, UDim2.new(0, 200, 0, 200))
	local outerFrame = s.outerFrame
	local contentFrame = s.contentFrame

	outerFrame.Size = UDim2.new(0.4, 0, 0.4, 0)
	outerFrame.Position = UDim2.new(0.3, 0, 0.3, 0)
	outerFrame.BackgroundColor3 = colors.helpPanelBg
	outerFrame.Parent = screenGui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.15, 0)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundColor3 = colors.helpTitleBg -- Pale blue
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = colors.helpText -- Dark gray text
	title.TextScaled = true
	title.Text = "Keyboard Shortcuts"
	title.Parent = contentFrame

	local particleColorList = Instance.new("ScrollingFrame")
	particleColorList.Size = UDim2.new(0.9, 0, 0.75, 0)
	particleColorList.Position = UDim2.new(0.05, 0, 0.2, 0)
	particleColorList.BackgroundTransparency = 1
	particleColorList.BorderSizePixel = 0
	particleColorList.ScrollBarThickness = 4
	particleColorList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	particleColorList.CanvasSize = UDim2.new(0, 0, 0, 0)
	particleColorList.Parent = contentFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.Parent = particleColorList

	for _, descriptor in pairs(particleEnums.ParticleDescriptors) do
		local _shortcut = ""
		local shortcutFrame = Instance.new("Frame")
		shortcutFrame.Size = UDim2.new(1, 0, 0, 40)
		shortcutFrame.BackgroundColor3 = colors.helpRowBg -- Soft green
		shortcutFrame.BorderSizePixel = 0
		shortcutFrame.Parent = particleColorList

		local keyLabel = Instance.new("TextLabel")
		keyLabel.Size = UDim2.new(0.15, 0, 0.8, 0)
		keyLabel.Position = UDim2.new(0.02, 0, 0.1, 0)
		keyLabel.BackgroundColor3 = colors.helpKeyBg -- Soft red
		keyLabel.Font = Enum.Font.GothamBold
		keyLabel.TextColor3 = colors.helpText
		keyLabel.TextScaled = true
		keyLabel.Text = descriptor.name --TODO not right.
		keyLabel.Parent = shortcutFrame

		local keyCorner = Instance.new("UICorner")
		keyCorner.CornerRadius = UDim.new(0.3, 0)
		keyCorner.Parent = keyLabel

		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(0.68, 0, 0.8, 0)
		descLabel.Position = UDim2.new(0.2, 0, 0.1, 0)
		descLabel.BackgroundTransparency = 1
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextColor3 = colors.helpText
		descLabel.TextScaled = true
		descLabel.Text = descriptor.name --TODO not right.
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.Parent = shortcutFrame

		local iconLabel = Instance.new("TextLabel")
		iconLabel.Size = UDim2.new(0.1, 0, 0.8, 0)
		iconLabel.Position = UDim2.new(0.88, 0, 0.1, 0)
		iconLabel.BackgroundTransparency = 1
		iconLabel.Font = Enum.Font.Gotham
		iconLabel.TextColor3 = colors.helpText
		iconLabel.TextScaled = true
		iconLabel.Text = "" --TODO not right.
		iconLabel.Parent = shortcutFrame
	end

	-- Adjust the ScrollingFrame's size
	local function updateScrollingFrameSize()
		local contentSize = listLayout.AbsoluteContentSize
		particleColorList.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y)
		particleColorList.Size = UDim2.new(0.9, 0, math.min(0.75, contentSize.Y / contentFrame.AbsoluteSize.Y), 0)
	end

	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateScrollingFrameSize)
	updateScrollingFrameSize()

	local closeButton = standardButton.CreateCloseButton({
		onClick = function()
			screenGui.Enabled = false
		end,
		size = UDim2.new(0.3, 0, 0.08, 0),
		parent = contentFrame,
	})
	closeButton.Position = UDim2.new(0.35, 0, 0.9, 0)

	-- Prevent camera scroll when hovering over particle explanation scrolling frame
	scrollingFrameUtils.PreventCameraScrollOnHover(particleColorList)

	return outerFrame
end

_annotate("end")
return module
