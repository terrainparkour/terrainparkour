--!strict
--eval 9.25.22

--2022 remaining bug: sometimes you get fail.04 or fail.05 and permanent  shifting.
--2022.02.12 why is this so hard to get right? or rather why doesn't it just work out of the box?
--2022.02.24 revisiting to finally fix LB bugs.

--2024 I'm struck by how when i left the game, this felt extremely complicated
--yet when I'm back now, it's very simple. Some huge too large functions hacking around with TLs, and otherwise a very simple loop of getting and updating data
--with some funk bits about local caching etc.
--but at a core level, this could pretty easily be redone and simplified, move the TL stuff out so the row management logic is visible
--really, why did I do this at all?
--it seems there also was an unused layer of deboucing for repeated quick joins, which was why there would occasionally be bugs?

-- 2024: the whole way this is done seems maybe backwards now?
-- like, why don't i have each client request the data they need?
-- i supposed because regardless, I still need a big push system from server to client so everybody can receive updates.
-- so i probably figured, why not just reuse that for the first data?
-- the problem is apparently something about leaving and rejoining, where in cases like that the 2nd join doesn't ever get data in it?
-- okay so overall the fix i'm trying is: remove the wrong? broken? partial blocker.
-- and genericize joins here.

local vscdebug = require(game.ReplicatedStorage.vscdebug)

local TweenService = game:GetService("TweenService")
local PlayersService = game:GetService("Players")

local leaderboardButtons = require(game.StarterPlayer.StarterCharacterScripts.buttons.leaderboardButtons)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
repeat
	game:GetService("RunService").RenderStepped:wait()
until game.Players.LocalPlayer.Character ~= nil

local StarterPlayer = game:GetService("StarterPlayer")
local LocalPlayer = game:GetService("Players").LocalPlayer
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local enums = require(game.ReplicatedStorage.util.enums)
local colors = require(game.ReplicatedStorage.util.colors)
local thumbnails = require(game.ReplicatedStorage.thumbnails)
local mt = require(game.StarterPlayer.StarterCharacterScripts.marathon.marathonTypes)
local tt = require(game.ReplicatedStorage.types.gametypes)
local remotes = require(game.ReplicatedStorage.util.remotes)

local toolTip = require(game.ReplicatedStorage.gui.toolTip)
local marathonClient = require(StarterPlayer.StarterCharacterScripts.marathon.marathonClient)
local mds = require(game.ReplicatedStorage.marathonDescriptors)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local lbEnums = require(game.ReplicatedStorage.enums.lbEnums)

local localRdb = require(game.ReplicatedStorage.localRdb)

local lbIsEnabled = true
local localPlayer = PlayersService.LocalPlayer
local doAnnotation = localPlayer.UserId == enums.objects.TerrainParkour and false
local function annotate(s): nil
	if doAnnotation then
		print("lb.client: " .. string.format("%.0f", tick()) .. " : " .. s)
	end
end

--used to do reverse ordering items in lb
local bignum = 10000000

-- this covers all the different types of lbupdates that can be sent. for example, one is tt_afterrundata, another is tt_inital join data + username,
type genericLbUpdateDataType = { [string]: number | string }

--returns changed keys and oldvalue
type userDataChange = { key: string, oldValue: number, newValue: number }

--map of { userId to {keyname:number}}
--note this is stored over time and serves as an in-user-memory re-usable cache.
local lbUserData: { [number]: genericLbUpdateDataType } = {}

--test wrapping this here to force stronger typing
type rowFrameType = { frame: Frame }

--the user-focused rowFrames go here.
local userId2rowframe: { [number]: rowFrameType } = {}

--the outer, created on time lbframe.
local lbframe: Frame

--active tracking
local lbRowCount = 0

--pixel heights.
local lbHeaderY = 19
local lbPlayerRowY = 24
local userLbRowCellWidth = 43
local lbwidth = 0
local lbtrans = 0.55

