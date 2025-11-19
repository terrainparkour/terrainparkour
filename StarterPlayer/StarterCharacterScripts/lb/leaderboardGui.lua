--!strict

-- leaderboardGui on client
-- drawing the LB rows and managing them

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local colors = require(game.ReplicatedStorage.util.colors)
local leaderboardEnums = require(game.StarterPlayer.StarterCharacterScripts.lb.leaderboardEnums)
local lt = require(game.StarterPlayer.StarterCharacterScripts.lb.leaderboardTypes)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local textUtil = require(game.ReplicatedStorage.util.textUtil)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local warper = require(game.StarterPlayer.StarterPlayerScripts.warper)
local LLMGeneratedUIFunctions = require(game.ReplicatedStorage.gui.menu.LLMGeneratedUIFunctions)
local drawFavoritesModal = require(game.ReplicatedStorage.gui.menu.drawFavoritesModal)
local PlayersService: Players = game:GetService("Players")
local tt = require(game.ReplicatedStorage.types.gametypes)

------------------FUNCTIONS--------------
module.CalculateCellWidths = function(enabledDescriptors: { [string]: boolean }): { [string]: number }
	local totalWidthWeightScale = 0
	local cellWidths: { [string]: number } = {}
	-- we add them up once, then use that for all rows.
	for _, lbUserCellDescriptor in pairs(leaderboardEnums.LbColumnDescriptors) do
		if enabledDescriptors[lbUserCellDescriptor.name] then
			totalWidthWeightScale += lbUserCellDescriptor.widthScaleImportance
		end
	end
	for _, lbUserCellDescriptor in pairs(leaderboardEnums.LbColumnDescriptors) do
		if enabledDescriptors[lbUserCellDescriptor.name] then
			cellWidths[lbUserCellDescriptor.name] = lbUserCellDescriptor.widthScaleImportance / totalWidthWeightScale
		end
	end
	_annotate("Cell widths", cellWidths)
	return cellWidths
end

--setup header row as first row in lbframe
module.MakeLeaderboardHeaderRow = function(enabledDescriptors: { [string]: boolean }, headerRowYOffsetFixed): Frame
	local headerRow = LLMGeneratedUIFunctions.createFrame({
		BorderMode = Enum.BorderMode.Inset,
		BorderSizePixel = 1,
		Name = "LeaderboardHeaderRow",
		Size = UDim2.new(1, 0, 0, math.min(headerRowYOffsetFixed, 80)),
		BackgroundColor3 = colors.greenGo,
		BackgroundTransparency = 0.2,
	})

	local listLayout = LLMGeneratedUIFunctions.createLayout("UIListLayout", headerRow, {
		FillDirection = Enum.FillDirection.Horizontal,
		Name = "HeaderRow-hh",
	})

	local uiScale = Instance.new("UIScale")
	uiScale.Parent = headerRow

	local cellWidths = module.CalculateCellWidths(enabledDescriptors)

	for _, lbUserCellDescriptor: lt.lbColumnDescriptor in pairs(leaderboardEnums.LbColumnDescriptors) do
		if not enabledDescriptors[lbUserCellDescriptor.name] then
			continue
		end
		local thisCellScale = cellWidths[lbUserCellDescriptor.name]

		local elb = LLMGeneratedUIFunctions.createTextLabel({
			Name = string.format("%02d.header.%s", lbUserCellDescriptor.num, lbUserCellDescriptor.userFacingName),
			Size = UDim2.fromScale(thisCellScale, 1),
			Parent = headerRow,
			BackgroundColor3 = colors.defaultGrey,
			BackgroundTransparency = 0,
			Text = lbUserCellDescriptor.userFacingName,
			ZIndex = lbUserCellDescriptor.num,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextScaled = true,
		})

		LLMGeneratedUIFunctions.addTextSizeConstraint(elb, 18)

		local keyHolder = Instance.new("StringValue")
		keyHolder.Name = "key"
		keyHolder.Value = lbUserCellDescriptor.name
		keyHolder.Parent = elb
	end

	-- Adjust UIScale to fit content within 80 pixel height
	local function updateUIScale()
		local contentSize = headerRow.AbsoluteSize
		if contentSize.Y > 80 then
			uiScale.Scale = 80 / contentSize.Y
		else
			uiScale.Scale = 1
		end
	end

	-- Connect the function to the appropriate signals
	headerRow:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateUIScale)
	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateUIScale)

	-- Initial call to set the correct scale
	updateUIScale()

	return headerRow
