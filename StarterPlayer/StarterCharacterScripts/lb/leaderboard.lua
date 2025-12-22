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
local enums = require(game.ReplicatedStorage.util.enums)

--TYPE
local tt = require(game.ReplicatedStorage.types.gametypes)
local leaderboardEnums = require(game.StarterPlayer.StarterPlayerScripts.lb.leaderboardEnums)
local leaderboardGui = require(game.StarterPlayer.StarterPlayerScripts.lb.leaderboardGui)
local lt = require(game.StarterPlayer.StarterPlayerScripts.lb.leaderboardTypes)
local windowFunctions = require(game.StarterPlayer.StarterPlayerScripts.guis.windowFunctions)

--UTIL
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local tpUtil: typeof(require(game.ReplicatedStorage.util.tpUtil)) = require(game.ReplicatedStorage.util.tpUtil)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local config = require(game.ReplicatedStorage.config)
local settings = require(game.ReplicatedStorage.settings)
-- local enums = require(game.ReplicatedStorage.util.enums)

local colors = require(game.ReplicatedStorage.util.colors)
local thumbnails = require(game.ReplicatedStorage.thumbnails)

local remotes = require(game.ReplicatedStorage.util.remotes)

local leaderboardButtons = require(game.StarterPlayer.StarterPlayerScripts.lb.leaderboardButtons)

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
local lbScrollingFrame: ScrollingFrame? = nil
local lbIsEnabled: boolean = true
local lbAllowInternalScrolling: boolean = false

-- removeUserLBRow is defined later in the file

-- the initial width and height scales.

local headerRowYOffsetFixed = 24
local fixedRowHeightPixels = 40
-- Default size matches settingEnums.LEADERBOARD_CONFIGURATION.defaultLuaValue.size (35% screen height)
local defaultLbSize = UDim2.new(0.44, 0, 0.35, 0)

-- local headerRowShrinkFactor = 0.6

local enabledDescriptors: { [string]: boolean } = {}

local function setDescriptorEnabled(descriptorName: string, newValue: boolean): boolean
	local currentValue = enabledDescriptors[descriptorName]
	-- Treat nil as false for comparison purposes to avoid false positives
	local normalizedCurrent = if currentValue == nil then false else currentValue
	if normalizedCurrent == newValue then
		return false
	end
	enabledDescriptors[descriptorName] = newValue
	return true
end

-- this will block things like adding rows.
local loadedSettings = false
local leaderboardConfiguration: tt.lbConfig? = nil

local lastSaveRequestCount = 0

----------------------- FOR SAVING LB CONFIGURATION -----------------
-- Helper to convert absolute position to scale-based UDim2 for monitor independence
local function absoluteToScale(absoluteX: number, absoluteY: number): UDim2
	local camera = workspace.CurrentCamera
	if not camera then
		return UDim2.fromOffset(absoluteX, absoluteY)
	end
	local viewportSize = camera.ViewportSize
	local scaleX = absoluteX / viewportSize.X
	local scaleY = absoluteY / viewportSize.Y
	return UDim2.fromScale(scaleX, scaleY)
end

-- Helper to convert absolute size to scale-based UDim2
local function sizeToScale(absoluteWidth: number, absoluteHeight: number): UDim2
	local camera = workspace.CurrentCamera
	if not camera then
		return UDim2.fromOffset(absoluteWidth, absoluteHeight)
	end
	local viewportSize = camera.ViewportSize
	local scaleX = absoluteWidth / viewportSize.X
	local scaleY = absoluteHeight / viewportSize.Y
	return UDim2.fromScale(scaleX, scaleY)
end

local function saveLeaderboardConfiguration()
	-- Reconstruct the configuration and save it.
	-- Uses scale-based positions for monitor independence (consistent with windowFunctions).
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
		local absolutePosition = lbOuterFrame.AbsolutePosition
		local absoluteSize = lbOuterFrame.AbsoluteSize
		-- Convert to scale-based for monitor independence (matches windowFunctions persistence)
		local positionAsScale = absoluteToScale(absolutePosition.X, absolutePosition.Y)
		local sizeAsScale = sizeToScale(absoluteSize.X, absoluteSize.Y)
		local setting: tt.userSettingValue = {
			name = settingEnums.settingDefinitions.LEADERBOARD_CONFIGURATION.name,
			domain = settingEnums.settingDomains.LEADERBOARD,
			kind = settingEnums.settingKinds.LUA,
			luaValue = {
				position = positionAsScale,
				size = sizeAsScale,
				minimized = lbOuterFrame:GetAttribute("IsMinimized"),
				sortDirection = lbConfig.sortDirection,
				sortColumn = lbConfig.sortColumn,
			},
		}
		_annotate(string.format("saving leaderboard configuration: pos=scale(%.3f,%.3f) size=scale(%.3f,%.3f)", positionAsScale.X.Scale, positionAsScale.Y.Scale, sizeAsScale.X.Scale, sizeAsScale.Y.Scale))
		settings.SetSetting(setting)
	end)
end

