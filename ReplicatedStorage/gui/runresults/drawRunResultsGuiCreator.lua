--!strict

-- DrawRunResultsGuiCreator: Creates the race result UI for player localscripts
-- Used locally

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local emojis = require(game.ReplicatedStorage.enums.emojis)
local colors = require(game.ReplicatedStorage.util.colors)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local thumbnails = require(game.ReplicatedStorage.thumbnails)
local enums = require(game.ReplicatedStorage.util.enums)
local settings = require(game.ReplicatedStorage.settings)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local warper = require(game.StarterPlayer.StarterPlayerScripts.warper)
local tt = require(game.ReplicatedStorage.types.gametypes)
local TweenService = game:GetService("TweenService")
local LLMGeneratedUIFunctions = require(game.ReplicatedStorage.gui.menu.LLMGeneratedUIFunctions)

local remotes = require(game.ReplicatedStorage.util.remotes)

-- local GenericClientUIEvent = remotes.getRemoteEvent("GenericClientUIEvent")
local GenericClientUIFunction = remotes.getRemoteFunction("GenericClientUIFunction")

local codeFont = Font.new("Code", Enum.FontWeight.Bold)
local codeFontLight = Font.new("Code")

local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)

------------------------- live-monitor this setting value. -------------
local userWantsHighlightingWhenWarpingFromRunResults = false

--global counter for this "class"
local rowCount = 1

local module = {}

-- Add this near the top of the file, after the imports
local heightsPixel = {
	race = 40,
	text = 25,
	row = 32,
	warp = 43,
	wrProgression = 30,
	closeButton = 40,
}

--[[
    Creates a row with chips (small text elements) for displaying player and race information.
    The first set of chips (mechips) uses the meColor, while the second set (otherChips) uses the bgcolor.
    This function is typically used to display player-specific information alongside general race data.
]]
local function addChippedRow(allChips: { tt.runChip }, parent: Frame, height: number, name: string): Frame
	rowCount += 1
	return LLMGeneratedUIFunctions.createChippedRow(allChips, {
		Parent = parent,
		Size = UDim2.new(1, 0, 0, height),
		Name = string.format("%02d-%s", rowCount, name),
	})
end

local function addTimeRow(yourText, timeText, parent, height, name)
	rowCount += 1
	local frame = Instance.new("Frame")
	frame.Parent = parent
	frame.Size = UDim2.new(1, 0, 0, height)
	frame.Name = string.format("%02d-%s", rowCount, name)

	local hh = Instance.new("UIListLayout")
	hh.Parent = frame
	hh.FillDirection = Enum.FillDirection.Horizontal

	local yourTextTl = guiUtil.getTl("02yourText", UDim2.new(0.8, 0, 1, 0), 2, frame, colors.meColor, 1, 0)
	yourTextTl.Text = yourText
	local timeTextTl = guiUtil.getTl("01timeText", UDim2.new(0.2, 0, 1, 0), 2, frame, colors.meColor, 1, 0)
	timeTextTl.FontFace = codeFont
	timeTextTl.Text = timeText
end

--actually more like addCell with optional text.
local function addRow(
	text: string,
	parent: Frame,
	height: number,
	name: string,
	bgcolor: Color3?,
	descriptor: string?,
	textcolor: Color3?,
	backgroundTransparency: number
): Frame
	rowCount += 1

	local frame = LLMGeneratedUIFunctions.createFrame({
		Parent = parent,
		Size = UDim2.new(1, 0, 0, height),
		Name = string.format("%02d-%s", rowCount, name),
		BackgroundColor3 = bgcolor or colors.defaultGrey,
		BackgroundTransparency = backgroundTransparency,
	})

	LLMGeneratedUIFunctions.createTextLabel({
		Parent = frame,
		Text = text,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = bgcolor or colors.defaultGrey,
		BackgroundTransparency = backgroundTransparency,
		TextColor3 = textcolor or colors.black,
		FontFace = descriptor == "mono" and codeFont or Font.new("SourceSans"),
		TextXAlignment = descriptor == "mono" and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center,
	})

	return frame
end

