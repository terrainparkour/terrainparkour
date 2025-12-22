--!strict
-- Contest button module that builds the contests popup action button on demand.
-- Fetches contest data asynchronously so UI startup stays snappy.

--a button that will pop a current contest, if any exists.
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local PlayersService = game:GetService("Players")
local localPlayer = PlayersService.LocalPlayer
local tpUtil: typeof(require(game.ReplicatedStorage.util.tpUtil)) = require(game.ReplicatedStorage.util.tpUtil)
local colors = require(game.ReplicatedStorage.util.colors)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local scrollingFrameUtils = require(game.ReplicatedStorage.gui.scrollingFrameUtils)
local standardButton = require(game.ReplicatedStorage.gui.standardButton)
local tt = require(game.ReplicatedStorage.types.gametypes)
local gt = require(game.ReplicatedStorage.gui.guiTypes)
local settings = require(game.ReplicatedStorage.settings)
local windowFunctions = require(game.StarterPlayer.StarterPlayerScripts.guis.windowFunctions)

local ContestResponseTypes = require(game.ReplicatedStorage.types.ContestResponseTypes)
local enums = require(game.ReplicatedStorage.util.enums)
local remotes = require(game.ReplicatedStorage.util.remotes)

local thumbnails = require(game.ReplicatedStorage.thumbnails)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)

local GetContestsFunction = remotes.getRemoteFunction("GetContestsFunction")
local GetSingleContestFunction = remotes.getRemoteFunction("GetSingleContestFunction")
local GetArchivedContestsFunction = remotes.getRemoteFunction("GetArchivedContestsFunction")

local warper = require(game.StarterPlayer.StarterCharacterScripts.client.warper)

type ActionButton = gt.actionButton
type Contest = ContestResponseTypes.Contest
type ContestRace = ContestResponseTypes.ContestRace

type Module = {
	contestButton: ActionButton?,
	Init: () -> nil,
	getArchivedContestsUI: (player: Player) -> ScreenGui,
}

local module: Module = {
	contestButton = nil,
	Init = function() end,
	getArchivedContestsUI = function(_player: Player): ScreenGui
		-- Placeholder, replaced below
		return Instance.new("ScreenGui")
	end,
}

local maxUsersToDisplayInContest = 10
local userSizedColumns = maxUsersToDisplayInContest + 2

local lastCanvasPosition = Vector2.new(0, 0)

--display multiple significant digits in contest lb
local shortenContestDigitDisplay = false

local function getColorForTimeGap(gap: number)
	local useColor = colors.defaultGrey
	local plus = ""
	if gap == 0 then
		plus = ""
		useColor = colors.greenGo
	elseif gap < 1000 then
		plus = "+"
		useColor = colors.lightGreen
	elseif gap < 3000 then
		plus = "+"
		useColor = colors.lightYellow
	elseif gap < 10000 then
		plus = "+"
		useColor = colors.WRProgressionColor
	elseif gap < 20000 then
		plus = "+"
		useColor = colors.lightRed
	else
		plus = "+"
		useColor = colors.redStop
	end

	return plus, useColor
end

local getPlaceByUsername = function(ss: { ContestResponseTypes.Runner }, username: string): ContestResponseTypes.Runner?
	for ii, el in ipairs(ss) do
		if el.username == username then
			return el
		end
	end
	return nil
end

--widths for rows like
local widths = { number = 0.025, race = 0.2, dist = 0.045, leads = 0.68, warp = 0.05 }