-- Minimum height: header + 1 row = 24 + 40 = 64 pixels (must fit at least 1 row without scrollbar)
local MIN_LEADERBOARD_HEIGHT = 64

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

	local originalSizeY = sizeY
	-- Ensure minimum height
	sizeY = math.max(sizeY, MIN_LEADERBOARD_HEIGHT)

	-- Calculate boundaries
	local minX = 0
	local minY = 0

	-- if the screen is smaller than the desired size
	local maxX = math.max(0, viewportSize.X - sizeX)
	local maxY = math.max(0, viewportSize.Y - sizeY)

	local newX = math.clamp(positionX, minX, maxX)
	local newY = math.clamp(positionY, minY, maxY)

	-- Check if position or size needs adjustment (compare pixels, not mixed formats)
	local positionChanged = math.abs(newX - positionX) > 0.5 or math.abs(newY - positionY) > 0.5
	local sizeChanged = math.abs(sizeY - originalSizeY) > 0.5

	if positionChanged or sizeChanged then
		-- Convert back to scale-based UDim2 for monitor independence
		local newPosition = absoluteToScale(newX, newY)
		local newSize = sizeToScale(sizeX, sizeY)

		leaderboardConfiguration.position = newPosition
		leaderboardConfiguration.size = newSize
		lbOuterFrame.Position = newPosition
		lbOuterFrame.Size = newSize

		_annotate(string.format("Adjusted Leaderboard: pos=scale(%.3f,%.3f) size=scale(%.3f,%.3f)", newPosition.X.Scale, newPosition.Y.Scale, newSize.X.Scale, newSize.Y.Scale))
		-- Position/size changes trigger windowFunctions persistence via PropertyChanged signals
		-- No need to call saveLeaderboardConfiguration() here
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
			-- Position/size/minimized are automatically saved by windowFunctions persistence system
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
			-- Minimized state is automatically saved by windowFunctions persistence system
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

	if lbAllowInternalScrolling then
		-- Fixed-height rows for scrolling mode
		for _, child in ipairs(lbUserRowFrame:GetChildren()) do
			if child:IsA("Frame") and child.Name ~= "LeaderboardHeaderRow" then
				child.Size = UDim2.new(1, 0, 0, fixedRowHeightPixels)
				child.Position = UDim2.new(0, 0, 0, 0)
			end
		end
		-- Update canvas size for the scrolling frame
		if lbScrollingFrame then
			local canvasHeight = rowCount * fixedRowHeightPixels
			lbScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, canvasHeight)
			_annotate(string.format("SIZE_DEBUG: setSize canvas=%d (%d rows * %d), scrollFrame.AbsoluteSize.Y=%d", canvasHeight, rowCount, fixedRowHeightPixels, lbScrollingFrame.AbsoluteSize.Y))
		end

		-- Clamp max height to content height so user can't drag below actual rows
		-- Content height = header + all data rows
		if lbOuterFrame then
			local contentHeight = headerRowYOffsetFixed + (rowCount * fixedRowHeightPixels)
			-- Minimum height: header + at least 1 row (exact, no buffer)
			-- This ensures scroll frame has exactly enough space to show 1 row without scrollbar
			local minHeight = headerRowYOffsetFixed + fixedRowHeightPixels
			lbOuterFrame:SetAttribute("MaxHeight", contentHeight)
			lbOuterFrame:SetAttribute("MinHeight", minHeight)

			-- Enable height snapping to row boundaries (prevents partial rows and unnecessary scrollbars)
			lbOuterFrame:SetAttribute("HeightSnapInterval", fixedRowHeightPixels)
			lbOuterFrame:SetAttribute("HeightSnapOffset", headerRowYOffsetFixed)

			-- Enforce height bounds: grow if too small, shrink if too large
			local currentHeight = lbOuterFrame.AbsoluteSize.Y
			if currentHeight < minHeight then
				-- Frame is too short - would show scrollbar. Grow to minHeight.
				local currentSize = lbOuterFrame.Size
				lbOuterFrame.Size = UDim2.new(currentSize.X.Scale, currentSize.X.Offset, 0, minHeight)
				_annotate(string.format("Grew LB height from %d to %d (too short for content)", currentHeight, minHeight))
			elseif currentHeight > contentHeight then
				-- Frame is too tall (e.g., player left). Shrink to fit.
				local currentSize = lbOuterFrame.Size
				lbOuterFrame.Size = UDim2.new(currentSize.X.Scale, currentSize.X.Offset, 0, contentHeight)
				_annotate(string.format("Shrunk LB height from %d to %d (player left)", currentHeight, contentHeight))
			end

			_annotate(string.format("Set MaxHeight to %d (header %d + %d rows * %d)", contentHeight, headerRowYOffsetFixed, rowCount, fixedRowHeightPixels))
		end

		_annotate("adjusted row fixed heights and canvas size.")
	else
		-- Original behavior: scale rows to fit
		-- No MaxHeight or snapping constraints in non-scrolling mode
		if lbOuterFrame then
			lbOuterFrame:SetAttribute("MaxHeight", nil)
			lbOuterFrame:SetAttribute("MinHeight", nil)
			lbOuterFrame:SetAttribute("HeightSnapInterval", nil)
			lbOuterFrame:SetAttribute("HeightSnapOffset", nil)
		end

		local normalizedPlayerRowYScale = 1 / rowCount
		for _, child in ipairs(lbUserRowFrame:GetChildren()) do
			if child:IsA("Frame") and child.Name ~= "LeaderboardHeaderRow" then
				child.Size = UDim2.new(1, 0, normalizedPlayerRowYScale, 0)
				child.Position = UDim2.new(0, 0, 0, 0)
			end
		end
		_annotate("adjusted row scales.")
	end
end

--important to use all lbUserCellParams here to make the row complete
--even if an update comes before the loading of full stats.
local function getNameForDescriptor(descriptor: lt.lbColumnDescriptor): string
	return string.format("%02d.cell.%s", descriptor.num, descriptor.name)
end

