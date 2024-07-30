--!strict

--warning: 2022.10 sometimes needs to be loaded late for some reason.
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local colors = require(game.ReplicatedStorage.util.colors)

local vscdebug = require(game.ReplicatedStorage.vscdebug)

local module = {}

module.enum = {}
module.enum.toolTipSize = {}
module.enum.toolTipSize.NormalText = UDim2.new(0, 350, 0, 80)
module.enum.toolTipSize.BigPane = UDim2.new(0, 450, 0, 320)

local ephemeralToolTipFrameName = "EphemeralTooltip"

local function DestroyToolTips(localPlayer: Player, killYoungerThan: number?)
	local ttgui = localPlayer.PlayerGui:FindFirstChild("ToolTipGui")
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

local tooltipAge = 0

--right=they float right+down rather than left+down from cursor. default is right.
module.setupToolTip = function(
	localPlayer: Player,
	target: TextLabel | TextButton | ImageLabel | Frame,
	tooltipContents: string | ImageLabel,
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
	if tooltipContents == nil then
		return
	end
	assert(tooltipContents)
	local mouse: Mouse = localPlayer:GetMouse()

	local myAge = 0

	target.MouseEnter:Connect(function()
		tooltipAge += 1
		myAge = tooltipAge
		-- reuse the ttgui
		local ttgui = localPlayer.PlayerGui:FindFirstChild("ToolTipGui")
		if ttgui == nil then
			ttgui = Instance.new("ScreenGui")
			ttgui.Parent = localPlayer.PlayerGui
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
		DestroyToolTips(localPlayer, myAge + 1)
	end)
end

_annotate("end")
return module