--descriptors used for user-LB rows for which the later ones, updates come up from server.
type lbUserCellDescriptorType = {
	name: string,
	num: number,
	width: number,
	userFacingName: string,
	tooltip: string,
	transparency: number,
}

--use num to artificially keep them separated
--these are the horizontal sections of each row.
local lbUserCellDescriptors: { lbUserCellDescriptorType } = {
	{ name = "portrait", num = 1, width = lbPlayerRowY, userFacingName = "", tooltip = "", transparency = 1 },
	{ name = "username", num = 3, width = 80, userFacingName = "", tooltip = "", transparency = 1 },
	{
		name = "awardCount",
		num = 5,
		width = userLbRowCellWidth - 10,
		userFacingName = "awards",
		tooltip = "How many special awards you've earned from contests or other achievements.",
		transparency = lbtrans,
	},
	{
		name = "userTix",
		num = 7,
		width = userLbRowCellWidth,
		userFacingName = "tix",
		tooltip = "How many tix you've earned from your runs and finds and records.",
		transparency = lbtrans,
	},
	{
		name = "userTotalFindCount",
		num = 9,
		width = userLbRowCellWidth,
		userFacingName = "finds",
		tooltip = "How many signs you've found!",
		transparency = lbtrans,
	},
	{
		name = "findRank",
		num = 11,
		width = userLbRowCellWidth,
		userFacingName = "rank",
		tooltip = "Your rank of how many signs you've found.",
		transparency = lbtrans,
	},
	{
		name = "userCompetitiveWRCount",
		num = 13,
		width = userLbRowCellWidth - 8,
		userFacingName = "cwrs",
		tooltip = "How many World Records you hold in competitive races!",
		transparency = lbtrans,
	},
	{
		name = "userTotalWRCount",
		num = 15,
		width = userLbRowCellWidth,
		userFacingName = "wrs",
		tooltip = "How many World Records you hold right now.",
		transparency = lbtrans,
	},
	{
		name = "top10s",
		num = 18,
		width = userLbRowCellWidth,
		userFacingName = "top10s",
		tooltip = "How many of your runs are still in the top10.",
		transparency = lbtrans,
	},
	{
		name = "races",
		num = 23,
		width = userLbRowCellWidth,
		userFacingName = "races",
		tooltip = "How many distinct runs you've done.",
		transparency = lbtrans,
	},
	{
		name = "runs",
		num = 26,
		width = userLbRowCellWidth,
		userFacingName = "runs",
		tooltip = "How many runs you've done in total.",
		transparency = lbtrans,
	},
	{
		name = "badgeCount",
		num = 31,
		width = userLbRowCellWidth,
		userFacingName = "badges",
		tooltip = "Total game badges you have won.",
		transparency = lbtrans,
	},
}

--why do I call this a lot? curious. Also, should I call it before or after adding the new RowFrame?
local function resetLbHeight(): nil
	lbframe.Size = UDim2.new(0, lbwidth, 0, lbHeaderY + lbPlayerRowY * lbRowCount)
end

--setup header row as first row in lbframe
--call once per character creation - the outer frame which has rows added/removed from it.
local function makeLBHeaderRowFrame(): Frame
	local headerFrame = Instance.new("Frame")
	headerFrame.Parent = lbframe
	headerFrame.BorderMode = Enum.BorderMode.Inset
	headerFrame.BorderSizePixel = 0
	headerFrame.Name = "00000000-lb-headerframe"
	headerFrame.Size = UDim2.new(1, 0, 0, lbHeaderY)
	headerFrame.BackgroundTransparency = 1
	local uu = Instance.new("UIListLayout")
	uu.FillDirection = Enum.FillDirection.Horizontal
	uu.Parent = headerFrame

	--create initial tiles for top of LB
	for _, lbUserCellDescriptor: lbUserCellDescriptorType in pairs(lbUserCellDescriptors) do
		local el = guiUtil.getTl(
			string.format("%02d.header.%s", lbUserCellDescriptor.num, lbUserCellDescriptor.userFacingName),
			UDim2.new(0, lbUserCellDescriptor.width, 1, 0),
			2,
			headerFrame,
			colors.defaultGrey,
			0,
			lbUserCellDescriptor.transparency
		)
		if lbUserCellDescriptor.tooltip ~= "" then
			toolTip.setupToolTip(localPlayer, el, lbUserCellDescriptor.tooltip, UDim2.fromOffset(300, 40), false)
		end
		el.Text = lbUserCellDescriptor.userFacingName
		el.ZIndex = lbUserCellDescriptor.num
		el.TextXAlignment = Enum.TextXAlignment.Center
		el.TextYAlignment = Enum.TextYAlignment.Center
		-- end
	end
	return headerFrame