local function ensureValueLabelForDescriptor(containerFrame: Frame, descriptor: lt.lbColumnDescriptor, bgcolor: Color3): (TextLabel, TextLabel)
	-- pinned/favs columns are frame-backed instead of TextLabel-backed. They must expose a TextLabel with an Inner child
	-- so downstream handlers can write text or swap in buttons. This helper enforces that exact structure so we never
	-- improvise at update-time.
	local desiredLabelName = string.format("%02d.cell.%s.valueHolder", descriptor.num, descriptor.name)
	local holderInstance = containerFrame:FindFirstChild(desiredLabelName)
	local holderLabel: TextLabel? = if holderInstance and holderInstance:IsA("TextLabel") then holderInstance :: TextLabel else nil
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
			-- Pass borderSizePixel=1 with black border to match other cells
			local portraitCell = thumbnails.createAvatarPortraitPopup(userId, true, colors.defaultGrey, 1, colors.black)
			portraitCell.Parent = userRowFrame
			portraitCell.Size = UDim2.fromScale(widthYScale, 1)
			portraitCell.Name = getNameForDescriptor(lbColumnDescriptor)
			portraitCell.LayoutOrder = lbColumnDescriptor.num
		elseif lbColumnDescriptor.columnKind == "computed" or lbColumnDescriptor.columnKind == "interactive" then
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
				-- Outer frame is invisible; inner TextLabel holder handles all styling
				descriptorFrame.BackgroundTransparency = 1
				descriptorFrame.BorderSizePixel = 0
				descriptorFrame.LayoutOrder = lbColumnDescriptor.num

				-- Skip text holder for columns with custom rendering (e.g. badge icons)
				if not lbColumnDescriptor.customRendering then
					ensureValueLabelForDescriptor(descriptorFrame, lbColumnDescriptor, bgcolor)
				end
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
				-- Set LayoutOrder on the outer element (parent) for proper UIListLayout sorting
				-- getTl returns the inner label, so we need to set LayoutOrder on its parent
				do
					local parentInstance = tl.Parent
					if parentInstance and parentInstance:IsA("TextLabel") then
						local outerLabel = parentInstance :: TextLabel
						outerLabel.LayoutOrder = lbColumnDescriptor.num
					end
				end
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
			local change: tt.leaderboardUserDataChange = { userId = userId, key = key, oldValue = MAGIC, newValue = thing }
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
		_annotate(string.format("trying to update lb for change %s %s=>%s", tostring(change.key), tostring(ovt), tostring(change.newValue)))

		-- warpPermission is a data key that drives the warpTo column, not a column itself
		-- Handle it specially before the descriptor check
		if change.key == "warpPermission" then
			local warpToDescriptor = leaderboardEnums.LbColumnDescriptors["warpTo"]
			if warpToDescriptor and enabledDescriptors["warpTo"] then
				if warpToDescriptor.columnKind ~= "interactive" then
					annotater.Error("warpTo column should have columnKind='interactive'")
				end
				local warpToCellName = getNameForDescriptor(warpToDescriptor)
				local warpToFrameInstance: Instance? = userRowFrame:FindFirstChild(warpToCellName)
				if warpToFrameInstance and warpToFrameInstance:IsA("Frame") then
					local warpToFrame: Frame = warpToFrameInstance :: Frame

					-- Apply green flash for warp permission changes
					-- Flash the inner holder label, not the transparent outer frame
					local shouldFlash = change.oldValue ~= MAGIC and change.oldValue ~= change.newValue
					local holderToFlash: TextLabel? = nil
					local innerToFlash: TextLabel? = nil
					if shouldFlash then
						local holderName = string.format("%02d.cell.%s.valueHolder", warpToDescriptor.num, warpToDescriptor.name)
						local holderInstance = warpToFrame:FindFirstChild(holderName)
						if holderInstance and holderInstance:IsA("TextLabel") then
							local holder = holderInstance :: TextLabel
							holder.BackgroundColor3 = colors.greenGo
							local innerInstance = holder:FindFirstChild("Inner")
							if innerInstance and innerInstance:IsA("TextLabel") then
								local inner = innerInstance :: TextLabel
								inner.BackgroundColor3 = colors.greenGo
								innerToFlash = inner
							end
							holderToFlash = holder
						end
					end

					local localFindCount = 0
					local localCache = lbUserDataCache[localPlayer.UserId]
					if localCache and localCache.findCount then
						localFindCount = localCache.findCount
					end
					leaderboardGui.DrawWarpToCell(warpToFrame, subjectUserId, change.newValue :: string, localPlayer.UserId, localFindCount)

					-- Tween background back to normal after flash
					if shouldFlash and holderToFlash then
						local tween = TweenService:Create(holderToFlash, TweenInfo.new(enums.greenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = bgcolor })
						tween:Play()
						if innerToFlash then
							local tween2 = TweenService:Create(innerToFlash, TweenInfo.new(enums.greenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = bgcolor })
							tween2:Play()
						end
					end
				elseif warpToFrameInstance then
					annotater.Error(string.format("warpTo cell expected Frame but got %s", warpToFrameInstance.ClassName))
				else
					annotater.Error(string.format("warpTo cell '%s' not found for user %d", warpToCellName, subjectUserId))
				end
			end
			continue
		end

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
			annotater.Error(string.format("LB change key '%s' has no descriptor in leaderboardEnums - data/enum mismatch", change.key))
			continue
		end

		local targetName = getNameForDescriptor(descriptor)
		local oldTextLabelParentInstance: Instance? = userRowFrame:FindFirstChild(targetName)
		if not oldTextLabelParentInstance then
			-- Column is enabled (we passed the enabledDescriptors check) but cell doesn't exist.
			-- This could indicate a timing issue or a bug in row creation.
			warn(string.format("LB cell '%s' not found for user %d but column is enabled - possible timing issue or creation bug", targetName, subjectUserId))
			continue
		end

		-- Custom rendering columns (e.g. badge icons) skip text holder logic entirely
		-- They handle everything in their draw function
		if descriptor.customRendering then
			if not oldTextLabelParentInstance:IsA("Frame") then
				annotater.Error(string.format("Custom rendering column '%s' expected Frame but got %s", change.key, oldTextLabelParentInstance.ClassName))
				continue
			end
			local customFrame: Frame = oldTextLabelParentInstance :: Frame

			-- Dispatch to draw function (no green flash for custom rendering columns)
			if descriptor.drawFunctionName == "DrawPinnedBadgeCell" then
				local isOwnRow = subjectUserId == localPlayer.UserId
				leaderboardGui.DrawPinnedBadgeCell(customFrame, change.newValue :: string, isOwnRow)
			elseif descriptor.drawFunctionName == "DrawLatestBadgeCell" then
				local isOwnRow = subjectUserId == localPlayer.UserId
				local userCache = lbUserDataCache[subjectUserId]
				local earnedAt = if userCache then userCache.latestBadgeEarnedAt else nil
				leaderboardGui.DrawLatestBadgeCell(customFrame, change.newValue :: string, earnedAt, isOwnRow)
			else
				annotater.Error(string.format("Custom rendering column '%s' has unknown drawFunctionName '%s'", change.key, tostring(descriptor.drawFunctionName)))
			end
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
			local parentTextLabel = if oldTextLabelParentInstance:IsA("TextLabel") then oldTextLabelParentInstance :: TextLabel else nil
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
			annotater.Error(string.format("Missing old label to put in - this should not happen %d %s", descriptor.num, descriptor.name))
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

		-- Interactive columns: dispatch to their draw function when change arrives
		if descriptor.columnKind == "interactive" then
			if not oldTextLabelParent then
				annotater.Error(string.format("Interactive column '%s' enabled but cell frame not found for user %d", change.key, subjectUserId))
				continue
			end
			local interactiveFrame: Frame = oldTextLabelParent

			-- Apply green flash for interactive columns too (if value actually changed)
			-- Flash the inner holder label, not the transparent outer frame
			local shouldFlash = change.oldValue ~= MAGIC and change.oldValue ~= change.newValue
			local holderToFlash: TextLabel? = nil
			local innerToFlash: TextLabel? = nil
			if shouldFlash then
				local holderName = string.format("%02d.cell.%s.valueHolder", descriptor.num, descriptor.name)
				local holderInstance = interactiveFrame:FindFirstChild(holderName)
				if holderInstance and holderInstance:IsA("TextLabel") then
					local holder = holderInstance :: TextLabel
					holder.BackgroundColor3 = colors.greenGo
					local innerInstance = holder:FindFirstChild("Inner")
					if innerInstance and innerInstance:IsA("TextLabel") then
						local inner = innerInstance :: TextLabel
						inner.BackgroundColor3 = colors.greenGo
						innerToFlash = inner
					end
					holderToFlash = holder
				end
			end

			-- Dispatch based on drawFunctionName (functions have different signatures, so we match explicitly)
			if descriptor.drawFunctionName == "DrawRaceWarper" then
				leaderboardGui.DrawRaceWarper(interactiveFrame, change)
			elseif descriptor.drawFunctionName == "DrawShowFavoriteRacesButton" then
				leaderboardGui.DrawShowFavoriteRacesButton(interactiveFrame, change, subjectUserId, localPlayer.UserId)
			elseif descriptor.drawFunctionName == "DrawBadgeCountCell" then
				local isOwnRow = subjectUserId == localPlayer.UserId
				leaderboardGui.DrawBadgeCountCell(interactiveFrame, change.newValue :: number, isOwnRow)
			else
				annotater.Error(string.format("Interactive column '%s' has unknown drawFunctionName '%s'", change.key, tostring(descriptor.drawFunctionName)))
			end

			-- Tween background back to normal after flash
			if shouldFlash and holderToFlash then
				local tween = TweenService:Create(holderToFlash, TweenInfo.new(enums.greenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = bgcolor })
				tween:Play()
				if innerToFlash then
					local tween2 = TweenService:Create(innerToFlash, TweenInfo.new(enums.greenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = bgcolor })
					tween2:Play()
				end
			end
			-- warpTo is handled separately via warpPermission change key, not here
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
					task.wait(enums.greenTime)
					if label then
						label.Text = finalText
					end
				end)

				--phase the cell and the parent back to the default color.
				local tween = TweenService:Create(oldTextLabel, TweenInfo.new(enums.greenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = bgcolor })
				tween:Play()

				local tween2 = TweenService:Create(parLabel, TweenInfo.new(enums.greenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = bgcolor })
				tween2:Play()
			end

			--we had more tweens before.
		end
		_annotate("done with updateUserLeaderboardRow")
	end

	-- Helper: get Frame cell for a non-standard column with loud error on mismatch
	local function getFrameCellForColumn(columnName: string): Frame?
		if not enabledDescriptors[columnName] then
			return nil
		end
		local descriptor = leaderboardEnums.LbColumnDescriptors[columnName]
		if not descriptor then
			annotater.Error(string.format("LB column '%s' enabled but descriptor missing from leaderboardEnums", columnName))
			return nil
		end
		if descriptor.columnKind ~= "computed" and descriptor.columnKind ~= "interactive" then
			annotater.Error(string.format("LB column '%s' used as computed/interactive but columnKind is '%s'", columnName, tostring(descriptor.columnKind)))
			return nil
		end
		local cellName = getNameForDescriptor(descriptor)
		local cellInstance = userRowFrame:FindFirstChild(cellName)
		if not cellInstance then
			annotater.Error(string.format("LB column '%s' cell '%s' not found in row frame", columnName, cellName))
			return nil
		end
		if not cellInstance:IsA("Frame") then
			annotater.Error(string.format("LB column '%s' cell '%s' expected Frame but got %s - check columnKind in descriptor", columnName, cellName, cellInstance.ClassName))
			return nil
		end
		return cellInstance :: Frame
	end

	-- Update computed columns (these derive from cached data, not individual change keys)
	local function updateComputedColumns()
		local userCache = lbUserDataCache[subjectUserId]
		if not userCache then
			return
		end

		local isOwnRow = subjectUserId == localPlayer.UserId

		-- Find Percent column
		local findPercentFrame = getFrameCellForColumn("findPercent")
		if findPercentFrame then
			local findCount = userCache.findCount or 0
			local totalSigns = userCache.serverPatchedInTotalSignCount or 1
			leaderboardGui.DrawFindPercentCell(findPercentFrame, findCount, totalSigns, bgcolor)
		end

		-- Similarity column
		local similarityFrame = getFrameCellForColumn("similarity")
		if similarityFrame then
			local myCache = lbUserDataCache[localPlayer.UserId] or {}
			leaderboardGui.DrawSimilarityCell(similarityFrame, myCache, userCache, isOwnRow)
		end

		-- pinnedBadge and latestBadge are interactive columns with custom draw functions

		-- Idle Time column
		local idleTimeFrame = getFrameCellForColumn("idleTime")
		if idleTimeFrame then
			local lastActivity = userCache.lastActivityTimestamp
			local shareIdle = userCache.shareIdleStatus
			leaderboardGui.DrawIdleTimeCell(idleTimeFrame, lastActivity, shareIdle, isOwnRow)
		end
	end
	updateComputedColumns()

	setSize()
	debounceUpdateUserLeaderboardRow[subjectUserId] = nil
