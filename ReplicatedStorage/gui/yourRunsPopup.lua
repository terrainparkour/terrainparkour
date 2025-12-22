--!strict

-- yourRunsPopup.lua
-- Shared module for displaying the "Your Runs" hover popup.
-- Used by both runResultGui (rrg) and WRProgressionGui.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local tt = require(game.ReplicatedStorage.types.gametypes)
local colors = require(game.ReplicatedStorage.util.colors)
local fonts = require(game.StarterPlayer.StarterPlayerScripts.guis.fonts)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local remotes = require(game.ReplicatedStorage.util.remotes)

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local GenericClientUIFunction = remotes.getRemoteFunction("GenericClientUIFunction")

local module = {}

-- Shared cache for user runs data
local myRunsCache: { [string]: tt.getUserRunsForRaceResponse } = {}

-- Helper to create a row in the popup with aligned columns
local function createMyRunsRow(index: number, timeText: string, ageText: string, bgColor: Color3): Frame
	local rowFrame = Instance.new("Frame")
	rowFrame.Name = string.format("Row_%d", index)
	rowFrame.Size = UDim2.new(1, 0, 0, 22)
	rowFrame.BackgroundColor3 = bgColor
	rowFrame.BorderSizePixel = 0
	rowFrame.LayoutOrder = index

	-- Time column (left, 50% width)
	local timeLabel = Instance.new("TextLabel")
	timeLabel.Name = "Time"
	timeLabel.Size = UDim2.fromScale(0.5, 1)
	timeLabel.Position = UDim2.fromScale(0, 0)
	timeLabel.BackgroundTransparency = 1
	timeLabel.TextColor3 = colors.black
	timeLabel.TextScaled = true
	timeLabel.FontFace = fonts.GetFont(true, false) -- monospaced
	timeLabel.TextXAlignment = Enum.TextXAlignment.Right
	timeLabel.Text = timeText
	timeLabel.Parent = rowFrame

	local timePadding = Instance.new("UIPadding")
	timePadding.PaddingRight = UDim.new(0, 8)
	timePadding.Parent = timeLabel

	-- Age column (right, 50% width)
	local ageLabel = Instance.new("TextLabel")
	ageLabel.Name = "Age"
	ageLabel.Size = UDim2.fromScale(0.5, 1)
	ageLabel.Position = UDim2.fromScale(0.5, 0)
	ageLabel.BackgroundTransparency = 1
	ageLabel.TextColor3 = colors.black
	ageLabel.TextScaled = true
	ageLabel.FontFace = fonts.GetFont(false, false)
	ageLabel.TextXAlignment = Enum.TextXAlignment.Left
	ageLabel.Text = ageText
	ageLabel.Parent = rowFrame

	local agePadding = Instance.new("UIPadding")
	agePadding.PaddingLeft = UDim.new(0, 8)
	agePadding.Parent = ageLabel

	local timeConstraint = Instance.new("UITextSizeConstraint")
	timeConstraint.MaxTextSize = 14
	timeConstraint.Parent = timeLabel

	local ageConstraint = Instance.new("UITextSizeConstraint")
	ageConstraint.MaxTextSize = 14
	ageConstraint.Parent = ageLabel

	return rowFrame
end

-- Populate the popup content from data
local function populateMyRunsContent(contentFrame: Frame, runs: { tt.userRunEntry })
	for _, child in ipairs(contentFrame:GetChildren()) do
		if child:IsA("Frame") or (child:IsA("TextLabel") and child.Name ~= "Header") then
			child:Destroy()
		end
	end

	if #runs == 0 then
		local noRunsLabel = Instance.new("TextLabel")
		noRunsLabel.Name = "NoRuns"
		noRunsLabel.Size = UDim2.new(1, 0, 0, 30)
		noRunsLabel.BackgroundTransparency = 1
		noRunsLabel.Text = "No runs found"
		noRunsLabel.TextColor3 = colors.black
		noRunsLabel.TextScaled = true
		noRunsLabel.LayoutOrder = 1
		noRunsLabel.Parent = contentFrame
		return
	end

	for i, run in ipairs(runs) do
		local formattedTime = tpUtil.fmtms(run.runMilliseconds)
		local ageSeconds = os.time() - run.created
		local formattedAge, _ = tpUtil.formatDateGap(ageSeconds)
		local row = createMyRunsRow(i, formattedTime, formattedAge .. " ago", colors.white)
		row.Parent = contentFrame
	end
