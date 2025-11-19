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
local windowFunctions = require(game.StarterPlayer.StarterPlayerScripts.guis.windowFunctions)

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

local removeUserLBRow -- forward declaration

-- the initial width and height scales.

local headerRowYOffsetFixed = 24

-- local headerRowShrinkFactor = 0.6

local enabledDescriptors: { [string]: boolean } = {}

-- this will block things like adding rows.
local loadedSettings = false
local leaderboardConfiguration: tt.lbConfig? = nil

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
	local lbConfig = leaderboardConfiguration
	if not lbConfig then
		_annotate("No leaderboardConfiguration in saveLeaderboardConfiguration")
		return
	end
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
				sortDirection = lbConfig.sortDirection,
				sortColumn = lbConfig.sortColumn,
			},
		}
		_annotate("saving leaderboard configuration", setting)
		settings.SetSetting(setting)
	end)
end

local MIN_LEADERBOARD_HEIGHT = 60 -- Set a minimum height in pixels

local function ensureLeaderboardOnScreen(reason: string?)
	_annotate("ensureLeaderboardOnScreen " .. (reason or ""))
	if not lbOuterFrame or not leaderboardConfiguration then
		_annotate("No lbOuterFrame or leaderboardConfiguration in ensureLeaderboardOnScreen")
		return
	end

	local viewportSize = workspace.CurrentCamera.ViewportSize
	local position = leaderboardConfiguration.position
	local size = leaderboardConfiguration.size

	-- Convert UDim2 values to pixel values
	local positionX = position.X.Scale * viewportSize.X + position.X.Offset
	local positionY = position.Y.Scale * viewportSize.Y + position.Y.Offset
	local sizeX = size.X.Scale * viewportSize.X + size.X.Offset
	local sizeY = size.Y.Scale * viewportSize.Y + size.Y.Offset

	-- Ensure minimum height
	sizeY = math.max(sizeY, MIN_LEADERBOARD_HEIGHT)

	-- Calculate boundaries
	local minX = 0
	local minY = 0

	-- if the screen is smaller than the desired size
	local maxX = math.max(0, viewportSize.X - sizeX)
	local maxY = math.max(0, viewportSize.Y - sizeY)

	-- -- Clamp position within boundaries
	-- if maxX > minX then
	-- 	annotater.Error(
	-- 		string.format(
	-- 			"maxX > minX %f > %f for user %s in this situation ensureLeaderboardOnScreen: %s",
	-- 			maxX,
	-- 			minX,
	-- 			Players.LocalPlayer.Name,
	-- 			reason or ""
	-- 		)
	-- 	)
	-- end
	local newX = math.clamp(positionX, minX, maxX)
	local newY = math.clamp(positionY, minY, maxY)

	-- Check if position or size needs adjustment
	if newX ~= positionX or newY ~= positionY or sizeY ~= size.Y.Offset then
		-- Convert back to UDim2
		local newPosition = UDim2.new(0, newX, 0, newY)
		local newSize = UDim2.new(size.X.Scale, size.X.Offset, 0, sizeY)

		leaderboardConfiguration.position = newPosition
		leaderboardConfiguration.size = newSize
		lbOuterFrame.Position = newPosition
		lbOuterFrame.Size = newSize

		_annotate(
			string.format(
				"Adjusted Leaderboard position to %s and size to %s",
				tostring(newPosition),
				tostring(newSize)
			)
		)
		saveLeaderboardConfiguration()
	end

	_annotate("done with ensureLeaderboardOnScreen " .. (reason or ""))
end