end

-- forward declaration
local removeUserLBRow: (number) -> () = nil

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

	-- draggable=true, resizable=true, minimizable=false, pinnable=false
	-- Use persistence with callback to save position + size + minimized + sort settings together
	local initialSize = if leaderboardConfiguration and leaderboardConfiguration.size then leaderboardConfiguration.size else defaultLbSize
	local lbSystemFrames = windowFunctions.SetupFrame(
		"lb",
		true, -- draggable
		true, -- resizable
		false, -- minimizable
		false, -- pinnable
		initialSize,
		false, -- maintainAspectRatio
		{
			settingName = "LEADERBOARD_CONFIGURATION",
			settingKey = "position",
			saveSize = true,
			sizeKey = "size",
			clampOnLoad = true,
			onSave = function(position: UDim2, size: UDim2?, minimized: boolean?)
				if not lbOuterFrame or not leaderboardConfiguration then
					return
				end
				-- Save position + size + minimized + sort settings together
				local setting: tt.userSettingValue = {
					name = settingEnums.settingDefinitions.LEADERBOARD_CONFIGURATION.name,
					domain = settingEnums.settingDomains.LEADERBOARD,
					kind = settingEnums.settingKinds.LUA,
					luaValue = {
						position = position,
						size = if size then size else lbOuterFrame.Size,
						minimized = if minimized ~= nil then minimized else (lbOuterFrame:GetAttribute("IsMinimized") or false),
						sortDirection = leaderboardConfiguration.sortDirection,
						sortColumn = leaderboardConfiguration.sortColumn,
					},
				}
				_annotate("saving leaderboard configuration via persistence callback", setting)
				settings.SetSetting(setting)
			end,
		},
		{
			position = "bottomRight", -- resize handle at bottom-right corner, below the frame
			positionBelow = true, -- Position resize handle just below the LB, not overlapping it
			zIndex = 30, -- Higher priority for click handling over action buttons
		}
	)
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
	-- Position and size are automatically loaded by windowFunctions persistence system
	-- If not loaded, use saved configuration
	if lbOuterFrame.Position.X.Offset == 0 and lbOuterFrame.Position.Y.Offset == 0 and lbOuterFrame.Position.X.Scale == 0 and lbOuterFrame.Position.Y.Scale == 0 then
		lbOuterFrame.Position = leaderboardConfiguration.position
	end

	-- Read internal scrolling setting first so we can enforce min height
	local scrollingSetting = settings.GetSettingByName(settingEnums.settingDefinitions.LEADERBOARD_ALLOW_INTERNAL_SCROLLING.name)
	lbAllowInternalScrolling = scrollingSetting.booleanValue or false

	-- Restore size, but enforce minimum height in scrolling mode to prevent scrollbar for single row
	-- Fall back to default if size is nil or has zero dimensions (corrupted data)
	local restoredSize = leaderboardConfiguration.size
	if not restoredSize or (restoredSize.Y.Scale == 0 and restoredSize.Y.Offset == 0) then
		_annotate(string.format("SIZE_DEBUG: invalid restored size, using default. size=%s", tostring(restoredSize)))
		restoredSize = defaultLbSize
	end
	_annotate(string.format("SIZE_DEBUG: config size = (%s, %s, %s, %s), scrolling=%s", tostring(restoredSize.X.Scale), tostring(restoredSize.X.Offset), tostring(restoredSize.Y.Scale), tostring(restoredSize.Y.Offset), tostring(lbAllowInternalScrolling)))
	if lbAllowInternalScrolling then
		-- Minimum height: header + at least 1 row (no extra buffer needed)
		local minHeight = headerRowYOffsetFixed + fixedRowHeightPixels
		-- Convert to absolute pixels to handle both Scale and Offset components
		local camera = workspace.CurrentCamera
		local viewportHeight = camera and camera.ViewportSize.Y or 1080
		local restoredHeight = restoredSize.Y.Scale * viewportHeight + restoredSize.Y.Offset
		_annotate(string.format("SIZE_DEBUG: minHeight=%d (header=%d + row=%d), restoredHeight=%d (scale=%.3f, offset=%d, viewport=%d)", minHeight, headerRowYOffsetFixed, fixedRowHeightPixels, restoredHeight, restoredSize.Y.Scale, restoredSize.Y.Offset, viewportHeight))
		-- Always enforce minimum height if restored height is smaller
		if restoredHeight < minHeight then
			-- Convert to pure offset to avoid Scale rounding issues
			restoredSize = UDim2.new(restoredSize.X.Scale, restoredSize.X.Offset, 0, minHeight)
			_annotate(string.format("SIZE_DEBUG: Enforced min height on load: %d -> %d", restoredHeight, minHeight))
		end
	end
	lbOuterFrame.Size = restoredSize
	_annotate(string.format("SIZE_DEBUG: lbOuterFrame.Size set to offset Y=%d", restoredSize.Y.Offset))
	ensureLeaderboardOnScreen("completelyResetUserLB initial placement")
	_annotate(string.format("SIZE_DEBUG: after ensureOnScreen, AbsoluteSize.Y=%d", lbOuterFrame.AbsoluteSize.Y))

	local headerRow = leaderboardGui.MakeLeaderboardHeaderRow(enabledDescriptors, headerRowYOffsetFixed)
	headerRow.Parent = lbContentFrame
	headerRow.Position = UDim2.new(0, 1, 0, 0)
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

	-- Create either a direct frame or a scrolling frame based on setting
	local rowsParent: Frame | ScrollingFrame
	if lbAllowInternalScrolling then
		-- Create scrolling frame wrapper
		-- Match header row's size and position for consistent alignment
		local newScrollingFrame: ScrollingFrame = Instance.new("ScrollingFrame")
		newScrollingFrame.Name = "lbScrollingFrame"
		newScrollingFrame.Parent = lbContentFrame
		newScrollingFrame.BorderMode = Enum.BorderMode.Inset
		newScrollingFrame.BorderSizePixel = 0
		newScrollingFrame.BackgroundTransparency = 1
		newScrollingFrame.BackgroundColor3 = colors.defaultGrey
		newScrollingFrame.Size = UDim2.new(1, -2, 1, -1 * headerRowYOffsetFixed)
		newScrollingFrame.Position = UDim2.new(0, 1, 0, headerRowYOffsetFixed)
		newScrollingFrame.ScrollBarThickness = 10
		-- Use None instead of Always to avoid reserving scroll bar width when not scrolling,
		-- which would cause column misalignment with the header row
		newScrollingFrame.VerticalScrollBarInset = Enum.ScrollBarInset.None
		newScrollingFrame.ScrollingDirection = Enum.ScrollingDirection.Y
		newScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
		newScrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.None
		lbScrollingFrame = newScrollingFrame
		rowsParent = newScrollingFrame
		_annotate(string.format("SIZE_DEBUG: scrollingFrame created, Size=(%s, %d, %s, %d)", tostring(newScrollingFrame.Size.X.Scale), newScrollingFrame.Size.X.Offset, tostring(newScrollingFrame.Size.Y.Scale), newScrollingFrame.Size.Y.Offset))
		task.defer(function()
			_annotate(string.format("SIZE_DEBUG: (deferred) scrollingFrame AbsoluteSize.Y=%d, CanvasSize.Y=%d", newScrollingFrame.AbsoluteSize.Y, newScrollingFrame.CanvasSize.Y.Offset))
		end)
	else
		lbScrollingFrame = nil
		rowsParent = lbContentFrame
	end

	local newLbUserRowFrame: Frame = Instance.new("Frame")
	newLbUserRowFrame.Parent = rowsParent
	newLbUserRowFrame.BorderMode = Enum.BorderMode.Inset
	newLbUserRowFrame.BorderSizePixel = 0
	if lbAllowInternalScrolling then
		-- In scrolling mode, match header row alignment: parent is scrollingFrame which is
		-- already offset from contentFrame, so use full width and no extra offset
		newLbUserRowFrame.Size = UDim2.new(1, 0, 0, 0)
		newLbUserRowFrame.Position = UDim2.new(0, 0, 0, 0)
		newLbUserRowFrame.AutomaticSize = Enum.AutomaticSize.Y
	else
		newLbUserRowFrame.Size = UDim2.new(1, -2, 1, -1 * headerRowYOffsetFixed)
		newLbUserRowFrame.Position = UDim2.new(0, 1, 0, headerRowYOffsetFixed)
	end
	newLbUserRowFrame.Name = "lbUserRowFrame"
	newLbUserRowFrame.BackgroundTransparency = 1
	newLbUserRowFrame.BackgroundColor3 = colors.defaultGrey
	lbUserRowFrame = newLbUserRowFrame

	local vv: UIListLayout = Instance.new("UIListLayout")
	vv.SortOrder = Enum.SortOrder.LayoutOrder
	vv.Name = "LeaderboardNameSorter"
	vv.Parent = newLbUserRowFrame

	leaderboardButtons.initActionButtons(lbOuterFrame)

	-- Only log error if entries exist during initial setup; user-initiated resets will have entries
	if kind == "initial setup." then
		for _, v in pairs(userId2rowframe) do
			_annotate("\tuserId2rowframe: " .. v.Name)
			annotater.Error(string.format("unexpected pre-existing row during initial setup: %s", v.Name))
		end
	end

	userId2rowframe = {}
	for _, player in pairs(Players:GetPlayers()) do
		getOrCreateRowForUser(player.UserId)
		local data = GetDataFromCacheForUser(player.UserId)
		applyUserDataChanges(data, player.UserId)
	end
	monitorLeaderboardFrame()
	setSize()

	-- Deferred size check after all setup complete
	task.defer(function()
		if lbOuterFrame and lbScrollingFrame then
			_annotate(string.format("SIZE_DEBUG: (end of reset) outer.AbsoluteSize.Y=%d, scrollFrame.AbsoluteSize.Y=%d, canvas.Y=%d", lbOuterFrame.AbsoluteSize.Y, lbScrollingFrame.AbsoluteSize.Y, lbScrollingFrame.CanvasSize.Y.Offset))
		end
	end)

	comdeb = false