end

-- Shows a popup with the user's top runs for a race
function module.ShowPopup(startSignId: number, endSignId: number, anchorElement: GuiObject)
	local cacheKey = string.format("%d-%d", startSignId, endSignId)

	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end

	local existingPopup = playerGui:FindFirstChild("MyRunsPopup")
	if existingPopup then
		existingPopup:Destroy()
	end

	local popupGui = Instance.new("ScreenGui")
	popupGui.Name = "MyRunsPopup"
	popupGui.DisplayOrder = 150
	popupGui.Parent = playerGui

	local anchorPos = anchorElement.AbsolutePosition
	local anchorSize = anchorElement.AbsoluteSize

	local popupWidth = 220
	local popupRowHeight = 22
	local headerHeight = 28
	local titleHeight = 26

	local popupFrame = Instance.new("Frame")
	popupFrame.Name = "PopupFrame"
	popupFrame.BackgroundColor3 = colors.meColor
	popupFrame.BorderSizePixel = 2
	popupFrame.BorderColor3 = colors.black
	popupFrame.Parent = popupGui

	local mainLayout = Instance.new("UIListLayout")
	mainLayout.SortOrder = Enum.SortOrder.LayoutOrder
	mainLayout.FillDirection = Enum.FillDirection.Vertical
	mainLayout.Parent = popupFrame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, titleHeight)
	titleLabel.BackgroundColor3 = colors.meColor
	titleLabel.BorderSizePixel = 0
	titleLabel.Text = "Your Best Runs"
	titleLabel.TextColor3 = colors.black
	titleLabel.TextScaled = true
	titleLabel.FontFace = fonts.GetFont(false, true)
	titleLabel.LayoutOrder = 0
	titleLabel.Parent = popupFrame

	local titleConstraint = Instance.new("UITextSizeConstraint")
	titleConstraint.MaxTextSize = 16
	titleConstraint.Parent = titleLabel

	local headerRow = Instance.new("Frame")
	headerRow.Name = "Header"
	headerRow.Size = UDim2.new(1, 0, 0, headerHeight)
	headerRow.BackgroundColor3 = colors.blueDone
	headerRow.BorderSizePixel = 0
	headerRow.LayoutOrder = 1
	headerRow.Parent = popupFrame

	local timeHeader = Instance.new("TextLabel")
	timeHeader.Name = "TimeHeader"
	timeHeader.Size = UDim2.fromScale(0.5, 1)
	timeHeader.Position = UDim2.fromScale(0, 0)
	timeHeader.BackgroundTransparency = 1
	timeHeader.TextColor3 = colors.black
	timeHeader.TextScaled = true
	timeHeader.FontFace = fonts.GetFont(false, true)
	timeHeader.TextXAlignment = Enum.TextXAlignment.Center
	timeHeader.Text = "Time"
	timeHeader.Parent = headerRow

	local ageHeader = Instance.new("TextLabel")
	ageHeader.Name = "AgeHeader"
	ageHeader.Size = UDim2.fromScale(0.5, 1)
	ageHeader.Position = UDim2.fromScale(0.5, 0)
	ageHeader.BackgroundTransparency = 1
	ageHeader.TextColor3 = colors.black
	ageHeader.TextScaled = true
	ageHeader.FontFace = fonts.GetFont(false, true)
	ageHeader.TextXAlignment = Enum.TextXAlignment.Center
	ageHeader.Text = "Run Age"
	ageHeader.Parent = headerRow

	local headerTimeConstraint = Instance.new("UITextSizeConstraint")
	headerTimeConstraint.MaxTextSize = 14
	headerTimeConstraint.Parent = timeHeader

	local headerAgeConstraint = Instance.new("UITextSizeConstraint")
	headerAgeConstraint.MaxTextSize = 14
	headerAgeConstraint.Parent = ageHeader

	local contentFrame = Instance.new("Frame")
	contentFrame.Name = "Content"
	contentFrame.Size = UDim2.new(1, 0, 0, 10 * popupRowHeight)
	contentFrame.BackgroundTransparency = 1
	contentFrame.LayoutOrder = 2
	contentFrame.Parent = popupFrame

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.FillDirection = Enum.FillDirection.Vertical
	contentLayout.Parent = contentFrame

	local cachedData = myRunsCache[cacheKey]
	if cachedData then
		local numRows = math.max(1, #cachedData.runs)
		local contentHeight = numRows * popupRowHeight
		contentFrame.Size = UDim2.new(1, 0, 0, contentHeight)
		popupFrame.Size = UDim2.fromOffset(popupWidth, titleHeight + headerHeight + contentHeight)
		popupFrame.Position = UDim2.fromOffset(anchorPos.X, anchorPos.Y + anchorSize.Y + 5)
		populateMyRunsContent(contentFrame, cachedData.runs)
		return
	end

	popupFrame.Size = UDim2.fromOffset(popupWidth, titleHeight + headerHeight + 30)
	popupFrame.Position = UDim2.fromOffset(anchorPos.X, anchorPos.Y + anchorSize.Y + 5)
	contentFrame.Size = UDim2.new(1, 0, 0, 30)

	local loadingLabel = Instance.new("TextLabel")
	loadingLabel.Name = "Loading"
	loadingLabel.Size = UDim2.new(1, 0, 0, 30)
	loadingLabel.BackgroundTransparency = 1
	loadingLabel.Text = "Loading..."
	loadingLabel.TextColor3 = colors.black
	loadingLabel.TextScaled = true
	loadingLabel.FontFace = fonts.GetFont(false, false)
	loadingLabel.LayoutOrder = 1
	loadingLabel.Parent = contentFrame

	task.spawn(function()
		local response: tt.getUserRunsForRaceResponse = GenericClientUIFunction:InvokeServer({
			eventKind = "getUserRunsForRaceRequest",
			data = {
				startSignId = startSignId,
				endSignId = endSignId,
				limit = 10,
			},
		})

		myRunsCache[cacheKey] = response

		if not popupGui.Parent then
			return
		end

		loadingLabel:Destroy()

		if response and response.runs then
			local numRows = math.max(1, #response.runs)
			local contentHeight = numRows * popupRowHeight
			contentFrame.Size = UDim2.new(1, 0, 0, contentHeight)
			popupFrame.Size = UDim2.fromOffset(popupWidth, titleHeight + headerHeight + contentHeight)
			populateMyRunsContent(contentFrame, response.runs)
		end
	end)
end

-- Hides the popup
function module.HidePopup()
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	local existingPopup = playerGui:FindFirstChild("MyRunsPopup")
	if existingPopup then
		existingPopup:Destroy()
	end
end

-- Clears the cache (call when parent GUI is destroyed)
function module.ClearCache()
	myRunsCache = {}
end

-- Sets up hover behavior on a TextLabel to show/hide the popup
function module.SetupHover(textLabel: TextLabel, startSignId: number, endSignId: number)
	local hoverConnection: RBXScriptConnection? = nil
	local leaveConnection: RBXScriptConnection? = nil

	hoverConnection = textLabel.MouseEnter:Connect(function()
		module.ShowPopup(startSignId, endSignId, textLabel)
	end)

	leaveConnection = textLabel.MouseLeave:Connect(function()
		module.HidePopup()
	end)

	textLabel.AncestryChanged:Connect(function(_, parent)
		if not parent then
			if hoverConnection then
				hoverConnection:Disconnect()
			end
			if leaveConnection then
				leaveConnection:Disconnect()
			end
			module.ClearCache()
		end
	end)
end

_annotate("end")
return module

