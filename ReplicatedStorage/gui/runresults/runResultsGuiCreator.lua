--!strict

--player localscripts call this to generate a raceresult UI.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local emojis = require(game.ReplicatedStorage.enums.emojis)
local colors = require(game.ReplicatedStorage.util.colors)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local thumbnails = require(game.ReplicatedStorage.thumbnails)
local enums = require(game.ReplicatedStorage.util.enums)
local localFunctions = require(game.ReplicatedStorage.localFunctions)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local warper = require(game.StarterPlayer.StarterPlayerScripts.warper)

local tt = require(game.ReplicatedStorage.types.gametypes)
local TweenService = game:GetService("TweenService")

local codeFont = Font.new("Code", Enum.FontWeight.Bold)
local codeFontLight = Font.new("Code")

------------------------- live-monitor this setting value. -------------
local userWantsHighlightingWhenWarpingFromRunResults = false

--global counter for this "class"
local rowCount = 1

local module = {}

local heightsPixel = { race = 40, text = 25, row = 32, warp = 43 }

local function addChippedRow(mechips, otherChips, parent, height, name, bgcolor)
	rowCount += 1
	local frame = Instance.new("Frame")
	frame.Parent = parent
	frame.Size = UDim2.new(1, 0, 0, height)
	frame.Name = string.format("%02d-%s", rowCount, name)

	local hh = Instance.new("UIListLayout")
	hh.Parent = frame
	hh.FillDirection = Enum.FillDirection.Horizontal
	local w = 1 / (#mechips + #otherChips)

	for cn, chunk in ipairs({ mechips, otherChips }) do
		if cn == 1 then
			bgcolor = colors.meColor
		else
			bgcolor = colors.defaultGrey
		end
		for ii, chip in ipairs(chunk) do
			if chip == nil or chip == "" then
				warn("chip")
				continue
			end
			local tl = guiUtil.getTl(tostring(ii), UDim2.new(w, 0, 1, 0), 3, frame, bgcolor, 1, 0)
			tl.Text = chip
		end
	end
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
	textcolor: Color3?
): Frame
	rowCount += 1

	if textcolor == nil then
		textcolor = colors.black
	end
	if bgcolor == nil then
		bgcolor = colors.defaultGrey
	end
	assert(bgcolor)

	local frame = Instance.new("Frame")
	frame.Parent = parent
	frame.Size = UDim2.new(1, 0, 0, height)
	frame.Name = string.format("%02d-%s", rowCount, name)

	if text == nil or text == "" then
		warn("text.")
	end

	local tl: TextLabel
	if descriptor == "mono" then
		tl = guiUtil.getTl("01" .. text, UDim2.new(1, 0, 1, 0), 2, frame, bgcolor, 1)
		tl.FontFace = codeFont
		tl.TextXAlignment = Enum.TextXAlignment.Left
	else
		tl = guiUtil.getTl("01" .. text, UDim2.new(1, 0, 1, 0), 4, frame, bgcolor, 1)
		tl.TextXAlignment = Enum.TextXAlignment.Center
	end
	tl.Text = text
	tl.TextColor3 = textcolor
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

	--thumb

	local img = Instance.new("ImageLabel")
	img.BorderMode = Enum.BorderMode.Inset
	img.Name = "2.runresult.Image"
	img.Size = UDim2.new(0, heightsPixel.row, 1, 0)
	local content = thumbnails.getThumbnailContent(runEntry.userId, Enum.ThumbnailType.HeadShot)
	img.Image = content
	img.BackgroundColor3 = useColor
	img.BorderSizePixel = 0
	img.Parent = frame

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
end

--sgui for the results of running a race OR a marathon!.