end

--after receiving an lb update, figure out what changed relative to known data
--store it and return a userDataChange for rendering into the LB
local storeUserDataDebounce = false
local function StoreUserData(userId: number, data: tt.lbUserStats): { tt.leaderboardUserDataChange }
	while storeUserDataDebounce do
		task.wait(0.1)
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
			local change: tt.leaderboardUserDataChange = { userId = userId, key = key, oldValue = oldValue, newValue = newValue }
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
		task.wait(0.1)
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
		task.wait(0.1)
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

-- Distance calculation for "distance from you" column
local distanceUpdateConnection: RBXScriptConnection? = nil
local DISTANCE_UPDATE_INTERVAL = 1.0 -- seconds between distance updates
local lastDistanceUpdate = 0

local function getLocalPlayerPosition(): Vector3?
	local character = localPlayer.Character
	if not character then
		return nil
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		return nil
	end
	return hrp.Position
end

local function getPlayerPosition(userId: number): Vector3?
	local player = Players:GetPlayerByUserId(userId)
	if not player then
		return nil
	end
	local character = player.Character
	if not character then
		return nil
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		return nil
	end
	return hrp.Position
end

local function formatDistanceInK(distanceStuds: number): string
	local distanceK = math.floor(distanceStuds / 1000 + 0.5) -- round to nearest 1k
	return string.format("%dk", distanceK)
