--!strict

-- signProfileSticky Grinding menu creation.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local module = {}

local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local colors = require(game.ReplicatedStorage.util.colors)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local textHighlighting = require(game.ReplicatedStorage.gui.textHighlighting)
local tt = require(game.ReplicatedStorage.types.gametypes)
local colors = require(game.ReplicatedStorage.util.colors)
local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)
local localPlayer = game.Players.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local warper = require(game.StarterPlayer.StarterPlayerScripts.warper)

--------------- FUNCTIONS -------------------------

local function getMouseoverableButtonToFaceAndHighlightSign(
	startSignId: number,
	num: number,
	rr: tt.relatedRace
): TextButton | nil
	local name = string.format("%d GrindUIButtonTo %s", num, rr.signName)
	local button = guiUtil.getTb(name, UDim2.new(0, 95, 0, 30), 1, nil, colors.lightBlue, 1)
	-- button.Size = UDim2.new(0, 95, 0, 30)
	button.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
	button.BorderSizePixel = 1
	button.BorderColor3 = Color3.fromRGB(100, 100, 100)
	button.TextScaled = true
	button.Text = string.format("%s (%d)", rr.signName, rr.totalRunnerCount)

	button.MouseEnter:Connect(function()
		local signProfileSgui: ScreenGui = localPlayer.PlayerGui:FindFirstChild("SignProfileSgui")
		if signProfileSgui then
			local theBadFrame: Frame = signProfileSgui:FindFirstChild("content_signProfile")
			if theBadFrame then
				theBadFrame.Visible = false
			end
		end

		textHighlighting.KillAllExistingHighlights()

		textHighlighting.DoHighlightSingleSignId(rr.signId)
		textHighlighting.RotateCameraToFaceSignId(rr.signId)
		-- textHighlighting.PointHumanoidAtSignId(rr.signId)
	end)

	button.Activated:Connect(function()
		warper.WarpToSignId(startSignId, rr.signId)
	end)

	return button.Parent
end

-- make the permanent popup. for now just show tiles.
module.MakeSignProfileStickyGui = function(startSignId: number, sourceName: string, guys: { tt.relatedRace }): Frame
	local d = windows.SetupFrame("signProfileSticky", true, true, true)
	local outerFrame = d.outerFrame
	local contentFrame = d.contentFrame

	outerFrame.Size = UDim2.new(0, 120, 0.4, 0)
	outerFrame.BackgroundColor3 = colors.defaultGrey
	outerFrame.Position = UDim2.new(0.1, 0, 0.1, 0)
	outerFrame.BackgroundTransparency = 0

	local hh = Instance.new("UIListLayout")
	hh.Wraps = true
	hh.Parent = contentFrame
	hh.FillDirection = Enum.FillDirection.Horizontal
	hh.HorizontalAlignment = Enum.HorizontalAlignment.Left
	hh.SortOrder = Enum.SortOrder.LayoutOrder
	hh.Parent = contentFrame
	hh.VerticalAlignment = Enum.VerticalAlignment.Top
	hh.Padding = UDim.new(0, 5)
	hh.Wraps = true

	local titleRow = Instance.new("Frame")
	titleRow.Name = "01_GrindUITitleRowFrame"
	titleRow.Size = UDim2.new(1, 0, 0, 48)
	titleRow.BackgroundColor3 = colors.meColor
	titleRow.Parent = contentFrame
	local titleTextLabel = Instance.new("TextLabel")
	titleTextLabel.Size = UDim2.new(1, 0, 1, 0)
	titleTextLabel.BackgroundColor3 = colors.black
	titleTextLabel.BackgroundTransparency = 1
	titleTextLabel.Text = sourceName
	titleTextLabel.TextColor3 = colors.black
	titleTextLabel.Parent = titleRow
	titleTextLabel.TextScaled = true

	local count = 0
	-- local rrcount = #guys
	-- local heightPerYScale = 1 / rrcount
	local innerContentFrame = Instance.new("Frame")
	innerContentFrame.Size = UDim2.new(1, 0, 1, -48)
	innerContentFrame.BackgroundColor3 = colors.defaultGrey
	innerContentFrame.Parent = contentFrame
	innerContentFrame.Name = "02_GrindUIInnerContentFrame"

	local vv = Instance.new("UIListLayout")
	vv.Parent = innerContentFrame
	vv.FillDirection = Enum.FillDirection.Vertical
	vv.HorizontalAlignment = Enum.HorizontalAlignment.Left
	vv.VerticalAlignment = Enum.VerticalAlignment.Top
	vv.Padding = UDim.new(0, 5)
	vv.Wraps = true
	vv.Name = "02_GrindUIInnerContentFrame_UIListLayout"

	local ii = 0
	for _, rr in ipairs(guys) do
		local sign = tpUtil.signId2Sign(rr.signId)
		if not sign then
			continue
		end

		local button = getMouseoverableButtonToFaceAndHighlightSign(startSignId, ii, rr)
		if button then
			button.Parent = innerContentFrame
			count += 1
		end
		ii += 1
	end

	local tb = guiUtil.getTb("ZZZCloseButton", UDim2.new(0, 95, 0, 30), 2, innerContentFrame, colors.redStop, 1, 0)
	tb.Text = "Close"
	tb.Activated:Connect(function()
		outerFrame:Destroy()
	end)
	return outerFrame
end

_annotate("end")
return module
