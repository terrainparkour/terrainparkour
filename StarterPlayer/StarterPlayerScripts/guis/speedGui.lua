--!strict

-- the overlay for the current speed, source of run, details etc during a run.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local movementEnums = require(game.StarterPlayer.StarterPlayerScripts.movementEnums)
local colors = require(game.ReplicatedStorage.util.colors)
local Players = game:GetService("Players")

-- Use guiUtil for UI creation
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)

--------------- GLOBAL PLAYER --------------
local localPlayer: Player = Players.LocalPlayer
local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid

-- just the speed and jump updater text.
local lastSpeedTextUpdated = ""
local lastJumpPowerTextUpdated = ""

------------------------ UTILS -----------------------

local jumpLabel: TextLabel
local speedLabel: TextLabel
local speedIncreaseLabel: TextLabel
local speedGuiTransparency = 0.7

-- just create one time per character load.
module.CreateSpeedGui = function()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local speedSgui: ScreenGui = playerGui:FindFirstChild("SpeedGui") :: ScreenGui
	if not speedSgui then
		speedSgui = Instance.new("ScreenGui") :: ScreenGui
		if speedSgui == nil then
			_annotate("xwef")
			return
		end
		speedSgui.Parent = playerGui
		speedSgui.Name = "SpeedGui"
		speedSgui.Enabled = true
	end
	local speedFrame = Instance.new("Frame")
	speedFrame.Parent = speedSgui
	speedFrame.Name = "SpeedFrame"
	speedFrame.Size = UDim2.new(0.5, 0, 0.08, 0)
	speedFrame.Position = UDim2.new(0.30, 0, 0.91, 0)
	speedFrame.BackgroundTransparency = 1
	speedFrame.BorderSizePixel = 2
	speedFrame.BorderColor3 = colors.meColor
	speedFrame.BorderMode = Enum.BorderMode.Inset
	local vv = Instance.new("UIListLayout")
	vv.Parent = speedFrame
	vv.Name = "SpeedFrameLayout"
	vv.FillDirection = Enum.FillDirection.Horizontal
	vv.VerticalAlignment = Enum.VerticalAlignment.Top
	vv.HorizontalAlignment = Enum.HorizontalAlignment.Left
	vv.SortOrder = Enum.SortOrder.Name

	speedIncreaseLabel = guiUtil.getTl(
		"3SpeedIncreaseLabel",
		UDim2.new(0.5, 0, 1, 0),
		0, -- padding
		speedFrame,
		colors.black,
		0, -- borderSizePixel
		speedGuiTransparency -- transparency
	)
	speedIncreaseLabel.TextColor3 = colors.meColor
	speedIncreaseLabel.FontFace = Font.new("rbxasset://fonts/families/Arimo.json")
	speedIncreaseLabel.TextXAlignment = Enum.TextXAlignment.Left

	speedLabel = guiUtil.getTl(
		"2SpeedLabel",
		UDim2.new(0.5, 0, 1, 0),
		0, -- padding
		speedFrame,
		colors.black,
		0, -- borderSizePixel
		speedGuiTransparency -- transparency
	)
	speedLabel.TextColor3 = colors.meColor
	speedLabel.FontFace = Font.new("rbxasset://fonts/families/Arimo.json")
	speedLabel.TextXAlignment = Enum.TextXAlignment.Left

	jumpLabel = guiUtil.getTl(
		"3JumpLabel",
		UDim2.new(0.26, 0, 1, 0),
		0, -- padding
		speedFrame,
		colors.black,
		0, -- borderSizePixel
		speedGuiTransparency -- transparency
	)
	jumpLabel.TextColor3 = colors.meColor
	jumpLabel.FontFace = Font.new("rbxasset://fonts/families/Arimo.json")
	jumpLabel.TextXAlignment = Enum.TextXAlignment.Center
	jumpLabel.Visible = false
end

module.AdjustSpeedGui = function(speed: number, jumpPower: number)
	local speedText = string.format("%0.1f", speed)
	local jumpText = string.format("%d", jumpPower)
	if speedText ~= lastSpeedTextUpdated or jumpText ~= lastJumpPowerTextUpdated then
		jumpLabel.Text = jumpText
		lastSpeedTextUpdated = speedText
		lastJumpPowerTextUpdated = jumpText

		speedLabel.Text = speedText
		jumpLabel.Text = jumpText

		-- the part that says like "+X%"
		local mult = humanoid.WalkSpeed / movementEnums.constants.globalDefaultRunSpeed
		if mult ~= 1 then
			local multOptionalPlusText = "+"
			if mult < 1 then
				multOptionalPlusText = ""
			end
			local gain = (mult - 1) * 100
			speedIncreaseLabel.Text = string.format("%s%0.1f%%", multOptionalPlusText, gain)
			speedIncreaseLabel.Visible = true
			speedIncreaseLabel.BackgroundTransparency = speedGuiTransparency
		else
			speedIncreaseLabel.Text = ""
			speedIncreaseLabel.BackgroundTransparency = 1
		end
	end

	--additional stuff to clearly highlight speedups, breaking certain speeds etc change the sound, appearance etc slightly.
end

_annotate("end")
return module
