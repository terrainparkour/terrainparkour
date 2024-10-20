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

local localPlayer = game:GetService("Players").LocalPlayer

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

module.DrawRaceWarper = function(rowFrame: Frame, newPinnedRaceRawValue: string)
	local oldChild: TextButton | nil = rowFrame:FindFirstChildOfClass("TextButton")
	if oldChild then
		oldChild:Destroy()
	end
	if newPinnedRaceRawValue == nil or newPinnedRaceRawValue == "" then
		LLMGeneratedUIFunctions.createTextButton({
			Text = "",
			Parent = rowFrame,
		})
		return
	end
	local parts = textUtil.stringSplit(newPinnedRaceRawValue, "-")
	local signId1 = tonumber(parts[1])
	local signId2 = tonumber(parts[2])
	local signName1 = tpUtil.signId2signName(signId1)
	local signName2 = tpUtil.signId2signName(signId2)

	if not signName1 or not signName2 or signName1 == "" or signName2 == "" or signId1 == nil then
		LLMGeneratedUIFunctions.createTextButton({
			Text = "",
			Parent = rowFrame,
		})
		return
	end
	local warpCellName = string.format("9999_%s_warper_%s-%s", localPlayer.Name, signName1, signName2)
	local warp = LLMGeneratedUIFunctions.createTextButton({
		Name = warpCellName,
		Size = UDim2.new(1, 0, 1, 0),
		Parent = rowFrame,
		BackgroundColor3 = colors.lightBlue,
		BackgroundTransparency = 0,
		Text = string.format("%s-%s", signName1, signName2),
	})

	warp.Activated:Connect(function()
		warper.WarpToSignId(signId1, signId2)
	end)
end

_annotate("end")
return module