--used for adding subrows to the stop score list in a high score viewer.
local function addPlayerPastResultRow(parent: Frame, runEntry: tt.runEntry, useColor: Color3)
	rowCount += 1

	local hh = Instance.new("UIListLayout")
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, heightsPixel.row)
	frame.Name = string.format("%02d-PlayerResults", rowCount)
	frame.Parent = parent
	hh.Parent = frame
	hh.FillDirection = Enum.FillDirection.Horizontal

	--this depends on semi-broken BE behavior about virtualized places, etc.
	local placeTl = guiUtil.getTl(tostring("1place"), UDim2.new(0.12, -10, 1, 0), 2, frame, useColor, 1)
	if runEntry.place == 0 then
		placeTl.Text = "-"
	else
		placeTl.Text = tostring(runEntry.place)
	end
	if runEntry.place == 11 then
		placeTl.Text = "KO " .. emojis.emojis.BOMB
	end
	placeTl.TextXAlignment = Enum.TextXAlignment.Center

	-- Replace the existing thumbnail code with createAvatarPortraitPopup
	local portraitCell = thumbnails.createAvatarPortraitPopup(runEntry.userId, frame)
	portraitCell.Size = UDim2.new(0, heightsPixel.row, 1, 0)
	portraitCell.Name = "2.runresult.PortraitCell"

	--username
	local nameTl = guiUtil.getTl("3username", UDim2.new(0.60, -10, 1, 0), 2, frame, useColor, 0)
	nameTl.Text = runEntry.username
	nameTl.TextXAlignment = Enum.TextXAlignment.Left
	nameTl.TextYAlignment = Enum.TextYAlignment.Center

	--time
	local timeTl = guiUtil.getTl("4time", UDim2.new(0.28, -12, 1, 0), 2, frame, useColor, 1)
	timeTl.Text = tpUtil.fmtms(runEntry.runMilliseconds)
	timeTl.TextXAlignment = Enum.TextXAlignment.Right
	timeTl.FontFace = codeFontLight

	-- Add tooltip for run age
	local formattedRunAge, _ageDescriptor = LLMGeneratedUIFunctions.formatDateGap(runEntry.runAgeSeconds)
	local tooltipText = string.format("Run age: %s", formattedRunAge)
	local toolTip = require(game.ReplicatedStorage.gui.toolTip)
	toolTip.setupToolTip(timeTl, tooltipText, toolTip.enum.toolTipSize.NormalText)
end

--sgui for the results of running a race OR a marathon!.

-- Add this function near the top of the file, after the imports
local function requestWRProgression(startSignId: number, endSignId: number)
	local success = GenericClientUIFunction:InvokeServer({
		eventKind = "wrProgressionRequest",
		data = {
			startSignId = startSignId,
			endSignId = endSignId,
		},
	})

	if not success then
		warn("Failed to request WR progression")
	end
end

-- Replace the existing createCombinedButtonRow function with this updated version
local function createCombinedButtonRow(frame: Frame, options: tt.dcRunResponse, raceResultSgui: ScreenGui)
	local combinedRow = Instance.new("Frame")
	combinedRow.Name = "CombinedButtonRow"
	combinedRow.Size = UDim2.new(1, 0, 0, heightsPixel.warp)
	combinedRow.BackgroundTransparency = 1
	combinedRow.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 0)
	layout.Parent = combinedRow

	-- Close button
	local closeButton = LLMGeneratedUIFunctions.createTextButton({
		Name = "CloseButton",
		Size = UDim2.new(1 / 3, 0, 1, 0),
		Text = "Close",
		TextColor3 = colors.black,
		BackgroundColor3 = colors.redStop,
		TextScaled = true,
		Font = Enum.Font.SourceSansBold,
		Parent = combinedRow,
	})

	LLMGeneratedUIFunctions.addTextSizeConstraint(closeButton, 24)

	closeButton.MouseButton1Click:Connect(function()
		raceResultSgui:Destroy()
	end)

	-- WR Progression button
	local wrButton = LLMGeneratedUIFunctions.createTextButton({
		Name = "WRProgressionButton",
		Size = UDim2.new(1 / 3, 0, 1, 0),
		Text = "WR Progression",
		TextColor3 = colors.black,
		BackgroundColor3 = colors.lightOrangeWRProgression,
		TextScaled = true,
		Font = Enum.Font.SourceSansBold,
		Parent = combinedRow,
	})

	LLMGeneratedUIFunctions.addTextSizeConstraint(wrButton, 24)

	wrButton.MouseButton1Click:Connect(function()
		_annotate(string.format("User %s clicked 'See WR progression' for race %s", options.username, options.raceName))
		requestWRProgression(options.startSignId, options.endSignId)
	end)

	-- Warp back button
	local warpButton = LLMGeneratedUIFunctions.createTextButton({
		Name = "WarpBackButton",
		Size = UDim2.new(1 / 3, 0, 1, 0),
		Text = "Warp",
		TextColor3 = colors.black,
		BackgroundColor3 = colors.lightBlue,
		TextScaled = true,
		Font = Enum.Font.SourceSansBold,
		Parent = combinedRow,
	})

	LLMGeneratedUIFunctions.addTextSizeConstraint(warpButton, 24)

	if options.startSignId and options.kind ~= "marathon results" then
		local startSign = tpUtil.signId2Sign(options.startSignId)
		if tpUtil.SignCanBeHighlighted(startSign) then
			local signName = enums.signId2name[options.startSignId]
			warpButton.Text = string.format("Warp to %s", signName)

			warpButton.MouseButton1Click:Connect(function()
				local useLastRunEnd = nil
				if userWantsHighlightingWhenWarpingFromRunResults then
					local endSign = tpUtil.signId2Sign(options.endSignId)
					if tpUtil.SignCanBeHighlighted(endSign) then
						useLastRunEnd = options.endSignId
					end
				end
				warper.WarpToSignId(options.startSignId, useLastRunEnd)
			end)
		else
			warpButton.BackgroundTransparency = 0.5
			warpButton.TextTransparency = 0.5
			warpButton.Active = false
		end
	else
		warpButton.BackgroundTransparency = 0.5
		warpButton.TextTransparency = 0.5
		warpButton.Active = false
	end

	return combinedRow