end

--problem: we also need to artificially trigger a user 'rejoin' to do this right.
--this basically works, except if you toggle the setting we do not know to re-send/reload in-server players.
local function completelyResetUserLB()
	--make initial row only. then as things happen (people join, or updates come in, apply them in-place)

	local pgui: PlayerGui = localPlayer:WaitForChild("PlayerGui")
	local oldLbSgui: ScreenGui? = pgui:FindFirstChild("LeaderboardScreenGui")
	if oldLbSgui ~= nil then
		oldLbSgui:Destroy()
	end
	if not lbIsEnabled then
		annotate("reset lb and it's disabled now so just end.")
		return
	end
	local lbSgui: ScreenGui = Instance.new("ScreenGui")
	lbSgui.Name = "LeaderboardScreenGui"
	lbSgui.Parent = pgui
	lbframe = Instance.new("Frame")
	lbframe.BorderMode = Enum.BorderMode.Inset
	lbframe.BorderSizePixel = 0
	lbframe.Parent = lbSgui
	lbframe.Size = UDim2.new(0, 0.2, 0, 0)
	lbframe.Position = UDim2.new(1, -1 * lbwidth - 3, 0, -36)
	lbframe.Name = "LeaderboardFrame"
	lbframe.BackgroundTransparency = 1
	local uu = Instance.new("UIListLayout")
	uu.FillDirection = Enum.FillDirection.Vertical
	uu.Name = "lbUIListLayout"
	uu.Parent = lbframe
	uu.HorizontalAlignment = Enum.HorizontalAlignment.Right

	lbRowCount = 0
	resetLbHeight()

	local headerFrame = makeLBHeaderRowFrame()
	headerFrame.Parent = lbframe

	leaderboardButtons.initActionButtons(lbframe, localPlayer)

	marathonClient.ReInitActiveMarathons()
end

--important to use all lbUserCellParams here to make the row complete
--even if an update comes before the loading of full stats.

