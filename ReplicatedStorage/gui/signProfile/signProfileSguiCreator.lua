--!strict

-- signProfileSguiCreator
-- 2022.03 pulled out commands from channel definitions

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local module = {}

local thumbnails = require(game.ReplicatedStorage.thumbnails)

local tt = require(game.ReplicatedStorage.types.gametypes)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local colors = require(game.ReplicatedStorage.util.colors)
local signProfileComponents = require(game.ReplicatedStorage.gui.signProfile.signProfileRows)

local windowFunctions = require(game.StarterPlayer.StarterPlayerScripts.guis.windowFunctions)
--------------- FUNCTIONS -------------------------
module.CreateSignProfileSGui = function(localPlayer: Player, data: tt.playerSignProfileData)
	local signProfileSgui = Instance.new("ScreenGui")
	signProfileSgui.IgnoreGuiInset = true

	local signProfileSystemFrames =
		windowFunctions.SetupFrame("signProfile", true, true, false, true, UDim2.new(0, 200, 0, 200))

	local signProfileOuterFrame = signProfileSystemFrames.outerFrame
	local signStatusContentFrame = signProfileSystemFrames.contentFrame

	signProfileSgui.Name = "SignProfileSgui"
	signProfileSgui.Parent = localPlayer.PlayerGui

	signProfileOuterFrame.Parent = signProfileSgui
	signProfileOuterFrame.Size = UDim2.new(0.5, 0, 0.5, 0)
	signProfileOuterFrame.Position = UDim2.new(0.25, 0, 0.25, 0)

	local vv = Instance.new("UIListLayout")
	vv.Parent = signStatusContentFrame
	vv.FillDirection = Enum.FillDirection.Vertical

	local signProfileHeaderRow = Instance.new("Frame")
	signProfileHeaderRow.Parent = signStatusContentFrame
	signProfileHeaderRow.Name = "01_SignProfile-headerRow."
	signProfileHeaderRow.Size = UDim2.new(1, 0, 0, 90)
	local hh = Instance.new("UIListLayout")
	hh.Name = "02_SignProfile-headerRow-layout."
	hh.Parent = signProfileHeaderRow
	hh.FillDirection = Enum.FillDirection.Horizontal

	local bgcolor = colors.grey
	if data.userId == localPlayer.UserId then
		bgcolor = colors.meColor
	end

	local img = Instance.new("ImageLabel")
	img.Size = UDim2.new(0.2, 0, 1, 0)
	local content =
		thumbnails.getThumbnailContent(data.userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
	img.Image = content
	img.BackgroundColor3 = bgcolor
	img.Name = "01_SignProfile-headerRow-thumbnail."
	img.Parent = signProfileHeaderRow
	img.BorderMode = Enum.BorderMode.Outline
	img.BackgroundTransparency = 0
	img.BorderSizePixel = 1

	local title = guiUtil.getTl(
		"02.Description" .. data.signName,
		UDim2.new(0.4, 0, 1, 0),
		2,
		signProfileHeaderRow,
		colors.blueDone,
		1,
		0
	)
	title.Text = string.format("%s's Sign Profile for: ", data.username)

	local signLabel = guiUtil.getTl(
		"03.SignName" .. data.signName,
		UDim2.new(0.4, 0, 1, 0),
		2,
		signProfileHeaderRow,
		colors.signColor,
		1,
		0
	)
	signLabel.TextColor3 = colors.white
	signLabel.Text = string.format("%s", data.signName)

	local signProfileContentFrame = Instance.new("Frame")
	signProfileContentFrame.Size = UDim2.new(1, 0, 1, -130)
	signProfileContentFrame.Parent = signStatusContentFrame
	signProfileContentFrame.Name = "02_SignProfile-contentFrame." .. data.signName

	local hh2 = Instance.new("UIListLayout")
	hh2.Parent = signProfileContentFrame
	hh2.FillDirection = Enum.FillDirection.Vertical

	--content rows
	local rowCount = #signProfileComponents.RowGenerators
	local height = 1 / rowCount
	for n, rowGenerator: (tt.playerSignProfileData) -> { TextLabel | TextButton } in
		ipairs(signProfileComponents.RowGenerators)
	do
		local thisRow = Instance.new("Frame")
		thisRow.Name = string.format("%02d-chiprow", n)
		thisRow.Parent = signProfileContentFrame
		thisRow.Size = UDim2.new(1, 0, height, 0)
		thisRow.BackgroundColor3 = colors.defaultGrey
		thisRow.BorderMode = Enum.BorderMode.Inset
		thisRow.BorderSizePixel = 1
		thisRow.Name = string.format("%02d-chiprow", n)
		local hh3 = Instance.new("UIListLayout")
		hh3.Parent = thisRow
		hh3.Name = "signProfileDataRow-hh" .. tostring(n)
		hh3.FillDirection = Enum.FillDirection.Horizontal
		local labels: { TextLabel | TextButton } = rowGenerator(data)
		for _, label in ipairs(labels) do
			label.Parent = thisRow
		end
	end

	-------close button
	local tb = guiUtil.getTb("ZZZCloseButton", UDim2.new(1, 0, 0, 40), 2, signStatusContentFrame, colors.redStop, 1, 0)
	tb.Text = "Close"
	tb.Activated:Connect(function()
		signProfileSgui:Destroy()
	end)
end

_annotate("end")
return module
