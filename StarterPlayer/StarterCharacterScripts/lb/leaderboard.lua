--!strict

--2022 remaining bug: sometimes you get fail.04 or fail.05 and permanent  shifting.
--2022.02.12 why is this so hard? or rather why doesn't it just work out of the box?
--2022.02.24 revisiting to finally fix LB bugs.

--2024 I'm struck by how when i left the game, this felt extremely complicated
--yet when I'm back now, it's very simple. Some huge too large functions hacking around with TLs, and otherwise a very simple loop of getting and updating data
--with some funk bits about local caching etc.
--but at a core level, this could pretty easily be redone and simplified, move the TL stuff out so the row management logic is visible
--really, why did I do this at all?
--it seems there also was an unused layer of deboucing for repeated quick joins, which was why there would occasionally be bugs?

-- OVERALL GOALS: make the entire leaderboard draggable smoothly and naturally.
-- And everything within it should lay itself out wonderfully.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

--TYPE
local tt = require(game.ReplicatedStorage.types.gametypes)
local leaderboardEnums = require(game.StarterPlayer.StarterCharacterScripts.lb.leaderboardEnums)
local leaderboardGui = require(game.StarterPlayer.StarterCharacterScripts.lb.leaderboardGui)
local lt = require(game.StarterPlayer.StarterCharacterScripts.lb.leaderboardTypes)

--UTIL
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local config = require(game.ReplicatedStorage.config)
local settings = require(game.ReplicatedStorage.settings)
local enums = require(game.ReplicatedStorage.util.enums)

local colors = require(game.ReplicatedStorage.util.colors)
local thumbnails = require(game.ReplicatedStorage.thumbnails)

local remotes = require(game.ReplicatedStorage.util.remotes)

local leaderboardButtons = require(game.StarterPlayer.StarterCharacterScripts.lb.leaderboardButtons)

local marathonClient = require(game.StarterPlayer.StarterCharacterScripts.client.marathonClient)
local localRdb = require(game.ReplicatedStorage.localRdb)
local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local TweenService = game:GetService("TweenService")

-------------------EVENTS ---------------------
-- we setup the event, but what if upstream playerjoinfunc is called first?
local LeaderboardUpdateEvent = remotes.getRemoteEvent("LeaderboardUpdateEvent")

----------------- TYPES ---------------------

-- this covers all the different types of lbupdates that can be sent. for example, one is tt_afterrundata, another is tt_inital join data + username,
-- whta happened, details, who it's actually ABOUT (not who it's to.)

-- this is for this client, their in-memory kv cache.
local lbUserDataCache: { [number]: { [string]: any } } = {}
local lbOuterFrame: Frame? = nil

------------- GLOBAL STATIC OBJECTS ----------------

-- GLOBAL DYNAMIC STATE VARS. EACH USER HAS JUST ONE LEADERBOARD. ----------------

--one rowFrame for each user is stored in here.
local userId2rowframe: { [number]: Frame } = {}

local lbUserRowFrame: Frame? = nil
local lbIsEnabled: boolean = true

-- the initial width and height scales.

local headerRowYOffsetFixed = 24
-- local headerRowShrinkFactor = 0.6

local enabledDescriptors: { [string]: boolean } = {}

-- this will block things like adding rows.
local loadedSettings = false
local leaderboardConfiguration: leaderboardConfiguration? = nil

type leaderboardConfiguration = {
	position: UDim2,
	size: UDim2,
	minimized: boolean,
	sortDirection: "ascending" | "descending",
	sortColumn: string,
}

local lastSaveRequestCount = 0

----------------------- FOR SAVING LB CONFIGURATION -----------------
local function saveLeaderboardConfiguration()
	-- reconstruct the configuration and save it.
	-- yes, this will happen a lot.
	if not lbOuterFrame then
		_annotate("No lbOuterFrame in saveLeaderboardConfiguration")
		return
	end
	lastSaveRequestCount += 1
	local yourSaveRequestCount = lastSaveRequestCount
	task.spawn(function()
		task.wait(0.4)
		if yourSaveRequestCount ~= lastSaveRequestCount then
			return
		end
		local topInset = game:GetService("GuiService"):GetGuiInset().Y
		local absolutePosition = lbOuterFrame.AbsolutePosition
		local positionInOffset = UDim2.new(0, absolutePosition.X, 0, absolutePosition.Y + topInset)
		local setting: tt.userSettingValue = {
			name = settingEnums.settingDefinitions.LEADERBOARD_CONFIGURATION.name,
			domain = settingEnums.settingDomains.LEADERBOARD,
			kind = settingEnums.settingKinds.LUA,
			luaValue = {
				position = positionInOffset,
				size = lbOuterFrame.Size,
				minimized = lbOuterFrame:GetAttribute("IsMinimized"),
				sortDirection = leaderboardConfiguration.sortDirection,
				sortColumn = leaderboardConfiguration.sortColumn,
			},
		}
		settings.SetSetting(setting)
	end)
