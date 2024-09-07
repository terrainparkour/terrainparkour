--!strict

-- the overlay for the current speed, source of run, details etc during a run.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local movementEnums = require(game.StarterPlayer.StarterPlayerScripts.movementEnums)
local colors = require(game.ReplicatedStorage.util.colors)
local Players = game:GetService("Players")

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

	speedIncreaseLabel = Instance.new("TextLabel")

	speedIncreaseLabel.TextScaled = true
	speedIncreaseLabel.Name = "3SpeedIncreaseLabel"
	speedIncreaseLabel.TextScaled = true
	speedIncreaseLabel.TextColor3 = colors.meColor
	speedIncreaseLabel.Font = Enum.Font.Gotham
	speedIncreaseLabel.Size = UDim2.new(0.5, 0, 1, 0)
	speedIncreaseLabel.BackgroundTransparency = speedGuiTransparency
	speedIncreaseLabel.BorderSizePixel = 0
	speedIncreaseLabel.FontFace = Font.new("rbxasset://fonts/families/DenkOne.json")
	speedIncreaseLabel.Text = ""
	speedIncreaseLabel.BackgroundColor3 = colors.black
	speedIncreaseLabel.TextXAlignment = Enum.TextXAlignment.Left
	speedIncreaseLabel.Parent = speedFrame

	speedLabel = Instance.new("TextLabel")
	speedLabel.TextScaled = true
	speedLabel.Name = "2SpeedLabel"
	-- speedLabel.Font = Enum.Font.Gotham
	speedLabel.FontFace = Font.new("rbxasset://fonts/families/DenkOne.json")
	speedLabel.Size = UDim2.new(0.5, 0, 1, 0)
	speedLabel.TextColor3 = colors.meColor
	speedLabel.BackgroundTransparency = speedGuiTransparency
	speedLabel.Text = ""
	speedLabel.BackgroundColor3 = colors.black
	speedLabel.TextXAlignment = Enum.TextXAlignment.Left
	speedLabel.Parent = speedFrame

	jumpLabel = Instance.new("TextLabel")
	jumpLabel.Name = "3JumpLabel"
	jumpLabel.TextScaled = true
	jumpLabel.TextColor3 = colors.meColor
	jumpLabel.Font = Enum.Font.Gotham
	jumpLabel.Size = UDim2.new(0.26, 0, 1, 0)
	jumpLabel.BackgroundTransparency = speedGuiTransparency
	jumpLabel.BorderSizePixel = 0
	jumpLabel.Text = ""
	jumpLabel.BackgroundColor3 = colors.black
	jumpLabel.FontFace = Font.new("rbxasset://fonts/families/DenkOne.json")
	jumpLabel.TextXAlignment = Enum.TextXAlignment.Center
	jumpLabel.Parent = speedFrame
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
