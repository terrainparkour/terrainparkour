--!strict

--a button that will pop a UI for showing popular top runs in game

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local PlayersService = game:GetService("Players")

local localPlayer = PlayersService.LocalPlayer
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local gt = require(game.ReplicatedStorage.gui.guiTypes)
local colors = require(game.ReplicatedStorage.util.colors)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local tt = require(game.ReplicatedStorage.types.gametypes)
local gt = require(game.ReplicatedStorage.gui.guiTypes)

local PopularResponseTypes = require(game.ReplicatedStorage.types.PopularResponseTypes)
local enums = require(game.ReplicatedStorage.util.enums)
local remotes = require(game.ReplicatedStorage.util.remotes)

local thumbnails = require(game.ReplicatedStorage.thumbnails)

local getNewRunsFunction = remotes.getRemoteFunction("GetNewRunsFunction")

local warper = require(game.StarterPlayer.StarterPlayerScripts.warper)

local module = {}

local lastCanvasPosition = Vector2.new(0, 0)

local function makeLeaderPositionChip(
	ii: number,
	el: { userId: number, place: number, username: string },
	width: number
): Frame
	local positionFrame = Instance.new("Frame")
	positionFrame.Name = string.format("%02d", ii) .. "_race_position"
	-- positionFrame.BorderMode = Enum.BorderMode.Inset
	positionFrame.Size = UDim2.new(width, 0, 1, 0)
	local hh = Instance.new("UIListLayout")
	hh.FillDirection = Enum.FillDirection.Horizontal
	hh.Parent = positionFrame
	--portrait

	local useColor = colors.defaultGrey
	if el.userId == localPlayer.UserId then
		useColor = colors.meColor
	end
	local img = Instance.new("ImageLabel")
	img.BorderMode = Enum.BorderMode.Outline
	img.BorderSizePixel = 0
	img.Size = UDim2.new(0.4, 0, 1, 0)
	local content =
		thumbnails.getThumbnailContent(el.userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
	-- local content,_ = Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
	img.Image = content
	img.BackgroundColor3 = useColor
	img.Name = "1img"
	img.Parent = positionFrame

	--position

	local right = Instance.new("Frame")
	right.Name = "2positionStuff"
	right.Size = UDim2.new(0.6, 0, 1, 0)
	right.Parent = positionFrame
	local vv = Instance.new("UIListLayout")
	vv.Parent = right
	vv.FillDirection = Enum.FillDirection.Vertical
	local posColor = colors.defaultGrey

	local useText = ""
	if el.place == nil then
		useText = "No Run"
		posColor = colors.defaultGrey
	elseif el.place > 10 then
		useText = "dnp"
		posColor = colors.defaultGrey
	else
		useText = tpUtil.getCardinalEmoji(el.place)
		if el.place == 1 then
			posColor = colors.greenGo
		else
			posColor = colors.lightBlue
		end
	end
	local pos = guiUtil.getTl("2pos", UDim2.new(1, 0, 0.5, 0), 1, right, posColor, 0)
	pos.Text = useText

	--TODO make sure this got fixed
	local username = guiUtil.getTl("3pos", UDim2.new(1, 0, 0.5, 0), 1, right, useColor, 0)
	username.Text = el.username

	return positionFrame
end

local function makePopRowFrame(
	pop: PopularResponseTypes.popularRaceResult,
	ii: number,
	parentSgui: ScreenGui,
	scrollingFrame: ScrollingFrame,
	warper: (startSignId: number, endSignId: number) -> ()
): Frame
	local fr = Instance.new("Frame")
	-- fr.BorderMode = Enum.BorderMode.Inset
	fr.BorderSizePixel = 0
	fr.Name = string.format("%03d", ii) .. "PopularResultFrameRow"
	fr.Size = UDim2.new(1, -10, 0.12, 0)
	local vv = Instance.new("UIListLayout")
	vv.FillDirection = Enum.FillDirection.Horizontal
	vv.Parent = fr

	local ct = guiUtil.getTl("PopularResult_1_CT", UDim2.new(0.06, 0, 1, 0), 2, fr, colors.defaultGrey)
	if pop.ct == 0 then
		ct.Text = "-"
	else
		ct.Text = tostring(pop.ct)
	end
	if pop.wasLastRace then
		ct.BorderSizePixel = 3
		ct.BorderColor3 = colors.greenGo
	end

	local kind = guiUtil.getTl("PopularResult_2_kind", UDim2.new(0.05, 0, 1, 0), 2, fr, colors.defaultGrey, 1)

	kind.Text = pop.kind

	local race = Instance.new("Frame")
	race.Size = UDim2.new(0.3, 0, 1, 0)
	race.Name = "PopularResult_3_Race"
	race.Parent = fr
	local vv = Instance.new("UIListLayout")
	vv.Parent = race
	vv.FillDirection = Enum.FillDirection.Vertical

	local start = guiUtil.getTl("PopularResult_2_0Start", UDim2.new(1, 0, 0.5, 0), 1, race, colors.signColor, 0)
	start.Text = pop.startSignName
	start.TextColor3 = colors.signTextColor
	start.TextXAlignment = Enum.TextXAlignment.Left

	local endChip = guiUtil.getTl("PopularResult_2_1End", UDim2.new(1, 0, 0.5, 0), 1, race, colors.signColor, 0)
	endChip.Text = pop.endSignName
	endChip.TextColor3 = colors.signTextColor
	endChip.TextXAlignment = Enum.TextXAlignment.Left

	local leaderFrame = Instance.new("Frame")
	-- leaderFrame.BorderMode = Enum.BorderMode.Inset
	leaderFrame.Size = UDim2.new(0.44, 0, 1, 0)
	leaderFrame.Parent = fr
	leaderFrame.Name = "PopularResult_4_Leaders"
	leaderFrame.AutomaticSize = Enum.AutomaticSize.Y
	local hh = Instance.new("UIListLayout")
	hh.FillDirection = Enum.FillDirection.Horizontal
	hh.Parent = leaderFrame

	for ii, el in ipairs(pop.userPlaces) do
		if el.place == nil then
			continue
		end
		local width = 1 / #pop.userPlaces
		width = math.min(width, 1 / 3)
		local chip = makeLeaderPositionChip(ii, el, width)
		chip.AutomaticSize = Enum.AutomaticSize.Y
		chip.Parent = leaderFrame
	end

	local mode = "found"
	if not pop.hasFoundStart then
		mode = "unfound"
	end
	if pop.hasFoundStart and enums.SignIdIsExcludedFromStart[pop.startSignId] then
		mode = "excluded"
	end

	if mode == "found" then
		local warp = guiUtil.getTb("PopularResult_4_Warp", UDim2.new(0.15, 0, 1, 0), 1, fr, colors.lightBlue, 1)
		warp.Text = "Warp"

		warp.Activated:Connect(function()
			warper(pop.startSignId, pop.endSignId)
			lastCanvasPosition = scrollingFrame.CanvasPosition
			parentSgui:Destroy()
		end)
	end
	if mode == "unfound" then
		local cantwarp =
			guiUtil.getTl("PopularResult_4_unfound", UDim2.new(0.15, 0, 1, 0), 2, fr, colors.defaultGrey, 1)
		cantwarp.Text = "Find Sign First"
	end
	if mode == "excluded" then
		local cantwarp =
			guiUtil.getTl("PopularResult_4_excluded", UDim2.new(0.15, 0, 1, 0), 2, fr, colors.defaultGrey, 1)
		cantwarp.Text = "Excluded"
	end

	return fr
end

local function getNewContents(player: Player, userIds: { number }): ScreenGui
	local popResults: { PopularResponseTypes.popularRaceResult } = getNewRunsFunction:InvokeServer(userIds)

	local screenGui = Instance.new("ScreenGui")
	screenGui.IgnoreGuiInset = true
	screenGui.Name = "PopularSG"
	local outerFrame = Instance.new("Frame")
	outerFrame.Name = "PopularFrame"
	outerFrame.BorderMode = Enum.BorderMode.Inset
	outerFrame.BorderSizePixel = 0
	outerFrame.Parent = screenGui
	outerFrame.Size = UDim2.new(0.5, 0, 0.6, 0)
	outerFrame.Position = UDim2.new(0.25, 0, 0.2, 0)
	outerFrame.BackgroundTransparency = 1
	--setup header on list.
	local vv0 = Instance.new("UIListLayout")
	vv0.FillDirection = Enum.FillDirection.Vertical
	vv0.Parent = outerFrame

	local tb = guiUtil.getTl("00NewTitle", UDim2.new(1, 0, 0, 30), 2, outerFrame, colors.defaultGrey, 1)
	tb.Text = "New Runs"

	local headerFrame = Instance.new("Frame")
	-- headerFrame.BorderMode = Enum.BorderMode.Inset
	headerFrame.Parent = outerFrame
	headerFrame.Name = "01popularHeaderRow"
	headerFrame.Size = UDim2.new(1, 0, 0, 20)
	local vv = Instance.new("UIListLayout")
	vv.FillDirection = Enum.FillDirection.Horizontal
	vv.Parent = headerFrame
	local tl = guiUtil.getTl("1", UDim2.new(0.06, 0, 0, 20), 2, headerFrame, colors.blueDone, 1)
	tl.Text = "Count"

	local tl2 = guiUtil.getTl("3", UDim2.new(0.3, 0, 0, 20), 2, headerFrame, colors.blueDone, 1)
	tl2.Text = "Run"

	local tlkind = guiUtil.getTl("2", UDim2.new(0.05, 0, 0, 20), 2, headerFrame, colors.blueDone, 1)
	tlkind.Text = "Kind"

	local tl3 = guiUtil.getTl("4", UDim2.new(0.44, 0, 0, 20), 2, headerFrame, colors.blueDone, 1)
	tl3.Text = "Leaders"

	local warp = guiUtil.getTl("5", UDim2.new(0.15, 0, 0, 20), 2, headerFrame, colors.blueDone, 1)
	warp.Text = "Warp"

	--scrolling setting frame
	local frameName = "1PopularScrollingFrame"
	local scrollingFrame = Instance.new("ScrollingFrame")
	-- scrollingFrame.BorderMode = Enum.BorderMode.Inset
	scrollingFrame.BorderSizePixel = 0
	scrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollingFrame.ScrollBarThickness = 10

	scrollingFrame.Name = frameName
	scrollingFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	scrollingFrame.Parent = outerFrame
	scrollingFrame.Size = UDim2.new(1, 0, 1, -80)
	scrollingFrame.VerticalScrollBarInset = Enum.ScrollBarInset.Always
	scrollingFrame.CanvasSize = UDim2.new(1, 0, 1, 0)
	local vv = Instance.new("UIListLayout")
	vv.FillDirection = Enum.FillDirection.Vertical
	vv.Parent = scrollingFrame

	for ii, pop in ipairs(popResults) do
		local rowFrame = makePopRowFrame(
			pop,
			ii,
			screenGui,
			scrollingFrame,
			warper.WarpToSignId
			--we make this new enclosure to make sure the type manager realizes taht in this case
			--we don't care about the return value.
		)
		rowFrame.Parent = scrollingFrame
	end

	local tb = guiUtil.getTbSimple()
	tb.Text = "Close"
	tb.Name = "ZZZPopularCloseButton"
	tb.Size = UDim2.new(1, 0, 0, 50)
	tb.BackgroundColor3 = colors.redStop
	tb.Parent = outerFrame
	tb.Activated:Connect(function()
		--store last scroll position
		lastCanvasPosition = scrollingFrame.CanvasPosition
		screenGui:Destroy()
	end)
	scrollingFrame.CanvasPosition = lastCanvasPosition

	return screenGui
end

local newButton: gt.actionButton = {
	name = "New Button",
	contentsGetter = getNewContents,
	hoverHint = "Show new first place runs",
	shortName = "New",
	getActive = function()
		return true
	end,
	widthXScale = 0.25,
}

module.newButton = newButton

_annotate("end")
return module
