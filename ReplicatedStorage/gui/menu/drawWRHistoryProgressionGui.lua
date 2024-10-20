--!strict

-- this is the companion to the serverside command: WRProgressionCommand!
-- there is a unified rpc name which clients can send as well as server. the next version is runResults

local tt = require(game.ReplicatedStorage.types.gametypes)
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local colors = require(game.ReplicatedStorage.util.colors)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local thumbnails = require(game.ReplicatedStorage.thumbnails)
local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)
local LLMGeneratedUIFunctions = require(game.ReplicatedStorage.gui.menu.LLMGeneratedUIFunctions)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)

local warper = require(game.StarterPlayer.StarterPlayerScripts.warper)
local settings = require(game.ReplicatedStorage.settings)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local userWantsHighlightingWhenWarpingFromRunResults = true
local PlayersService = game:GetService("Players")
local localPlayer = PlayersService.LocalPlayer

local module = {}

-- Add these global variables for text size constraints
local globalTextSize = 16
local globalMinTextSize = 8
local globalMaxTextSize = 24
local globalFixedWidthFontSize = 26
local rowHeightPixels = 45

local wrProgressionDataTableHeaders: { tt.headerDefinition } = {
	{ text = "Best Time", width = 0.15, order = 1, isMonospaced = true, TextXAlignment = Enum.TextXAlignment.Right },
	{ text = "Improvement", width = 0.15, order = 2, isMonospaced = true, TextXAlignment = Enum.TextXAlignment.Right },
	{ text = "Username", width = 0.30, order = 3, isMonospaced = false, TextXAlignment = Enum.TextXAlignment.Right },
	{
		text = "Portrait",
		width = rowHeightPixels,
		order = 4,
		isMonospaced = false,
		TextXAlignment = Enum.TextXAlignment.Center,
	},
	{ text = "Lasted", width = 0.20, order = 5, isMonospaced = true, TextXAlignment = Enum.TextXAlignment.Right },
	{ text = "Date Set", width = 0.20, order = 6, isMonospaced = true, TextXAlignment = Enum.TextXAlignment.Center },
}

-- Use the imported functions
local createUIElement = LLMGeneratedUIFunctions.createUIElement
local createTextLabel = LLMGeneratedUIFunctions.createTextLabel
local createImageLabel = LLMGeneratedUIFunctions.createImageLabel
local createFrame = LLMGeneratedUIFunctions.createFrame
local createLayout = LLMGeneratedUIFunctions.createLayout
local createScrollingFrame = LLMGeneratedUIFunctions.createScrollingFrame
local createButton = LLMGeneratedUIFunctions.createButton

-- Add this near the top of the file, with the other imports
local remotes = require(game.ReplicatedStorage.util.remotes)
local GenericClientUIEvent = remotes.getRemoteEvent("GenericClientUIEvent")
local GenericClientUIFunction = remotes.getRemoteFunction("GenericClientUIFunction")

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

local function requestRunResults(startSignId: number, endSignId: number)
	local success = GenericClientUIFunction:InvokeServer({
		eventKind = "runResultsRequest",
		data = {
			userId = localPlayer.UserId,
			startSignId = startSignId,
			endSignId = endSignId,
		},
	})

	if not success then
		warn("Failed to request RunResult")
	end
end