end

local function updateAllDistances()
	if not enabledDescriptors["distanceFromYou"] then
		return
	end

	local localPos = getLocalPlayerPosition()
	if not localPos then
		return
	end

	for userId, _ in pairs(lbUserDataCache) do
		if userId == localPlayer.UserId then
			-- Show "you" for self since distance to yourself is meaningless
			local oldValue = lbUserDataCache[userId]["distanceFromYou"]
			local newValue = "you"
			if oldValue ~= newValue then
				lbUserDataCache[userId]["distanceFromYou"] = newValue
				local changes: { tt.leaderboardUserDataChange } = {
					{ userId = userId, key = "distanceFromYou", oldValue = MAGIC, newValue = newValue },
				}
				applyUserDataChanges(changes, userId)
			end
		else
			local otherPos = getPlayerPosition(userId)
			if otherPos then
				local distance = (localPos - otherPos).Magnitude
				local newValue = formatDistanceInK(distance)
				local oldValue = lbUserDataCache[userId]["distanceFromYou"]
				if oldValue ~= newValue then
					lbUserDataCache[userId]["distanceFromYou"] = newValue
					local changes: { tt.leaderboardUserDataChange } = {
						{ userId = userId, key = "distanceFromYou", oldValue = MAGIC, newValue = newValue },
					}
					applyUserDataChanges(changes, userId)
				end
			end
		end
	end