end

local function ensureLeaderboardOnScreen()
	if not lbOuterFrame or not leaderboardConfiguration then
		_annotate("No lbOuterFrame or leaderboardConfiguration in ensureLeaderboardOnScreen")
		return
	end

	local viewportSize = workspace.CurrentCamera.ViewportSize
	local position = leaderboardConfiguration.position
	local size = leaderboardConfiguration.size

	local minX = 0
	local minY = 0
	local maxX = viewportSize.X - size.X.Offset
	local maxY = viewportSize.Y - size.Y.Offset

	local newX = math.clamp(position.X.Offset, minX, maxX)
	local newY = math.clamp(position.Y.Offset, minY, maxY)

	if newX ~= position.X.Offset or newY ~= position.Y.Offset then
		local newPosition = UDim2.new(0, newX, 0, newY)
		leaderboardConfiguration.position = newPosition
		lbOuterFrame.Position = newPosition
		_annotate(string.format("Adjusted Leaderboard position to %s", tostring(newPosition)))
		-- saveLeaderboardConfiguration()
	end
end

local function monitorLeaderboardFrame()
	if not lbOuterFrame then
		_annotate("No lbOuterFrame in monitorLeaderboardFrame")
		return
	end

	-- these are changes that are made directly by windows.
	-- other changes, like those of the sort data, are made in here and direclty save when changed.
	lbOuterFrame:GetPropertyChangedSignal("Position"):Connect(function()
		leaderboardConfiguration.position = lbOuterFrame.Position
		ensureLeaderboardOnScreen()
		saveLeaderboardConfiguration()
	end)

	lbOuterFrame:GetPropertyChangedSignal("Size"):Connect(function()
		leaderboardConfiguration.size = lbOuterFrame.Size
		ensureLeaderboardOnScreen()
		saveLeaderboardConfiguration()
	end)

	lbOuterFrame:GetAttributeChangedSignal("IsMinimized"):Connect(function()
		local minimizeState = lbOuterFrame:GetAttribute("IsMinimized")
		leaderboardConfiguration.minimized = minimizeState
		ensureLeaderboardOnScreen()
		saveLeaderboardConfiguration()
	end)

	-- Add viewport size changed connection
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		ensureLeaderboardOnScreen()
	end)
end

------------------ FUNCTIONS -----------------