local function getMaxDecimalPlaces(numbers: { number }): number
	local maxDecimals = 0
	for _, num in ipairs(numbers) do
		local _, fractionalPart = math.modf(num)
		local decimals = 0
		if fractionalPart ~= 0 then
			decimals = math.min(#tostring(fractionalPart) - 2, 3) -- Subtract 2 for "0.", max 3 digits
		end
		maxDecimals = math.max(maxDecimals, decimals)
	end
	print("drawing decimals: ", maxDecimals, " probably should be at min 1?")
	return maxDecimals
end

local function getMaxIntegerDigits(numbers: { number }): number
	local maxDigits = 0
	for _, num in ipairs(numbers) do
		local integerPart = math.floor(num)
		local digits = #tostring(integerPart)
		maxDigits = math.max(maxDigits, digits)
	end
	return maxDigits
end

local function calculateColumnWidths(totalWidth: number): { number }
	local fixedWidth = 0
	local flexibleWidthTotal = 0
	local columnWidths = {}

	-- First pass: calculate total fixed width and total flexible width
	for _, header in ipairs(wrProgressionDataTableHeaders) do
		if type(header.width) == "number" then
			if header.width <= 1 then
				flexibleWidthTotal = flexibleWidthTotal + header.width
			else
				fixedWidth = fixedWidth + header.width
			end
		end
	end

	local remainingWidth = totalWidth - fixedWidth

	-- Second pass: calculate actual widths
	for _, header in ipairs(wrProgressionDataTableHeaders) do
		local width
		if type(header.width) == "number" then
			if header.width <= 1 then
				width = remainingWidth * (header.width / flexibleWidthTotal)
			else
				width = header.width
			end
		end
		table.insert(columnWidths, math.floor(width))
	end

	return columnWidths
end

local function createResponsiveHeader(header: tt.headerDefinition, parent: Instance, width: number)
	local headerLabel
	if header.text == "Portrait" then
		headerLabel = createImageLabel({
			Name = string.format("%02d", table.find(wrProgressionDataTableHeaders, header))
				.. "_Header_"
				.. header.text,
			Size = UDim2.new(0, width, 0, width), -- Make it square
			Parent = parent,
			BackgroundColor3 = colors.lightOrangeWRProgression,
		})
	else
		headerLabel = createTextLabel({
			Name = string.format("%02d", table.find(wrProgressionDataTableHeaders, header))
				.. "_Header_"
				.. header.text,
			Size = UDim2.new(0, width, 1, 0),
			Text = header.text,
			Parent = parent,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = colors.black,
			Font = Enum.Font.SourceSansBold,
			TextScaled = true,
			BackgroundColor3 = colors.lightOrangeWRProgression,
			isMonospaced = header.isMonospaced,
		})

		if header.text ~= "Portrait" then
			local textSizeConstraint = Instance.new("UITextSizeConstraint")
			textSizeConstraint.MaxTextSize = globalTextSize
			textSizeConstraint.MinTextSize = globalMinTextSize
			textSizeConstraint.Parent = headerLabel
		end
	end

	return headerLabel
end

-- Modify the createColumn function
local function createColumn(
	header: tt.headerDefinition,
	content: string | number,
	entryFrame: Frame,
	backgroundColor: Color3?,
	width: number,
	xalign: Enum.TextXAlignment
): TextLabel | ImageLabel
	local headerIndex = table.find(wrProgressionDataTableHeaders, header) or 0
	if headerIndex == 0 then
		_annotate(string.format("createColumn: header not found: %s", header.text))
	end
	local name = string.format("%02d%s", headerIndex, header.text)
	local size = UDim2.new(0, width, 1, 0)
	local layoutOrder = headerIndex

	if header.text == "Portrait" then
		return createImageLabel({
			Name = name,
			Size = size,
			Parent = entryFrame,
			LayoutOrder = layoutOrder,
			Image = content,
			BackgroundColor3 = backgroundColor,
		})
	else
		return createTextLabel({
			Name = name,
			Size = size,
			Text = tostring(content),
			Parent = entryFrame,
			TextXAlignment = xalign,
			LayoutOrder = layoutOrder,
			TextSize = header.text == "Username" and globalFixedWidthFontSize - 5 or globalFixedWidthFontSize,
			BackgroundColor3 = backgroundColor,
			isMonospaced = header.isMonospaced,
		})
	end
end

local function CreateWRProgressionEntry(
	entry: tt.wrProgressionEntry,
	index: number,
	formatString: string,
	usernameBackgroundColor: Color3,
	lastedCellUseColor: Color3,
	columnWidths: { number },
	kind: string -- either "normal" or "theUserSpecial"
): Frame
	local entryFrame = createFrame({
		Size = UDim2.new(1, 0, 0, rowHeightPixels),
		BackgroundColor3 = colors.defaultGrey,
		LayoutOrder = index,
		Name = string.format("%04d", index) .. "_WRProgressionEntry_" .. entry.username,
	})

	createLayout("UIListLayout", entryFrame, {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 0),
	})

	-- Create columns using the calculated widths
	for i, header in ipairs(wrProgressionDataTableHeaders) do
		local content
		local backgroundColor = nil

		local align: Enum.TextXAlignment = header.TextXAlignment

		if header.text == "Best Time" then
			content = string.format(formatString, entry.runMilliseconds / 1000) .. "s"
		elseif header.text == "Improvement" then
			if kind == "theUserSpecial" then
				content = ""
			else
				content = entry.improvementMs and (string.format(formatString, entry.improvementMs / 1000) .. "s") or ""
			end
		elseif header.text == "Username" then
			content = entry.username
			backgroundColor = usernameBackgroundColor
		elseif header.text == "Portrait" then
			-- Use the new createAvatarPortraitPopup function here
			local portraitCell = thumbnails.createAvatarPortraitPopup(entry.userId, entryFrame)
			portraitCell.Size = UDim2.new(0, columnWidths[i], 1, 0)
			portraitCell.LayoutOrder = i
			portraitCell.Name = string.format("%02d%s", i, header.text)
			continue -- Skip the rest of the loop for this column
		elseif header.text == "Lasted" then
			if kind == "theUserSpecial" then
				content = ""
			else
				local formattedToDisplay, desc = LLMGeneratedUIFunctions.formatDateGap(entry.recordStood)

				if desc == "seconds" or desc == "minutes" then
					align = Enum.TextXAlignment.Left
				elseif desc == "hours" then
					align = Enum.TextXAlignment.Center
				elseif desc == "days" then
					align = Enum.TextXAlignment.Right
				end
				content = entry.recordStood and formattedToDisplay or ""
				backgroundColor = lastedCellUseColor
			end
		elseif header.text == "Date Set" then
			content = os.date("%Y-%m-%d", entry.runTime)
		end

		local width = (columnWidths and columnWidths[i]) or header.width
		if type(width) == "number" and width <= 1 then
			width = width * entryFrame.AbsoluteSize.X
		end
		if header.text ~= "Portrait" then
			local _column = createColumn(header, content, entryFrame, backgroundColor, width, align)
		end
	end

	return entryFrame
