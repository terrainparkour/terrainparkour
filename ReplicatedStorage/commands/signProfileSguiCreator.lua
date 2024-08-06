--!strict

--2022.03 pulled out commands from channel definitions

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local module = {}

local thumbnails = require(game.ReplicatedStorage.thumbnails)
local toolTip = require(game.ReplicatedStorage.gui.toolTip)
local tt = require(game.ReplicatedStorage.types.gametypes)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local colors = require(game.ReplicatedStorage.util.colors)
local signProfileComponents = require(game.ReplicatedStorage.commands.signProfileComponents)
local textUtil = require(game.ReplicatedStorage.util.textUtil)

----------------- GLOBALS -------------------------
--just leave this here so that tooltips can hang off the bottom FFS
local globalFrame: Frame? = nil

local function makeChip(ii: number, chipspec: tt.chipType, parent: Frame, width: number)
	local useWidth = width
	if chipspec.widthWeight then
		useWidth = width * chipspec.widthWeight
	end

	local useColor = chipspec.bgcolor or colors.defaultGrey

	local chip = guiUtil.getTl(string.format("%02d-chip.", ii), UDim2.new(useWidth, 0, 1, 0), 2, parent, useColor, 1, 0)
	if chipspec.toolTip and chipspec.toolTip ~= "" then
		local dividedTooltip = {}
		for _, line in ipairs(textUtil.stringSplit(chipspec.toolTip, ",")) do
			table.insert(dividedTooltip, line)
		end
		-- local len = math.max(#chipspec.toolTip * 2, 30)
		toolTip.setupToolTip(
			chip,
			dividedTooltip,
			UDim2.new(0.75, 0, 0.155, 0),
			true,
			Enum.TextXAlignment.Left,
			true,
			globalFrame
		)
	end

	chip.Text = chipspec.text
end

local function getWeights(chipspecs: { tt.chipType })
	local tot = 0
	for _, cs in ipairs(chipspecs) do
		if cs.widthWeight ~= nil then
			tot += cs.widthWeight
			continue
		end
		tot += 1
	end
	return tot
end

local function addRow(chipspecs: { tt.chipType }, parent: Frame, height: number, n)
	local f = Instance.new("Frame")
	f.Parent = parent
	f.Size = UDim2.new(1, 0, height, 0)
	f.Name = string.format("%02d-chiprow", n)
	local hh = Instance.new("UIListLayout")
	hh.Parent = f
	hh.FillDirection = Enum.FillDirection.Horizontal
	local width = 1 / getWeights(chipspecs)
	for ii, chipspec in ipairs(chipspecs) do
		makeChip(ii, chipspec, f, width)
	end
end

type rowDescriptor = (tt.playerSignProfileData) -> { tt.chipType }

module.createSgui = function(localPlayer: Player, data: tt.playerSignProfileData)
	local sg = Instance.new("ScreenGui")

	sg.Name = "SignStatusSgui"
	sg.Parent = localPlayer.PlayerGui

	local fr = Instance.new("Frame")
	fr.Parent = sg
	local w, h = 0.5, 0.5
	fr.Size = UDim2.new(w, 0, h, 0)
	fr.Position = UDim2.new(w / 2, 0, h / 2, 0)
	fr.Name = "SignStatusUIFrame"
	globalFrame = fr
	local vv = Instance.new("UIListLayout")
	vv.Parent = fr
	vv.FillDirection = Enum.FillDirection.Vertical

	local hframe = Instance.new("Frame")
	hframe.Parent = fr
	hframe.Name = "01SignProfile-header-row."
	hframe.Size = UDim2.new(1, 0, 0, 120)
	local hh = Instance.new("UIListLayout")
	hh.Parent = hframe
	hh.FillDirection = Enum.FillDirection.Horizontal

	local bgcolor = colors.grey
	if data.userId == localPlayer.UserId then
		bgcolor = colors.meColor
	end

	local img = Instance.new("ImageLabel")
	img.Size = UDim2.new(0.1, 0, 1, 0)
	local content = thumbnails.getThumbnailContent(data.userId, Enum.ThumbnailType.HeadShot)
	img.Image = content
	img.BackgroundColor3 = bgcolor
	img.Name = "01.thumbnail."
	img.Parent = hframe
	img.BorderMode = Enum.BorderMode.Outline
	-- img.BorderSizePixel=1
	img.BackgroundTransparency = 0
	img.BorderSizePixel = 1

	local title = guiUtil.getTl("02.SignProfile.Title", UDim2.new(0.4, 0, 1, 0), 2, hframe, colors.blueDone, 1, 0)
	title.Text = string.format("%s's Sign Profile for: ", data.username)

	local signLabel = guiUtil.getTl("03.SignProfile.Title", UDim2.new(0.5, 0, 1, 0), 2, hframe, colors.signColor, 1, 0)
	signLabel.TextColor3 = colors.white
	signLabel.Text = string.format("%s", data.signName)

	local innerFrame = Instance.new("Frame")
	innerFrame.Size = UDim2.new(1, 0, 1, -80)
	innerFrame.Parent = fr
	innerFrame.Name = "02-signprofile-innerframe."

	local hh2 = Instance.new("UIListLayout")
	hh2.Parent = innerFrame
	hh2.FillDirection = Enum.FillDirection.Vertical

	--content rows
	local rowCount = #signProfileComponents.rowGenerators
	local height = 1 / rowCount
	for n, rowGenerator in ipairs(signProfileComponents.rowGenerators) do
		local chipSpecs = rowGenerator(data)
		addRow(chipSpecs, innerFrame, height, n + 1)
	end

	-------close button
	local tb = guiUtil.getTb("ZZZCloseButton", UDim2.new(1, 0, 0, 40), 2, fr, colors.redStop, 1, 0)
	tb.Text = "Close"
	tb.Activated:Connect(function()
		toolTip.KillFinalTooltip()
		sg:Destroy()
	end)
end

_annotate("end")
return module