end

local function startDistanceUpdates()
	if distanceUpdateConnection then
		return
	end
	local RunService = game:GetService("RunService")
	distanceUpdateConnection = RunService.Heartbeat:Connect(function()
		local now = tick()
		if now - lastDistanceUpdate >= DISTANCE_UPDATE_INTERVAL then
			lastDistanceUpdate = now
			updateAllDistances()
		end
	end)
	_annotate("Started distance update loop")
end

local function stopDistanceUpdates()
	if distanceUpdateConnection then
		distanceUpdateConnection:Disconnect()
		distanceUpdateConnection = nil
		_annotate("Stopped distance update loop")
	end
end

local removeDebouncers = {}
removeUserLBRow = function(userId: number): ()
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
	_annotate(string.format("leaderboard handleUserSettingChanged: loading setting: %s=%s", tostring(setting.name), useValue))
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

	if setting.name == settingEnums.settingDefinitions.LEADERBOARD_CONFIGURATION.name and setting.domain == settingEnums.settingDomains.LEADERBOARD then
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

	local descriptorChanged = false

	if setting.domain == settingEnums.settingDomains.LEADERBOARD then
		if setting.name == settingEnums.settingDefinitions.LEADERBOARD_PINNED_RACE.name then
			_annotate("received pinned race name but we don't apparently care. (since the info arrives with the update from db.")
		else
			if setting.booleanValue == nil then
				annotater.Error("a LB setting value boolean value was nil, which isn't possible for the remaining LB settings which are all toggles (until we add more)")
				error("a LB setting value boolean value was nil, which isn't possible")
			end
			local actualValue = setting.booleanValue or false
			local function applyDescriptor(descriptorName: string)
				if setDescriptorEnabled(descriptorName, actualValue) then
					descriptorChanged = true
				end
			end

			if setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_PORTRAIT.name then
				applyDescriptor("portrait")
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_USERNAME.name then
				applyDescriptor("username")
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_AWARDS.name then
				applyDescriptor("awardCount")
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_TIX.name then
				applyDescriptor("userTix")
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_FINDS.name then
				applyDescriptor("findCount")
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_FINDRANK.name then
				applyDescriptor("findRank")
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_CWRS.name then
				applyDescriptor("cwrs")
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_CWRANK.name then
				applyDescriptor("cwrRank")
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_CWRTOP10S.name then
				applyDescriptor("cwrTop10s")
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_TOP10S.name then
				applyDescriptor("top10s")
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_WRS.name then
				applyDescriptor("wrCount")
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_WRRANK.name then
				applyDescriptor("wrRank")
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_RACES.name then
				applyDescriptor("userTotalRaceCount")
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_RUNS.name then
				applyDescriptor("userTotalRunCount")
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_BADGES.name then
				applyDescriptor("badgeCount")
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_DAYSINGAME_COLUMN.name then
				applyDescriptor("daysInGame")
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_PINNED_RACE_COLUMN.name then
				applyDescriptor("pinnedRace")
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_FAVORITES.name then
				applyDescriptor("userFavoriteRaceCount")
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_RUNSTODAY_COLUMN.name then
				applyDescriptor("runsToday")
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_WRSTODAY_COLUMN.name then
				applyDescriptor("wrsToday")
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_CWRSTODAY_COLUMN.name then
				applyDescriptor("cwrsToday")
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_DISTANCE_FROM_YOU.name then
				applyDescriptor("distanceFromYou")
				if actualValue then
					startDistanceUpdates()
				else
					stopDistanceUpdates()
				end
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_WARP_TO.name then
				applyDescriptor("warpTo")
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_FIND_PERCENT.name then
				applyDescriptor("findPercent")
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_SIMILARITY.name then
				applyDescriptor("similarity")
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_PINNED_BADGE.name then
				applyDescriptor("pinnedBadge")
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_LATEST_BADGE.name then
				applyDescriptor("latestBadge")
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_IDLE_TIME.name then
				applyDescriptor("idleTime")
			elseif setting.name == settingEnums.settingDefinitions.LEADERBOARD_ALLOW_INTERNAL_SCROLLING.name then
				-- Internal scrolling setting requires a complete reset
				if not initial then
					_annotate("completely resetting userLB due to internal scrolling setting change")
					completelyResetUserLB(false, "internal scrolling setting changed")
				end
			else
				warn("unknown leaderboard setting: " .. tostring(setting.name))
			end
		end
	end

	-- this is the fallthrough for any of the columnsEnabled changes.
	if not initial and descriptorChanged then
		_annotate("completely resetting userLB cause setting changed")
		completelyResetUserLB(false, "non-initial reset within handleUserSettingChanged for setting: " .. tostring(setting.name))
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
	warpPermission = "none",
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
	warpPermission = "robloxFriends",
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
	warpPermission = "all",
}