local function createLbRowframeAboutUser(userId: number, username: string): rowFrameType?
	--remember, this user may not actually be present in the server!
	local rowFrame: rowFrameType = { frame = Instance.new("Frame") }
	local userDataFromCache = lbUserData[userId]
	if not username then
		--just look
		username = localRdb.getUsernameByUserId(userId)
	end
	--we need this to get ordering before tix are known.
	if userDataFromCache.userTix == nil then
		userDataFromCache.userTix = 0
	end

	local userTixCount: number = userDataFromCache.userTix :: number
	--we order by usertix. Surely this isn't the right way to do this. Plus it'd be SO nice to have alternative sorting orders or filtering/etc! TODO 2024
	local rowName = tostring((bignum - userTixCount) .. username)
	rowFrame.frame.Name = rowName
	rowFrame.frame.Size = UDim2.new(1, 0, 0, lbPlayerRowY)
	rowFrame.frame.BorderMode = Enum.BorderMode.Inset
	rowFrame.frame.BorderSizePixel = 0
	rowFrame.frame.BackgroundTransparency = 1
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Parent = rowFrame.frame
	rowFrame.frame.Parent = lbframe
	local bgcolor = colors.grey
	if userId == localPlayer.UserId then
		bgcolor = colors.meColor
	end

	for _, lbUserCellDescriptor: lbUserCellDescriptorType in pairs(lbUserCellDescriptors) do
		if lbUserCellDescriptor.name == "portrait" then
			local img = Instance.new("ImageLabel")
			img.Size = UDim2.new(0, lbUserCellDescriptor.width, 1, 0)
			local content = thumbnails.getThumbnailContent(userId, Enum.ThumbnailType.HeadShot)
			img.Image = content
			img.BackgroundColor3 = bgcolor
			img.Name = string.format("%02d.value", lbUserCellDescriptor.num)
			img.Parent = rowFrame.frame
			img.BorderMode = Enum.BorderMode.Outline
			-- img.BorderSizePixel=1

			if false then --disabled user thumbnail mouseover TODO
				local content2 = thumbnails.getThumbnailContent(userId, Enum.ThumbnailType.HeadShot, 256, 256)
				local innerImg = Instance.new("ImageLabel")
				innerImg.Size = UDim2.new(1, 0, 1, 0)
				innerImg.Image = content2
				innerImg.BackgroundColor3 = bgcolor
				innerImg.Name = string.format("%02d.inner.bigImg", lbUserCellDescriptor.num)
				toolTip.setupToolTip(localPlayer, img, innerImg, UDim2.fromOffset(200, 200), true)
			end
			img.BackgroundTransparency = lbEnums.lbTransparency
			img.BorderSizePixel = 1
		else --it's a textlabel whatever we're generating anyway.
			local tl = guiUtil.getTl(
				string.format("%02d.value", lbUserCellDescriptor.num),
				UDim2.new(0, lbUserCellDescriptor.width - 3, 1, 0),
				2,
				rowFrame.frame,
				bgcolor,
				1,
				lbEnums.lbTransparency
			)

			--find text for value.
			--note that depending on what the user does first, userDataFromCache may have missing values.
			if lbUserCellDescriptor.name == "findRank" then
				local foundRank = userDataFromCache.findRank
				if foundRank ~= nil then
					tl.Text = tpUtil.getCardinalEmoji(foundRank)
				end
			elseif lbUserCellDescriptor.name == "username" then
				tl.Text = username
			elseif lbUserCellDescriptor.name == "badges" then
				tl.Text = "..."
			else
				local candidateTextValue = userDataFromCache[lbUserCellDescriptor.name]

				local textValue: string
				if candidateTextValue == nil then
					textValue = ""
				else
					textValue = tostring(candidateTextValue)
				end
				tl.Text = textValue
			end
		end
	end
	return rowFrame
end

--after receiving an lb update, figure out what changed relative to known data
--store it and return a userDataChange for rendering into the LB
local function storeUserData(userId: number, data: genericLbUpdateDataType): { userDataChange }
	local res: { userDataChange } = {}
	if lbUserData[userId] == nil then --received new data.
		lbUserData[userId] = {}
	end

	--TODO is there ever a case where there's out of order in time data/
	-- like, I shouldn't update to a value that's earlier than the value for a key i've got already.
	for key: string, newValue in pairs(data) do
		if newValue == nil then
			--don't know why this would happen, probably impossible.
			warn("no newvalue " .. key)
			continue
		end
		local oldValue = lbUserData[userId][key]
		if newValue ~= oldValue then
			--reset source of truth to the new data that came in.
			local change: userDataChange = { key = key, oldValue = oldValue, newValue = newValue }
			lbUserData[userId][key] = newValue
			table.insert(res, change)
		end
	end
	return res
end

-- ctrl+M,0 to fold, ctrl+m,j to open.

--1.
--q: what happens if you receive multiple of these at the same time? how to debounce this?
--a: just let it happen. most significant ones won't collide.