local function makeLeaderCell(runner: ContestResponseTypes.Runner, ii: number, leadTime: number)
	local fr = Instance.new("Frame")
	fr.Size = UDim2.new(widths.leads / userSizedColumns, 0, 1, 0)
	fr.Name = string.format("%02d.LeaderCellFor%s", ii, (runner == nil and ".none" or runner.username))
	if runner == nil then
		return fr
	end

	local hh = Instance.new("UIListLayout")
	hh.FillDirection = Enum.FillDirection.Vertical
	hh.SortOrder = Enum.SortOrder.Name
	hh.Parent = fr

	local useColor = colors.defaultGrey
	if runner.userId == localPlayer.UserId then
		useColor = colors.meColor
	end
	local img = Instance.new("ImageLabel")
	img.BorderMode = Enum.BorderMode.Outline
	img.BorderSizePixel = 0
	img.Size = UDim2.new(1, 0, 0.5, 0)
	local content = thumbnails.getThumbnailContent(runner.userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
	img.Image = content
	img.BackgroundColor3 = useColor
	img.Name = "03LeaderPortrait"
	img.Parent = fr

	local tl = guiUtil.getTl("01.Username", UDim2.new(1, 0, 0.2, 0), 1, fr, colors.defaultGrey, 1)
	tl.Text = runner.username

	local tl2 = guiUtil.getTl("02.Time", UDim2.new(1, 0, 0.15, 0), 1, fr, colors.defaultGrey, 1)
	tl2.Text = string.format("%0.3fs", runner.timeMs / 1000)

	if ii == 1 then
		--user ios leader so we don't display a timegap!

		local tl3 = guiUtil.getTl("03.TimeGap", UDim2.new(1, 0, 0.15, 0), 1, fr, colors.greenGo, 1)
		tl3.Text = "Leading!"
	else
		local behindMs = runner.timeMs - leadTime
		local plus, behindnessUseColor = getColorForTimeGap(behindMs)
		local tl3 = guiUtil.getTl("03.TimeGap", UDim2.new(1, 0, 0.15, 0), 1, fr, behindnessUseColor, 1)
		tl3.Text = string.format("%s%0.3fs", plus, behindMs / 1000)
	end
	return fr
end

local function makeContestRow(
	contestResult: ContestResponseTypes.Contest,
	race: ContestResponseTypes.ContestRace,
	ii: number,
	parentSgui: ScreenGui,
	scrollingFrame: ScrollingFrame,
	showScrollbar: boolean --wehter scrollbar is shown; i f so make num cell 10 pixels narroweer.
): Frame
	local fr = Instance.new("Frame")
	-- fr.BorderMode = Enum.BorderMode.Inset
	fr.BorderSizePixel = 0
	fr.Name = string.format("%03d", ii) .. "PopularResultFrameRow"
	fr.Size = UDim2.new(1, 0, 0, 30)
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.Parent = fr
	local wpix = 0
	if showScrollbar then
		wpix = -10
	end
	local numTl = guiUtil.getTl("00", UDim2.new(widths.number, wpix, 1, 0), 2, fr, colors.defaultGrey)
	numTl.Text = tostring(race.raceNumber)

	local raceTl = guiUtil.getTl("01", UDim2.new(widths.race, 0, 1, 0), 2, fr, colors.signColor)
	raceTl.Text = race.startSignName .. " - " .. race.endSignName
	raceTl.TextXAlignment = Enum.TextXAlignment.Left
	raceTl.TextColor3 = colors.signTextColor

	local distTl = guiUtil.getTl("02", UDim2.new(widths.dist, 0, 1, 0), 0, fr, colors.defaultGrey)
	distTl.Text = string.format("%dd", race.dist)

	local bestTl = guiUtil.getTl("03", UDim2.new(widths.leads / userSizedColumns, 0, 1, 0), 0, fr, colors.defaultGrey)
	bestTl.Text = "(unrun)"
	if race ~= nil and race.best ~= nil then
		bestTl.Text = string.format("%s\n%0.3fs", race.best.username, race.best.timeMs / 1000)
		if race.best.username == localPlayer.Name then
			bestTl.BackgroundColor3 = colors.meColor
		end
	end

	local missingRunPlaceholder = "(unrun)"

	-------------------POSITION RESULTS contestrow-------------------

	local pos = 1
	while pos <= maxUsersToDisplayInContest do
		local guy = contestResult.leaders[tostring(pos)]
		local num = string.format("%02d", 3 + pos)

		if guy == nil then --there isn't even an maxth runner at ALL
			local posTl = guiUtil.getTl(num, UDim2.new(widths.leads / userSizedColumns, 0, 1, 0), 1, fr, colors.lightGrey)
			posTl.Text = ""
		else
			local theRun = getPlaceByUsername(race.runners, guy.username)

			if theRun == nil then
				local posTl = guiUtil.getTl(num, UDim2.new(widths.leads / userSizedColumns, 0, 1, 0), 7, fr, colors.lightGrey)
				posTl.Text = missingRunPlaceholder
			else
				local posTl = guiUtil.getTl(num, UDim2.new(widths.leads / userSizedColumns, 0, 1, 0), 1, fr, colors.defaultGrey)
				if shortenContestDigitDisplay then
					posTl.Text = string.format("%0.0fs", theRun.timeMs / 1000)
				else
					posTl.Text = string.format("%0.1fs", theRun.timeMs / 1000)
				end
			end
		end
		pos += 1
	end

	---YOU
	--get the run to display in your column from either the top10, or the special user-scoped ".user" field.
	local theRun = getPlaceByUsername(race.runners, localPlayer.Name)
	if theRun == nil then
		local fakeUseronlyRunnser = {}
		table.insert(fakeUseronlyRunnser, race.user)
		theRun = getPlaceByUsername(fakeUseronlyRunnser, localPlayer.Name)
	end
	local youFrame = Instance.new("Frame")
	youFrame.Name = "19.youFrame"
	youFrame.Parent = fr
	youFrame.Size = UDim2.new(widths.leads / userSizedColumns, 0, 1, 0)
	local hh = Instance.new("UIListLayout")
	hh.Parent = youFrame
	hh.FillDirection = Enum.FillDirection.Horizontal
	if theRun ~= nil then
		local youTl = guiUtil.getTl("01", UDim2.new(0.5, 0, 1.0, 0), 1, youFrame, colors.defaultGrey)
		youTl.Text = string.format("%0.3fs", theRun.timeMs / 1000)
		local gap = theRun.timeMs - race.best.timeMs
		local plus, gapColor = getColorForTimeGap(gap)
		local diffTl = guiUtil.getTl("02", UDim2.new(0.5, 0, 1, 0), 1, youFrame, gapColor)
		diffTl.Text = string.format("%s%0.03fs", plus, gap / 1000)
	else
		local youTl = guiUtil.getTl("20", UDim2.new(1, 0, 1, 0), 7, youFrame, colors.lightGrey)
		youTl.Text = missingRunPlaceholder
	end

	local warp = guiUtil.getPaddedButton("21.ContestWarp", UDim2.new(widths.warp, 0, 1, 0), 1, fr, colors.warpColor, 1)
	warp.Text = "Warp"

	warp.Activated:Connect(function()
		local signId = enums.namelower2signId[race.startSignName:lower()]
		warper.WarpToSignId(signId)
		lastCanvasPosition = scrollingFrame.CanvasPosition
		parentSgui:Destroy()
	end)

	return fr
end

local function getContest(contest: ContestResponseTypes.Contest): ScreenGui
	local rowHeight = 30
	--get contest status for player, aggregated info from other people too.
	local scrollingFrameRows = #contest.races
	local screenGui = Instance.new("ScreenGui")
	screenGui.IgnoreGuiInset = true
	screenGui.Name = "ContestScreenGui"

	-- Use modern window frame for drag/resize/persistence
	local persistenceConfig: windowFunctions.PositionPersistenceConfig = {
		settingName = "CONTEST_GUI_LAYOUT",
		settingKey = "position",
		saveSize = true,
		sizeKey = "size",
		clampOnLoad = true,
		defaultPosition = UDim2.new(0.075, 0, 0.125, 0),
	}

	local frameResult = windowFunctions.SetupFrame(
		"ContestFrame",
		true, -- draggable
		true, -- resizable
		false, -- minimizable
		false, -- pinnable
		UDim2.new(0.85, 0, 0.75, 0), -- size
		false, -- maintainAspectRatio
		persistenceConfig,
		nil, -- resizeConfig
		nil, -- guiSpec (we're using existing content)
		nil, -- contentOptions
		nil -- popupOptions
	)

	local outerFrame = frameResult.outerFrame
	outerFrame.Parent = screenGui
	outerFrame.BackgroundTransparency = 1

	-- Use contentFrame for all the existing content
	local contentFrame = frameResult.contentFrame
	contentFrame.BackgroundTransparency = 1
	-- Ensure contentFrame fills outerFrame (scale-based sizing for proper resize behavior)
	contentFrame.Size = UDim2.new(1, 0, 1, 0)
	contentFrame.Position = UDim2.new(0, 0, 0, 0)

	-- Enable clipping to prevent overflow during resize
	task.defer(function()
		if outerFrame and outerFrame.Parent then
			outerFrame.ClipsDescendants = true
		end
	end)

	-- Fixed heights for layout calculation (use absolute positioning for proper resize behavior)
	local INTRO_HEIGHT = 40
	local AWARDS_HEIGHT = 30
	local LEADER_SUMMARY_HEIGHT = 120
	local HEADER_HEIGHT = rowHeight -- 30
	local CLOSE_HEIGHT = 30
	local FIXED_TOP_HEIGHT = INTRO_HEIGHT + AWARDS_HEIGHT + LEADER_SUMMARY_HEIGHT + HEADER_HEIGHT

	local introduction = guiUtil.getTl("00.Introduction", UDim2.new(1, 0, 0, INTRO_HEIGHT), 2, contentFrame, colors.defaultGrey, 1)
	introduction.Position = UDim2.new(0, 0, 0, 0)
	if contest.active then
		introduction.Text = "Welcome to Contests. Run each race below to compete!"
	else
		introduction.Text = string.format("Historical archive view of %s", contest.name)
	end
	introduction.TextXAlignment = Enum.TextXAlignment.Left

	local awards = guiUtil.getTl("01.ContestTitle", UDim2.new(1, 0, 0, AWARDS_HEIGHT), 4, contentFrame, colors.defaultGrey, 1)
	awards.Position = UDim2.new(0, 0, 0, INTRO_HEIGHT)
	if contest.active then
		local t = string.format("%s - Prizes: Gold contest badge + %s tix, Silver + %s tix, Bronze + %s tix. Completing all runs: Participation badge + %s tix", contest.name, tpUtil.getNumberEmojis(1111), tpUtil.getNumberEmojis(555), tpUtil.getNumberEmojis(333), tpUtil.getNumberEmojis(111))
		awards.Text = t
	else
		awards.Text = string.format("Ran from %s to %s. Times shown are from the contest period only.", contest.conteststart, contest.contestend)
	end

	awards.TextXAlignment = Enum.TextXAlignment.Left

	---------LEADER SUMMARY AND CURRENT RESULTS------------
	local leaderSummaryRow = Instance.new("Frame")
	-- headerFrame.BorderMode = Enum.BorderMode.Inset
	leaderSummaryRow.Parent = contentFrame
	leaderSummaryRow.Name = "02.LeaderSummaryRow"
	leaderSummaryRow.Size = UDim2.new(1, 0, 0, LEADER_SUMMARY_HEIGHT)
	leaderSummaryRow.Position = UDim2.new(0, 0, 0, INTRO_HEIGHT + AWARDS_HEIGHT)
	local holderIntro = guiUtil.getTl("01.Holder", UDim2.new(widths.number + widths.race + widths.dist + widths.leads / userSizedColumns, 0, 1, 0), 4, leaderSummaryRow, colors.defaultGrey, 1)
	if contest.contestremaining > 0 then
		task.spawn(function()
			local ii = 0
			while true do
				ii += 1
				if introduction.Parent == nil then
					break
				end
				holderIntro.Text = "Contest End: " .. contest.contestend .. " UTC\nRemaining: " .. tostring(contest.contestremaining - ii) .. " seconds."
				if screenGui.Parent == nil then
					break
				end
				task.wait(1)
				_annotate("stuck in leaderSummaryRow")
			end
		end)
	else
		holderIntro.Text = "Contest is complete. Congrats to the winners!"
	end

	--frame for gold leader

	local jj = 1

	local leadTime = nil
	if contest.leaders[tostring(1)] ~= nil then
		leadTime = contest.leaders[tostring(1)].timeMs
	end

	while jj <= maxUsersToDisplayInContest do
		local chunk = makeLeaderCell(contest.leaders[tostring(jj)], jj, leadTime)
		chunk.Parent = leaderSummaryRow
		jj += 1
	end

	local youpos = makeLeaderCell(contest.user, 12, leadTime)
	youpos.Parent = leaderSummaryRow

	local leaderLayout = Instance.new("UIListLayout")
	leaderLayout.FillDirection = Enum.FillDirection.Horizontal
	leaderLayout.Parent = leaderSummaryRow

	----------------HEADER--------------
	local headerFrame = Instance.new("Frame")
	-- headerFrame.BorderMode = Enum.BorderMode.Inset
	headerFrame.Parent = contentFrame
	headerFrame.Name = "03.contestHeaderRow"
	headerFrame.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
	headerFrame.Position = UDim2.new(0, 0, 0, INTRO_HEIGHT + AWARDS_HEIGHT + LEADER_SUMMARY_HEIGHT)
	local headerLayout = Instance.new("UIListLayout")
	headerLayout.FillDirection = Enum.FillDirection.Horizontal
	headerLayout.Parent = headerFrame
	local tl0 = guiUtil.getTl("00", UDim2.new(widths.number, 0, 1, 0), 2, headerFrame, colors.blueDone, 1)
	tl0.Text = "Num"

	local runLabel = guiUtil.getTl("01", UDim2.new(widths.race, 0, 1, 0), 2, headerFrame, colors.blueDone, 1)
	runLabel.Text = "Run"

	local distLabel = guiUtil.getTl("02", UDim2.new(widths.dist, 0, 1, 0), 2, headerFrame, colors.blueDone, 1)
	distLabel.Text = "Dist"

	--lead section consists of best, gold,silver,bronze,4-8th (8), plus YOU
	local leadCount = maxUsersToDisplayInContest + 2 --(display+best+YOU)

	local bestLabel = guiUtil.getTl("03", UDim2.new(widths.leads / leadCount, 0, 1, 0), 2, headerFrame, colors.blueDone, 1)
	bestLabel.Text = "Best"

	local medalIndex = 1

	while medalIndex <= maxUsersToDisplayInContest do
		local placeLabel = guiUtil.getTl(string.format("%02d", 3 + medalIndex), UDim2.new(widths.leads / leadCount, 0, 1, 0), 2, headerFrame, colors.blueDone, 1)
		local text = tpUtil.getCardinalEmoji(medalIndex)
		if medalIndex == 1 then
			text = "Gold " .. tpUtil.getCardinalEmoji(1)
		elseif medalIndex == 2 then
			text = "Silver " .. tpUtil.getCardinalEmoji(2)
		elseif medalIndex == 3 then
			text = "Bronze " .. tpUtil.getCardinalEmoji(3)
		end
		placeLabel.Text = text
		medalIndex += 1
	end

	local tlYou = guiUtil.getTl("14", UDim2.new(widths.leads / leadCount, 0, 1, 0), 2, headerFrame, colors.blueDone, 1)
	tlYou.Text = "You"

	local warp = guiUtil.getTl("15", UDim2.new(widths.warp, 0, 1, 0), 2, headerFrame, colors.blueDone, 1)
	warp.Text = "Warp"

	--scrolling setting frame - uses scale-based height to fill remaining space
	local frameName = "04ContestScrollingFrame"
	local scrollingFrame = Instance.new("ScrollingFrame")
	-- -- scrollingFrame.BorderMode = Enum.BorderMode.Inset
	scrollingFrame.BorderSizePixel = 0
	scrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollingFrame.ScrollBarThickness = 10

	scrollingFrame.Name = frameName
	scrollingFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	scrollingFrame.Parent = contentFrame
	local maxYPixels = scrollingFrameRows * rowHeight
	local showScrollbar = maxYPixels > 200 -- Show scrollbar if content would exceed reasonable height

	-- Use scale-based sizing: fill remaining space between header and close button
	scrollingFrame.Position = UDim2.new(0, 0, 0, FIXED_TOP_HEIGHT)
	scrollingFrame.Size = UDim2.new(1, 0, 1, -(FIXED_TOP_HEIGHT + CLOSE_HEIGHT))
	scrollingFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	scrollingFrame.VerticalScrollBarPosition = Enum.VerticalScrollBarPosition.Left
	-- Initial canvas size; AutomaticCanvasSize will adjust as content is added
	scrollingFrame.CanvasSize = UDim2.new(1, 0, 0, maxYPixels)
	local scrollingLayout = Instance.new("UIListLayout")
	scrollingLayout.FillDirection = Enum.FillDirection.Vertical
	scrollingLayout.Parent = scrollingFrame

	for rowIndex, race: ContestResponseTypes.ContestRace in ipairs(contest.races) do
		local rowFrame = makeContestRow(contest, race, rowIndex + 10, screenGui, scrollingFrame, showScrollbar)
		rowFrame.Parent = scrollingFrame
	end

	local closeButton = standardButton.CreateCloseButton({
		onClick = function()
			--store last scroll position
			lastCanvasPosition = scrollingFrame.CanvasPosition
			screenGui:Destroy()
		end,
		size = UDim2.new(1, 0, 0, CLOSE_HEIGHT),
		parent = contentFrame,
	})
	closeButton.Name = "ZZZPopularCloseButton"
	closeButton.Position = UDim2.new(0, 0, 1, -CLOSE_HEIGHT)
	scrollingFrame.CanvasPosition = lastCanvasPosition

	-- Force layout recalculation when contentFrame resizes (UIListLayout scale children don't always auto-update)
	contentFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		-- Re-apply scrollingFrame size to ensure it recalculates (Scale-based sizing can be sticky)
		scrollingFrame.Size = UDim2.new(1, 0, 1, -(FIXED_TOP_HEIGHT + CLOSE_HEIGHT))

		-- Touch the canvas to force children to recalculate their scale-based sizes
		local currentCanvas = scrollingFrame.CanvasSize
		scrollingFrame.CanvasSize = UDim2.new(1, 0, currentCanvas.Y.Scale, currentCanvas.Y.Offset)

		-- Update close button position (should be automatic but let's ensure it)
		closeButton.Position = UDim2.new(0, 0, 1, -CLOSE_HEIGHT)

		-- Force UIListLayouts in header and leader summary rows to recalculate
		for _, descendant in ipairs(contentFrame:GetDescendants()) do
			if descendant:IsA("UIListLayout") then
				descendant.Padding = descendant.Padding
			end
		end
	end)

	-- Prevent camera scroll when hovering over contest scrolling frame
	scrollingFrameUtils.PreventCameraScrollOnHover(scrollingFrame)

	return screenGui
end

local function makeGetter(contest: Contest): (Player) -> ScreenGui
	local function f(_player: Player): ScreenGui
		local newcontest = GetSingleContestFunction:InvokeServer(contest.contestid)
		return getContest(newcontest)
	end
	return f
end
module.contestButton = nil

-- UI for viewing archived (past) contests
function module.getArchivedContestsUI(_player: Player): ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ArchivedContestsGui"
	screenGui.IgnoreGuiInset = true

	-- Use modern window frame for drag/resize/persistence
	local persistenceConfig: windowFunctions.PositionPersistenceConfig = {
		settingName = "ARCHIVED_CONTESTS_GUI_LAYOUT",
		settingKey = "position",
		saveSize = true,
		sizeKey = "size",
		clampOnLoad = true,
		defaultPosition = UDim2.new(0.3, 0, 0.25, 0),
	}

	local frameResult = windowFunctions.SetupFrame(
		"ArchivedContestsFrame",
		true, -- draggable
		true, -- resizable
		false, -- minimizable
		false, -- pinnable
		UDim2.new(0.4, 0, 0.5, 0), -- size
		false, -- maintainAspectRatio
		persistenceConfig,
		nil, -- resizeConfig
		nil, -- guiSpec
		nil, -- contentOptions
		nil -- popupOptions
	)

	local outerFrame = frameResult.outerFrame
	outerFrame.Parent = screenGui

	local contentFrame = frameResult.contentFrame
	contentFrame.BackgroundColor3 = colors.defaultGrey
	-- Ensure contentFrame fills outerFrame (scale-based sizing for proper resize behavior)
	contentFrame.Size = UDim2.new(1, 0, 1, 0)
	contentFrame.Position = UDim2.new(0, 0, 0, 0)

	-- Enable clipping to prevent overflow during resize
	task.defer(function()
		if outerFrame and outerFrame.Parent then
			outerFrame.ClipsDescendants = true
		end
	end)

	-- Fixed heights for layout (use absolute positioning for proper resize behavior)
	local TITLE_HEIGHT = 40
	local MESSAGE_HEIGHT = 30
	local CLOSE_BTN_HEIGHT = 30
	local FIXED_TOP = TITLE_HEIGHT + MESSAGE_HEIGHT

	-- Title
	local title = guiUtil.getTl("00.Title", UDim2.new(1, 0, 0, TITLE_HEIGHT), 1, contentFrame, colors.signColor, 1)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.Text = "Past Contests"
	title.TextColor3 = colors.white
	title.Font = Enum.Font.GothamBold

	-- Message row
	local messageRow = guiUtil.getTl("01.Message", UDim2.new(1, 0, 0, MESSAGE_HEIGHT), 1, contentFrame, colors.defaultGrey, 1)
	messageRow.Position = UDim2.new(0, 0, 0, TITLE_HEIGHT)
	messageRow.Text = "No active contest. Browse past contests below:"
	messageRow.TextColor3 = colors.black

	-- Scrolling frame for archived contests (fills remaining space)
	local scrollingFrame = Instance.new("ScrollingFrame")
	scrollingFrame.Name = "02.ScrollingFrame"
	scrollingFrame.Position = UDim2.new(0, 0, 0, FIXED_TOP)
	scrollingFrame.Size = UDim2.new(1, 0, 1, -(FIXED_TOP + CLOSE_BTN_HEIGHT))
	scrollingFrame.BackgroundColor3 = colors.defaultGrey
	scrollingFrame.BorderSizePixel = 0
	scrollingFrame.ScrollBarThickness = 8
	scrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollingFrame.Parent = contentFrame

	local scrollLayout = Instance.new("UIListLayout")
	scrollLayout.FillDirection = Enum.FillDirection.Vertical
	scrollLayout.SortOrder = Enum.SortOrder.Name
	scrollLayout.Padding = UDim.new(0, 2)
	scrollLayout.Parent = scrollingFrame

	-- Fetch archived contests
	local archivedContests = GetArchivedContestsFunction:InvokeServer()

	if archivedContests == nil or #archivedContests == 0 then
		local noContests = guiUtil.getTl("01.NoContests", UDim2.new(1, 0, 0, 40), 1, scrollingFrame, colors.defaultGrey, 1)
		noContests.Text = "No past contests found."
		noContests.TextColor3 = colors.black
	else
		for ii, archived: ContestResponseTypes.ArchivedContest in ipairs(archivedContests) do
			local rowFrame = Instance.new("Frame")
			rowFrame.Name = string.format("%02d.Contest_%d", ii, archived.contestId)
			rowFrame.Size = UDim2.new(1, 0, 0, 50)
			rowFrame.BackgroundColor3 = colors.lightGrey
			rowFrame.BorderSizePixel = 0
			rowFrame.Parent = scrollingFrame

			local rowLayout = Instance.new("UIListLayout")
			rowLayout.FillDirection = Enum.FillDirection.Horizontal
			rowLayout.SortOrder = Enum.SortOrder.Name
			rowLayout.Parent = rowFrame

			-- Contest info
			local infoFrame = Instance.new("Frame")
			infoFrame.Name = "01.Info"
			infoFrame.Size = UDim2.new(0.7, 0, 1, 0)
			infoFrame.BackgroundTransparency = 1
			infoFrame.Parent = rowFrame

			local infoLayout = Instance.new("UIListLayout")
			infoLayout.FillDirection = Enum.FillDirection.Vertical
			infoLayout.Parent = infoFrame

			local nameTl = guiUtil.getTl("01.Name", UDim2.new(1, 0, 0.5, 0), 1, infoFrame, colors.lightGrey, 1)
			nameTl.Text = archived.name
			nameTl.TextColor3 = colors.black
			nameTl.Font = Enum.Font.GothamBold
			nameTl.TextXAlignment = Enum.TextXAlignment.Left

			local dateTl = guiUtil.getTl("02.Date", UDim2.new(1, 0, 0.5, 0), 1, infoFrame, colors.lightGrey, 1)
			dateTl.Text = string.format("%s to %s (%d races)", archived.startDate, archived.endDate, archived.raceCount)
			dateTl.TextColor3 = colors.black
			dateTl.TextXAlignment = Enum.TextXAlignment.Left

			-- View button
			local viewBtn = guiUtil.getPaddedButton("02.View", UDim2.new(0.3, 0, 1, 0), 1, rowFrame, colors.warpColor, 1)
			viewBtn.Text = "View Results"
			viewBtn.Activated:Connect(function()
				-- Fetch full contest data and display it
				local contest = GetSingleContestFunction:InvokeServer(archived.contestId)
				if contest then
					screenGui:Destroy()
					local contestGui = getContest(contest)
					contestGui.Parent = localPlayer:WaitForChild("PlayerGui")
				end
			end)
		end
	end

	-- Close button (positioned at bottom)
	local closeButton = standardButton.CreateCloseButton({
		onClick = function()
			screenGui:Destroy()
		end,
		size = UDim2.new(1, 0, 0, CLOSE_BTN_HEIGHT),
		parent = contentFrame,
	})
	closeButton.Name = "ZZZCloseButton"
	closeButton.Position = UDim2.new(0, 0, 1, -CLOSE_BTN_HEIGHT)

	-- Force layout recalculation when contentFrame resizes
	contentFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		-- Re-apply scrollingFrame size to ensure it recalculates
		scrollingFrame.Size = UDim2.new(1, 0, 1, -(FIXED_TOP + CLOSE_BTN_HEIGHT))

		-- Touch the canvas to force children to recalculate
		local currentCanvas = scrollingFrame.CanvasSize
		scrollingFrame.CanvasSize = UDim2.new(1, 0, currentCanvas.Y.Scale, currentCanvas.Y.Offset)

		-- Update close button position
		closeButton.Position = UDim2.new(0, 0, 1, -CLOSE_BTN_HEIGHT)

		for _, descendant in ipairs(contentFrame:GetDescendants()) do
			if descendant:IsA("UIListLayout") then
				descendant.Padding = descendant.Padding
			end
		end
	end)

	-- Prevent camera scroll on hover
	scrollingFrameUtils.PreventCameraScrollOnHover(scrollingFrame)

	return screenGui
end

local contestLoadInProgress = false

local function buildActionButton(contest: Contest): ActionButton
	local button: ActionButton = {
		name = "Contest Button" .. contest.name,
		contentsGetter = makeGetter(contest),
		hoverHint = "Show Contests Ranks",
		shortName = contest.name .. " (" .. tostring(#contest.races) .. ")",
		getActive = function()
			return true
		end,
		widthXScale = 0.20,
	}
	return button
end

local function refreshContestButtonAsync()
	if contestLoadInProgress then
		return
	end

	contestLoadInProgress = true

	task.spawn(function()
		local ok, result = pcall(function()
			return GetContestsFunction:InvokeServer({})
		end)

		if not ok then
			warn(string.format(" failed to load contests: %s", tostring(result)))
			contestLoadInProgress = false
			return
		end

		if typeof(result) ~= "table" then
			warn("GetContestsFunction returned non-table result")
			contestLoadInProgress = false
			return
		end

		local contests = result :: { Contest }

		module.contestButton = nil

		for _, currentContest in ipairs(contests) do
			module.contestButton = buildActionButton(currentContest)
			break
		end

		contestLoadInProgress = false
	end)
end

local function handleUserSettingChanged(setting: tt.userSettingValue)
	if setting.name == settingEnums.settingDefinitions.SHORTEN_CONTEST_DIGIT_DISPLAY.name then
		shortenContestDigitDisplay = setting.booleanValue == true
	end
	return nil
end

module.Init = function()
	_annotate("init")
	settings.RegisterFunctionToListenForSettingName(handleUserSettingChanged, settingEnums.settingDefinitions.SHORTEN_CONTEST_DIGIT_DISPLAY.name, "contestButton")

	handleUserSettingChanged(settings.GetSettingByName(settingEnums.settingDefinitions.SHORTEN_CONTEST_DIGIT_DISPLAY.name))

	refreshContestButtonAsync()

	_annotate("init done")
end

_annotate("end")
return module
