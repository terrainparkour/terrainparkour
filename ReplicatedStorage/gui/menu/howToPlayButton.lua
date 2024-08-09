--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local colors = require(game.ReplicatedStorage.util.colors)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local gt = require(game.ReplicatedStorage.gui.guiTypes)

local module = {}

local getHowToPlayModal = function(localPlayer: Player): ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.IgnoreGuiInset = true
	screenGui.Name = "SettingsSgui"

	local outerFrame = Instance.new("Frame")
	outerFrame.Parent = screenGui
	outerFrame.Size = UDim2.new(0.4, 0, 0.5, 0)
	outerFrame.Position = UDim2.new(0.3, 0, 0.3, 0)
	local vv2 = Instance.new("UIListLayout")
	vv2.FillDirection = Enum.FillDirection.Vertical
	vv2.Parent = outerFrame

	--scrolling setting frame
	local frameName = "HowToPlayModal"
	local scrollingFrame = Instance.new("ScrollingFrame")
	scrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollingFrame.ScrollBarThickness = 10
	scrollingFrame.Name = frameName
	scrollingFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	scrollingFrame.Parent = outerFrame
	scrollingFrame.CanvasSize = UDim2.new(1, 0, 1, 0)
	scrollingFrame.Size = UDim2.new(1, 0, 1, 0)

	local vv = Instance.new("UIListLayout")
	vv.FillDirection = Enum.FillDirection.Vertical
	vv.Parent = scrollingFrame

	local text = guiUtil.getTl("Text", UDim2.new(1, 0, 1, 0), 2, scrollingFrame, colors.defaultGrey, 1)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.FontSize = Enum.FontSize.Size14
	text.Text = "Run and touch red signs to 'find' them.  Run from one to the other to complete runs.  Look at your run results and see how you did.  Get WRs. Get badges. Find your favorite spots.\n\nAdvanced play: Turn on marathons using settings and try to complete one.  Find 300+ signs.  Click a sign to examine other people's records. Complete sign runs to take over a sign. Use the secret command line commands to find things out. Get badges.  \n\nThe game has been around since 2017."
		.. "\n\nExplorer - Wander around randomly"
		.. "\n\nGrinder - Warp back over and over trying to beat a run"
		.. "\n\nSign takeover - try to get to sign leader (click sign and have most WRs to/from it)"
		.. "\n\nMarathoner - complete all marathons"
		.. "\n\nTeam random racer - challenge someone to complete /rr runs"
		.. "\n\nChainer - do a run, then click the sign.  Do the shortest suggested run which you _haven't_ done yet."
		.. "\n\nSniper - try to gradually eliminate all other WR holders from a sign"

	local tb = guiUtil.getTb("ZZZSettingsCloseButton", UDim2.new(1, 0, 0, 40), 2, outerFrame, colors.redStop)
	tb.Text = "Close"
	tb.Activated:Connect(function()
		screenGui:Destroy()
	end)
	return screenGui
end

local howToPlayButton: gt.button = {
	name = "Ways to play",
	contentsGetter = getHowToPlayModal,
}

module.howToPlayButton = howToPlayButton

_annotate("end")
return module
