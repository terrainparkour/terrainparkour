--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local colors = require(game.ReplicatedStorage.util.colors)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local tt = require(game.ReplicatedStorage.types.gametypes)
local gt = require(game.ReplicatedStorage.gui.guiTypes)

local module = {}

module.getHamburger = function(): ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.IgnoreGuiInset = true
	screenGui.Name = "HamburgerMenu"
	local frame = Instance.new("Frame")
	local corner = 32
	frame.Size = UDim2.new(0, corner, 0, corner)
	frame.Name = "hamburgerFrame"
	frame.Parent = screenGui
	frame.Position = UDim2.new(1, -1 * corner, 1, -1 * corner)
	local tb = guiUtil.getTbSimple()
	tb.Name = "button"
	tb.Parent = frame
	tb.Text = "S"
	return screenGui
end

module.getMenuList = function(localPlayer: Player, buttons: { gt.button }, pgui: PlayerGui)
	local userId = localPlayer.UserId
	local screenGui = Instance.new("ScreenGui")
	screenGui.IgnoreGuiInset = true
	screenGui.Name = "MenuList"
	local outerFrame = Instance.new("Frame")
	outerFrame.Parent = screenGui
	outerFrame.Size = UDim2.new(0.4, 0, 0, 0)
	outerFrame.Position = UDim2.new(0.3, 0, 0.3, 0)
	outerFrame.AutomaticSize = Enum.AutomaticSize.Y
	local vv2 = Instance.new("UIListLayout")
	vv2.FillDirection = Enum.FillDirection.Vertical
	vv2.Parent = outerFrame

	local frameName = "MenuListModal"

	local scrollingFrame = Instance.new("ScrollingFrame")
	scrollingFrame.AutomaticSize = Enum.AutomaticSize.Y
	scrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollingFrame.ScrollBarThickness = 10
	scrollingFrame.CanvasSize = UDim2.new(1, 0, 1, 0)
	scrollingFrame.Name = frameName
	scrollingFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	scrollingFrame.Parent = outerFrame
	scrollingFrame.Position = UDim2.new(1, 0, 1, 0)
	scrollingFrame.Size = UDim2.new(1, 0, 0, 0)
	local vv = Instance.new("UIListLayout")
	vv.FillDirection = Enum.FillDirection.Vertical
	vv.Parent = scrollingFrame

	for ii, but in ipairs(buttons) do
		local buttonTb = guiUtil.getTbSimple()
		buttonTb.Name = string.format("Button%02d_%s", ii, but.name)
		buttonTb.Text = but.name
		buttonTb.Size = UDim2.new(1, 0, 0, 50)
		buttonTb.Parent = scrollingFrame
		buttonTb.Activated:Connect(function()
			task.spawn(function()
				local content = but.contentsGetter(localPlayer)
				content.Parent = pgui
				screenGui:Destroy()
			end)
		end)
	end

	local tb = guiUtil.getTbSimple()
	tb.Text = "Close"
	tb.Size = UDim2.new(1, 0, 0, 50)
	tb.BackgroundColor3 = colors.redStop
	tb.Parent = outerFrame
	tb.Activated:Connect(function()
		screenGui:Destroy()
	end)
	return screenGui
end

_annotate("end")
return module
