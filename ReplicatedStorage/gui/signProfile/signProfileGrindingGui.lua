--!strict
local StarterPlayer = game:GetService("StarterPlayer")

-- signProfileGrindingGui
-- Grinding menu creation.

local windowFunctions = require(StarterPlayer.StarterPlayerScripts.guis.windowFunctions)
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local module = {}

local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local colors = require(game.ReplicatedStorage.util.colors)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local textHighlighting = require(game.ReplicatedStorage.gui.textHighlighting)
local tt = require(game.ReplicatedStorage.types.gametypes)

local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)
local localPlayer = game:GetService("Players").LocalPlayer
-- local character = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
-- local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local warper = require(game.StarterPlayer.StarterPlayerScripts.warper)

--------------- FUNCTIONS -------------------------

-- we need to be very careful; if not rr.hasFoundSign, we need to make sure we don't let the player highlight the target.
local function getIndividualGrindButton(startSignId: number, num: number, rr: tt.relatedRace): TextButton | nil
	local name = string.format("%03d_GrindUIButtonTo %s", num, rr.signName)
	local button = guiUtil.getTb(name, UDim2.new(0, 90, 0, 30), 1, nil, colors.warpColor, 1)

	button.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
	button.BorderSizePixel = 0
	button.BorderColor3 = Color3.fromRGB(100, 100, 100)
	button.TextScaled = true
	local hasFoundSignText = ""
	if not rr.hasFoundSign then
		hasFoundSignText = " (?)"
	end
	button.Text = string.format("%s%s (%d)", rr.signName, hasFoundSignText, rr.totalRunnerCount)

	button.MouseEnter:Connect(function()
		local signProfileSgui: ScreenGui = localPlayer.PlayerGui:FindFirstChild("SignProfileSgui") :: ScreenGui
		if signProfileSgui then
			local theBadFrame: Frame = signProfileSgui:FindFirstChild("content_signProfile") :: Frame
			if theBadFrame then
				theBadFrame.Visible = false
			end
		end
	end)

	if rr.hasFoundSign then
		button.Activated:Connect(function()
			textHighlighting.KillAllExistingHighlights()
			textHighlighting.DoHighlightSingleSignId(rr.signId, "getGrindButton.")
			textHighlighting.RotateCameraToFaceSignId(rr.signId)
			warper.WarpToSignId(startSignId, rr.signId)
		end)
	end

	local par: TextButton = button.Parent :: TextButton

	return par
end

-- make the permanent popup. for now just show tiles.
module.MakeSignProfileGrindingGui = function(
	startSignId: number,
	sourceName: string,
	relatedUnrunRacesOfType: { tt.relatedRace }
): Frame
	local d = windowFunctions.SetupFrame("signProfileGrinding", true, true, false, true, UDim2.new(0, 200, 0, 200))
	local outerFrame = d.outerFrame
	local contentFrame = d.contentFrame

	local realGuyCount = 0
	local buttons = {}
	for _, unrunRelationship: tt.relatedRace in ipairs(relatedUnrunRacesOfType) do
		local sign = tpUtil.signId2Sign(unrunRelationship.signId)
		if not sign then
			continue
		end

		local button = getIndividualGrindButton(startSignId, realGuyCount, unrunRelationship)
		if button then
			table.insert(buttons, button)
			realGuyCount += 1
		end
	end

	-- one button for a sign is 30 pixels tall and 95 pixels wide.
	local pixYHeight = math.min(240, realGuyCount * 30 / 2 + 5)

	outerFrame.Size = UDim2.new(0, 2 * 95, 0, pixYHeight + 93)
	outerFrame.BackgroundColor3 = colors.defaultGrey
	outerFrame.Position = UDim2.new(0, 10, 0.1, 5)
	outerFrame.BackgroundTransparency = 0

	local vv = Instance.new("UIListLayout")
	vv.Parent = contentFrame
	vv.FillDirection = Enum.FillDirection.Vertical
	vv.HorizontalAlignment = Enum.HorizontalAlignment.Left
	vv.VerticalAlignment = Enum.VerticalAlignment.Top
	vv.Padding = UDim.new(0, 0)
	vv.Wraps = false
	vv.Name = "vvGrinding"

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
	titleTextLabel.Name = "GrindUI Title"

	local scrollFrameHolder = Instance.new("Frame")
	scrollFrameHolder.Size = UDim2.new(1, 0, 1, -78)
	scrollFrameHolder.Position = UDim2.new(0, 0, 0, 0)
	scrollFrameHolder.BackgroundTransparency = 1
	scrollFrameHolder.Parent = contentFrame
	scrollFrameHolder.Name = "02_scrollFrameHolder"
	scrollFrameHolder.ClipsDescendants = true
	-- scrollFrameHolder.Position = UDim2.new(0, 0, 0, 0)

	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "GrindUI_Internal_ScrollingFrame"
	scrollFrame.BorderMode = Enum.BorderMode.Inset
	scrollFrame.ScrollBarThickness = 16
	scrollFrame.HorizontalScrollBarInset = Enum.ScrollBarInset.None
	scrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.Always
	scrollFrame.BackgroundTransparency = 0
	scrollFrame.BorderSizePixel = 1

	scrollFrame.AutomaticSize = Enum.AutomaticSize.None
	scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y

	scrollFrame.Size = UDim2.new(1, 0, 1, 0) -- Keep full width

	scrollFrame.Parent = scrollFrameHolder

	-- (in the test game, some guys won't be real. )
	scrollFrame.CanvasSize = UDim2.new(1, 0, 0, 10 * realGuyCount / 2) -- Set initial canvas size to 0

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

	local vv2 = Instance.new("UIListLayout")
	vv2.Parent = scrollFrame
	vv2.FillDirection = Enum.FillDirection.Horizontal
	vv2.HorizontalAlignment = Enum.HorizontalAlignment.Left
	vv2.VerticalAlignment = Enum.VerticalAlignment.Top
	-- vv2.VerticalFlex = Enum.UIFlexAlignment.Fill
	vv2.HorizontalFlex = Enum.UIFlexAlignment.Fill -- Changed from Fill
	vv2.Padding = UDim.new(0, 0)
	vv2.SortOrder = Enum.SortOrder.Name
	vv2.Wraps = true
	vv2.Name = "GrindScrollframe_vv2"

	-- Add right padding to the content
	local uiPadding = Instance.new("UIPadding")
	uiPadding.PaddingRight = UDim.new(0, 16) -- Width of scrollbar
	uiPadding.Parent = scrollFrame

	for _, button in ipairs(buttons) do
		button.Parent = scrollFrame
		button.Size = UDim2.new(0, 90, 0, 30) -- Ensure consistent size
	end

	return outerFrame
end

_annotate("end")
return module
