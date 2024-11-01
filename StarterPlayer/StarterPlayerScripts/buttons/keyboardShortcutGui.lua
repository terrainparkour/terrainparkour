--!strict

-- keyboardShortcutGui
-- client keyboard shortcut explanation UI

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)

local PlayersService = game:GetService("Players")
local localPlayer = PlayersService.LocalPlayer

module.CreateShortcutGui = function()
	local playerGui: PlayerGui = localPlayer:WaitForChild("PlayerGui")
	local existingGui: ScreenGui = playerGui:FindFirstChild("KeyboardShortcutsGui")

	if existingGui then
		existingGui.Enabled = true
		return
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.IgnoreGuiInset = true
	screenGui.Name = "KeyboardShortcutsGui"
	screenGui.ResetOnSpawn = true
	screenGui.Parent = playerGui
	screenGui.Enabled = true

	local outerKeyboardFrame = Instance.new("Frame")
	outerKeyboardFrame.Name = "KeyboardOuterFrame"
	outerKeyboardFrame.Size = UDim2.new(0.4, 0, 0.4, 0)
	outerKeyboardFrame.Position = UDim2.new(0.3, 0, 0.3, 0)
	outerKeyboardFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	outerKeyboardFrame.Parent = screenGui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.15, 0)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundColor3 = Color3.fromRGB(168, 208, 230) -- Pale blue
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(70, 70, 70) -- Dark gray text
	title.TextScaled = true
	title.Text = "Keyboard Shortcuts"
	title.Parent = outerKeyboardFrame
	title.Name = "1_KeyboardTitle"

	-- local titleCorner = Instance.new("UICorner")
	-- titleCorner.CornerRadius = UDim.new(0.2, 0)
	-- titleCorner.Parent = title
	local listLayout2 = Instance.new("UIListLayout")
	listLayout2.Padding = UDim.new(0, 0)
	listLayout2.Parent = outerKeyboardFrame
	listLayout2.SortOrder = Enum.SortOrder.Name
	listLayout2.FillDirection = Enum.FillDirection.Vertical
	listLayout2.Name = "KeyboardHH"

	local shortcuts = {
		{ key = "r", desc = "Warp to last completed run", icon = "🏃" },
		{ key = "1", desc = "Warp to last completed run", icon = "🏃" },
		{ key = "2", desc = "Warp to last sign you started a race from", icon = "🏃" },
		{ key = "h", desc = "Remove sign highlights", icon = "🚫" },
		{ key = "z", desc = "Cancel current race", icon = "🚫" },
		{ key = "x", desc = "Remove popped up UIs and notifications", icon = "🗑️" },
		{ key = "Tab", desc = "Toggle leaderboard", icon = "📊" },
	}

	local shortcutList = Instance.new("ScrollingFrame")
	shortcutList.Size = UDim2.new(1, 0, 0.7, 0)
	shortcutList.BackgroundTransparency = 0
	shortcutList.BorderSizePixel = 0
	shortcutList.ScrollBarThickness = 10
	shortcutList.VerticalScrollBarInset = Enum.ScrollBarInset.Always
	shortcutList.Parent = outerKeyboardFrame
	-- shortcutList.AutomaticSize = Enum.AutomaticSize.Y
	shortcutList.CanvasSize = UDim2.new(0, 0, 0, 40 * #shortcuts)
	shortcutList.Name = "2_KeyboardShortcutsList"

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 0)
	listLayout.Parent = shortcutList
	listLayout.Name = "KeyboardHH"

	for _, shortcut in ipairs(shortcuts) do
		local shortcutFrame = Instance.new("Frame")
		shortcutFrame.Size = UDim2.new(1, 0, 0, 40)
		shortcutFrame.BackgroundColor3 = Color3.fromRGB(184, 216, 186) -- Soft green
		shortcutFrame.BorderSizePixel = 0
		shortcutFrame.Parent = shortcutList
		shortcutFrame.Name = "KeyboardShortcutFrame_" .. shortcut.key

		-- local shortcutCorner = Instance.new("UICorner")
		-- shortcutCorner.CornerRadius = UDim.new(0.2, 0)
		-- shortcutCorner.Parent = shortcutFrame

		local keyLabel = Instance.new("TextLabel")
		keyLabel.Size = UDim2.new(0.15, 0, 0.8, 0)
		keyLabel.Position = UDim2.new(0.02, 0, 0.1, 0)
		keyLabel.BackgroundColor3 = Color3.fromRGB(241, 167, 167) -- Soft red
		keyLabel.Font = Enum.Font.GothamBold
		keyLabel.TextColor3 = Color3.fromRGB(70, 70, 70)
		keyLabel.TextScaled = true
		keyLabel.Text = shortcut.key
		keyLabel.Parent = shortcutFrame

		-- local keyCorner = Instance.new("UICorner")
		-- keyCorner.CornerRadius = UDim.new(0.3, 0)
		-- keyCorner.Parent = keyLabel

		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(0.68, 0, 0.8, 0)
		descLabel.Position = UDim2.new(0.2, 0, 0.1, 0)
		descLabel.BackgroundTransparency = 1
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextColor3 = Color3.fromRGB(70, 70, 70)
		descLabel.TextScaled = true
		descLabel.Text = shortcut.desc
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.Parent = shortcutFrame

		local iconLabel = Instance.new("TextLabel")
		iconLabel.Size = UDim2.new(0.1, 0, 0.8, 0)
		iconLabel.Position = UDim2.new(0.88, 0, 0.1, 0)
		iconLabel.BackgroundTransparency = 1
		iconLabel.Font = Enum.Font.Gotham
		iconLabel.TextColor3 = Color3.fromRGB(70, 70, 70)
		iconLabel.TextScaled = true
		iconLabel.Text = shortcut.icon
		iconLabel.Parent = shortcutFrame
	end

	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.new(1, 0, 0.15, 0)
	closeButton.BackgroundColor3 = Color3.fromRGB(241, 167, 167) -- Soft red
	closeButton.Text = "Close"
	closeButton.TextColor3 = Color3.fromRGB(70, 70, 70)
	closeButton.Font = Enum.Font.Gotham
	closeButton.TextSize = 14
	closeButton.Name = "3keyboardClose"
	closeButton.Parent = outerKeyboardFrame

	-- local closeCorner = Instance.new("UICorner")
	-- closeCorner.CornerRadius = UDim.new(0.3, 0)
	-- closeCorner.Parent = closeButton

	closeButton.MouseButton1Click:Connect(function()
		screenGui:Destroy()
	end)

	-- windows.SetupDraggability(outerKeyboardFrame)
	-- windows.SetupResizeability(outerKeyboardFrame)

	return outerKeyboardFrame
end

_annotate("end")
return module