module.createNewRunResultSgui = function(options: tt.pyUserFinishedRunResponse): ScreenGui
	rowCount = 0
	options.userId = tonumber(options.userId) :: number
	local raceResultSgui = Instance.new("ScreenGui")
	raceResultSgui.Name = string.format("RaceResultSgui-%s", options.raceName)

	local raceResultFrameName = string.format("raceResultFrame%s", options.raceName)
	local frame: Frame = Instance.new("Frame")
	frame.Name = raceResultFrameName
	frame.Parent = raceResultSgui
	--the used framesize; will be expanded later.
	frame.Position = UDim2.new(0.72, -5, 0.18, 0)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Name = "UIListLayoutV"
	layout.Parent = frame

	addRow(options.raceName, frame, heightsPixel.race, "raceName", colors.signColor, nil, colors.white)

	addTimeRow(
		options.yourText,
		string.format("%0.3fs", options.thisRunMilliseconds / 1000),
		frame,
		heightsPixel.text,
		"timeRelatedRow"
	)

	--run details.

	local meRuns = string.format("You've run %d times", options.userRaceRunCount)
	if options.userRaceRunCount == 1 then
		meRuns = string.format("You've run once")
	end

	--we add an appelation to a race depending on how many total racers it has.
	local raceLevel = ""
	if options.totalRacersOfThisRaceCount == 0 then
		raceLevel = " (new)"
	elseif options.totalRacersOfThisRaceCount > 10 then
		raceLevel = " (c)"
	elseif options.totalRacersOfThisRaceCount > 100 then
		raceLevel = " (c2)"
	elseif options.totalRacersOfThisRaceCount > 1000 then
		raceLevel = " (mega)"
	end

	local racers = string.format("%d racers%s", options.totalRacersOfThisRaceCount, raceLevel)

	if options.totalRacersOfThisRaceCount == 1 then
		racers = string.format("%d racer", options.totalRacersOfThisRaceCount)
	end

	local otherChipTexts = {}
	if options.totalRunsOfThisRaceCount ~= 1 then
		local otherRuns = string.format("%d runs", options.totalRunsOfThisRaceCount)
		table.insert(otherChipTexts, otherRuns)
	end
	table.insert(otherChipTexts, racers)
	local dist = string.format("%0.1fd", options.distance)
	table.insert(otherChipTexts, dist)

	if options.thisRunMilliseconds > 0 then
		local spd = string.format("%0.1fd/s", options.distance / options.thisRunMilliseconds * 1000)
		table.insert(otherChipTexts, spd)
	end

	addChippedRow({ meRuns }, otherChipTexts, frame, heightsPixel.text, "Comparisons", colors.meColor)

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
	end

	local signName = enums.signId2name[options.startSignId]
	local warpRow: Frame = nil
	--we will display a button to warp back to startId
	if signName ~= nil then
		local bad = false
		for _, badname in ipairs(enums.ExcludeSignNamesFromStartingAt) do
			if badname == signName then
				bad = true
				break
			end
		end
		if not bad then
			local uis = game:GetService("UserInputService")
			local mobileText = ""
			if uis.KeyboardEnabled then
				mobileText = " [1]"
			end

			warpRow = addRow(
				string.format("Warp back to %s%s", signName, mobileText),
				frame,
				heightsPixel.warp,
				"warpRow",
				colors.lightBlue
			)
			local useLastRunEnd = nil
			if userWantsHighlightingWhenWarpingFromRunResults then
				useLastRunEnd = options.endSignId
			end
			local invisibleTextButton = Instance.new("TextButton")
			invisibleTextButton.Position = warpRow.Position
			invisibleTextButton.Size = UDim2.new(1, 0, 1, 0)
			invisibleTextButton.Transparency = 1.0
			invisibleTextButton.Text = "warp"
			invisibleTextButton.TextScaled = true
			invisibleTextButton.ZIndex = 20
			invisibleTextButton.Parent = warpRow
			invisibleTextButton.Activated:Connect(function()
				warper.WarpToSign(options.startSignId, useLastRunEnd)
			end)
		end
	end

	local ypix = 0
	for _, el: Frame in ipairs(frame:GetChildren()) do
		if el:IsA("Frame") then
			ypix += el.Size.Y.Offset
		end
	end

	frame.Size = UDim2.new(0.27, 0, 0, ypix)
	guiUtil.setupKillOnClick(raceResultSgui, nil, warpRow)
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

local function handleUserSettingChanged(item: tt.userSettingValue): any
	userWantsHighlightingWhenWarpingFromRunResults = item.value
end

localFunctions.registerLocalSettingChangeReceiver(
	handleUserSettingChanged,
	settingEnums.settingNames.HIGHLIGHT_ON_RUN_COMPLETE_WARP
)

local userSettingValue = localFunctions.getSettingByName(settingEnums.settingNames.HIGHLIGHT_ON_RUN_COMPLETE_WARP)
handleUserSettingChanged(userSettingValue)

_annotate("end")
return module
