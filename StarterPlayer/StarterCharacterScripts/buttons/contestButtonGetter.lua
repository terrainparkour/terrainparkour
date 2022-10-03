--!strict

--eval 9.25.22
--a button that will pop a current contest, if any exists.

local localPlayer = game:GetService("Players").LocalPlayer
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local gt = require(game.ReplicatedStorage.gui.guiTypes)
local colors = require(game.ReplicatedStorage.util.colors)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local tt = require(game.ReplicatedStorage.types.gametypes)
local gt = require(game.ReplicatedStorage.gui.guiTypes)

local ContestResponseTypes = require(game.ReplicatedStorage.types.ContestResponseTypes)
local enums = require(game.ReplicatedStorage.util.enums)
local rf = require(game.ReplicatedStorage.util.remotes)

local thumbnails = require(game.ReplicatedStorage.thumbnails)

local getContestsFunction = rf.getRemoteFunction("GetContestsFunction")
local getSingleContestFunction = rf.getRemoteFunction("GetSingleContestFunction")

local warper = require(game.ReplicatedStorage.warper)

local module = {}

local maxUsersToDisplayInContest = 10
local userSizedColumns = maxUsersToDisplayInContest + 2

local lastCanvasPosition = Vector2.new(0, 0)

--display multiple significant digits in contest lb
local shortenContestDigitDisplay = false

local function getPlaceByUsername(ss: { ContestResponseTypes.Runner }, username: string): ContestResponseTypes.Runner
	for ii, el in ipairs(ss) do
		if el.username == username then
			return el
		end
	end
end

--widths for rows like
local widths = { number = 0.025, race = 0.2, dist = 0.045, leads = 0.68, warp = 0.05 }

local function makeLeaderCell(runner: ContestResponseTypes.Runner, ii: number)
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
	img.Size = UDim2.new(1, 0, 0.6, 0)
	local content = thumbnails.getThumbnailContent(runner.userId, Enum.ThumbnailType.HeadShot)
	img.Image = content
	img.BackgroundColor3 = useColor
	img.Name = "03LeaderPortrait"
	img.Parent = fr

	local tl = guiUtil.getTl("01.Username", UDim2.new(1, 0, 0.2, 0), 1, fr, colors.defaultGrey, 1)
	tl.Text = runner.username

	local tl2 = guiUtil.getTl("02.Time", UDim2.new(1, 0, 0.2, 0), 1, fr, colors.defaultGrey, 1)
	tl2.Text = string.format("%0.3fs", runner.timeMs / 1000)

	return fr
end

local function makeContestRow(
	contestResult: ContestResponseTypes.Contest,
	race: ContestResponseTypes.ContestRace,
	ii: number,
	parentSgui: ScreenGui,
	scrollingFrame: ScrollingFrame,
	warper: tt.warperWrapper,
	showScrollbar: boolean --wehter scrollbar is shown; i f so make num cell 10 pixels narroweer.
): Frame
	local fr = Instance.new("Frame")
	-- fr.BorderMode = Enum.BorderMode.Inset
	fr.BorderSizePixel = 0
	fr.Name = string.format("%03d", ii) .. "PopularResultFrameRow"
	fr.Size = UDim2.new(1, 0, 0, 30)
	local vv = Instance.new("UIListLayout")
	vv.FillDirection = Enum.FillDirection.Horizontal
	vv.Parent = fr
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
			local posTl =
				guiUtil.getTl(num, UDim2.new(widths.leads / userSizedColumns, 0, 1, 0), 1, fr, colors.lightGrey)
			posTl.Text = ""
		else
			local theRun = getPlaceByUsername(race.runners, guy.username)

			if theRun == nil then
				local posTl =
					guiUtil.getTl(num, UDim2.new(widths.leads / userSizedColumns, 0, 1, 0), 7, fr, colors.lightGrey)
				posTl.Text = missingRunPlaceholder
			else
				local posTl =
					guiUtil.getTl(num, UDim2.new(widths.leads / userSizedColumns, 0, 1, 0), 1, fr, colors.defaultGrey)
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
	local theRun = getPlaceByUsername(race.runners, localPlayer.Name)
	local youFrame = Instance.new("Frame")
	youFrame.Name = "19.youFrame"
	youFrame.Parent = fr
	youFrame.Size = UDim2.new(widths.leads / userSizedColumns, 0, 1, 0)
	local vv = Instance.new("UIListLayout")
	vv.Parent = youFrame
	vv.FillDirection = Enum.FillDirection.Vertical
	if theRun ~= nil then
		local youTl = guiUtil.getTl("01", UDim2.new(1, 0, 0.5, 0), 1, youFrame, colors.defaultGrey)
		youTl.Text = string.format("%0.3fs", theRun.timeMs / 1000)
		local gap = theRun.timeMs - race.best.timeMs
		local useColor = colors.lightRed
		local plus = "+"
		--determining colors for relative position to leader.
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
			useColor = colors.lightOrange
		elseif gap < 20000 then
			plus = "+"
			useColor = colors.lightRed
		end
		local diffTl = guiUtil.getTl("02", UDim2.new(1, 0, 0.5, 0), 1, youFrame, useColor)
		diffTl.Text = string.format("%s%0.03fs", plus, gap / 1000)
	else
		local youTl = guiUtil.getTl("20", UDim2.new(1, 0, 1, 0), 7, youFrame, colors.lightGrey)
		youTl.Text = missingRunPlaceholder
	end

	local warp = guiUtil.getTb("21.ContestWarp", UDim2.new(widths.warp, 0, 1, 0), 1, fr, colors.lightBlue, 1)
	warp.Text = "Warp"

	warp.Activated:Connect(function()
		local signId = enums.namelower2signId[race.startSignName:lower()]
		warper.requestWarpToSign(signId)
		lastCanvasPosition = scrollingFrame.CanvasPosition
		parentSgui:Destroy()
	end)

	return fr
