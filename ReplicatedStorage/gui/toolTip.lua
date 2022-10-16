--!strict

--eval 9.21
--warning: 2022.10 sometimes needs to be loaded late for some reason.

local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local colors = require(game.ReplicatedStorage.util.colors)

local vscdebug = require(game.ReplicatedStorage.vscdebug)

local module = {}

module.enum = {}
module.enum.toolTipSize = {}
module.enum.toolTipSize.NormalText = UDim2.new(0, 350, 0, 80)
module.enum.toolTipSize.BigPane = UDim2.new(0, 450, 0, 320)

local ephemeralToolTipFrameName = "EphemeralTooltip"

local function destroyToolTips(localPlayer: Player)
	local theGuy = localPlayer.PlayerGui:FindFirstChild("ToolTipGui")
	if theGuy then
		for _, el in ipairs(theGuy:GetChildren()) do
			if el.Name == ephemeralToolTipFrameName then
				for _, el2 in ipairs(el:GetChildren()) do
					el2:Destroy()
				end
				el:Destroy()
			end
		end
	end
end

--right=they float right+down rather than left+down from cursor. default is right.
module.setupToolTip = function(
	localPlayer: Player,
	target: TextLabel | TextButton | ImageLabel | Frame,
	tooltipContents: string | ImageLabel,
	size: UDim2,
	right: boolean?,
	xalignment: any?
)
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

	target.MouseEnter:Connect(function()
		destroyToolTips(localPlayer)

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

		if typeof(tooltipContents) == "string" then
			local tl = guiUtil.getTl("theTl", UDim2.new(1, 0, 1, 0), 2, tooltipFrame, colors.defaultGrey, 1)
			tl.Text = tooltipContents
			tl.TextScaled = true
			tl.Font = Enum.Font.Gotham
			tl.TextXAlignment = xalignment
			tl.TextYAlignment = Enum.TextYAlignment.Top
			tl.Parent.ZIndex = 400
			tl.ZIndex = 500
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
	end)
	target.MouseLeave:Connect(function()
		-- if true then return end

		destroyToolTips(localPlayer)
	end)
end

return module