end

local function createWRHistoryProgression(data: tt.WRProgressionEndpointResponse): Frame?
	if not data.raceExists then
		-- Race doesn't exist, return nil to indicate no GUI should be created
		return nil
	end

	-- Calculate format string for times and improvements
	local times = {}
	local improvements = {}
	for _, entry in ipairs(data.wrProgression) do
		table.insert(times, entry.runMilliseconds / 1000)
		if #times > 1 then
			table.insert(improvements, times[#times] - times[#times - 1])
		end
	end

	local maxDecimalPlaces = math.min(getMaxDecimalPlaces(times), getMaxDecimalPlaces(improvements), 3)
	local maxIntegerDigits = math.max(getMaxIntegerDigits(times), getMaxIntegerDigits(improvements))
	local formatString = string.format("%%%d.%df", maxIntegerDigits + maxDecimalPlaces + 1, maxDecimalPlaces)

	-- Create main GUI elements
	local pgui: PlayerGui = PlayersService.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local existingSgui = pgui:FindFirstChild("WRHistoryProgressionSgui")
	if existingSgui then
		existingSgui:Destroy()
	end

	local newWrHistorySgui = createUIElement("ScreenGui", {
		IgnoreGuiInset = true,
		Name = "WRHistoryProgressionSgui",
		Parent = pgui,
	})

	local wrSystemFrames = windows.SetupFrame("wrhistory", true, true, true)
	local wrOuterFrame = wrSystemFrames.outerFrame
	local wrContentFrame = wrSystemFrames.contentFrame

	wrOuterFrame.Parent = newWrHistorySgui

	-- Create UIListLayout for wrContentFrame
	local contentListLayout = createLayout("UIListLayout", wrContentFrame, {
		FillDirection = Enum.FillDirection.Vertical,
		Name = "UIListLayoutV",
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 0),
	})

	-- Modify the wrOuterFrame size calculation
	local recordCount = #data.wrProgression
	local minHeight = 0.3 -- Minimum height as a fraction of screen height
	local maxHeight = 0.8 -- Maximum height as a fraction of screen height
	local heightPerRecord = 0.05 -- Height increment per record
	local calculatedHeight = math.min(maxHeight, math.max(minHeight, recordCount * heightPerRecord))

	wrOuterFrame.Size = UDim2.new(0.6, 0, calculatedHeight, 0) -- Increased width from 0.5 to 0.6
	wrOuterFrame.Position = UDim2.new(0.2, 0, (1 - calculatedHeight) / 2, 0) -- Adjusted position

	createLayout("UIListLayout", wrContentFrame, {
		FillDirection = Enum.FillDirection.Vertical,
		Name = "UIListLayoutV",
	})

	-- Create title and race name row
	local titleRaceFrame = createFrame({
		Size = UDim2.new(1, 0, 0, rowHeightPixels),
		BackgroundTransparency = 1,
		Parent = wrContentFrame,
		Name = "01TitleRace",
	})

	createLayout("UIListLayout", titleRaceFrame, {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 0),
	})

	local function createTitleTile(name: string, text: string, color: Color3, textColor: Color3, order: number)
		local tile = guiUtil.getTl(name, UDim2.new(1 / 3, 0, 1, 0), 0.8, titleRaceFrame, color, 1)
		tile.Text = text
		tile.TextXAlignment = Enum.TextXAlignment.Center
		tile.TextColor3 = textColor
		tile.LayoutOrder = order
		tile.Font = LLMGeneratedUIFunctions.getFont(false) -- Not monospaced
	end

	createTitleTile("01Title", "WR Progression: ", colors.lightOrangeWRProgression, colors.black, 1)
	createTitleTile("02StartName", data.raceHistoryData.raceStartName, colors.signColor, colors.signTextColor, 2)
	createTitleTile("03EndName", data.raceHistoryData.raceEndName, colors.signColor, colors.signTextColor, 3)

	-- Create race details frame
	local detailsFrame = createFrame({
		Parent = wrContentFrame,
		Name = "02Details",
		Size = UDim2.new(1, 0, 0, rowHeightPixels),
		BackgroundTransparency = 1,
	})

	createLayout("UIListLayout", detailsFrame, {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.Name,
		Padding = UDim.new(0, 0),
	})

	-- Add this before creating the details frame
	local currentPlayers = PlayersService:GetPlayers()
	local currentPlayerNames = {}
	for _, player in ipairs(currentPlayers) do
		currentPlayerNames[player.Name] = true
	end

	-- Modify the detailsData table to include the first runner information and portrait
	type wrProgressionDetailButton = {
		name: string,
		text: string,
		sizeProportion: number,
		color: Color3,
		isButton: boolean,
		isPortrait: boolean,
	}

	local detailsData: { wrProgressionDetailButton } = {
		{
			name = "03FirstRun",
			text = string.format("First run: %s", os.date("%Y-%m-%d", data.raceHistoryData.raceCreatedTime)),
			sizeProportion = 4,
			color = colors.defaultGrey,
			isButton = false,
			isPortrait = false,
		},
		{
			name = "02FirstRunner",
			sizeProportion = 3,
			text = string.format("First Runner: %s", data.raceHistoryData.firstRunnerUsername or "N/A"),
			color = (data.raceHistoryData.firstRunnerUserId == localPlayer.UserId and colors.meColor)
				or (currentPlayerNames[data.raceHistoryData.firstRunnerUsername] and colors.lightOrangeWRProgression)
				or colors.defaultGrey,
			isButton = false,
			isPortrait = false,
		},
		{
			name = "01FirstRunnerPortrait",
			isPortrait = true,
			sizeProportion = 1,
			text = "",
			color = (data.raceHistoryData.firstRunnerUserId == localPlayer.UserId and colors.meColor)
				or (currentPlayerNames[data.raceHistoryData.firstRunnerUsername] and colors.lightOrangeWRProgression)
				or colors.defaultGrey,
			isButton = false,
		},
		{
			name = "06Length",
			sizeProportion = 4,
			text = string.format("Length: %.1fd", data.raceHistoryData.raceLength),

			color = colors.defaultGrey,
			isButton = false,
			isPortrait = false,
		},
		{
			name = "04TotalRuns",
			sizeProportion = 4,
			text = string.format("Total Runs: %d", data.raceHistoryData.raceRunCount),

			color = colors.defaultGrey,
			isButton = false,
			isPortrait = false,
		},
		{
			sizeProportion = 5,
			name = "05TotalRunners",
			text = string.format("Total Runners: %d", data.raceHistoryData.raceRunnerCount),
			color = colors.defaultGrey,
			isButton = false,
			isPortrait = false,
		},
		{
			name = "08YourRuns",
			sizeProportion = 3,
			text = string.format("Your Runs: %d", data.raceHistoryData.userRunCount),

			color = colors.meColor,
			isButton = false,
			isPortrait = false,
		},
		{
			name = "09RunResults",
			text = "Top 10",
			sizeProportion = 3,
			color = colors.lightOrangeWRProgression,
			isButton = true,
			isPortrait = false,
		},
		{
			name = "10ReverseRace",
			text = "Reverse Race",
			sizeProportion = 3,
			color = colors.lightOrangeWRProgression,
			isButton = true,
			isPortrait = false,
		},
	}

	local totalSizeProportion = 0
	for _, detail in ipairs(detailsData) do
		totalSizeProportion += detail.sizeProportion or 0
	end

	-- When creating each detail item, adjust the size and color accordingly
	for _, detail in ipairs(detailsData) do
		local sizeFraction = (detail.sizeProportion or 1) / totalSizeProportion
		if detail.isPortrait then
			local portraitFrame = createFrame({
				Name = detail.name,
				Size = UDim2.new(sizeFraction, 0, 1, 0),
				Parent = detailsFrame,
				BackgroundTransparency = 0, -- Opaque background
				BackgroundColor3 = detail.color,
			})
			if data.raceHistoryData.firstRunnerUserId then
				local portraitCell =
					thumbnails.createAvatarPortraitPopup(data.raceHistoryData.firstRunnerUserId, portraitFrame)
				portraitCell.Size = UDim2.new(1, 0, 1, 0)
			end
		else
			if detail.name == "10ReverseRace" then
				local reverseRaceButton = LLMGeneratedUIFunctions.createButton({
					Size = UDim2.new(sizeFraction, 0, 1, 0),
					Text = "Reverse Race",
					TextColor3 = colors.black,
					BackgroundColor3 = colors.lightOrangeWRProgression,
					Parent = detailsFrame,
					Name = "ReverseRaceButton",
				})

				-- Reverse race button functionality
				reverseRaceButton.MouseButton1Click:Connect(function()
					local startSignId = tpUtil.signName2SignId(data.raceHistoryData.raceEndName)
					local endSignId = tpUtil.signName2SignId(data.raceHistoryData.raceStartName)
					requestWRProgression(startSignId, endSignId)
					newWrHistorySgui:Destroy()
				end)
			elseif detail.name == "09RunResults" then
				local runResultsButton = LLMGeneratedUIFunctions.createButton({
					Size = UDim2.new(sizeFraction, 0, 1, 0),
					Text = "Top 10",
					TextColor3 = colors.black,
					BackgroundColor3 = colors.lightOrangeWRProgression,
					Parent = detailsFrame,
					Name = "RunResultsButton",
				})

				runResultsButton.MouseButton1Click:Connect(function()
					local startSignId = tpUtil.signName2SignId(data.raceHistoryData.raceStartName)
					local endSignId = tpUtil.signName2SignId(data.raceHistoryData.raceEndName)
					requestRunResults(startSignId, endSignId)
					newWrHistorySgui:Destroy()
				end)
			else
				local label =
					guiUtil.getTl(detail.name, UDim2.new(sizeFraction, 0, 1, 0), 0.7, detailsFrame, detail.color, 1)
				label.Text = detail.text
			end
		end
	end

	-- Create header frame
	local headerFrame = createFrame({
		Name = "04Header",
		Size = UDim2.new(1, 0, 0, rowHeightPixels),
		BackgroundColor3 = colors.lightOrangeWRProgression,
		Parent = wrContentFrame,
	})

	createLayout("UIListLayout", headerFrame, {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 0),
	})

	local function calculateAndUpdateColumnWidths()
		local columnWidths = calculateColumnWidths(headerFrame.AbsoluteSize.X)
		for i, header in ipairs(wrProgressionDataTableHeaders) do
			local headerLabel = headerFrame:FindFirstChild(string.format("%02d", i) .. "_Header_" .. header.text)
			if headerLabel then
				if header.text == "Portrait" then
					headerLabel.Size = UDim2.new(0, rowHeightPixels, 0, rowHeightPixels)
				else
					headerLabel.Size = UDim2.new(0, columnWidths[i], 1, 0)
				end
			end
		end
		return columnWidths
	end

	for i, header in ipairs(wrProgressionDataTableHeaders) do
		createResponsiveHeader(header, headerFrame, header.text == "Portrait" and rowHeightPixels or 0)
	end

	local columnWidths = calculateAndUpdateColumnWidths()

	-- Create record holder list frame
	local recordHolderListFrame = createScrollingFrame({
		Name = "05RecordHolderList",
		Size = UDim2.new(1, 0, 1, -(rowHeightPixels * 3)),
		BackgroundTransparency = 0,
		BackgroundColor3 = colors.defaultGrey,
		BorderSizePixel = 1,
		Parent = wrContentFrame,
		ScrollBarThickness = scrollbarThickness,
	})

	createLayout("UIListLayout", recordHolderListFrame, {
		SortOrder = Enum.SortOrder.Name,
		Padding = UDim.new(0, 0),
	})

	local weStillNeedToDisplayUsersRun = false
	if data.raceHistoryData.userFastestRun and data.raceHistoryData.userFastestRun.runId then
		weStillNeedToDisplayUsersRun = true
	end

	local function actuallyInsertUsersBestAttemptData(i: number)
		local specialOverrideUserBestAttemptEverEntry: tt.wrProgressionEntry = {
			runMilliseconds = data.raceHistoryData.userFastestRun.runMilliseconds,
			username = localPlayer.Name,
			userId = localPlayer.UserId,
			runTime = data.raceHistoryData.userFastestRun.runTime,
			-- Set other fields to nil or default values
			improvementMs = nil,
			recordStood = nil,
		}

		local userEntryFrame = CreateWRProgressionEntry(
			specialOverrideUserBestAttemptEverEntry,
			i,
			formatString,
			colors.meColor,
			colors.defaultGrey,
			columnWidths,
			"theUserSpecial"
		)
		userEntryFrame.Name = string.format("%04d__USERoverride", i)
		userEntryFrame.Parent = recordHolderListFrame

		-- -- Customize the user entry frame
		for _, child in ipairs(userEntryFrame:GetChildren()) do
			if child:IsA("TextLabel") then
				-- if child.Name:match("Improvement$") or child.Name:match("Lasted$") then

				-- if child.Name:match("Best Time$") then
				-- 	child.Text = string.format(
				-- 		formatString,
				-- 		specialOverrideUserBestAttemptEverEntry.runMilliseconds / 1000
				-- 	) .. "s"
				-- 	child.BackgroundColor3 = colors.meColor
				if child.Name:match("Username$") then
					child.BackgroundColor3 = colors.meColor
					local placeText = ""
					if data.raceHistoryData.userFastestRun.contemporaneousPlace == 0 then
						placeText = "wasn't top 10."
					else
						placeText = "was "
							.. tpUtil.getCardinal(data.raceHistoryData.userFastestRun.contemporaneousPlace)
							.. " at the time."
					end
					child.Text = "Your best ever run " .. placeText
				end
			end
		end
	end

	-- Create WR progression entries
	for i = 1, #data.wrProgression do
		local entry = data.wrProgression[i]
		if entry.userId == localPlayer.UserId then
			weStillNeedToDisplayUsersRun = false
		end
		if weStillNeedToDisplayUsersRun then
			if entry.runMilliseconds > data.raceHistoryData.userFastestRun.runMilliseconds then
				weStillNeedToDisplayUsersRun = false
				actuallyInsertUsersBestAttemptData(i)
			end
		end
		local isCurrentWR = (i == 1)
		local lastedCellUseColor = isCurrentWR and colors.greenGo or colors.defaultGrey
		local usernameCellUseColor = colors.defaultGrey
		if entry.username == localPlayer.Name then
			usernameCellUseColor = colors.meColor
		elseif currentPlayerNames[entry.username] then
			usernameCellUseColor = colors.lightOrangeWRProgression
		end

		if isCurrentWR then
			entry.recordStood = os.time() - entry.runTime
		end

		local theEntryFrame = CreateWRProgressionEntry(
			entry,
			i,
			formatString,
			usernameCellUseColor,
			lastedCellUseColor,
			columnWidths,
			"normal"
		)
		theEntryFrame.Parent = recordHolderListFrame
	end

	if weStillNeedToDisplayUsersRun then
		actuallyInsertUsersBestAttemptData(#data.wrProgression)
	end

	-- Create a container for buttons
	local buttonContainer = createFrame({
		Name = "06ButtonContainer",
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.new(0, 0, 1, -40),
		BackgroundTransparency = 1,
		Parent = wrContentFrame,
	})

	-- Create layout for buttons
	LLMGeneratedUIFunctions.createLayout("UIListLayout", buttonContainer, {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 0),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	})

	local closeButton = LLMGeneratedUIFunctions.createButton({
		Size = UDim2.new(1 / 2, 0, 1, 0),
		Text = "Close",
		TextColor3 = colors.black,
		BackgroundColor3 = Color3.new(1, 0, 0),
		Parent = buttonContainer,
		Name = "CloseButton",
	})

	closeButton.MouseButton1Click:Connect(function()
		newWrHistorySgui:Destroy()
	end)

	local warpButton = LLMGeneratedUIFunctions.createButton({
		Size = UDim2.new(1 / 2, 0, 1, 0),
		Text = "Warp",
		TextColor3 = colors.black,
		BackgroundColor3 = colors.lightBlue,
		Parent = buttonContainer,
		Name = "WarpButton",
	})

	-- Warp button functionality
	warpButton.MouseButton1Click:Connect(function()
		warper.WarpToSignId(data.raceHistoryData.raceStartSignId, data.raceHistoryData.raceEndSignId)
		newWrHistorySgui:Destroy()
	end)

	for _, button in ipairs({ warpButton, closeButton }) do
		LLMGeneratedUIFunctions.addTextSizeConstraint(button)
	end

	task.defer(function()
		task.wait() -- Wait for the next frame to ensure all elements are properly sized
		local totalContentHeight = contentListLayout.AbsoluteContentSize.Y
		local viewportHeight = wrOuterFrame.AbsoluteSize.Y

		if totalContentHeight < viewportHeight then
			-- Content fits, adjust the outer frame size
			wrOuterFrame.Size = UDim2.new(wrOuterFrame.Size.X.Scale, wrOuterFrame.Size.X.Offset, 0, totalContentHeight)
		else
			-- Content doesn't fit, keep the original size and enable scrolling
			recordHolderListFrame.CanvasSize =
				UDim2.new(0, 0, 0, recordHolderListFrame.UIListLayout.AbsoluteContentSize.Y)
		end

		-- Reposition the frame to be centered
		wrOuterFrame.Position = UDim2.new(0.2, 0, 0.5, -wrOuterFrame.AbsoluteSize.Y / 2)
	end)

	-- Modify the resize connection to update both headers and rows
	wrOuterFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		local newColumnWidths = calculateAndUpdateColumnWidths()

		-- Update widths for all entries in the recordHolderListFrame
		for _, child in ipairs(recordHolderListFrame:GetChildren()) do
			if child:IsA("Frame") and child.Name:match("^%d+_WRProgressionEntry_") then
				for i, header in ipairs(wrProgressionDataTableHeaders) do
					local column = child:FindFirstChild(string.format("%02d%s", i, header.text))
					if column then
						if header.text == "Portrait" then
							column.Size = UDim2.new(0, rowHeightPixels, 0, rowHeightPixels)
						else
							column.Size = UDim2.new(0, newColumnWidths[i], 1, 0)
						end
					end
				end
			end
		end
	end)

	return wrOuterFrame
end

module.CreateWRHistoryProgressionGui = createWRHistoryProgression

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
		"drawWRHistoryProgressionGui"
	)

	local userSettingValue =
		settings.GetSettingByName(settingEnums.settingDefinitions.HIGHLIGHT_ON_RUN_COMPLETE_WARP.name)
	handleUserSettingChanged(userSettingValue)
	_annotate("init done")
end

_annotate("end")
return module