end

local function getContest(contest: ContestResponseTypes.Contest): ScreenGui
	local rowHeight = 30
	--get contest status for player, aggregated info from other people too.
	local scrollingFrameRows = #contest.races
	local sg = Instance.new("ScreenGui")
	sg.Name = "ContestSG"
	local outerFrame = Instance.new("Frame")
	outerFrame.Name = "ContestFrame"
	outerFrame.BorderMode = Enum.BorderMode.Inset
	outerFrame.BorderSizePixel = 0
	outerFrame.Parent = sg
	outerFrame.Size = UDim2.new(0.85, 0, 0.75, 0)
	outerFrame.Position = UDim2.new(0.15 / 2, 0, 0.25 / 2, 0)
	outerFrame.BackgroundTransparency = 1
	--setup header on list.
	local vv0 = Instance.new("UIListLayout")
	vv0.FillDirection = Enum.FillDirection.Vertical
	vv0.Parent = outerFrame

	local introduction = guiUtil.getTl("00.Introduction", UDim2.new(1, 0, 0, 40), 2, outerFrame, colors.defaultGrey, 1)
	introduction.Text = "Welcome to Contests. Run each race below to compete!"
	introduction.TextXAlignment = Enum.TextXAlignment.Left

	local awards = guiUtil.getTl("01.ContestTitle", UDim2.new(1, 0, 0, 30), 4, outerFrame, colors.defaultGrey, 1)
	awards.Text = contest.name
		.. " - Prizes: Gold contest badge + 1111 tix, Silver + 555 tix, Bronze + 333 tix. Completing all runs: Participation badge + 111tix"
	awards.TextXAlignment = Enum.TextXAlignment.Left

	---------LEADER SUMMARY AND CURRENT RESULTS------------
	local leaderSummaryRow = Instance.new("Frame")
	-- headerFrame.BorderMode = Enum.BorderMode.Inset
	leaderSummaryRow.Parent = outerFrame
	leaderSummaryRow.Name = "02.LeaderSummaryRow"
	leaderSummaryRow.Size = UDim2.new(1, 0, 0, 120)
	local holderIntro = guiUtil.getTl(
		"01.Holder",
		UDim2.new(widths.number + widths.race + widths.dist + widths.leads / userSizedColumns, 0, 1, 0),
		4,
		leaderSummaryRow,
		colors.defaultGrey,
		1
	)
	if contest.contestremaining > 0 then
		spawn(function()
			local ii = 0
			while true do
				ii += 1
				if introduction == nil then
					break
				end
				holderIntro.Text = "Contest End: "
					.. contest.contestend
					.. " UTC\nRemaining: "
					.. tostring(contest.contestremaining - ii)
					.. " seconds."
				if sg == nil then
					break
				end
				wait(1)
			end
		end)
	else
		holderIntro.Text = "Contest is complete. Congrats to the winners!"
	end

	--frame for gold leader

	local jj = 1
	while jj <= maxUsersToDisplayInContest do
		local chunk = makeLeaderCell(contest.leaders[tostring(jj)], jj)
		chunk.Parent = leaderSummaryRow
		jj += 1
	end

	local youpos = makeLeaderCell(contest.user, 12)
	youpos.Parent = leaderSummaryRow

	local vv = Instance.new("UIListLayout")
	vv.FillDirection = Enum.FillDirection.Horizontal
	vv.Parent = leaderSummaryRow

	----------------HEADER--------------
	local headerFrame = Instance.new("Frame")
	-- headerFrame.BorderMode = Enum.BorderMode.Inset
	headerFrame.Parent = outerFrame
	headerFrame.Name = "03.contestHeaderRow"
	headerFrame.Size = UDim2.new(1, 0, 0, rowHeight)
	local vv = Instance.new("UIListLayout")
	vv.FillDirection = Enum.FillDirection.Horizontal
	vv.Parent = headerFrame
	local tl0 = guiUtil.getTl("00", UDim2.new(widths.number, 0, 1, 0), 2, headerFrame, colors.blueDone, 1)
	tl0.Text = "Num"

	local tl = guiUtil.getTl("01", UDim2.new(widths.race, 0, 1, 0), 2, headerFrame, colors.blueDone, 1)
	tl.Text = "Run"

	local tl2 = guiUtil.getTl("02", UDim2.new(widths.dist, 0, 1, 0), 2, headerFrame, colors.blueDone, 1)
	tl2.Text = "Dist"

	--lead section consists of best, gold,silver,bronze,4-8th (8), plus YOU
	local leadCount = maxUsersToDisplayInContest + 2 --(display+best+YOU)

	local tl3 = guiUtil.getTl("03", UDim2.new(widths.leads / leadCount, 0, 1, 0), 2, headerFrame, colors.blueDone, 1)
	tl3.Text = "Best"

	local ii = 1

	while ii <= maxUsersToDisplayInContest do
		local tl = guiUtil.getTl(
			string.format("%02d", 3 + ii),
			UDim2.new(widths.leads / leadCount, 0, 1, 0),
			2,
			headerFrame,
			colors.blueDone,
			1
		)
		local text = tpUtil.getCardinal(ii)
		if ii == 1 then
			text = "Gold"
		elseif ii == 2 then
			text = "Silver"
		elseif ii == 3 then
			text = "Bronze"
		end
		tl.Text = text
		ii += 1
	end

	local tlYou = guiUtil.getTl("14", UDim2.new(widths.leads / leadCount, 0, 1, 0), 2, headerFrame, colors.blueDone, 1)
	tlYou.Text = "You"

	local warp = guiUtil.getTl("15", UDim2.new(widths.warp, 0, 1, 0), 2, headerFrame, colors.blueDone, 1)
	warp.Text = "Warp"

	--scrolling setting frame
	local frameName = "04ContestScrollingFrame"
	local scrollingFrame = Instance.new("ScrollingFrame")
	-- -- scrollingFrame.BorderMode = Enum.BorderMode.Inset
	scrollingFrame.BorderSizePixel = 0
	scrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollingFrame.ScrollBarThickness = 10

	scrollingFrame.Name = frameName
	scrollingFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	scrollingFrame.Parent = outerFrame
	local maxYPixels = scrollingFrameRows * rowHeight
	local windowScrollPanelHeight = maxYPixels
	local showScrollbar = false
	if maxYPixels > 400 then
		windowScrollPanelHeight = 400
		showScrollbar = true
	end
	scrollingFrame.Size = UDim2.new(1, 0, 0, windowScrollPanelHeight)
	scrollingFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	scrollingFrame.VerticalScrollBarPosition = Enum.VerticalScrollBarPosition.Left
	--TODO this scrollingness is kinda useless.
	scrollingFrame.CanvasSize = UDim2.new(1, 0, 0, maxYPixels)
	local vv = Instance.new("UIListLayout")
	vv.FillDirection = Enum.FillDirection.Vertical
	vv.Parent = scrollingFrame

	for ii, race: ContestResponseTypes.ContestRace in ipairs(contest.races) do
		local rowFrame = makeContestRow(
			contest,
			race,
			ii + 10,
			sg,
			scrollingFrame,
			{ requestWarpToSign = warper.requestWarpToSign },
			showScrollbar
		)
		rowFrame.Parent = scrollingFrame
	end

	local tb = guiUtil.getTbSimple()
	tb.Text = "Close"
	tb.Name = "ZZZPopularCloseButton"
	tb.Size = UDim2.new(1, 0, 0, 30)
	tb.BackgroundColor3 = colors.redStop
	tb.Parent = outerFrame
	tb.Activated:Connect(function()
		--store last scroll position
		lastCanvasPosition = scrollingFrame.CanvasPosition
		sg:Destroy()
	end)
	scrollingFrame.CanvasPosition = lastCanvasPosition

	return sg
