--!strict

--eval 9.21

local module = {}

--player localscripts call this to generate a raceresult UI.

local colors = require(game.ReplicatedStorage.util.colors)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local thumbnails = require(game.ReplicatedStorage.thumbnails)
local tt = require(game.ReplicatedStorage.types.gametypes)

local function addRow(
	text: string,
	parent,
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
		if bgcolor == nil then
			bgcolor = colors.defaultGrey
		end
		assert(bgcolor)
		local tl = guiUtil.getTl("01" .. text, UDim2.new(width, 0, 1, 0), 2, frame, bgcolor, 1)
		tl.Text = text
		if textColor ~= nil then
			tl.TextColor3 = textColor
		end
		tl.TextXAlignment = Enum.TextXAlignment.Left
	end
	return frame
end

module.createFindScreenGui = function(options: tt.signFindOptions): ScreenGui
	local newFindSgui: ScreenGui = Instance.new("ScreenGui")
	newFindSgui.Name = "NewFindSgui"

	local detailsMessage = tostring(options.userTotalFindCount) .. "/" .. tostring(options.totalSignsInGame)
	local finderMessage = tpUtil.getCardinal(options.signTotalFinds) .. " finder!"

	local frame = Instance.new("Frame")
	frame.Parent = newFindSgui
	local findScreenGuiName = "FindScreenGui"
	frame.Name = findScreenGuiName
	frame.Size = UDim2.new(0.15, 0, 0.27, 0)
	frame.Position = UDim2.new(0.02, 0, 0.52, 0)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Name = "UIListLayoutV"
	layout.Parent = frame

	local details = addRow("You found a sign!", frame, 0.08, "01", colors.meColor)
	local ttl = details:FindFirstChildOfClass("TextLabel")
	if ttl ~= nil then
		ttl.TextXAlignment = Enum.TextXAlignment.Left
	end

	--sign chunk
	addRow(options.signName, frame, 0.25, "02", colors.signColor, nil, colors.signTextColor)

	--two-panel lower th
	local finderHFrame = Instance.new("Frame")
	finderHFrame.Parent = frame
	finderHFrame.Name = "03Details"
	local layout2 = Instance.new("UIListLayout")
	layout2.FillDirection = Enum.FillDirection.Horizontal
	layout2.Name = "UIListLayoutH"
	layout2.Parent = finderHFrame

	finderHFrame.Size = UDim2.new(1, 0, 0.10, 0)

	--you found X
	local tl = guiUtil.getTl("01" .. detailsMessage, UDim2.new(0.3, 0, 1, 0), 2, finderHFrame, colors.meColor, 1)
	tl.Text = detailsMessage
	tl.TextXAlignment = Enum.TextXAlignment.Center

	--other finders of this sign
	local tl2 = guiUtil.getTl("02" .. finderMessage, UDim2.new(0.7, 0, 1, 0), 2, finderHFrame, colors.meColor, 1)
	tl2.Text = finderMessage
	tl2.TextXAlignment = Enum.TextXAlignment.Center

	--other finders of this sign
	local descTl = guiUtil.getTl("03lastfound", UDim2.new(1, 0, 0.10, 0), 2, frame, colors.meColor, 1)
	descTl.Text = string.format("Last found by " .. options.lastFinderUsername)
	descTl.TextXAlignment = Enum.TextXAlignment.Center

	if options.lastFinderUserId and options.lastFinderUserId ~= 0 and options.lastFinderUserId ~= "0" then
		--other finders of this sign
		local portraitRow = Instance.new("Frame")
		portraitRow.Parent = frame
		portraitRow.Name = "FindPortraitRow"
		portraitRow.Size = UDim2.new(1, 0, 0.47, 0)
		local av = Instance.new("ImageLabel")
		av.BorderMode = Enum.BorderMode.Inset
		av.Size = UDim2.new(1, 0, 1, 0)
		if options.lastFinderUserId < 0 then
			--default to shed, for some reason doesn't work tho.
			options.lastFinderUserId = 261
		end
		local content = thumbnails.getThumbnailContent(options.lastFinderUserId, Enum.ThumbnailType.HeadShot)
		av.Image = content
		av.BackgroundColor3 = colors.grey
		av.Parent = portraitRow
	end

	guiUtil.setupKillOnClick(newFindSgui, nil)
	return newFindSgui
end

return module