local fakeUserStats3: tt.genericLeaderboardUpdateDataType = {
	userId = 12345, -- A fake user ID
	kind = "lbupdate",
	lbUserStats = lb3,
}

module.Reset = function()
	loadedSettings = false
	enabledDescriptors = {}
	userId2rowframe = {}
	lbUserRowFrame = nil
	lbIsEnabled = true

	localPlayer = Players.LocalPlayer
	handleUserSettingChanged(settings.GetSettingByName(settingEnums.settingDefinitions.LEADERBOARD_CONFIGURATION.name), true)
	handleUserSettingChanged(settings.GetSettingByName(settingEnums.settingDefinitions.HIDE_LEADERBOARD.name), true)

	for _, userSetting in pairs(settings.GetSettingByDomain(settingEnums.settingDomains.LEADERBOARD)) do
		handleUserSettingChanged(userSetting, true)
	end

	completelyResetUserLB(true, "initial setup.")
	loadedSettings = true
end

module.Init = function()
	_annotate("Starting leaderboard initialization")
	module.Reset()

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

	-- Listen for warp permission changes to update the local user's leaderboard row
	settings.RegisterFunctionToListenForSettingName(function(item: tt.userSettingValue): any
		_annotate(string.format("WARP_TO_PERMISSION changed to: %s", tostring(item.stringValue)))
		local newPermission = item.stringValue or "none"
		local userId = localPlayer.UserId

		-- Update local cache
		if lbUserDataCache[userId] then
			local oldValue = lbUserDataCache[userId]["warpPermission"]
			if oldValue ~= newPermission then
				lbUserDataCache[userId]["warpPermission"] = newPermission
				-- Trigger UI update
				local changes: { tt.leaderboardUserDataChange } = {
					{ userId = userId, key = "warpPermission", oldValue = oldValue, newValue = newPermission },
				}
				applyUserDataChanges(changes, userId)
				_annotate(string.format("Updated warpPermission UI: %s -> %s", tostring(oldValue), newPermission))
			end
		else
			_annotate("No cache entry for local user, cannot update warpPermission UI")
		end
		return nil
	end, settingEnums.settingDefinitions.WARP_TO_PERMISSION.name, "leaderboard_warp")

	if config.IsInStudio() and false then
		task.wait(0.2)
		module.ClientReceiveNewLeaderboardData(fakeUserStats)
		task.wait(0.2)
		module.ClientReceiveNewLeaderboardData(fakeUserStats2)
		task.wait(0.2)
		module.ClientReceiveNewLeaderboardData(fakeUserStats3)
	end

	-- Periodic refresh for idle time column (once per minute)
	-- Active users get updates naturally via data events; this catches idle users
	task.spawn(function()
		local IDLE_REFRESH_INTERVAL = 60
		while true do
			task.wait(IDLE_REFRESH_INTERVAL)
			if not lbIsEnabled or not enabledDescriptors["idleTime"] then
				continue
			end
			local idleDescriptor = leaderboardEnums.LbColumnDescriptors["idleTime"]
			if not idleDescriptor then
				continue
			end
			for userId, rowFrame in pairs(userId2rowframe) do
				local userCache = lbUserDataCache[userId]
				if not userCache then
					continue
				end
				local cellName = getNameForDescriptor(idleDescriptor)
				local frameInstance = rowFrame:FindFirstChild(cellName)
				if frameInstance and frameInstance:IsA("Frame") then
					local lastActivity = userCache.lastActivityTimestamp
					local shareIdle = userCache.shareIdleStatus
					local isOwnRow = userId == localPlayer.UserId
					leaderboardGui.DrawIdleTimeCell(frameInstance :: Frame, lastActivity, shareIdle, isOwnRow)
				end
			end
			_annotate("Periodic idle time refresh complete")
		end
	end)

	_annotate("init done")
end

_annotate("end")

return module