local function monitorLeaderboardFrame()
	_annotate("Starting monitorLeaderboardFrame")
	if not lbOuterFrame then
		_annotate("No lbOuterFrame in monitorLeaderboardFrame")
		return
	end

	local function deferredUpdate()
		local lbConfig = leaderboardConfiguration
		if not lbConfig then
			return
		end
		task.defer(function()
			_annotate("Deferred update triggered")
			lbConfig.position = lbOuterFrame.Position
			lbConfig.size = lbOuterFrame.Size

			ensureLeaderboardOnScreen("deferredUpdate")
			saveLeaderboardConfiguration()
		end)
	end

	lbOuterFrame:GetPropertyChangedSignal("Position"):Connect(deferredUpdate)
	lbOuterFrame:GetPropertyChangedSignal("Size"):Connect(deferredUpdate)

	lbOuterFrame:GetAttributeChangedSignal("IsMinimized"):Connect(function()
		_annotate("IsMinimized attribute changed")
		local lbConfig = leaderboardConfiguration
		if not lbConfig then
			return
		end
		local minimizeState = lbOuterFrame:GetAttribute("IsMinimized")
		if type(minimizeState) == "boolean" then
			lbConfig.minimized = minimizeState
			ensureLeaderboardOnScreen('GetAttributeChangedSignal("IsMinimized")')
			saveLeaderboardConfiguration()
		else
			annotater.Error(string.format("Invalid type for IsMinimized attribute: %s", tostring(minimizeState)))
		end
	end)

	-- Add viewport size changed connection
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		_annotate("Viewport size changed")
		ensureLeaderboardOnScreen("viewportSizeChanged")
	end)

	_annotate("Finished setting up monitorLeaderboardFrame")
end

------------------ FUNCTIONS -----------------

local function shouldEnableRichText(descriptor: lt.lbColumnDescriptor): boolean
	-- Enable RichText for columns that should allow wrapping
	-- RichText + TextWrapped enables more aggressive text wrapping behavior
	return descriptor.doWrapping
end

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

	for _, child in ipairs(lbUserRowFrame:GetChildren()) do
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

local function ensureValueLabelForDescriptor(
	containerFrame: Frame,
	descriptor: lt.lbColumnDescriptor,
	bgcolor: Color3
): (TextLabel, TextLabel)
	-- pinned/favs columns are frame-backed instead of TextLabel-backed. They must expose a TextLabel with an Inner child
	-- so downstream handlers can write text or swap in buttons. This helper enforces that exact structure so we never
	-- improvise at update-time.
	local desiredLabelName = string.format("%02d.cell.%s.valueHolder", descriptor.num, descriptor.name)
	local holderInstance = containerFrame:FindFirstChild(desiredLabelName)
	local holderLabel: TextLabel? = if holderInstance and holderInstance:IsA("TextLabel")
		then holderInstance :: TextLabel
		else nil
	local innerLabel: TextLabel? = if holderLabel then holderLabel:FindFirstChild("Inner") :: TextLabel? else nil

	if not holderLabel or not innerLabel then
		if holderLabel then
			holderLabel:Destroy()
			holderLabel = nil
			innerLabel = nil
		end
		local createdInner = guiUtil.getTl(desiredLabelName, UDim2.fromScale(1, 1), 2, containerFrame, bgcolor, 1, 0)
		local parentInstance = createdInner.Parent
		if parentInstance and parentInstance:IsA("TextLabel") then
			local parentLabel = parentInstance :: TextLabel
			parentLabel.Name = desiredLabelName
			holderLabel = parentLabel
			innerLabel = createdInner
		end
	end

	assert(holderLabel ~= nil, string.format("Failed to create holder for descriptor %s", descriptor.name))
	assert(innerLabel ~= nil, string.format("Failed to create inner for descriptor %s", descriptor.name))

	local confirmedHolder = holderLabel :: TextLabel
	local confirmedInner = innerLabel :: TextLabel

	confirmedHolder.Size = UDim2.fromScale(1, 1)
	confirmedHolder.BackgroundColor3 = bgcolor
	confirmedHolder.BackgroundTransparency = 0
	confirmedHolder.BorderMode = Enum.BorderMode.Inset
	confirmedHolder.BorderSizePixel = 1
	confirmedHolder.LayoutOrder = descriptor.num

	confirmedInner.Text = ""
	confirmedInner.TextScaled = true
	confirmedInner.TextWrapped = true
	confirmedInner.RichText = shouldEnableRichText(descriptor)

	return confirmedHolder, confirmedInner
