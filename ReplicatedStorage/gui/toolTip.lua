--!strict

--warning: 2022.10 sometimes needs to be loaded late for some reason.
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
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
	if not playerGui then
		return
	end
	local ttgui = playerGui:FindFirstChild("ToolTipGui")
	if not ttgui then
		return
	end
	for _, el in ipairs(ttgui:GetChildren()) do
		if el.Name ~= ephemeralToolTipFrameName then
			continue
		end

		if killYoungerThan ~= nil then
			local ageValue = el:FindFirstChild("AgeValue")
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

--right=they float right+down rather than left+down from cursor. default is right.
local LLMGeneratedUIFunctions = require(game.ReplicatedStorage.gui.menu.LLMGeneratedUIFunctions)

module.setupToolTip = function(
	target: TextLabel | TextButton | ImageLabel | Frame,
	tooltipContents: string | ImageLabel | { signName: string, extraText: string },
	size: UDim2,
	right: boolean?,
	xalignment: any?,
	alongBottom: boolean?,
	frame: Frame?
)
	if tooltipContents == nil or tooltipContents == "" then
		warn("Tooltip contents is empty or nil")
		return
	end

	if xalignment == nil then
		xalignment = Enum.TextXAlignment.Center
	end
	if right == nil then
		right = true
	end

	local mouse: Mouse = localPlayer:GetMouse()

	local myAge = 0

	target.MouseEnter:Connect(function()
		tooltipAge += 1
		myAge = tooltipAge
		local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
		local ttgui = playerGui:FindFirstChild("ToolTipGui")
		if ttgui == nil then
			ttgui = LLMGeneratedUIFunctions.createUIElement("ScreenGui", {
				Name = "ToolTipGui",
				Parent = playerGui,
				Enabled = true,
				DisplayOrder = 100,
			})
		end

		local tooltipFrame = LLMGeneratedUIFunctions.createFrame({
			Name = ephemeralToolTipFrameName,
			Size = size,
			Parent = ttgui,
			ZIndex = 10,
			BackgroundTransparency = 0,
			BackgroundColor3 = Color3.new(0.8, 0.8, 0.8), -- Light grey background
		})

		local numberValue = Instance.new("NumberValue")
		numberValue.Name = "AgeValue"
		numberValue.Value = myAge
		numberValue.Parent = tooltipFrame

		if typeof(tooltipContents) == "string" then
			_annotate(string.format("Creating text tooltip: %s", tooltipContents)) -- Debug print
			local tl = LLMGeneratedUIFunctions.createTextLabel({
				Name = "TooltipContent",
				Size = UDim2.new(1, -10, 1, -10), -- Fill most of the frame, leaving a small margin
				Position = UDim2.new(0, 5, 0, 5), -- Small offset from the edges
				Text = tooltipContents,
				TextColor3 = Color3.new(0, 0, 0), -- Black text
				BackgroundTransparency = 1,
				TextScaled = true, -- Enable text scaling
				Font = Enum.Font.GothamBold, -- Use a bold font for better visibility
				TextXAlignment = xalignment,
				TextYAlignment = Enum.TextYAlignment.Center, -- Center text vertically
				Parent = tooltipFrame,
				ZIndex = 11, -- Higher Z-index than the tooltipFrame
			})

			-- Add text size constraint
			local sizeConstraint = Instance.new("UITextSizeConstraint")
			sizeConstraint.MaxTextSize = 48 -- Increase max text size for larger text
			sizeConstraint.Parent = tl
		elseif typeof(tooltipContents) == "table" then
			-- Handle the case for insane mouseover sign names
			-- This part needs to be implemented based on your specific requirements
		else
			local s, e = pcall(function()
				tooltipContents.Parent = tooltipFrame
			end)
			if not s then
				warn(e)
			end
		end

		local function updatePosition()
			local mousePos = game:GetService("UserInputService"):GetMouseLocation()
			local viewportSize = workspace.CurrentCamera.ViewportSize
			local xPos, yPos

			if right then
				xPos = mousePos.X + 10
				yPos = mousePos.Y + 10
			else
				xPos = mousePos.X - size.X.Offset - 10
				yPos = mousePos.Y + 10
			end

			-- Ensure the tooltip doesn't go off-screen
			xPos = math.clamp(xPos, 0, viewportSize.X - size.X.Offset)
			yPos = math.clamp(yPos, 0, viewportSize.Y - size.Y.Offset)

			tooltipFrame.Position = UDim2.fromOffset(xPos, yPos)
		end

		updatePosition()

		-- Update position when the mouse moves
		local connection
		connection = game:GetService("UserInputService").InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				updatePosition()
			end
		end)

		-- Disconnect the InputChanged event when the tooltip is destroyed
		tooltipFrame.AncestryChanged:Connect(function(_, parent)
			if not parent then
				connection:Disconnect()
			end
		end)
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
