local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local colors = require(game.ReplicatedStorage.util.colors)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local fonts = require(game.StarterPlayer.StarterPlayerScripts.guis.fonts)
---------------- CONSTANTS--------------
--max visualization (CAMERA, not PLAYER) range.
local bbguiMaxDist = 150

module.DrawDynamicMouseover = function(from: string, to: string): TextLabel?
	local bbgui = Instance.new("BillboardGui")
	local width = 150
	bbgui.Size = UDim2.new(0, width, 0, 160)
	bbgui.StudsOffset = Vector3.new(0, 6, 0)
	bbgui.MaxDistance = bbguiMaxDist
	bbgui.AlwaysOnTop = false
	bbgui.Name = "DynamicRunning_For_" .. from .. "_to_" .. to
	local frame: Frame = Instance.new("Frame")
	frame.Parent = bbgui
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundTransparency = 1

	local textLabel: TextLabel = Instance.new("TextLabel")
	textLabel.Parent = frame
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.TextSize = 80
	textLabel.TextWrapped = true

	textLabel.Text = ""
	textLabel.TextTransparency = 0.0
	textLabel.BackgroundTransparency = 1
	textLabel.BackgroundColor3 = colors.white
	textLabel.TextColor3 = colors.white

	local theFont = fonts.GetFont(true, true)
	textLabel.FontFace = theFont
	textLabel.TextScaled = false
	local constraint = Instance.new("UITextSizeConstraint")

	constraint.Name = "UITextSizeConstraint_Text"
	constraint.MaxTextSize = 24
	constraint.Parent = textLabel

	local sign = tpUtil.signName2Sign(to)
	bbgui.Parent = sign

	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = colors.black
	uiStroke.Thickness = 6
	uiStroke.Parent = textLabel

	return textLabel
end

_annotate("end")
return module