end

local debounceCreateRowForUser = false
-- we got an upda
local function getOrCreateRowForUser(userId: number): Frame?
	_annotate("getOrCreateRowForUser called for userId: " .. tostring(userId))

	if debounceCreateRowForUser then
		return
	end

	if not lbUserRowFrame then
		_annotate("getOrCreateRowForUser called with no lbUserRowFrame")
		debounceCreateRowForUser = false
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
	local userRowFrameInstance: Instance? = lbUserRowFrame:FindFirstChild(userIntendedRowName)
	local userRowFrame: Frame?
	if userRowFrameInstance and userRowFrameInstance:IsA("Frame") then
		userRowFrame = userRowFrameInstance :: Frame
	end
	if not userRowFrame then
		local newFrame: Frame = Instance.new("Frame")
		newFrame.BorderMode = Enum.BorderMode.Inset
		newFrame.BorderSizePixel = 0
		newFrame.BackgroundTransparency = 0.1
		newFrame.Name = userIntendedRowName
		userRowFrame = newFrame
		userId2rowframe[userId] = newFrame
		newFrame.Parent = lbUserRowFrame

		local horizontalLayout = Instance.new("UIListLayout")
		horizontalLayout.FillDirection = Enum.FillDirection.Horizontal
		horizontalLayout.Parent = newFrame
		horizontalLayout.Name = "LeaderboardUserRowHH_" .. username
	end
	if not userRowFrame then
		debounceCreateRowForUser = false
		return nil
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
			local existingPortrait = userRowFrame:FindFirstChild(getNameForDescriptor(lbColumnDescriptor))
			if existingPortrait then
				existingPortrait.Parent = nil
			end
			local portraitCell = thumbnails.createAvatarPortraitPopup(userId, true, colors.defaultGrey)
			portraitCell.Parent = userRowFrame
			portraitCell.Size = UDim2.fromScale(widthYScale, 1)
			portraitCell.Name = getNameForDescriptor(lbColumnDescriptor)
		elseif lbColumnDescriptor.name == "pinnedRace" or lbColumnDescriptor.name == "userFavoriteRaceCount" then
			local cellName = getNameForDescriptor(lbColumnDescriptor)
			local containerInstance = userRowFrame:FindFirstChild(cellName)
			local containerFrame: Frame?
			if containerInstance and containerInstance:IsA("Frame") then
				containerFrame = containerInstance :: Frame
			else
				if containerInstance then
					containerInstance:Destroy()
				end
				local newFrame = Instance.new("Frame")
				newFrame.Name = cellName
				newFrame.Parent = userRowFrame
				containerFrame = newFrame
			end

			if containerFrame then
				local descriptorFrame: Frame = containerFrame
				descriptorFrame.Size = UDim2.fromScale(widthYScale, 1)
				descriptorFrame.BackgroundColor3 = bgcolor
				descriptorFrame.BackgroundTransparency = 0
				descriptorFrame.BorderMode = Enum.BorderMode.Inset
				descriptorFrame.BorderSizePixel = 1
				descriptorFrame.LayoutOrder = lbColumnDescriptor.num

				ensureValueLabelForDescriptor(descriptorFrame, lbColumnDescriptor, bgcolor)
			end
		else --it's a textlabel whatever we're generating anyway.
			local cellName = getNameForDescriptor(lbColumnDescriptor)
			local tlInstance: Instance? = userRowFrame:FindFirstChild(cellName)
			local tl: TextLabel?
			if tlInstance and tlInstance:IsA("TextLabel") then
				tl = tlInstance :: TextLabel
			end
			if not tl then
				tl = guiUtil.getTl(cellName, UDim2.fromScale(widthYScale, 1), 2, userRowFrame, bgcolor, 1, 0)
			end
			if tl then
				tl.Text = ""
				tl.TextScaled = true
				tl.TextWrapped = true
				tl.RichText = shouldEnableRichText(lbColumnDescriptor)
				tl.LayoutOrder = lbColumnDescriptor.num
			end
		end
	end
	debounceCreateRowForUser = false
	return userRowFrame