-- naming: the FOR user is obviously the one whose local script this is.
-- but the object of the row, i.e. the person whose data we are showing, is another user potentiall, the one this
-- is all ABOUT.
local function receivedLBUpdateAboutUser(userData: genericLbUpdateDataType, initial: boolean): nil
	if not lbIsEnabled then
		return
	end
	local subjectUserId = userData.userId
	-- print("got info about: ", subjectUserId)
	-- print(userData)
	--check if this client's user has any lbframe.
	if subjectUserId == nil then
		warn("nil userid for update.: " .. tostring(initial))
		warn(userData)
		return
	end

	if lbframe == nil then
		completelyResetUserLB()
	elseif lbframe.Parent == nil then
		completelyResetUserLB()
	end

	--first check if there is anything worthwhile to draw - anything changed.

	local userDataChanges = storeUserData(subjectUserId, userData)
	if userDataChanges == {} then
		warn("redrawUserLBRow.die since not different for target: " .. subjectUserId)
		return
	end

	--patch things up if needed.
	local userRowFrame: rowFrameType = userId2rowframe[subjectUserId]
	if userRowFrame == nil or userRowFrame.frame.Parent == nil then
		if userRowFrame == nil then
		else
			userRowFrame.frame:Destroy()
		end
		userId2rowframe[subjectUserId] = nil
		local candidateRowFrame: rowFrameType = createLbRowframeAboutUser(subjectUserId, userData.name)
		if candidateRowFrame == nil then --case when the user is gone already.
			return
		end
		lbRowCount = lbRowCount + 1
		resetLbHeight()
		userId2rowframe[subjectUserId] = candidateRowFrame
		userRowFrame = candidateRowFrame
		userRowFrame.frame.Parent = lbframe
	end

	local bgcolor = colors.grey
	if subjectUserId == localPlayer.UserId then
		bgcolor = colors.meColor
	end

	for _, change in pairs(userDataChanges) do
		-- find the userCellDescriptor corresponding to it.

		local descriptor = nil
		for _, lbUserCellDescriptor in ipairs(lbUserCellDescriptors) do
			if lbUserCellDescriptor.name == change.key then
				descriptor = lbUserCellDescriptor
				break
			end
		end

		--if we receive a tix update, update rowframe. This is because we order by tix count.
		if change.key == "userTix" then
			local username = localRdb.getUsernameByUserId(subjectUserId)
			local newName = tostring(bignum - change.newValue) .. username
			userRowFrame.frame.Name = newName
			userRowFrame.frame.Name = newName
		end

		--if no descriptor, quit. effectively the same as name doesn't appear in: updateUserLbRowKeys
		--note: this can happen because lbupdates have full BE stats in them, not all of which we render into LB
		if descriptor == nil then
			continue
		end

		local targetName = string.format("%02d.value", descriptor.num)
		--it's important this targetname matches via interpolatino
		local oldTextLabel: TextLabel = userRowFrame.frame:FindFirstChild(targetName) :: TextLabel
		if oldTextLabel == nil then
			warn("Missing old label to put in - this should not happen " .. descriptor.num)
			warn(descriptor)
		end
		if oldTextLabel ~= nil then
			oldTextLabel:Destroy()
		end

		--if this exists, do green fade
		local newIntermediateText: string? = nil

		--what do we have to do.
		--we have old number and new number.
		--if not findRank, calculate the intermediate text and set up greenfade.
		--and in either case, do a green fade.
		local newFinalText = tostring(change.newValue)
		if descriptor.name == "findRank" then
			newFinalText = tpUtil.getCardinalEmoji(change.newValue)
		end

		local improvement = false

		--oldValue may be nil indicating nothing known.
		if change.oldValue and not initial then
			local gap = change.newValue - change.oldValue
			local sign = ""
			if gap > 0 then
				improvement = true
				sign = "+"
			end
			--findrank (rank decrease) is always semantically positive
			if change.key == "findRank" then
				improvement = not improvement
				sign = ""
			end
			if gap ~= 0 then
				newIntermediateText = string.format("%s\n(%s%s)", newFinalText, sign, gap)
			end
		end

		--so this basically means, if you're trying to do initial user setup, and then you find that
		-- one of the changes you're intending to apply is actually an overwrite, don't do it.
		-- i'm not sure how this is supposed to work - probably legacy from when I didn't have tix
		-- separated out. what's actually happening is that tix is showing up as loaded already
		-- probably because the main user data stuff is slower than the tix load stuff.
		if change.oldValue and initial then
			warn("weird initial.")
			print(userData)
			print(userDataChanges)
			print(change)
			print(newIntermediateText)
		end

		local newTL = guiUtil.getTl(
			string.format("%02d.value", descriptor.num),
			UDim2.new(0, descriptor.width, 1, 0),
			2,
			userRowFrame.frame,
			bgcolor,
			1,
			lbEnums.lbTransparency
		)
		local par = newTL.Parent :: TextLabel

		--phase to new color if needed
		if newIntermediateText == nil then
			newTL.Text = newFinalText
			newTL.BackgroundColor3 = bgcolor
			par.BackgroundColor3 = bgcolor
		else
			if improvement then
				newTL.BackgroundColor3 = colors.greenGo
				par.BackgroundColor3 = colors.greenGo
			else
				newTL.BackgroundColor3 = colors.lightRed
				par.BackgroundColor3 = colors.lightRed
			end
			newTL.Text = newIntermediateText
			spawn(function()
				wait(enums.greenTime)
				newTL.Text = newFinalText
			end)
			local tween = TweenService:Create(newTL, TweenInfo.new(enums.greenTime), { BackgroundColor3 = bgcolor })
			tween:Play()
			local tween2 =
				TweenService:Create(newTL.Parent, TweenInfo.new(enums.greenTime), { BackgroundColor3 = bgcolor })
			tween2:Play()
		end
	end