end

module.DrawRunResultsGui = function(options: tt.dcRunResponse): ScreenGui
	rowCount = 0
	options.userId = tonumber(options.userId) :: number
	local raceResultSgui = Instance.new("ScreenGui")
	raceResultSgui.Name = string.format("RaceResultSgui-%s", options.raceName)
	raceResultSgui.IgnoreGuiInset = true
	local raceResultFrameName = string.format("raceResultFrame%s", options.raceName)

	-- Create the window frame
	local windowFrames = windows.SetupFrame(raceResultFrameName, true, true, true)
	local frame: Frame = windowFrames.contentFrame
	local outerFrame: Frame = windowFrames.outerFrame

	outerFrame.Parent = raceResultSgui
	outerFrame.Position = UDim2.new(0.72, -5, 0.18, 0)

	local layout = LLMGeneratedUIFunctions.createLayout("UIListLayout", frame, {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 0),
	})

	-- Initialize totalHeight
	local totalHeight = 0

	-- Add content
	-- Replace the existing addRow call with this new function call
	local titleFrame = LLMGeneratedUIFunctions.createTitleRow(options.raceName, {
		Name = "TitleFrame",
		Size = UDim2.new(1, 0, 0, heightsPixel.race),
		BackgroundColor3 = colors.signColor,
		TextColor3 = colors.signTextColor,
		MaxTextSize = 24,
		Parent = frame,
	})
	totalHeight += titleFrame.AbsoluteSize.Y

	addTimeRow(
		options.yourText,
		string.format("%0.3fs", options.runMilliseconds / 1000),
		frame,
		heightsPixel.text,
		"timeRelatedRow"
	)
	totalHeight += heightsPixel.text

	-- Keep the existing logic for creating orderedRunChips
	local orderedRunChips: { tt.runChip } = {}

	local meRuns = string.format("You've run %d times", options.userRaceRunCount)
	if options.userRaceRunCount == 1 then
		meRuns = "You've run once"
	end
	table.insert(orderedRunChips, { text = meRuns, bgcolor = colors.meColor })

	local racers = string.format("%d racers", options.totalRacersOfThisRaceCount)
	if options.totalRacersOfThisRaceCount == 1 then
		racers = "1 racer"
	end
	table.insert(orderedRunChips, { text = racers, bgcolor = colors.defaultGrey })

	-- Determine race level
	local raceLevel = "normal"
	if options.totalRacersOfThisRaceCount > 1000 then
		raceLevel = "mega"
	elseif options.totalRacersOfThisRaceCount > 100 then
		raceLevel = "competitive2"
	elseif options.totalRacersOfThisRaceCount > 10 then
		raceLevel = "competitive"
	end
	table.insert(orderedRunChips, { text = raceLevel, bgcolor = colors.defaultGrey })

	if options.totalRunsOfThisRaceCount ~= 1 then
		local otherRuns = string.format("%d runs", options.totalRunsOfThisRaceCount)
		table.insert(orderedRunChips, { text = otherRuns, bgcolor = colors.defaultGrey })
	end

	local dist = string.format("%0.1fd", options.distance)
	table.insert(orderedRunChips, { text = dist, bgcolor = colors.defaultGrey })

	if options.runMilliseconds > 0 then
		local spd = string.format("%0.1fd/s", options.distance / options.runMilliseconds * 1000)
		table.insert(orderedRunChips, { text = spd, bgcolor = colors.defaultGrey })
	end

	-- Use the shared function to create the header row with orderedRunChips
	LLMGeneratedUIFunctions.createHeaderChipsRow(orderedRunChips, {
		Parent = frame,
		Size = UDim2.new(1, 0, 0, heightsPixel.text),
		Name = string.format("%02d-HeaderChips", rowCount),
	})

	totalHeight += heightsPixel.text

	local hasShownYourLastRun = false
	local hasShownYourPastRun = false
	local hasShownYourBoth = false
	if options.runEntries == nil then
		warn("nil pbs.")
		options.runEntries = {}
	end
	for _, runEntry: tt.runEntry in ipairs(options.runEntries) do
		if runEntry.place == nil then
			warn("weirdly nil runentry. ")
			continue
		end

		local useColor = colors.defaultGrey
		if runEntry.userId == options.userId then
			if runEntry.kind == "past run" then
				useColor = colors.mePastColor
				hasShownYourPastRun = true
			else
				hasShownYourLastRun = true
				useColor = colors.meColor
			end
		end
		hasShownYourBoth = hasShownYourLastRun and hasShownYourPastRun
		--KO conditions: 10th place, AND I just entered the race (have current, no past)
		if runEntry.place == 11 then
			useColor = colors.redStop
		end

		--this has bugs and neeeds tests when you "knock" yourself out.
		if runEntry.place > 10 then
			if runEntry.userId == options.userId then
				runEntry.place = 0
			else
				--skip 11+ unless they've been pushed down.
				if
					(
						hasShownYourBoth --no knockouts can happen
						or (hasShownYourPastRun and not hasShownYourLastRun) --just show a blue past
						or (not hasShownYourLastRun and not hasShownYourPastRun) --show nothing
					) and runEntry.place == 11
				then
					continue
				end
			end
		end
		if runEntry.place > 11 then
			continue
		end

		addPlayerPastResultRow(frame, runEntry, useColor)
		totalHeight += heightsPixel.row
	end

	-- In the DrawRunResultGui function, replace the separate button creation code with:
	createCombinedButtonRow(frame, options, raceResultSgui)
	totalHeight += heightsPixel.warp

	-- Update the outerFrame size calculation:
	outerFrame.Size = UDim2.new(0.27, 0, 0, totalHeight)

	frame.BorderSizePixel = 4
	frame.BorderColor3 = colors.meColor
	local tween = TweenService:Create(frame, TweenInfo.new(2, Enum.EasingStyle.Linear), { BorderColor3 = colors.black })
	tween:Play()
	frame.MouseEnter:Connect(function()
		tween:Cancel()
		frame.BorderColor3 = colors.meColor
	end)

	frame.MouseLeave:Connect(function()
		tween:Cancel()
		frame.BorderColor3 = colors.black
	end)

	return raceResultSgui
end

local function handleUserSettingChanged(item: tt.userSettingValue)
	if item.name == settingEnums.settingDefinitions.HIGHLIGHT_ON_RUN_COMPLETE_WARP.name then
		userWantsHighlightingWhenWarpingFromRunResults = item.booleanValue or false
	end
	return
end

module.Init = function()
	_annotate("init")
	settings.RegisterFunctionToListenForSettingName(
		handleUserSettingChanged,
		settingEnums.settingDefinitions.HIGHLIGHT_ON_RUN_COMPLETE_WARP.name,
		"runResult"
	)

	local userSettingValue =
		settings.GetSettingByName(settingEnums.settingDefinitions.HIGHLIGHT_ON_RUN_COMPLETE_WARP.name)
	handleUserSettingChanged(userSettingValue)
	_annotate("init done")
end

_annotate("end")
return module
