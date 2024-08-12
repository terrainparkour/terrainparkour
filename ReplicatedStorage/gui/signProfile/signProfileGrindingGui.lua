--!strict

-- signProfileGrindingGui
-- Grinding menu creation.

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

local function getIndividualGrindButton(startSignId: number, num: number, rr: tt.relatedRace): TextButton | nil
	local name = string.format("%d GrindUIButtonTo %s", num, rr.signName)
	local button = guiUtil.getTb(name, UDim2.new(0, 95, 0, 30), 1, nil, colors.lightBlue, 1)

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
module.MakeSignProfileGrindingGui = function(startSignId: number, sourceName: string, guys: { tt.relatedRace }): Frame
	local d = windows.SetupFrame("signProfileGrinding", true, true, true)
	local outerFrame = d.outerFrame
	local contentFrame = d.contentFrame

	outerFrame.Size = UDim2.new(0, 103, 0.4, 0)
	outerFrame.BackgroundColor3 = colors.defaultGrey
	outerFrame.Position = UDim2.new(0, 0, 0.1, 0)
	outerFrame.BackgroundTransparency = 0

	local vv = Instance.new("UIListLayout")
	vv.Parent = contentFrame
	vv.FillDirection = Enum.FillDirection.Vertical
	vv.HorizontalAlignment = Enum.HorizontalAlignment.Left
	vv.VerticalAlignment = Enum.VerticalAlignment.Top
	vv.Padding = UDim.new(0, 0)
	vv.Wraps = false
	vv.Name = "vv"

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

	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "03_ScrollingFrame"
	scrollFrame.Size = UDim2.new(1, 0, 1, -78)
	scrollFrame.Position = UDim2.new(0, 0, 0, 0)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0) -- Set initial canvas size to 0
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y -- Automatically size canvas vertically
	scrollFrame.ScrollBarThickness = 2
	scrollFrame.Parent = contentFrame

	-- Add close button at the bottom
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "04_CloseButton"
	closeButton.Size = UDim2.new(1, 0, 0, 30)
	closeButton.Position = UDim2.new(0, 0, 1, -30)
	closeButton.BackgroundColor3 = Color3.new(0.87, 0.3, 0.3)
	closeButton.BorderSizePixel = 0
	closeButton.Text = "Close"
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.TextScaled = true
	closeButton.Parent = contentFrame

	closeButton.Activated:Connect(function()
		outerFrame:Destroy()
	end)

	local scrollFrameContent = Instance.new("Frame")
	scrollFrameContent.Size = UDim2.new(1, 0, 1, 0)
	scrollFrameContent.BackgroundColor3 = colors.defaultGrey
	scrollFrameContent.Parent = scrollFrame
	scrollFrameContent.Name = "02_GrindUIInnerContentFrame"
	local vv2 = Instance.new("UIListLayout")
	vv2.Parent = scrollFrameContent
	vv2.FillDirection = Enum.FillDirection.Vertical
	vv2.HorizontalAlignment = Enum.HorizontalAlignment.Left
	vv2.VerticalAlignment = Enum.VerticalAlignment.Top
	vv2.Padding = UDim.new(0, 3)
	vv2.SortOrder = Enum.SortOrder.LayoutOrder
	vv2.Wraps = true
	vv2.Name = "vv2"

	local ii = 0
	local buttons = {}
	for _, rr in ipairs(guys) do
		local sign = tpUtil.signId2Sign(rr.signId)
		if not sign then
			continue
		end

		local button = getIndividualGrindButton(startSignId, ii, rr)
		if button then
			table.insert(buttons, button)
			button.Parent = scrollFrameContent
			ii += 1
		end
	end

	local sz = math.min((ii * 30), 300)
	outerFrame.Size = UDim2.new(0, 101, 0, sz + 84)
	scrollFrame.Size = UDim2.new(1, 0, 1, -78)
	scrollFrame.CanvasSize = UDim2.new(1, 0, 0, sz) -- Adjust canvas size based on number of items
	-- scrollFrame.ScrollingEnabled = true
	scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y

	return outerFrame
end

_annotate("end")
return module