end

local function removeUserLBRow(userId: number)
	if not lbIsEnabled then
		return
	end
	local row: rowFrameType = userId2rowframe[userId]
	userId2rowframe[userId] = nil
	lbUserData[userId] = nil
	if row ~= nil then
		pcall(function()
			if row.frame ~= nil then
				row.frame:Destroy()
			end
		end)
		if lbRowCount > 0 then
			lbRowCount = math.min(0, lbRowCount - 1)
		else
			warn("okay, clear error here. lbRowcount too low")
		end
	end
	resetLbHeight()
end

--data is a list of kvs for update data. if any change, redraw the row (and highlight that cell.)
--First keyed to receive data about a userId. But later overloading data to just be blobs  of things of specific types to display in leaderboard.
local function clientReceiveNewLeaderboardData(lbUpdateData: genericLbUpdateDataType)
	lbUpdateData.userId = tonumber(lbUpdateData.userId)

	if lbUpdateData.kind == "leave" then
		lbUserData[lbUpdateData.userId] = nil
		removeUserLBRow(lbUpdateData.userId)
		return
	end

	local initial = false
	if
		lbUpdateData.kind == "update other about joiner"
		or lbUpdateData.kind == "update joiner lb"
		or lbUpdateData.kind == "joiner update other lb"
	then
		initial = true
	elseif lbUpdateData.kind == "badge update" then
		initial = false
	else
		print("unknown incoming data KIND. is this even needed (setup)?" .. lbUpdateData.kind)
		initial = false
	end

	-- print(string.format("LBUpdate: %s for %s about %s", lbUpdateData.kind, LocalPlayer.Name, lbUpdateData.userId))
	-- print(lbUpdateData)

	receivedLBUpdateAboutUser(lbUpdateData, initial)
end

