--!strict

--2022 centralize to this game's ui style.
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

--get a tl, put it into parent with padding, return inner thing for further work

module.getTl = function(
	name: string,
	size: UDim2,
	padding: number,
	parent: Frame | ScrollingFrame | nil,
	bgcolor: Color3,
	borderSizePixel: number?,
	transparency: number?,
	automaticSize: Enum.AutomaticSize?
): TextLabel
	if transparency == nil then
		transparency = 0
	end

	local tl = Instance.new("TextLabel")
	tl.ZIndex = 1
	tl.TextTransparency = 1
	tl.Size = size
	tl.Parent = parent
	tl.Name = name
	tl.BackgroundColor3 = bgcolor
	tl.BorderMode = Enum.BorderMode.Inset
	tl.BorderSizePixel = 1
	tl.BackgroundTransparency = transparency or 0
	if automaticSize ~= nil then
		tl.AutomaticSize = automaticSize
	end

	if borderSizePixel ~= nil then
		tl.BorderSizePixel = borderSizePixel
		tl.BorderMode = Enum.BorderMode.Outline
	end

	local innerTl = Instance.new("TextLabel")
	innerTl.Parent = tl
	innerTl.TextScaled = true
	innerTl.ZIndex = 2
	innerTl.Name = "Inner"
	innerTl.Font = Enum.Font.Gotham
	innerTl.Size = UDim2.new(1, -2 * padding, 1, -2 * padding)
	innerTl.Position = UDim2.new(0, padding, 0, padding)
	innerTl.BackgroundColor3 = bgcolor
	innerTl.BorderSizePixel = 0
	innerTl.AutoLocalize = true
	if transparency ~= 0 then
		innerTl.BackgroundTransparency = 1
	end

	return innerTl
end

--todo deprecate
module.getTbSimple = function(): TextButton
	local tl = Instance.new("TextButton")
	tl.TextScaled = true
	tl.Font = Enum.Font.Gotham
	tl.Size = UDim2.new(1, 0, 1, 0)
	tl.BorderMode = Enum.BorderMode.Outline
	tl.BorderSizePixel = 1
	return tl
end

module.getTb = function(
	name: string,
	size: UDim2,
	padding: number,
	parent: Frame | ScrollingFrame | nil,
	bgcolor: Color3,
	borderSizePixel: number?,
	transparency: number?
): TextButton
	if transparency == nil then
		transparency = 0
	end

	local outerTb = Instance.new("TextButton")
	outerTb.ZIndex = 1
	outerTb.TextTransparency = 1
	outerTb.Size = size
	outerTb.Parent = parent
	outerTb.Name = name
	outerTb.BackgroundColor3 = bgcolor
	outerTb.BorderMode = Enum.BorderMode.Inset
	outerTb.BorderSizePixel = 1

	outerTb.BackgroundTransparency = transparency or 0

	if borderSizePixel ~= nil then
		outerTb.BorderSizePixel = borderSizePixel
		outerTb.BorderMode = Enum.BorderMode.Outline
	end

	local innerTb = Instance.new("TextButton")
	innerTb.Parent = outerTb
	innerTb.TextScaled = true
	innerTb.ZIndex = 2
	innerTb.Name = "Inner"
	innerTb.Font = Enum.Font.Gotham
	innerTb.Size = UDim2.new(1, -2 * padding, 1, -2 * padding)
	innerTb.Position = UDim2.new(0, padding, 0, padding)
	innerTb.BackgroundColor3 = bgcolor
	innerTb.BorderSizePixel = 0
	innerTb.BorderMode = Enum.BorderMode.Inset
	if transparency ~= 0 then
		innerTb.BackgroundTransparency = 1
	end
	return innerTb
end

--kill a sgui with an invisible textbutton on top of it.
--shrinkYScale is to leave room for a warper or other button at the bottom.
--IS used for runresults, not used for find
module.setupKillOnClick = function(sgui: ScreenGui, excludeElementName: string?, actualExcludedFrame: Frame?)
	local invisibleCloseModalButton = Instance.new("TextButton")
	local mainFrame = sgui:FindFirstChildOfClass("Frame") :: Frame
	if not mainFrame then
		annotater.Error("no mainiframe.'")
	end
	invisibleCloseModalButton.Position = mainFrame.Position
	invisibleCloseModalButton.Size = mainFrame.Size
	invisibleCloseModalButton.Name = "invisibleCloseModalButton"
	invisibleCloseModalButton.Transparency = 1.0
	invisibleCloseModalButton.Text = "kill but can't see"
	invisibleCloseModalButton.TextScaled = true
	invisibleCloseModalButton.Parent = sgui
	invisibleCloseModalButton.Activated:Connect(function()
		sgui:Destroy()
	end)
	invisibleCloseModalButton.ZIndex = 10
end

--pixel-sized udim creator
module.p = function(xpixel: number, ypixel: number): UDim2
	return UDim2.new(0, xpixel, 0, ypixel)
end

--scaled udim creator
module.s = function(xscale: number, yscale: number): UDim2
	return UDim2.new(xscale, 0, yscale, 0)
end

_annotate("end")
return module
