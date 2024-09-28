--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local colors = require(game.ReplicatedStorage.util.colors)
local leaderboardEnums = require(game.StarterPlayer.StarterCharacterScripts.lb.leaderboardEnums)
local lt = require(game.StarterPlayer.StarterCharacterScripts.lb.leaderboardTypes)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local textUtil = require(game.ReplicatedStorage.util.textUtil)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local warper = require(game.StarterPlayer.StarterPlayerScripts.warper)
local module = {}

------------------FUNCTIONS--------------
module.CalculateCellWidths = function(enabledDescriptors): { [string]: number }
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
	local headerRow = Instance.new("Frame")
	headerRow.BorderMode = Enum.BorderMode.Inset
	headerRow.BorderSizePixel = 1
	headerRow.Name = "LeaderboardHeaderRow"
	headerRow.Size = UDim2.new(1, 0, 0, headerRowYOffsetFixed)
	headerRow.BackgroundColor3 = colors.greenGo
	headerRow.BackgroundTransparency = 0.2
	local hh = Instance.new("UIListLayout")
	hh.FillDirection = Enum.FillDirection.Horizontal
	hh.Parent = headerRow
	hh.Name = "HeaderRow-hh"

	local cellWidths = module.CalculateCellWidths(enabledDescriptors)

	for _, lbUserCellDescriptor: lt.lbColumnDescriptor in pairs(leaderboardEnums.LbColumnDescriptors) do
		if not enabledDescriptors[lbUserCellDescriptor.name] then
			continue
		end
		local thisCellScale = cellWidths[lbUserCellDescriptor.name]

		local elb = guiUtil.getTb(
			string.format("%02d.header.%s", lbUserCellDescriptor.num, lbUserCellDescriptor.userFacingName),
			UDim2.fromScale(thisCellScale, 1),
			2,
			headerRow,
			colors.defaultGrey,
			0
		)

		elb.Text = lbUserCellDescriptor.userFacingName
		elb.ZIndex = lbUserCellDescriptor.num
		elb.TextXAlignment = Enum.TextXAlignment.Center
		elb.TextYAlignment = Enum.TextYAlignment.Center
		elb.TextScaled = true

		local keyHolder = Instance.new("StringValue")
		keyHolder.Name = "key"
		keyHolder.Value = lbUserCellDescriptor.name
		keyHolder.Parent = elb
	end

	return headerRow
end

local localPlayer = game.Players.LocalPlayer

module.DrawRaceWarper = function(rowFrame: Frame, newPinnedRaceRawValue: string)
	local oldChild = rowFrame:FindFirstChildOfClass("TextButton")
	if oldChild and oldChild ~= nil then
		oldChild:Destroy()
	end
	if newPinnedRaceRawValue == nil or newPinnedRaceRawValue == "" then
		local tb = Instance.new("TextButton")
		tb.Text = ""
		tb.Parent = rowFrame
		return
	end
	local parts = textUtil.stringSplit(newPinnedRaceRawValue, "-")
	local signId1 = tonumber(parts[1])
	local signId2 = tonumber(parts[2])
	local signName1 = tpUtil.signId2signName(signId1)
	local signName2 = tpUtil.signId2signName(signId2)

	if not signName1 or not signName2 or signName1 == "" or signName2 == "" then
		local tb = Instance.new("TextButton")
		tb.Text = ""
		tb.Parent = rowFrame
		return
	end
	local warpCellName = string.format("9999_%s_warper_%s-%s", localPlayer.Name, signName1, signName2)
	local warp = guiUtil.getTb(warpCellName, UDim2.new(1, 0, 1, 0), 1, rowFrame, colors.lightBlue, 1)
	warp.Text = string.format("%s-%s", signName1, signName2)

	warp.Activated:Connect(function()
		warper.WarpToSignId(signId1, signId2)
	end)
end

_annotate("end")
return module
