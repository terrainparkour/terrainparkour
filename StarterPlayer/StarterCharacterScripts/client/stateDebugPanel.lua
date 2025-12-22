--!strict

-- stateDebugPanel.lua - scs.client
-- Persistent debug HUD that surfaces key racing state variables.

local Players = game:GetService("Players")

local module = {}

local localPlayer: Player = Players.LocalPlayer
local playerGui: PlayerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

local GUI_NAME = "StateDebugPanel"

local function createGui(): (ScreenGui, Frame)
	local existing = playerGui:FindFirstChild(GUI_NAME)
	if existing and existing:IsA("ScreenGui") then
		existing:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = GUI_NAME
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 9999
	screenGui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	panel.Size = UDim2.new(0.2, 0, 0.4, 0)
	panel.Position = UDim2.new(0, 0, 0.2, 0)
	panel.Parent = screenGui

	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = Color3.fromRGB(255, 255, 255)
	uiStroke.Thickness = 1
	uiStroke.Transparency = 0.75
	uiStroke.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Parent = panel

	return screenGui, panel
end

local _screenGui, panel = createGui()
local rows: { [string]: TextLabel } = {}
local layoutOrder = 0

local function createRow(key: string): TextLabel
	layoutOrder += 1
	local rowFrame = Instance.new("Frame")
	rowFrame.Name = string.format("%sRow", key)
	rowFrame.BackgroundTransparency = 1
	rowFrame.Size = UDim2.new(1, 0, 0, 24)
	rowFrame.LayoutOrder = layoutOrder
	rowFrame.Parent = panel

	local keyLabel = Instance.new("TextLabel")
	keyLabel.Name = "Key"
	keyLabel.BackgroundTransparency = 1
	keyLabel.Size = UDim2.new(0.45, 0, 1, 0)
	keyLabel.Font = Enum.Font.SourceSans
	keyLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	keyLabel.TextXAlignment = Enum.TextXAlignment.Left
	keyLabel.TextSize = 14
	keyLabel.Text = key
	keyLabel.Parent = rowFrame

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Name = "Value"
	valueLabel.BackgroundTransparency = 1
	valueLabel.Size = UDim2.new(0.55, 0, 1, 0)
	valueLabel.Position = UDim2.new(0.45, 0, 0, 0)
	valueLabel.Font = Enum.Font.SourceSansBold
	valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Left
	valueLabel.TextSize = 14
	valueLabel.Text = "..."
	valueLabel.Parent = rowFrame

	rows[key] = valueLabel
	return valueLabel
end

function module.SetValue(key: string, value: string | number | boolean)
	local textValue = if typeof(value) == "string" then value else tostring(value)
	local label = rows[key] or createRow(key)
	label.Text = textValue
end

return module

