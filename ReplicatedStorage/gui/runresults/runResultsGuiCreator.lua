--!strict

--eval 9.21

--player localscripts call this to generate a raceresult UI.

local colors = require(game.ReplicatedStorage.util.colors)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local thumbnails = require(game.ReplicatedStorage.thumbnails)
local enums = require(game.ReplicatedStorage.util.enums)
-- local PlayersService = game:GetService("Players")
local tt = require(game.ReplicatedStorage.types.gametypes)
local resultRowHeightScale = 0.08
local lesserYScale = 0.04

local playerRowHeight = 0.055

local module = {}

--actually more like addCell with optional text.
local function addRow(
	text: string,
	parent: Frame,
	height: number,
	name: string,
	bgcolor: Color3?,
	width: number?,
	textColor: Color3?
): Frame
	local frame = Instance.new("Frame")
	frame.Parent = parent
	if height == nil then
		height = 0.1
	end
	if width == nil then
		width = 1
	end
	frame.Size = UDim2.new(width, 0, height, 0)
	if name ~= nil then
		frame.Name = name
	end
	if text ~= nil and text ~= "" then
		frame.Name = frame.Name .. tostring(text)
		if width == nil then
			width = 1
		end
		assert(width)
		if bgcolor == nil then
			bgcolor = colors.defaultGrey
		end
		assert(bgcolor)
		local tl = guiUtil.getTl("01" .. text, UDim2.fromScale(width, 1), 2, frame, bgcolor, 1)
		tl.Text = text
		if textColor ~= nil then
			tl.TextColor3 = textColor
		end
		tl.TextXAlignment = Enum.TextXAlignment.Left
	end
	return frame
end

--used for adding subrows to the stop score list in a high score viewer.
local function addPlayerPastResultRow(frame: Frame, rowOrder: number, runEntry: tt.runEntry, useColor: Color3)
	local name = string.format("%02d", rowOrder)
	local f = addRow("", frame, playerRowHeight, name)
	local hh = Instance.new("UIListLayout")
	hh.Parent = f
	hh.FillDirection = Enum.FillDirection.Horizontal

	--this depends on semi-broken BE behavior about virtualized places, etc.
	local tl = guiUtil.getTl(tostring("1place"), UDim2.new(0.1, 0, 1, 0), 2, f, useColor, 1)
	if runEntry.place == 0 then
		tl.Text = "-"
	else
		tl.Text = tostring(runEntry.place)
	end
	if runEntry.place == 11 then
		tl.Text = "KO"
	end
	tl.TextXAlignment = Enum.TextXAlignment.Center

	--thumb

	local av = Instance.new("ImageLabel")
	av.BorderMode = Enum.BorderMode.Inset
	av.Name = "2runresultImage"
	av.Size = UDim2.new(0.1, 0, 1, 0)
	local content = thumbnails.getThumbnailContent(runEntry.userId, Enum.ThumbnailType.HeadShot)
	av.Image = content
	av.BackgroundColor3 = useColor
	av.BorderSizePixel = 0
	av.Parent = f

	--username
	local n = guiUtil.getTl("3username", UDim2.new(0.58, 0, 1, 0), 2, f, useColor, 0)
	n.Text = runEntry.username
	n.TextXAlignment = Enum.TextXAlignment.Left
	n.TextYAlignment = Enum.TextYAlignment.Center

	--time
	local t = guiUtil.getTl("4time", UDim2.new(0.22, 0, 1, 0), 2, f, useColor, 1)
	t.Text = tpUtil.fmtms(runEntry.runMilliseconds)
	t.TextXAlignment = Enum.TextXAlignment.Right
end