end

local function makeGetter(contest: ContestResponseTypes.Contest, userIds: { number }): (Player) -> (ScreenGui)
	local function f(localPlayer: Player): ScreenGui
		local newcontest = getSingleContestFunction:InvokeServer(userIds, contest.contestid)
		return getContest(newcontest)
	end
	return f
end

module.getContestButtons = function(userIds: { number }): { gt.actionButton }
	local contests: { ContestResponseTypes.Contest } = getContestsFunction:InvokeServer(userIds)
	local res = {}
	for _, contest in ipairs(contests) do
		local contestButton: gt.actionButton = {
			name = "Contest Button" .. contest.name,
			contentsGetter = makeGetter(contest, userIds),
			hoverHint = "Show Contests Ranks",
			shortName = contest.name .. " (" .. tostring(#contest.races) .. ")",
			getActive = function()
				return contest.contestremaining > 0
			end,
		}
		table.insert(res, contestButton)
	end

	return res
end

local function handleUserSettingChanged(player: Player, setting: tt.userSettingValue)
	if setting.name == "shorten contest digit display" then
		if setting.value then
			shortenContestDigitDisplay = true
		else
			shortenContestDigitDisplay = false
		end
	end
end

local localFunctions = require(game.ReplicatedStorage.localFunctions)
localFunctions.registerSettingChangeReceiver(function(player: Player, item)
	return handleUserSettingChanged(player, item)
end, "shorten contest digit display")

return module