local function setSize()
	if not lbUserRowFrame then
		_annotate("No lbUserRowFrame1?")
		return
	end
	local rowCount = 0
	for _, _ in pairs(lbUserDataCache) do
		rowCount += 1
	end
	local normalizedPlayerRowYScale = 1 / rowCount

	for _, child: Frame in ipairs(lbUserRowFrame:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "LeaderboardHeaderRow" then
			child.Size = UDim2.fromScale(1, normalizedPlayerRowYScale)
		end
	end
	_annotate("adjusted row scales.")
end

--important to use all lbUserCellParams here to make the row complete
--even if an update comes before the loading of full stats.
local function getNameForDescriptor(descriptor: lt.lbColumnDescriptor): string
	return string.format("%02d.cell.%s", descriptor.num, descriptor.name)
end

local debounceCreateRowForUser = false
-- we got an upda
local function getOrCreateRowForUser(userId: number): Frame?
	_annotate("getOrCreateRowForUser called for userId: " .. tostring(userId))

	if debounceCreateRowForUser then
		return
	end

	-- get their data to set up the proper name.
	local userDataFromCache = lbUserDataCache[userId]
	local username = localRdb.GetUsernameByUserId(userId)
	if userDataFromCache == nil then
		_annotate("createRowForUser called with no userDataFromCache for userId: " .. tostring(userId))
		debounceCreateRowForUser = false
		return
	end

	--we need this to get ordering before tix are known.
	if userDataFromCache.userTix == nil then
		userDataFromCache.userTix = 0
	end

	debounceCreateRowForUser = true

	local userIntendedRowName = string.format("LBRow_%s", username)
	local userRowFrame: Frame = lbUserRowFrame:FindFirstChild(userIntendedRowName)
	if userRowFrame == nil then
		userRowFrame = Instance.new("Frame")
		userRowFrame.BorderMode = Enum.BorderMode.Inset
		userRowFrame.BorderSizePixel = 0
		userRowFrame.BackgroundTransparency = 0.1
		userRowFrame.Name = userIntendedRowName
		userId2rowframe[userId] = userRowFrame
		userRowFrame.Parent = lbUserRowFrame

		local horizontalLayout = Instance.new("UIListLayout")
		horizontalLayout.FillDirection = Enum.FillDirection.Horizontal
		horizontalLayout.Parent = userRowFrame
		horizontalLayout.Name = "LeaderboardUserRowHH_" .. username
	end

	local bgcolor = colors.defaultGrey
	if userId == localPlayer.UserId then
		bgcolor = colors.meColor
	end

	local cellWidths = leaderboardGui.CalculateCellWidths(enabledDescriptors)

	for _, lbColumnDescriptor: lt.lbColumnDescriptor in pairs(leaderboardEnums.LbColumnDescriptors) do
		if not enabledDescriptors[lbColumnDescriptor.name] then
			_annotate('skipping adding col: "' .. lbColumnDescriptor.name .. '"')
			continue
		end
		-- _annotate("adding col: " .. lbColumnDescriptor.name)
		local widthYScale = cellWidths[lbColumnDescriptor.name]

		-- okay, somewhat dumbly we do this here when we're just creating the empty frame.
		if lbColumnDescriptor.name == "portrait" then
			local portraitCell = userRowFrame:FindFirstChild(getNameForDescriptor(lbColumnDescriptor))
			if not portraitCell then
				portraitCell = Instance.new("Frame")
				portraitCell.Size = UDim2.fromScale(widthYScale, 1)
				portraitCell.BackgroundTransparency = 1
				portraitCell.Name = getNameForDescriptor(lbColumnDescriptor)
				portraitCell.Parent = userRowFrame
				local img = Instance.new("ImageLabel")
				img.Size = UDim2.new(1, 0, 1, 0)
				img.BackgroundColor3 = colors.defaultGrey
				img.Name = "PortraitImage"
				img.Parent = portraitCell
				img.BorderMode = Enum.BorderMode.Outline
				img.ScaleType = Enum.ScaleType.Crop
				img.BorderSizePixel = 1
				local content =
					thumbnails.getThumbnailContent(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
				img.Image = content
				-- Add mouseover functionality so that when you mouseover the portrait cell (the 1st one) to the left of it,
				-- a larger portrait appears.  It has no effect on the row.

				local avatarImages = Instance.new("Frame")
				avatarImages.Size = UDim2.new(0, 420, 0, 420)
				avatarImages.Position = UDim2.new(0, -440, 0, 0)
				avatarImages.Parent = portraitCell
				avatarImages.Visible = false
				local vv = Instance.new("UIListLayout")
				vv.FillDirection = Enum.FillDirection.Vertical
				vv.Parent = avatarImages
				vv.Name = "avatarVV"
				local allContents = {
					thumbnails.getThumbnailContent(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420),
				}
				for _, content in pairs(allContents) do
					local img = Instance.new("ImageLabel")
					img.Size = UDim2.new(1, 0, 1, 0)
					img.BackgroundColor3 = colors.defaultGrey
					img.Visible = false
					img.ZIndex = 10
					img.Image = content
					img.Visible = true
					img.Name = "LargeAvatarImage_" .. tostring(userId)
					img.Parent = avatarImages
				end

				-- in general mouseenter can fire before mouseleave. which means sometimes the avatar image gets stuck
				portraitCell.MouseEnter:Connect(function()
					avatarImages.Visible = true
				end)
				portraitCell.MouseLeave:Connect(function()
					avatarImages.Visible = false
				end)
			end
		else --it's a textlabel whatever we're generating anyway.
			local cellName = getNameForDescriptor(lbColumnDescriptor)
			local tl: TextLabel = userRowFrame:FindFirstChild(cellName)
			if not tl then
				tl = guiUtil.getTl(cellName, UDim2.fromScale(widthYScale, 1), 2, userRowFrame, bgcolor, 1, 0)
			end
			tl.Text = ""

			tl.TextScaled = true
		end
	end
	debounceCreateRowForUser = false
	return userRowFrame
end

-- ugh for now we use this to show that this is not a "new" value but merely a hidden redraw.
local MAGIC = -456897
local function GetDataFromCacheForUser(userId: number): { tt.leaderboardUserDataChange }
	local res = {}
	local guyCache = lbUserDataCache[userId]
	if guyCache then
		for key, thing in pairs(guyCache) do
			local change: tt.leaderboardUserDataChange = { key = key, oldValue = MAGIC, newValue = thing }
			table.insert(res, change)
		end
	end

	return res
end

local debounceUpdateUserLeaderboardRow = {}
local function applyUserDataChanges(userDataChanges, subjectUserId: number)
	--patch things up if needed.
	--2_annotate("patching up existing rowframe with new data")
	local userRowFrame: Frame? = getOrCreateRowForUser(subjectUserId)
	if not userRowFrame then
		_annotate("no userRowFrame able to be gotten for: " .. tostring(subjectUserId))
		return
	end

	local bgcolor = colors.defaultGrey
	if subjectUserId == localPlayer.UserId then
		bgcolor = colors.meColor
	end

	for _, change: tt.leaderboardUserDataChange in pairs(userDataChanges) do
		-- okay why do we do this twice? we seriously do this in the initial setup and here!
		-- Shouldn't the initail create row just do nothing except create emptye values, and this guy does the update?
		if change.key == "kind" or change.key == "userId" or change.key == "serverPatchedInTotalSignCount" then
			-- we hard skip these since they're just carryalongs in the mixed dict of "keys to update"
			-- this is obviously a bad practice.
			continue
		end

		local ovt = change.oldValue and tostring(change.oldValue) or ""
		_annotate(
			string.format(
				"trying to update lb for change %s %s=>%s",
				tostring(change.key),
				tostring(ovt),
				tostring(change.newValue)
			)
		)
		if enabledDescriptors[change.key] == nil then
			_annotate("missing descriptor status at all for received change for: " .. tostring(change.key))
			continue
		end

		if not enabledDescriptors[change.key] then
			_annotate(string.format("showing %s is not enabled for this user.", change.key))
			continue
		end

		local descriptor = leaderboardEnums.LbColumnDescriptors[change.key]
		if not descriptor then
			-- this semems not okay.
			_annotate("W. Error, this descriptor should not be missing. " .. change.key)
			continue
		end

		local targetName = getNameForDescriptor(descriptor)
		--it's important this targetname matches via interpolatino
		local oldTextLabelParent: TextLabel = userRowFrame:FindFirstChild(targetName) :: TextLabel
		if oldTextLabelParent == nil then
			-- this user isn't displaying that data.
			-- still, we have stored it so if they re-enable it we are good.
			_annotate(string.format("missing oldTextLabelParent for %s", targetName))
			continue
		end
		local oldTextLabel: TextLabel = oldTextLabelParent:FindFirstChild("Inner")

		if oldTextLabel == nil then
			warn("Missing old label to put in - this should not happen " .. descriptor.num)
			debounceUpdateUserLeaderboardRow[subjectUserId] = nil
			annotater.Error(descriptor)
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
		if change.oldValue == MAGIC then
			improvement = false
			newIntermediateText = newFinalText
		elseif type(change.oldValue) == "number" then
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
			_annotate(string.format("newIntermediateText: %s", newIntermediateText))
		elseif type(change.oldValue) == "string" then
			improvement = true
			newIntermediateText = change.newValue
		end

		if change.key == "pinnedRace" then
			leaderboardGui.DrawRaceWarper(oldTextLabel.Parent, change.newValue)
		--phase to new color if needed
		elseif newIntermediateText == nil then
			oldTextLabel.Text = newFinalText
			oldTextLabel.BackgroundColor3 = bgcolor
			local par = oldTextLabel.Parent :: TextLabel
			par.BackgroundColor3 = bgcolor
		else
			if improvement then
				oldTextLabel.BackgroundColor3 = colors.greenGo
				local par = oldTextLabel.Parent :: TextLabel
				par.BackgroundColor3 = colors.greenGo
			else
				if change.oldValue ~= MAGIC then
					oldTextLabel.BackgroundColor3 = colors.blueDone

					local par = oldTextLabel.Parent :: TextLabel
					par.BackgroundColor3 = colors.blueDone
				end
			end
			oldTextLabel.Text = newIntermediateText

			if improvement and change.oldValue ~= MAGIC then
				-- while it's flashing, show the intermediate text, the new value followed by the diff improvement (i.e. ' (+1)')
				task.spawn(function()
					wait(enums.greenTime)
					oldTextLabel.Text = newFinalText
				end)

				--phase the cell and the parent back to the default color.
				local tween = TweenService:Create(
					oldTextLabel,
					TweenInfo.new(enums.greenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ BackgroundColor3 = bgcolor }
				)
				tween:Play()

				local tween2 = TweenService:Create(
					oldTextLabel.Parent,
					TweenInfo.new(enums.greenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ BackgroundColor3 = bgcolor }
				)
				tween2:Play()
			end

			--we had more tweens before.
		end
		_annotate("done with updateUserLeaderboardRow")
	end

	setSize()
	debounceUpdateUserLeaderboardRow[subjectUserId] = nil
end

local function sortLeaderboard()
	_annotate("sortLeaderboard with userId2rowframe: " .. #userId2rowframe)

	local sortedRows = {}
	for userId, frame in pairs(userId2rowframe) do
		table.insert(sortedRows, {
			userId = userId,
			frame = frame,
			value = lbUserDataCache[userId][leaderboardConfiguration.sortColumn],
			originalIndex = frame.LayoutOrder, -- Store the original order
		})
	end

	table.sort(sortedRows, function(a, b)
		if a.value == b.value then
			-- If values are equal, maintain original order
			return a.originalIndex < b.originalIndex
		elseif leaderboardConfiguration.sortDirection == "ascending" then
			if a.value == nil then
				return true
			end
			if b.value == nil then
				return false
			end
			return a.value < b.value
		else
			if a.value == nil then
				return false
			end
			if b.value == nil then
				return true
			end
			return a.value > b.value
		end
	end)

	for i, row in ipairs(sortedRows) do
		row.frame.LayoutOrder = i
	end
end

local function receiveHeaderRowClick(key: string)
	if key == "portrait" then
		return
	end

	-- whoah, insane special case here:   IF you click on ANOTHER column, AND it just so happens that that column is already physically
	-- laid out in the default sort order (ascending), then it will be slightly strange that you click it and nothing happens!
	-- okay, i'm going to ignore this now.
	--
	if leaderboardConfiguration.sortColumn == key then
		-- clicked on the current sort column so flip direction and resort.
		_annotate("flipping sort direction on column: " .. key)
		if leaderboardConfiguration.sortDirection == "ascending" then
			leaderboardConfiguration.sortDirection = "descending"
		else
			leaderboardConfiguration.sortDirection = "ascending"
		end
		saveLeaderboardConfiguration()
	else
		_annotate("sorting by new column: " .. key .. "and resetting sortdirection.")
		leaderboardConfiguration.sortColumn = key
		leaderboardConfiguration.sortDirection = "descending"
		saveLeaderboardConfiguration()
	end
	sortLeaderboard()
end

local comdeb = false
local function completelyResetUserLB(forceResize: boolean)
	if comdeb then
		return
	end
	while not leaderboardConfiguration do
		_annotate("waiting for lb configuration.")
		task.wait(0.1)
	end

	comdeb = true
	_annotate(string.format("completely reset? lb, forceResize: %s", tostring(forceResize)))
	--make initial row only. then as things happen (people join, or updates come in, apply them in-place)
	local pgui: PlayerGui = localPlayer:WaitForChild("PlayerGui")

	local oldLbSgui: ScreenGui = pgui:FindFirstChild("LeaderboardScreenGui") :: ScreenGui?
	local oldSize
	local oldPosition
	if oldLbSgui ~= nil then
		local old: Frame = oldLbSgui:FindFirstChild("outer_lb")
		if old then
			oldSize = old.Size
			oldPosition = old.Position
		end
		oldLbSgui:Destroy()
	end

	if not lbIsEnabled then
		_annotate("reset lb and it's disabled now so just end.")
		comdeb = false
		return
	end

	local existingSgui = pgui:FindFirstChild("LeaderboardScreenGui")
	if existingSgui ~= nil then
		existingSgui:Destroy()
	end
	local lbSgui: ScreenGui = Instance.new("ScreenGui")
	lbSgui.Name = "LeaderboardScreenGui"
	lbSgui.Parent = pgui
	lbSgui.IgnoreGuiInset = true

	--previous lb frame items now just are floating independently and adjustable freely.

	local lbSystemFrames = windows.SetupFrame("lb", true, true, true)
	lbOuterFrame = lbSystemFrames.outerFrame
	local lbContentFrame = lbSystemFrames.contentFrame

	lbOuterFrame.Parent = lbSgui
	lbOuterFrame.Position = leaderboardConfiguration.position
	lbOuterFrame.Size = leaderboardConfiguration.size

	local headerRow = leaderboardGui.MakeLeaderboardHeaderRow(enabledDescriptors, headerRowYOffsetFixed)
	headerRow.Parent = lbContentFrame
	headerRow.Position = UDim2.new(0, 0, 0, 0)
	for _, elb: TextButton in pairs(headerRow:GetChildren()) do
		if not elb:IsA("TextButton") then
			continue
		end
		local keyHolder = elb:FindFirstChild("Inner"):FindFirstChild("key") :: StringValue
		local key = keyHolder.Value
		-- Add click event for sorting
		local inner = elb:FindFirstChild("Inner") :: TextButton
		inner.MouseButton1Click:Connect(function()
			receiveHeaderRowClick(key)
		end)
	end

	lbUserRowFrame = Instance.new("Frame")
	lbUserRowFrame.Parent = lbContentFrame
	lbUserRowFrame.BorderMode = Enum.BorderMode.Inset
	lbUserRowFrame.BorderSizePixel = 0
	lbUserRowFrame.Size = UDim2.new(1, 0, 1, -1 * headerRowYOffsetFixed)
	lbUserRowFrame.Position = UDim2.new(0, 0, 0, headerRowYOffsetFixed)
	lbUserRowFrame.Name = "lbUserRowFrame"
	lbUserRowFrame.BackgroundTransparency = 1
	lbUserRowFrame.BackgroundColor3 = colors.defaultGrey

	local vv: UIListLayout = Instance.new("UIListLayout")
	vv.SortOrder = Enum.SortOrder.LayoutOrder
	vv.Name = "LeaderboardNameSorter"
	vv.Parent = lbUserRowFrame

	leaderboardButtons.initActionButtons(lbOuterFrame)

	for _, v in pairs(userId2rowframe) do
		_annotate("\tuserId2rowframe: " .. v.Name)
		annotater.Error("which is weird cause we're reserttings it.")
	end

	userId2rowframe = {}
	for _, player in pairs(Players:GetPlayers()) do
		getOrCreateRowForUser(player.UserId)
		local data = GetDataFromCacheForUser(player.UserId)
		applyUserDataChanges(data, player.UserId)
	end
	monitorLeaderboardFrame()
	setSize()
	comdeb = false
end

--after receiving an lb update, figure out what changed relative to known data
--store it and return a userDataChange for rendering into the LB
local storeUserDataDebounce = false
local function StoreUserData(userId: number, data: tt.lbUserStats): { tt.leaderboardUserDataChange }
	while storeUserDataDebounce do
		wait(0.1)
	end
	storeUserDataDebounce = true
	local res: { tt.leaderboardUserDataChange } = {}
	if lbUserDataCache[userId] == nil then --received new data.
		lbUserDataCache[userId] = {}
	end

	--TODO is there ever a case where there's out of order in time data/
	-- like, I shouldn't update to a value that's earlier than the value for a key i've got already.
	for key: string, newValue in pairs(data) do
		if newValue == nil then
			--don't know why this would happen, probably impossible.
			-- if you don't want to send anything, just don't include the key.
			-- key missing = fine, zero or no change
			-- key there but nil, error.
			warn("no newvalue " .. key)
			continue
		end
		local oldValue = lbUserDataCache[userId][key]
		if newValue ~= oldValue then
			--reset source of truth to the new data that came in.
			local change: tt.leaderboardUserDataChange = { key = key, oldValue = oldValue, newValue = newValue }
			lbUserDataCache[userId][key] = newValue
			table.insert(res, change)
		end
	end
	storeUserDataDebounce = false
	return res
end

-- store the data in-memory.

local function updateUserLeaderboardRow(userStats: tt.lbUserStats): ()
	while not loadedSettings do
		wait(0.1)
		_annotate("waiting for settings to load for updateUserLeaderboardRow")
	end
	if lbUserRowFrame == nil then
		annotater.Error("lbUserRowFrame is nil. how is this possible?")
		return
	end

	local subjectUserId = userStats.userId
	--check if this client's user has any lbframe.
	if subjectUserId == nil then
		warn("nil userid for update.")
		debounceUpdateUserLeaderboardRow[userStats.userId] = nil
		return
	end

	while debounceUpdateUserLeaderboardRow[subjectUserId] do
		_annotate(string.format("waiting for user %s to finish receiving their lb update", userStats.userId))
		wait(0.1)
	end
	debounceUpdateUserLeaderboardRow[subjectUserId] = true
	if not lbIsEnabled then
		debounceUpdateUserLeaderboardRow[subjectUserId] = nil
		return
	end

	--first check if there is anything worthwhile to draw - anything changed.
	local userDataChanges: { tt.leaderboardUserDataChange } = StoreUserData(subjectUserId, userStats)
	if userDataChanges == nil or #userDataChanges == 0 then
		debounceUpdateUserLeaderboardRow[userStats.userId] = nil
		return
	end
	applyUserDataChanges(userDataChanges, subjectUserId)
end

local removeDebouncers = {}
local function removeUserLBRow(userId: number): ()
	if removeDebouncers[userId] then
		return
	end
	--2_annotate("removeUserLBRow called for userId: " .. tostring(userId))
	removeDebouncers[userId] = true
	if not lbIsEnabled then
		removeDebouncers[userId] = nil
		return
	end
	local row: Frame = userId2rowframe[userId]
	userId2rowframe[userId] = nil
	lbUserDataCache[userId] = nil
	if row ~= nil then
		pcall(function()
			if row ~= nil then
				row:Destroy()
			end
		end)
	end
	setSize()
	--2_annotate("done with remove UserLbRow")
	removeDebouncers[userId] = nil
end

--data is a list of kvs for update data. if any change, redraw the row (and highlight that cell.)
--First keyed to receive data about a userId. But later overloading data to just be blobs  of things of specific types to display in leaderboard.
local receiveDataDebouncer = false
module.ClientReceiveNewLeaderboardData = function(theUpdate: tt.genericLeaderboardUpdateDataType)
	while not loadedSettings do
		_annotate("waiting for user's leaderboard settings to load.")
		task.wait(0.1)
	end
	if receiveDataDebouncer then
		task.wait(0.1)
	end
	receiveDataDebouncer = true

	if theUpdate.kind == "leave" then
		removeUserLBRow(theUpdate.userId)
		receiveDataDebouncer = false
		return
	end

	-- the ONLY kinds now are: leave and lbupdate

	updateUserLeaderboardRow(theUpdate.lbUserStats)
	sortLeaderboard()
	setSize()
	receiveDataDebouncer = false
end

--user changed marathon settings in UI - uses registration to monitor it.
--note there is an init call here so user settings _will_ show up here and we should
--be careful not to mistakenly reinit LB needlessly.
local function handleUserSettingChanged(setting: tt.userSettingValue, initial: boolean)
	while not initial and not loadedSettings do
		task.wait(0.1)
		_annotate("waiting for settings to load for updateUserLeaderboardRow2")
	end
	_annotate(
		string.format(
			"leaderboard handleUserSettingChanged: loading setting: %s=%s",
			tostring(setting.name),
			tostring(setting.booleanValue)
		)
	)
	if setting.name == settingEnums.settingDefinitions.HIDE_LEADERBOARD.name then
		if setting.booleanValue ~= lbIsEnabled then
			lbIsEnabled = not setting.booleanValue

			if lbIsEnabled then
				marathonClient.Init()
			else
				marathonClient.CloseAllMarathons()
			end
		end
		return
	end

	if
		setting.name == settingEnums.settingDefinitions.LEADERBOARD_CONFIGURATION.name
		and setting.domain == settingEnums.settingDomains.LEADERBOARD
	then
		if setting.luaValue then
			leaderboardConfiguration = setting.luaValue
			_annotate("loaded leaderboardConfiguration")
			for k, v in pairs(leaderboardConfiguration) do
				_annotate(string.format("\tleaderboardConfiguration: %s=%s", tostring(k), tostring(v)))
			end
			sortLeaderboard()
		else
			annotater.Error("leaderboardConfiguration is nil")
		end
		return
	end

	if setting.domain == settingEnums.settingDomains.LEADERBOARD then
		if setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_PORTRAIT.name then
			enabledDescriptors["portrait"] = setting.booleanValue
		elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_USERNAME.name then
			enabledDescriptors["username"] = setting.booleanValue
		elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_AWARDS.name then
			enabledDescriptors["awardCount"] = setting.booleanValue
		elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_TIX.name then
			enabledDescriptors["userTix"] = setting.booleanValue
		elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_FINDS.name then
			enabledDescriptors["findCount"] = setting.booleanValue
		elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_FINDRANK.name then
			enabledDescriptors["findRank"] = setting.booleanValue
		elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_CWRS.name then
			enabledDescriptors["cwrs"] = setting.booleanValue
		elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_CWRANK.name then
			enabledDescriptors["cwrRank"] = setting.booleanValue
		elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_CWRTOP10S.name then
			enabledDescriptors["cwrTop10s"] = setting.booleanValue
		elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_TOP10S.name then
			enabledDescriptors["top10s"] = setting.booleanValue
		elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_WRS.name then
			enabledDescriptors["wrCount"] = setting.booleanValue
		elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_WRRANK.name then
			enabledDescriptors["wrRank"] = setting.booleanValue
		elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_RACES.name then
			enabledDescriptors["userTotalRaceCount"] = setting.booleanValue
		elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_RUNS.name then
			enabledDescriptors["userTotalRunCount"] = setting.booleanValue
		elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_BADGES.name then
			enabledDescriptors["badgeCount"] = setting.booleanValue
		elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_DAYSINGAME_COLUMN.name then
			enabledDescriptors["daysInGame"] = setting.booleanValue
		elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_PINNED_RACE_COLUMN.name then
			enabledDescriptors["pinnedRace"] = setting.booleanValue
		elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_RUNSTODAY_COLUMN.name then
			enabledDescriptors["runsToday"] = setting.booleanValue
		elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_WRSTODAY_COLUMN.name then
			enabledDescriptors["wrsToday"] = setting.booleanValue
		elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_CWRSTODAY_COLUMN.name then
			enabledDescriptors["cwrsToday"] = setting.booleanValue
		elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_PINNED_RACE.name then
		else
			warn("unknown leaderboard setting: " .. tostring(setting.name))
		end
	end

	-- this is the fallthrough for any of the columnsEnabled changes.
	if not initial then
		_annotate("completely resetting userLB cause setting changed")
		completelyResetUserLB(false)
	end
end

local lb: tt.lbUserStats = {
	userId = 123456789,
	username = "FakePlayer",
	userTix = 1000,
	findCount = 50,
	findRank = 1,
	cwrs = 100,
	cwrRank = 1,
	cwrTop10s = 10,
	top10s = 10,
	wrCount = 10,
	wrRank = 1,
	userTotalRaceCount = 10,
	userTotalRunCount = 10,
	badgeCount = 10,

	awardCount = 10,
	daysInGame = 10,
	kind = "update other about joiner",

	serverPatchedInTotalSignCount = 0,
	cwrsToday = 0,
	wrsToday = 0,
	runsToday = 0,
	pinnedRace = "",
}

local fakeUserStats: tt.genericLeaderboardUpdateDataType = {
	userId = 123456789, -- A fake user ID
	kind = "lbupdate",
	lbUserStats = lb,
}

local lb2: tt.lbUserStats = {
	userId = 1234544,
	username = "FakePlayer2",
	userTix = 10100,
	findCount = 510,
	findRank = 1,
	cwrs = 100,
	cwrRank = 1,
	cwrTop10s = 10,
	top10s = 0,
	wrCount = 10,
	wrRank = 1,
	userTotalRaceCount = 110,
	userTotalRunCount = 10,
	badgeCount = 110,

	awardCount = 10,
	daysInGame = 110,
	kind = "update other about joiner",

	serverPatchedInTotalSignCount = 10,
	cwrsToday = 10,
	wrsToday = 10,
	runsToday = 10,
	pinnedRace = "",
}

local fakeUserStats2: tt.genericLeaderboardUpdateDataType = {
	userId = 1234544, -- A fake user ID
	kind = "lbupdate",
	lbUserStats = lb2,
}

local lb3: tt.lbUserStats = {
	userId = 12345,
	username = "FakePlayer3",
	userTix = 1000000,
	findCount = 0,
	findRank = 1,
	cwrs = 100,
	cwrRank = 11111,
	cwrTop10s = 10,
	top10s = 10,
	wrCount = 1,
	wrRank = 1000,
	userTotalRaceCount = 10000,
	userTotalRunCount = 10,
	badgeCount = 10,

	awardCount = 1,
	daysInGame = 10,
	kind = "update other about joiner",

	serverPatchedInTotalSignCount = 0,
	cwrsToday = 0,
	wrsToday = 0,
	runsToday = 0,
	pinnedRace = "",
}

local fakeUserStats3: tt.genericLeaderboardUpdateDataType = {
	userId = 12345, -- A fake user ID
	kind = "lbupdate",
	lbUserStats = lb3,
}

module.Init = function()
	_annotate("init")
	loadedSettings = false
	enabledDescriptors = {}
	--the user-focused rowFrames go here.
	userId2rowframe = {}
	--the outer, created on time lbframe.
	lbUserRowFrame = nil
	lbIsEnabled = true

	localPlayer = Players.LocalPlayer
	-- get and apply the initial configuration of the leaderboard. That is, position, size, and minimized state.
	handleUserSettingChanged(
		settings.GetSettingByName(settingEnums.settingDefinitions.LEADERBOARD_CONFIGURATION.name),
		true
	)
	handleUserSettingChanged(settings.GetSettingByName(settingEnums.settingDefinitions.HIDE_LEADERBOARD.name), true)

	-- load initial default userSetting values.
	-- this has INITIAL set so that we don't redraw the LB for all 40 or whatever the future value LB setting count will be.
	for _, userSetting in pairs(settings.GetSettingByDomain(settingEnums.settingDomains.LEADERBOARD)) do
		handleUserSettingChanged(userSetting, true)
	end

	-- all column settings are loaded so we can draw the LB.

	--initial load at game start.
	completelyResetUserLB(true)
	loadedSettings = true

	-- now we hook up to listen to user data events
	LeaderboardUpdateEvent.OnClientEvent:Connect(function(data)
		module.ClientReceiveNewLeaderboardData(data)
	end)

	sortLeaderboard()

	-- it's sorted; if new sort values come in, we'll sort as a result of the following monitoring.

	-- now we listen for subsequent setting changes.
	settings.RegisterFunctionToListenForSettingName(function(item: tt.userSettingValue): any
		return handleUserSettingChanged(item, false)
	end, settingEnums.settingDefinitions.HIDE_LEADERBOARD.name)

	settings.RegisterFunctionToListenForDomain(function(item: tt.userSettingValue): any
		return handleUserSettingChanged(item, false)
	end, settingEnums.settingDomains.LEADERBOARD)
	if config.isInStudio() and false then
		task.wait(0.2)
		module.ClientReceiveNewLeaderboardData(fakeUserStats)
		task.wait(0.2)
		module.ClientReceiveNewLeaderboardData(fakeUserStats2)
		task.wait(0.2)
		module.ClientReceiveNewLeaderboardData(fakeUserStats3)
	end
	_annotate("init done")
end

_annotate("end")

return module
