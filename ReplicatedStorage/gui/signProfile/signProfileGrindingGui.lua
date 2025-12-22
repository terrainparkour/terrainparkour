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
local scrollingFrameUtils = require(game.ReplicatedStorage.gui.scrollingFrameUtils)
local standardButton = require(game.ReplicatedStorage.gui.standardButton)
local tpUtil: typeof(require(game.ReplicatedStorage.util.tpUtil)) = require(game.ReplicatedStorage.util.tpUtil)
local textHighlighting = require(game.ReplicatedStorage.gui.textHighlighting)
local tt = require(game.ReplicatedStorage.types.gametypes)

local localPlayer = game:GetService("Players").LocalPlayer
-- local character = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
-- local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local warper = require(game.StarterPlayer.StarterCharacterScripts.client.warper)

--------------- FUNCTIONS -------------------------

-- we need to be very careful; if not rr.hasFoundSign, we need to make sure we don't let the player highlight the target.
local function getIndividualGrindButton(startSignId: number, num: number, rr: tt.relatedRace): TextButton | nil
	local name = string.format("%03d_GrindUIButtonTo %s", num, rr.signName)
	local button = guiUtil.getPaddedButton(name, UDim2.new(0, 90, 0, 30), 1, nil, colors.warpColor, 1)

	button.BackgroundColor3 = colors.buttonNeutral
	button.BorderSizePixel = 0
	button.BorderColor3 = colors.buttonBorder
	button.TextScaled = true
	local hasFoundSignText = ""
	if not rr.hasFoundSign then
		hasFoundSignText = " (?)"
	end
	button.Text = string.format("%s%s (%d)", rr.signName, hasFoundSignText, rr.totalRunnerCount)

	button.MouseEnter:Connect(function()
		local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
		if not playerGui then
			return
		end
		local signProfileSgui = playerGui:FindFirstChild("SignProfileSgui")
		if not signProfileSgui or not signProfileSgui:IsA("ScreenGui") then
			return
		end
		local theBadFrame = signProfileSgui:FindFirstChild("content_signProfile")
		if theBadFrame and theBadFrame:IsA("Frame") then
			theBadFrame.Visible = false
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

	local buttonParent = button.Parent
	if not buttonParent or not buttonParent:IsA("TextButton") then
		annotater.Error("getIndividualGrindButton: missing padded button parent")
		return nil
	end
	local par: TextButton = buttonParent

	return par
end

-- make the permanent popup. for now just show tiles.
module.MakeSignProfileGrindingGui = function(
	startSignId: number,
	sourceName: string,
	relatedUnrunRacesOfType: { tt.relatedRace }
): Frame
	local d = windowFunctions.SetupFrame(
		"signProfileGrinding",
		true, -- draggable
		true, -- resizable
		false, -- minimizable
		true, -- pinnable
		UDim2.new(0, 200, 0, 200),
		false, -- maintainAspectRatio
		{
			settingName = "SIGN_GRINDING_GUI_LAYOUT",
			settingKey = "position",
			saveSize = false, -- size is dynamic based on content
			clampOnLoad = true,
			defaultPosition = UDim2.new(0.75, 0, 0.15, 0), -- right side, avoids chat
		}
	)
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

	-- one button for a sign is 30 pixels tall and 90 pixels wide.
	local buttonHeight = 30
	local buttonsPerRow = 2
	local rowCount = math.ceil(realGuyCount / buttonsPerRow)
	local contentHeight = rowCount * buttonHeight

	-- Cap at 40 items (20 rows) or screen height
	local maxItems = 40
	local maxRows = math.ceil(maxItems / buttonsPerRow) -- 20
	local maxPreferredHeight = maxRows * buttonHeight -- 600

	local viewportHeight = workspace.CurrentCamera.ViewportSize.Y
	local maxSafeHeight = math.max(200, viewportHeight * 0.8) -- Use 80% of screen height, min 200

	local limitHeight = math.min(maxPreferredHeight, maxSafeHeight)

	-- We want to expand to fit content, up to limitHeight
	local pixYHeight = math.min(contentHeight, limitHeight)

	-- Ensure we have at least a bit of height if there are items
	if realGuyCount > 0 and pixYHeight < buttonHeight then
		pixYHeight = buttonHeight
	end

	-- Widen frame to fit 2 columns + scrollbar (90*2 = 180 + 16 = 196 -> use 200 for a tight fit)
	outerFrame.Size = UDim2.new(0, 200, 0, pixYHeight + 93)
	outerFrame.BackgroundColor3 = colors.defaultGrey
	-- Position is handled by persistenceConfig with defaultPosition; don't overwrite saved position
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
	-- scrollFrame.CanvasSize = UDim2.new(1, 0, 0, 10 * realGuyCount / 2) -- Set initial canvas size to 0

	-- Add close button at the bottom
	local closeButton = standardButton.CreateCloseButton({
		onClick = function()
			outerFrame:Destroy()
		end,
		size = UDim2.new(1, 0, 0, 30),
		parent = contentFrame,
	})
	closeButton.Name = "04_CloseButton"
	closeButton.Position = UDim2.new(0, 0, 1, -30)

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
		if button then
			button.Parent = scrollFrame
			button.Size = UDim2.new(0, 90, 0, 30) -- Ensure consistent size
		end
	end

	-- Prevent camera scroll when hovering over grinding GUI scrolling frame
	scrollingFrameUtils.PreventCameraScrollOnHover(scrollFrame)

	return outerFrame
end

_annotate("end")
return module