local function testJoinRejoinBugs()
	spawn(function()
		wait(5)
		print("fake ,join.")
		local thisDatatype = [[export type afterData_getStatsByUser = {
		kind: string,
		userId: number,
		runs: number,
		userTotalFindCount: number,
		findRank: number,
		top10s: number,
		races: number,
		userTix: number,
		userCompetitiveWRCount: number,
		userTotalWRCount: number,
		wrRank: number,
		totalSignCount: number,
		awardCount: number]]
		local fakeDataUpdateData: tt.afterData_getStatsByUser = {
			kind = "joiner update other lb",
			userId = 90115385,
			runs = 123,
			userTotalFindCount = 123,
			findRank = 123,
			top10s = 123,
			races = 123,
			userTix = 123,
			userCompetitiveWRCount = 123,
			userTotalWRCount = 123,
			wrRank = 123,
			totalSignCount = 123,
			awardCount = 123,
			badgeCount = 1233,
		}
		clientReceiveNewLeaderboardData(fakeDataUpdateData)

		wait(2)
		clientReceiveNewLeaderboardData({ userId = 90115385, kind = "leave" })
		wait(2)
		clientReceiveNewLeaderboardData(fakeDataUpdateData)
	end)
end

--user changed marathon settings in UI - uses registration to monitor it.
--note there is an init call here so user settings _will_ show up here and we should
--be careful not to mistakenly reinit LB needlessly.
local function handleUserSettingChanged(setting: tt.userSettingValue)
	if setting.name == settingEnums.settingNames.HIDE_LEADERBOARD then
		if setting.value then
			lbIsEnabled = false
			marathonClient.CloseAllMarathons()
			completelyResetUserLB()
		else
			if not lbIsEnabled then
				lbIsEnabled = true
				completelyResetUserLB()
			end
		end
	end
end

--ideally filter at the registration layer but whatever.
--also why is this being done here rather than in marathon client?
local function handleMarathonSettingsChanged(setting: tt.userSettingValue)
	if setting.domain ~= settingEnums.settingDomains.MARATHONS then
		return
	end
	local key = string.split(setting.name, " ")[2]
	local targetMarathon: mt.marathonDescriptor = mds[key]
	if targetMarathon == nil then
		warn("bad setting probably legacy bad naming, shouldn't be many and no effect." .. key)
		return
	end
	if setting.value then
		marathonClient.InitMarathon(targetMarathon, true)
	else
		marathonClient.DisableMarathon(targetMarathon)
	end
end

local function init()
	game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	lbwidth = -6
	for _, lbUserCellDescriptor in pairs(lbUserCellDescriptors) do
		lbwidth = lbwidth + lbUserCellDescriptor.width
	end
	local localFunctions = require(game.ReplicatedStorage.localFunctions)
	local hideLb = localFunctions.getSettingByName(settingEnums.settingNames.HIDE_LEADERBOARD)
	if hideLb.value then
		lbIsEnabled = false
	else
		lbIsEnabled = true
	end

	localFunctions.registerLocalSettingChangeReceiver(function(item: tt.userSettingValue): any
		return handleUserSettingChanged(item)
	end, "leaderboardSettingListener")

	localFunctions.registerLocalSettingChangeReceiver(function(item: tt.userSettingValue): any
		return handleMarathonSettingsChanged(item)
	end, "handleMarathonSettingsChanged")

	completelyResetUserLB()

	--we setup the event, but what if upstream playerjoinfunc is called first?
	local leaderboardUpdateEvent = remotes.getRemoteEvent("LeaderboardUpdateEvent")
	leaderboardUpdateEvent.OnClientEvent:Connect(clientReceiveNewLeaderboardData)

	--listen to racestart, raceendevent

	marathonClient.Init()
	local initialMarathonSettings = localFunctions.getSettingByDomain(settingEnums.settingDomains.MARATHONS)

	--load marathons according to the users settings
	for _, userSetting in pairs(initialMarathonSettings) do
		handleMarathonSettingsChanged(userSetting)
	end

	local userSettings = localFunctions.getSettingByDomain(settingEnums.settingDomains.USERSETTINGS)

	for _, userSetting in pairs(userSettings) do
		handleUserSettingChanged(userSetting)
	end
end

testJoinRejoinBugs()

init()
