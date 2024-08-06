--!strict

--warning: 2022.10 sometimes needs to be loaded late for some reason.
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local textHighlighting = require(game.ReplicatedStorage.gui.textHighlighting)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local colors = require(game.ReplicatedStorage.util.colors)

local textUtil = require(game.ReplicatedStorage.util.textUtil)
local Players = game:GetService("Players")
local localPlayer: Player = Players.LocalPlayer
------------------ SETUP ------------------
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid: Humanoid = character:WaitForChild("Humanoid") :: Humanoid

local module = {}

module.enum = {}
module.enum.toolTipSize = {}
module.enum.toolTipSize.NormalText = UDim2.new(0, 350, 0, 80)
module.enum.toolTipSize.BigPane = UDim2.new(0, 450, 0, 320)

local ephemeralToolTipFrameName = "EphemeralTooltip"

local tooltipAge = 0

local function DestroyToolTips(killYoungerThan: number?)
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local ttgui = playerGui:FindFirstChild("ToolTipGui")
	if not ttgui then
		return
	end
	for _, el in ipairs(ttgui:GetChildren()) do
		if not el.Name == ephemeralToolTipFrameName then
			continue
		end

		if killYoungerThan ~= nil then
			local ageValue: NumberValue = el:FindFirstChild("AgeValue")
			if ageValue and ageValue:IsA("NumberValue") then
				if ageValue.Value < killYoungerThan then
					for _, el2 in ipairs(el:GetChildren()) do
						el2:Destroy()
					end
					el:Destroy()
				end
			end
		else
			for _, el2 in ipairs(el:GetChildren()) do
				el2:Destroy()
			end
			el:Destroy()
		end
	end
end

module.KillFinalTooltip = function()
	DestroyToolTips(1000000)
end

local function getMouseoverableButton(signName: string)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 100, 0, 30)
	button.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
	button.BorderSizePixel = 2
	button.BorderColor3 = Color3.fromRGB(100, 100, 100)
	button.Text = ""

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = signName
	textLabel.TextScaled = true
	textLabel.Parent = button
	local t = signName
	button.MouseEnter:Connect(function()
		if string.find(t, " %(") then
			t = textUtil.stringSplit(t, " (")[1]
		end
		t = t:match("^%s*(.-)%s*$")

		local signStatusSgui: ScreenGui = localPlayer.PlayerGui:FindFirstChild("SignStatusSgui")
		if signStatusSgui then
			local theBadFrame: Frame = signStatusSgui:FindFirstChild("SignStatusUIFrame")
			if theBadFrame then
				theBadFrame.Visible = false
			end
		end
		local signId: number = tpUtil.signName2SignId(t)
		textHighlighting.KillAllExistingHighlights()
		textHighlighting.DoHighlightSingleSignId(signId)
		textHighlighting.RotateCameraToFaceSignId(signId)
		textHighlighting.PointPlayerAtSignId(signId)
	end)

	return button
end

--right=they float right+down rather than left+down from cursor. default is right.
module.setupToolTip = function(
	target: TextLabel | TextButton | ImageLabel | Frame,
	tooltipContents: string | ImageLabel | { string }, --when its a {string} we make a grid of insane mouseover sign names which highlight.
	size: UDim2,
	right: boolean?, --this refers to where the draws itself related to the mouse (i.e. default is the tooltip falls down to the lower right from the mouse, but if this is false, its to the lower left. )
	xalignment: any?, --this refers to the text
	alongBottom: boolean?,
	frame: Frame?
)
	if tooltipContents == nil or tooltipContents == "" then
		return
	end

	if xalignment == nil then
		xalignment = Enum.TextXAlignment.Center
	end
	if right == nil then
		right = true
	end
	assert(tooltipContents)
	local mouse: Mouse = localPlayer:GetMouse()

	local myAge = 0

	target.MouseEnter:Connect(function()
		tooltipAge += 1
		myAge = tooltipAge
		-- reuse the ttgui
		local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
		local ttgui = playerGui:FindFirstChild("ToolTipGui")
		if ttgui == nil then
			ttgui = Instance.new("ScreenGui")
			ttgui.Parent = playerGui
			ttgui.Name = "ToolTipGui"
			ttgui.Enabled = true
		end
		local tooltipFrame = Instance.new("Frame")
		tooltipFrame.Size = size
		tooltipFrame.Name = ephemeralToolTipFrameName
		tooltipFrame.Parent = ttgui

		local numberValue = Instance.new("NumberValue")
		numberValue.Name = "AgeValue"
		numberValue.Value = myAge
		numberValue.Parent = tooltipFrame

		if typeof(tooltipContents) == "string" then
			local tl = guiUtil.getTl("theTl", UDim2.new(1, 0, 1, 0), 2, tooltipFrame, colors.defaultGrey, 1)
			tl.Text = tooltipContents
			tl.TextScaled = true
			tl.Font = Enum.Font.Gotham
			tl.TextXAlignment = xalignment
			tl.TextYAlignment = Enum.TextYAlignment.Top
		elseif typeof(tooltipContents) == "table" then
			local listLayout = Instance.new("UIListLayout")
			listLayout.Wraps = true
			listLayout.Parent = tooltipFrame
			listLayout.FillDirection = Enum.FillDirection.Horizontal
			listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
			listLayout.SortOrder = Enum.SortOrder.LayoutOrder
			listLayout.Parent = tooltipFrame
			listLayout.FillDirection = Enum.FillDirection.Vertical
			listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
			listLayout.Padding = UDim.new(0, 5)

			for _, signName in ipairs(tooltipContents) do
				local button = getMouseoverableButton(signName)
				button.Parent = tooltipFrame
			end
		else --image tooltips not working so well.
			local s, e = pcall(function()
				tooltipContents.Parent = tooltipFrame
			end)
			if not s then
				warn(e)
			end
		end

		if right then
			tooltipFrame.Position = UDim2.fromOffset(mouse.X + 10, mouse.Y + 10)
		else
			tooltipFrame.Position = UDim2.fromOffset(mouse.X + 10 - size.X.Offset, mouse.Y + 10)
		end

		if alongBottom then
			-- we hang down below hangOffTheBottomOfThis which is a screengui
			-- we want to hang down below the center of that screengui

			local pos =
				UDim2.fromOffset(frame.AbsolutePosition.X - 240, frame.AbsolutePosition.Y + frame.AbsoluteSize.Y + 90)
			tooltipFrame.Position = pos
		end
	end)

	target.MouseLeave:Connect(function()
		-- if true then return en1d
		-- TRULY a hack
		-- leave the last tooltip open when you mouseoff from signProfilegui (so it becomes more like a button...)
		local adder = 0
		if frame then
			adder = 0
		else
			adder = 1
		end
		DestroyToolTips(myAge + adder)
	end)
end

_annotate("end")
return module