end

module.DrawRaceWarper = function(rowFrame: Frame | nil, change: tt.leaderboardUserDataChange)
	if rowFrame == nil then
		return
	end

	local oldCell = rowFrame:FindFirstChild("Inner")
	if oldCell then
		oldCell:Destroy()
	end
	local newPinnedRaceRawValue: string = change.newValue :: string

	if newPinnedRaceRawValue == nil or newPinnedRaceRawValue == "" then
		guiUtil.getTl("Inner", UDim2.fromScale(1, 1), 2, rowFrame, colors.defaultGrey, 1, 0)
		return
	end

	local parts = textUtil.stringSplit(newPinnedRaceRawValue, "-")
	local signId1 = tonumber(parts[1])
	local signId2 = tonumber(parts[2])
	local signName1 = tpUtil.signId2signName(signId1)
	local signName2 = tpUtil.signId2signName(signId2)

	if not signName1 or not signName2 or signName1 == "" or signName2 == "" or signId1 == nil then
		guiUtil.getTl("Inner", UDim2.fromScale(1, 1), 2, rowFrame, colors.defaultGrey, 1, 0)
		return
	end

	local innerFrame = guiUtil.getTl("Inner", UDim2.fromScale(1, 1), 2, rowFrame, colors.warpColor, 1, 0)
	local displayText = string.format("%s-%s", signName1, signName2)
	innerFrame.Text = displayText
	innerFrame.TextScaled = true
	innerFrame.RichText = true
	innerFrame.TextWrapped = true

	local warpButton = Instance.new("TextButton")
	warpButton.Name = "WarpButton"
	warpButton.Size = UDim2.fromScale(1, 1)
	warpButton.BackgroundTransparency = 1
	warpButton.Text = ""
	warpButton.Parent = innerFrame

	warpButton.Activated:Connect(function()
		warper.WarpToSignId(signId1, signId2)
	end)
end

module.DrawShowFavoriteRacesButton = function(
	rowFrame: Frame,
	change: tt.leaderboardUserDataChange,
	targetUserId: number,
	requestingUserId: number
)
	_annotate("calling show favorite racesbutton.")
	local newFavoriteRaceCount: number = change.newValue :: number

	local oldCell = rowFrame:FindFirstChild("070.favs")
	if oldCell then
		oldCell:Destroy()
	end

	local innerFrame = guiUtil.getTl("070.favs", UDim2.fromScale(1, 1), 2, rowFrame, colors.defaultGrey, 1, 0)
	innerFrame.Text = string.format("%d Favs", newFavoriteRaceCount)
	innerFrame.TextScaled = true

	local fb = Instance.new("TextButton")
	fb.Name = string.format("ShowFavoritesButtonFor_%d", targetUserId)
	fb.Size = UDim2.fromScale(1, 1)
	fb.BackgroundTransparency = 1
	fb.Text = ""
	fb.Parent = innerFrame

	local otherUserIds = {}
	for _, oplayer in ipairs(PlayersService:GetPlayers()) do
		if oplayer.UserId ~= targetUserId and oplayer.UserId ~= requestingUserId then
			table.insert(otherUserIds, oplayer.UserId)
		end
	end

	fb.Activated:Connect(function()
		drawFavoritesModal.DrawFavoriteRacesModal(targetUserId, requestingUserId, otherUserIds)
	end)
end

_annotate("end")
return module
