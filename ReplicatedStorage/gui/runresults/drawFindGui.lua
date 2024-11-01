--!strict

-- Player localscripts call this to generate a raceresult UI.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local module = {}

local colors = require(game.ReplicatedStorage.util.colors)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local tt = require(game.ReplicatedStorage.types.gametypes)
local windows = require(game.StarterPlayer.StarterPlayerScripts.guis.windows)
local wt = require(game.StarterPlayer.StarterPlayerScripts.guis.windowsTypes)

module.CreateFindScreenGui = function(options: tt.dcFindResponse): ScreenGui
	local detailsMessage =
		string.format("You've found %d out of %d signs!", options.userFindCount, options.totalSignsInGame)
	local finderMessage =
		string.format("You are the %s finder of %s!", tpUtil.getCardinalEmoji(options.signTotalFinds), options.signName)

	local daysAgo = math.floor(options.lastFindAgoSeconds / 86400)
	local hoursAgo = math.floor((options.lastFindAgoSeconds - (daysAgo * 86400)) / 3600)
	local minutesAgo = math.floor((options.lastFindAgoSeconds - (daysAgo * 86400) - (hoursAgo * 3600)) / 60)
	local secondsAgo =
		math.floor(options.lastFindAgoSeconds - (daysAgo * 86400) - (hoursAgo * 3600) - (minutesAgo * 60))
	local lastFoundText = string.format(
		"Last found by %s, %d days, %d hours, %d minutes, and %d seconds ago.",
		options.lastFinderUsername,
		daysAgo,
		hoursAgo,
		minutesAgo,
		secondsAgo
	)

	local guiSpec: wt.guiSpec = {
		name = "FindScreenGui",
		rowSpecs = {
			{
				name = "TitleRow",
				order = 1,
				height = UDim.new(0, 40),
				tileSpecs = {
					{
						name = "Title",
						order = 1,
						width = UDim.new(1, 0),
						spec = {
							type = "text",
							text = "You found a sign!",
							isMonospaced = false,
							isBold = false,
							textColor = colors.black,
							backgroundColor = colors.meColor,
							textXAlignment = Enum.TextXAlignment.Center,
							includeTextSizeConstraint = false,
						},
					},
				},
			},
			{
				name = "SignNameRow",
				order = 2,
				height = UDim.new(0, 75),
				tileSpecs = {
					{
						name = "SignName",
						order = 1,
						width = UDim.new(1, 0),
						spec = {
							type = "text",
							text = options.signName,
							isMonospaced = false,
							isBold = true,
							backgroundColor = colors.signColor,
							textColor = colors.white,
							textXAlignment = Enum.TextXAlignment.Center,
							includeTextSizeConstraint = false,
						},
					},
				},
			},
			{
				name = "DetailsRow",
				order = 3,
				height = UDim.new(0, 40),
				tileSpecs = {
					{
						name = "FindCount",
						order = 1,
						width = UDim.new(0.5, 0),
						spec = {
							type = "text",
							text = detailsMessage,
							isMonospaced = false,
							isBold = false,
							backgroundColor = colors.meColor,
							textColor = colors.black,
							textXAlignment = Enum.TextXAlignment.Center,
						},
					},
					{
						name = "FinderMessage",
						order = 2,
						width = UDim.new(0.5, 0),
						spec = {
							type = "text",
							text = finderMessage,
							isMonospaced = false,
							isBold = false,
							backgroundColor = colors.meColor,
							textColor = colors.black,
							textXAlignment = Enum.TextXAlignment.Center,
						},
					},
				},
			},
			{
				name = "LastFoundRow",
				order = 4,
				height = UDim.new(0, 40),
				tileSpecs = {
					{
						name = "LastFound",
						order = 1,
						width = UDim.new(1, 0),
						spec = {
							type = "text",
							text = lastFoundText,
							isMonospaced = false,
							isBold = false,
							backgroundColor = colors.defaultGrey,
							textColor = colors.black,
							textXAlignment = Enum.TextXAlignment.Center,
						},
					},
				},
			},
		},
	}

	if options.lastFinderUserId and options.lastFinderUserId ~= 0 then
		local portraitTileSpec: wt.portraitTileSpec = {
			type = "portrait",
			userId = options.lastFinderUserId < 0 and 261 or options.lastFinderUserId,
			doPopup = false,
			width = UDim.new(1, 0),
			backgroundColor = colors.grey,
		}
		local portraitRow: wt.rowSpec = {
			name = "PortraitRow",
			order = 5,
			height = UDim.new(0, 200),
			tileSpecs = {
				{
					name = "Portrait",
					order = 1,
					width = UDim.new(1, 0),
					spec = portraitTileSpec,
				},
			},
		}
		table.insert(guiSpec.rowSpecs, portraitRow)
	end

	local closeRow: wt.rowSpec = {
		name = "CloseRow",
		order = 6,
		height = UDim.new(0, 30),
		tileSpecs = { windows.StandardCloseButton },
		horizontalAlignment = Enum.HorizontalAlignment.Right,
	}
	table.insert(guiSpec.rowSpecs, closeRow)

	local popupName = string.format("NewFindSgui_%s", options.signName)
	local newFindSgui =
		windows.CreatePopup(guiSpec, popupName, false, false, false, false, true, true, UDim2.new(0.15, 0, 0, 336))

	local outerFrame = newFindSgui:FindFirstChildOfClass("Frame")
	if outerFrame then
		outerFrame.Position = UDim2.new(0.02, 0, 0.52, 0)
	end

	local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	newFindSgui.Parent = playerGui

	return newFindSgui
end

_annotate("end")

return module