end

-- ugh for now we use this to show that this is not a "new" value but merely a hidden redraw.
local MAGIC = -456897
local function GetDataFromCacheForUser(userId: number): { tt.leaderboardUserDataChange }
	local res: { tt.leaderboardUserDataChange } = {}
	local guyCache = lbUserDataCache[userId]
	if guyCache then
		for key, thing in pairs(guyCache) do
			local change: tt.leaderboardUserDataChange =
				{ userId = userId, key = key, oldValue = MAGIC, newValue = thing }
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
		local oldTextLabelParentInstance: Instance? = userRowFrame:FindFirstChild(targetName)
		if not oldTextLabelParentInstance then
			-- this user isn't displaying that data.
			-- still, we have stored it so if they re-enable it we are good.
			_annotate(string.format("missing oldTextLabelParent for %s", targetName))
			continue
		end
		local oldTextLabelParent: Frame?
		local oldTextLabel: TextLabel?
		local parTextLabel: TextLabel?

		if oldTextLabelParentInstance:IsA("Frame") then
			local frameParent: Frame = oldTextLabelParentInstance :: Frame
			oldTextLabelParent = frameParent
			local holderLabel, innerLabel = ensureValueLabelForDescriptor(frameParent, descriptor, bgcolor)
			parTextLabel = holderLabel
			oldTextLabel = innerLabel
		else
			local oldTextLabelInstance: Instance? = oldTextLabelParentInstance:FindFirstChild("Inner")
			local parentTextLabel = if oldTextLabelParentInstance:IsA("TextLabel")
				then oldTextLabelParentInstance :: TextLabel
				else nil
			if oldTextLabelInstance and oldTextLabelInstance:IsA("TextLabel") then
				oldTextLabel = oldTextLabelInstance :: TextLabel
				parTextLabel = parentTextLabel or oldTextLabel
			elseif parentTextLabel then
				oldTextLabel = parentTextLabel
				parTextLabel = parentTextLabel
			end
		end

		if not oldTextLabel or not parTextLabel then
			debounceUpdateUserLeaderboardRow[subjectUserId] = nil
			annotater.Error(
				string.format(
					"Missing old label to put in - this should not happen %d %s",
					descriptor.num,
					descriptor.name
				)
			)
			continue
		end

		oldTextLabel.BackgroundColor3 = bgcolor
		parTextLabel.BackgroundColor3 = bgcolor
		oldTextLabel.RichText = shouldEnableRichText(descriptor)
		oldTextLabel.TextWrapped = true

		--if this exists, do green fade
		local newIntermediateText: string | nil = nil

		--what do we have to do.
		--we have old number and new number.
		--if not findRank, calculate the intermediate text and set up greenfade.
		--and in either case, do a green fade.
		local newFinalText: string
		if descriptor.name == "findRank" and type(change.newValue) == "number" then
			newFinalText = tpUtil.getCardinalEmoji(change.newValue)
		else
			newFinalText = tostring(change.newValue)
		end

		local improvement = false

		--oldValue may be nil indicating nothing known.
		if change.oldValue == MAGIC then
			improvement = false
			newIntermediateText = newFinalText
		elseif type(change.newValue) == "number" and type(change.oldValue) == "number" then
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
				local formattedGap = tostring(gap)
				newIntermediateText = string.format("%s\n(%s%s)", newFinalText, sign, formattedGap)
			end
			if newIntermediateText then
				_annotate(string.format("newIntermediateText: %s", newIntermediateText))
			end
		elseif type(change.newValue) == "string" then
			improvement = true
			newIntermediateText = change.newValue
		end

		if change.key == "pinnedRace" then
			if not oldTextLabelParent then
				continue
			end
			local pinnedFrame: Frame = oldTextLabelParent
			leaderboardGui.DrawRaceWarper(pinnedFrame, change)
		elseif change.key == "userFavoriteRaceCount" then
			if not oldTextLabelParent then
				continue
			end
			local favFrame: Frame = oldTextLabelParent
			leaderboardGui.DrawShowFavoriteRacesButton(favFrame, change, subjectUserId, localPlayer.UserId)
			--phase to new color if needed
		elseif newIntermediateText == nil then
			oldTextLabel.Text = newFinalText
			oldTextLabel.BackgroundColor3 = bgcolor
			parTextLabel.BackgroundColor3 = bgcolor
		else
			if improvement then
				oldTextLabel.BackgroundColor3 = colors.greenGo
				parTextLabel.BackgroundColor3 = colors.greenGo
			else
				if change.oldValue ~= MAGIC then
					oldTextLabel.BackgroundColor3 = colors.blueDone
					parTextLabel.BackgroundColor3 = colors.blueDone
				end
			end
			oldTextLabel.Text = newIntermediateText

			if improvement and change.oldValue ~= MAGIC then
				-- while it's flashing, show the intermediate text, the new value followed by the diff improvement (i.e. ' (+1)')
				local finalText = newFinalText
				local label = oldTextLabel
				local parLabel = parTextLabel
				task.spawn(function()
					wait(enums.greenTime)
					if label then
						label.Text = finalText
					end
				end)

				--phase the cell and the parent back to the default color.
				local tween = TweenService:Create(
					oldTextLabel,
					TweenInfo.new(enums.greenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ BackgroundColor3 = bgcolor }
				)
				tween:Play()

				local tween2 = TweenService:Create(
					parLabel,
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

	if not leaderboardConfiguration then
		return
	end
	local sortedRows = {}
	local orphanedUserIds: { number } = {}
	for userId, frame in pairs(userId2rowframe) do
		local userCache = lbUserDataCache[userId]
		if not userCache then
			-- State inconsistency: row frame exists but cache data is missing
			-- Collect for cleanup to maintain invariant
			table.insert(orphanedUserIds, userId)
			continue
		end
		table.insert(sortedRows, {
			userId = userId,
			frame = frame,
			value = userCache[leaderboardConfiguration.sortColumn],
			originalIndex = frame.LayoutOrder, -- Store the original order
		})
	end

	-- Clean up orphaned row frames to maintain state consistency
	for _, userId in ipairs(orphanedUserIds) do
		_annotate(string.format("Removing orphaned row frame for userId %s (cache data missing)", tostring(userId)))
		removeUserLBRow(userId)
	end

	local lbConfig = leaderboardConfiguration
	table.sort(sortedRows, function(a, b)
		if a.value == b.value then
			-- If values are equal, maintain original order
			return a.originalIndex < b.originalIndex
		elseif lbConfig.sortDirection == "ascending" then
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
	if not leaderboardConfiguration then
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
local function completelyResetUserLB(forceResize: boolean, kind: string)
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
	local pguiInstance: Instance = localPlayer:WaitForChild("PlayerGui")
	if not pguiInstance:IsA("PlayerGui") then
		annotater.Error("PlayerGui is not a PlayerGui")
		comdeb = false
		return
	end
	local pgui: PlayerGui = pguiInstance :: PlayerGui

	local oldLbSguiInstance: Instance? = pgui:FindFirstChild("LeaderboardScreenGui")
	local oldLbSgui: ScreenGui?
	if oldLbSguiInstance and oldLbSguiInstance:IsA("ScreenGui") then
		oldLbSgui = oldLbSguiInstance :: ScreenGui
	end
	if oldLbSgui then
		local oldInstance: Instance? = oldLbSgui:FindFirstChild("outer_lb")
		if oldInstance and oldInstance:IsA("Frame") then
			-- old size/position not used
		end
		oldLbSgui:Destroy()
	end

	if not lbIsEnabled then
		_annotate("reset lb and it's disabled now so just end.")
		comdeb = false
		return
	end

	local existingSgui = pgui:FindFirstChild("LeaderboardScreenGui")
	if existingSgui then
		existingSgui:Destroy()
	end
	local lbSgui: ScreenGui = Instance.new("ScreenGui")
	lbSgui.Name = "LeaderboardScreenGui"
	lbSgui.Parent = pgui
	lbSgui.IgnoreGuiInset = true

	--previous lb frame items now just are floating independently and adjustable freely.

	local lbSystemFrames = windowFunctions.SetupFrame("lb", true, true, true, true, UDim2.new(0, 300, 0, 100))
	lbOuterFrame = lbSystemFrames.outerFrame
	local lbContentFrame = lbSystemFrames.contentFrame
	if not lbOuterFrame then
		return
	end

	if not leaderboardConfiguration then
		annotater.Error("leaderboardConfiguration is nil in completelyResetUserLB")
		comdeb = false
		return
	end
	lbOuterFrame.Parent = lbSgui
	lbOuterFrame.Position = leaderboardConfiguration.position
	lbOuterFrame.Size = leaderboardConfiguration.size

	local headerRow = leaderboardGui.MakeLeaderboardHeaderRow(enabledDescriptors, headerRowYOffsetFixed)
	headerRow.Parent = lbContentFrame
	headerRow.Position = UDim2.new(0, 0, 0, 0)
	for _, elbInstance: Instance in pairs(headerRow:GetChildren()) do
		if not elbInstance:IsA("TextButton") then
			continue
		end
		local elb: TextButton = elbInstance :: TextButton
		local innerInstance: Instance? = elb:FindFirstChild("Inner")
		if not innerInstance or not innerInstance:IsA("TextButton") then
			continue
		end
		local inner: TextButton = innerInstance :: TextButton
		local keyHolderInstance: Instance? = inner:FindFirstChild("key")
		if not keyHolderInstance or not keyHolderInstance:IsA("StringValue") then
			continue
		end
		local keyHolder: StringValue = keyHolderInstance :: StringValue
		local key = keyHolder.Value
		-- Add click event for sorting
		inner.MouseButton1Click:Connect(function()
			receiveHeaderRowClick(key)
		end)
	end

	local newLbUserRowFrame: Frame = Instance.new("Frame")
	newLbUserRowFrame.Parent = lbContentFrame
	newLbUserRowFrame.BorderMode = Enum.BorderMode.Inset
	newLbUserRowFrame.BorderSizePixel = 0
	newLbUserRowFrame.Size = UDim2.new(1, 0, 1, -1 * headerRowYOffsetFixed)
	newLbUserRowFrame.Position = UDim2.new(0, 0, 0, headerRowYOffsetFixed)
	newLbUserRowFrame.Name = "lbUserRowFrame"
	newLbUserRowFrame.BackgroundTransparency = 1
	newLbUserRowFrame.BackgroundColor3 = colors.defaultGrey
	lbUserRowFrame = newLbUserRowFrame

	local vv: UIListLayout = Instance.new("UIListLayout")
	vv.SortOrder = Enum.SortOrder.LayoutOrder
	vv.Name = "LeaderboardNameSorter"
	vv.Parent = newLbUserRowFrame

	leaderboardButtons.initActionButtons(lbOuterFrame)

	for _, v in pairs(userId2rowframe) do
		_annotate("\tuserId2rowframe: " .. v.Name)
		annotater.Error(string.format("which is weird cause we're reserttings it. %s", kind))
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
			local change: tt.leaderboardUserDataChange =
				{ userId = userId, key = key, oldValue = oldValue, newValue = newValue }
			lbUserDataCache[userId][key] = newValue
			table.insert(res, change)
		end
	end
	storeUserDataDebounce = false
	return res
end

-- store the data in-memory.

local function updateUserLeaderboardRow(userStats: tt.lbUserStats): ()
	_annotate(string.format("Updating leaderboard row for user %s", tostring(userStats.userId)))
	while not loadedSettings do
		wait(0.1)
		_annotate("waiting for settings to load for updateUserLeaderboardRow")
	end
	if lbUserRowFrame == nil then
		annotater.Error("lbUserRowFrame is nil. how is this possible?")
		return
	end

	local subjectUserId = userStats.userId
	if subjectUserId == nil then
		warn("nil userid for update.")
		debounceUpdateUserLeaderboardRow[userStats.userId] = nil
		return
	end

	while debounceUpdateUserLeaderboardRow[subjectUserId] do
		_annotate(string.format("waiting for user %s to finish receiving their lb update", tostring(userStats.userId)))
		wait(0.1)
	end
	debounceUpdateUserLeaderboardRow[subjectUserId] = true
	if not lbIsEnabled then
		debounceUpdateUserLeaderboardRow[subjectUserId] = nil
		return
	end

	local userDataChanges: { tt.leaderboardUserDataChange } = StoreUserData(subjectUserId, userStats)
	if userDataChanges == nil or #userDataChanges == 0 then
		_annotate("No changes detected for user " .. tostring(subjectUserId))
		debounceUpdateUserLeaderboardRow[userStats.userId] = nil
		return
	end
	applyUserDataChanges(userDataChanges, subjectUserId)
	_annotate(string.format("Finished updating leaderboard row for user %s", tostring(userStats.userId)))
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
	local row: Frame? = userId2rowframe[userId]
	userId2rowframe[userId] = nil
	lbUserDataCache[userId] = nil
	if row then
		pcall(function()
			if row then
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
	local useValue = ""
	if setting.booleanValue ~= nil then
		useValue = tostring(setting.booleanValue)
	elseif setting.luaValue ~= nil then
		useValue = tostring(setting.luaValue)
	elseif setting.stringValue ~= nil then
		useValue = tostring(setting.stringValue)
	end
	_annotate(
		string.format("leaderboard handleUserSettingChanged: loading setting: %s=%s", tostring(setting.name), useValue)
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
			leaderboardConfiguration = setting.luaValue :: tt.lbConfig
			_annotate("loaded leaderboardConfiguration")
			local lbConfig = leaderboardConfiguration
			if lbConfig then
				for k, v in pairs(lbConfig) do
					_annotate(string.format("\tleaderboardConfiguration: %s=%s", tostring(k), tostring(v)))
				end
				sortLeaderboard()
			end
		else
			annotater.Error("leaderboardConfiguration is nil")
		end
		return
	end

	if setting.domain == settingEnums.settingDomains.LEADERBOARD then
		if setting.name == settingEnums.settingDefinitions.LEADERBOARD_PINNED_RACE.name then
			_annotate(
				"received pinned race name but we don't apparently care. (since the info arrives with the update from db."
			)
		else
			if setting.booleanValue == nil then
				annotater.Error(
					"a LB setting value boolean value was nil, which isn't possible for the remaining LB settings which are all toggles (until we add more)"
				)
				error("a LB setting value boolean value was nil, which isn't possible")
			end
			local actualValue = setting.booleanValue or false
			if setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_PORTRAIT.name then
				enabledDescriptors["portrait"] = actualValue
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_USERNAME.name then
				enabledDescriptors["username"] = actualValue
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_AWARDS.name then
				enabledDescriptors["awardCount"] = actualValue
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_TIX.name then
				enabledDescriptors["userTix"] = actualValue
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_FINDS.name then
				enabledDescriptors["findCount"] = actualValue
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_FINDRANK.name then
				enabledDescriptors["findRank"] = actualValue
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_CWRS.name then
				enabledDescriptors["cwrs"] = actualValue
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_CWRANK.name then
				enabledDescriptors["cwrRank"] = actualValue
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_CWRTOP10S.name then
				enabledDescriptors["cwrTop10s"] = actualValue
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_TOP10S.name then
				enabledDescriptors["top10s"] = actualValue
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_WRS.name then
				enabledDescriptors["wrCount"] = actualValue
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_WRRANK.name then
				enabledDescriptors["wrRank"] = actualValue
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_RACES.name then
				enabledDescriptors["userTotalRaceCount"] = actualValue
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_RUNS.name then
				enabledDescriptors["userTotalRunCount"] = actualValue
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_BADGES.name then
				enabledDescriptors["badgeCount"] = actualValue
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_DAYSINGAME_COLUMN.name then
				enabledDescriptors["daysInGame"] = actualValue
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_PINNED_RACE_COLUMN.name then
				enabledDescriptors["pinnedRace"] = actualValue
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_FAVORITES.name then
				enabledDescriptors["userFavoriteRaceCount"] = actualValue
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_RUNSTODAY_COLUMN.name then
				enabledDescriptors["runsToday"] = actualValue
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_WRSTODAY_COLUMN.name then
				enabledDescriptors["wrsToday"] = actualValue
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_CWRSTODAY_COLUMN.name then
				enabledDescriptors["cwrsToday"] = actualValue
			else
				warn("unknown leaderboard setting: " .. tostring(setting.name))
			end
		end
	end

	-- this is the fallthrough for any of the columnsEnabled changes.
	if not initial then
		_annotate("completely resetting userLB cause setting changed")
		completelyResetUserLB(
			false,
			"non-initial reset within handleUserSettingChanged for setting: " .. tostring(setting.name)
		)
	end
	return nil
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
	userFavoriteRaceCount = 0,
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
	userFavoriteRaceCount = 12,
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
	userFavoriteRaceCount = 10,
}

local fakeUserStats3: tt.genericLeaderboardUpdateDataType = {
	userId = 12345, -- A fake user ID
	kind = "lbupdate",
	lbUserStats = lb3,
}

module.Init = function()
	_annotate("Starting leaderboard initialization")
	loadedSettings = false
	enabledDescriptors = {}
	userId2rowframe = {}
	lbUserRowFrame = nil
	lbIsEnabled = true

	localPlayer = Players.LocalPlayer
	handleUserSettingChanged(
		settings.GetSettingByName(settingEnums.settingDefinitions.LEADERBOARD_CONFIGURATION.name),
		true
	)
	handleUserSettingChanged(settings.GetSettingByName(settingEnums.settingDefinitions.HIDE_LEADERBOARD.name), true)

	for _, userSetting in pairs(settings.GetSettingByDomain(settingEnums.settingDomains.LEADERBOARD)) do
		handleUserSettingChanged(userSetting, true)
	end

	completelyResetUserLB(true, "initial setup.")
	loadedSettings = true

	LeaderboardUpdateEvent.OnClientEvent:Connect(function(data)
		_annotate("Received leaderboard update event")
		module.ClientReceiveNewLeaderboardData(data)
	end)

	sortLeaderboard()

	-- it's sorted; if new sort values come in, we'll sort as a result of the following monitoring.

	-- now we listen for subsequent setting changes.
	settings.RegisterFunctionToListenForSettingName(function(item: tt.userSettingValue): any
		return handleUserSettingChanged(item, false)
	end, settingEnums.settingDefinitions.HIDE_LEADERBOARD.name, "leaderboard")

	settings.RegisterFunctionToListenForDomain(function(item: tt.userSettingValue): any
		return handleUserSettingChanged(item, false)
	end, settingEnums.settingDomains.LEADERBOARD)
	if config.IsInStudio() and false then
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