--sgui for the results of running a race OR a marathon!.
module.createNewRunResultSgui =
	function(options: tt.pyUserFinishedRunResponse, warperWrapper: tt.warperWrapper): ScreenGui
		options.userId = tonumber(options.userId) :: number
		local raceResultSgui = Instance.new("ScreenGui")
		raceResultSgui.Name = "RaceResultSgui"

		local raceResultFrameName = "raceResultFrame"
		local frame: Frame = Instance.new("Frame")
		frame.Name = raceResultFrameName

		local defaultOuterFrameSize = 0.49

		--the used framesize; will be expanded later.
		local frameYUsed = 0
		local totalSent: number = 0
		frame.Position = UDim2.new(0.72, -5, 0.33, 0)

		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Vertical
		layout.Name = "UIListLayoutV"
		layout.Parent = frame

		if options.playerText ~= "" and options.playerText ~= nil then
			addRow(
				options.playerText,
				frame,
				resultRowHeightScale,
				string.format("%02d-playerText", totalSent),
				colors.meColor
			)
			frameYUsed = frameYUsed + resultRowHeightScale
			totalSent += 1
		end
		if options.yourText ~= "" and options.yourText ~= nil then
			addRow(options.yourText, frame, lesserYScale, string.format("%02d-yourText", totalSent), colors.meColor)
			frameYUsed = frameYUsed + lesserYScale
			totalSent += 1
		end
		if options.lossText ~= "" and options.lossText ~= nil then
			addRow(
				options.lossText,
				frame,
				resultRowHeightScale,
				string.format("%02d-losstext", totalSent),
				colors.meColor
			)
			frameYUsed = frameYUsed + resultRowHeightScale
			totalSent += 1
		end

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
			totalSent = totalSent + 1
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

			addPlayerPastResultRow(frame, totalSent, runEntry, useColor)
			frameYUsed = frameYUsed + playerRowHeight
		end

		if options.personalRaceHistoryText ~= "" then
			addRow(options.personalRaceHistoryText, frame, 0.04, string.format("%02d", totalSent), colors.meColor)
			frameYUsed = frameYUsed + 0.04
			totalSent += 1
		end

		if options.raceTotalHistoryText ~= "" then
			addRow(options.raceTotalHistoryText, frame, 0.04, string.format("%02d", totalSent))
			frameYUsed = frameYUsed + 0.04
			totalSent += 1
		end

		local signName = enums.signId2name[options.startSignId]
		local warpRow: Frame = nil
		if signName ~= nil then
			local bad = false
			for ii, badname in ipairs(enums.ExcludeSignNamesFromStartingAt) do
				if badname == signName then
					bad = true
					break
				end
			end
			if not bad then
				--we will display a button to warp back to startId

				local warpRowName = string.format("%02d Warp", totalSent)
				warpRow = addRow("Warp back to " .. signName, frame, 0.09, warpRowName, colors.lightBlue)
				local invisibleTextButton = Instance.new("TextButton")
				invisibleTextButton.Position = warpRow.Position
				invisibleTextButton.Size = UDim2.new(1, 0, 1, 0)
				invisibleTextButton.Transparency = 1.0
				invisibleTextButton.Text = "warp"
				invisibleTextButton.TextScaled = true
				invisibleTextButton.Parent = warpRow
				invisibleTextButton.Activated:Connect(function()
					warperWrapper.requestWarpToSign(options.startSignId)
				end)

				frameYUsed = frameYUsed + 0.09
				totalSent += 1
			end
		end

		frame.Parent = raceResultSgui

		--scale outer frame
		local globalYScaleToUse = math.min(defaultOuterFrameSize, frameYUsed)

		frame.Size = UDim2.new(0.27, 0, globalYScaleToUse, 0)

		--scale internal items so they take up 1.0
		local ratio = 1 / frameYUsed
		--if total yscale isn't used, expand them.  this is independent of size of the popup scaling.
		local childFrames = frame:GetChildren()
		for _, innerframe in ipairs(childFrames) do
			if not innerframe:IsA("Frame") then
				continue
			end
			local iff = innerframe :: Frame
			iff.Size = UDim2.new(iff.Size.X.Scale, 0, iff.Size.Y.Scale * ratio, 0)
		end

		guiUtil.setupKillOnClick(raceResultSgui, nil, warpRow)

		return raceResultSgui
	end

return module
