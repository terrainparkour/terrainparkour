--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local colors = require(game.ReplicatedStorage.util.colors)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local scrollingFrameUtils = require(game.ReplicatedStorage.gui.scrollingFrameUtils)
local tt = require(game.ReplicatedStorage.types.gametypes)
local gt = require(game.ReplicatedStorage.gui.guiTypes)

local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local settingSort = require(game.ReplicatedStorage.settingSort)
local settings = require(game.ReplicatedStorage.settings)

local PlayersService = game:GetService("Players")

local module = {}

local function makeSurveyRowFrame(setting: tt.userSettingValue, player: Player?, n: number): Frame
	local fr = Instance.new("Frame")
	fr.Name = string.format("33-settingRow-%04d", n) .. "setting." .. setting.name
	fr.Size = UDim2.new(1, 0, 0, 30)
	local vv = Instance.new("UIListLayout")
	vv.FillDirection = Enum.FillDirection.Horizontal
	vv.SortOrder = Enum.SortOrder.Name
	vv.Parent = fr
	local label = guiUtil.getTl("00-Domain", UDim2.new(0.2, 0, 1, 0), 4, fr, colors.defaultGrey, 1)
	label.TextScaled = false
	label.Text = setting.domain
	label.TextSize = 18
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center

	local tl = guiUtil.getTl("01-SettingName", UDim2.new(0.5, 0, 1, 0), 4, fr, colors.defaultGrey, 1)
	tl.Text = setting.name .. "?"
	tl.TextXAlignment = Enum.TextXAlignment.Left
	local noButton = guiUtil.getTb("02-No." .. setting.name, UDim2.new(0.1, -3, 1, 0), 2, fr, colors.defaultGrey, 1)
	noButton.Text = "No"

	local unsetButton =
		guiUtil.getTb("03-Unset-" .. setting.name, UDim2.new(0.1, -4, 1, 0), 2, fr, colors.defaultGrey, 1)
	unsetButton.Text = "-"
	local yesButton = guiUtil.getTb("04-Yes-" .. setting.name, UDim2.new(0.1, -3, 1, 0), 2, fr, colors.defaultGrey, 1)
	yesButton.Text = "Yes"
	local nowValue: boolean | nil = nil

	if setting.booleanValue == false then
		noButton.BackgroundColor3 = colors.redStop
		nowValue = false
	elseif setting.booleanValue == true then
		yesButton.BackgroundColor3 = colors.greenGo
		nowValue = true
	else
		nowValue = nil
	end

	noButton.Activated:Connect(function()
		if nowValue == false then
			nowValue = nil
			noButton.BackgroundColor3 = colors.defaultGrey
		elseif nowValue == nil or nowValue == true then
			nowValue = false
			noButton.BackgroundColor3 = colors.redStop
			yesButton.BackgroundColor3 = colors.defaultGrey
		end
		setting.booleanValue = nowValue
		settings.SetSetting(setting)
	end)

	unsetButton.Activated:Connect(function()
		if nowValue == false or nowValue == true then
			nowValue = nil
			noButton.BackgroundColor3 = colors.defaultGrey
			yesButton.BackgroundColor3 = colors.defaultGrey
			setting.booleanValue = nowValue
			settings.SetSetting(setting)
		end
	end)

	yesButton.Activated:Connect(function()
		if nowValue == false or nowValue == nil then
			nowValue = true
			noButton.BackgroundColor3 = colors.defaultGrey
			yesButton.BackgroundColor3 = colors.greenGo
		elseif nowValue == true then
			nowValue = nil
			noButton.BackgroundColor3 = colors.defaultGrey
			yesButton.BackgroundColor3 = colors.defaultGrey
		end
		setting.booleanValue = nowValue
		settings.SetSetting(setting)
	end)

	return fr
end

--we already have clientside stuff whic hgets initial settings value.
local getSurveyModal = function(localPlayer: Player): ScreenGui
	local userId = localPlayer.UserId
	local screenGui = Instance.new("ScreenGui")
	screenGui.IgnoreGuiInset = true
	screenGui.Name = "SettingsSgui"

	--just get marathon settings.
	local surveyData = settings.GetSettingByDomain(settingEnums.settingDomains.SURVEYS)

	local outerFrame = Instance.new("Frame")
	outerFrame.Parent = screenGui
	outerFrame.Size = UDim2.new(0.5, 0, 0.5, 0)
	outerFrame.Position = UDim2.new(0.25, 0, 0.3, 0)
	local vv2 = Instance.new("UIListLayout")
	vv2.FillDirection = Enum.FillDirection.Vertical
	vv2.Parent = outerFrame

	local headerFrameHeight = 40
	local headerFrame = Instance.new("Frame")
	headerFrame.Parent = outerFrame
	headerFrame.Name = "01SurveySettingsHeader"
	headerFrame.Size = UDim2.new(1, 0, 0, headerFrameHeight)
	local vv = Instance.new("UIListLayout")
	vv.FillDirection = Enum.FillDirection.Horizontal
	vv.Parent = headerFrame
	local tl = guiUtil.getTl("01Type", UDim2.new(0.20, 0, 1, 0), 2, headerFrame, colors.blueDone, 1)
	tl.Text = "Type"

	local tln = guiUtil.getTl("02Name", UDim2.new(0.5, 0, 1, 0), 2, headerFrame, colors.blueDone, 1)
	tln.Text = "Name"

	local tlv = guiUtil.getTl("03Value", UDim2.new(0.3, 0, 1, 0), 2, headerFrame, colors.blueDone, 1)
	tlv.Text = "Value"

	-- local tlp = guiUtil.getTl("04Others", UDim2.new(0.1, 0, 1, 0), 2, headerFrame, colors.blueDone, 1)
	-- tlp.Text = "Others?"

	--scrolling setting frame
	local frameName = "02SettingsModal"
	local scrollingFrame = Instance.new("ScrollingFrame")
	scrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollingFrame.ScrollBarThickness = 10
	scrollingFrame.Name = frameName
	scrollingFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	scrollingFrame.Parent = outerFrame
	scrollingFrame.Size = UDim2.new(1, 0, 1, -60)
	scrollingFrame.VerticalScrollBarInset = Enum.ScrollBarInset.Always
	scrollingFrame.CanvasSize = UDim2.new(1, 0, 1, 0)
	local vv3 = Instance.new("UIListLayout")
	vv3.FillDirection = Enum.FillDirection.Vertical
	vv3.Parent = scrollingFrame

	local player: Player? = PlayersService:GetPlayerByUserId(userId)
	if player == nil then
		player = localPlayer
	end
	local ii = 0

	local settingsHolder = {}
	for _, setting in pairs(surveyData) do
		table.insert(settingsHolder, setting)
	end
	table.sort(settingsHolder, settingSort.SettingSort)

	for _, setting in pairs(settingsHolder) do
		ii += 1
		if setting.domain ~= settingEnums.settingDomains.SURVEYS then
			continue
		end
		local rowFrame = makeSurveyRowFrame(setting, player, ii)
		rowFrame.Parent = scrollingFrame
	end

	local tb = guiUtil.getTbSimple()
	tb.Text = "Close"
	tb.Name = "03ZZZMarathonSettingsCloseButton"
	tb.Size = UDim2.new(1, 0, 0, 40)
	tb.BackgroundColor3 = colors.redStop
	tb.BorderSizePixel = 1
	tb.Parent = outerFrame
	tb.Activated:Connect(function()
		screenGui:Destroy()
	end)

	local publicNotice =
		guiUtil.getTl("02ZZZpublicWarning", UDim2.new(1, 0, 0, 40), 1, outerFrame, colors.defaultGrey, 1, 0)
	publicNotice.Text = "Your answers are public."
	
	-- Prevent camera scroll when hovering over survey scrolling frame
	scrollingFrameUtils.PreventCameraScrollOnHover(scrollingFrame)

	return screenGui
end

local surveySettingsButton: gt.button = {
	name = "Surveys",
	contentsGetter = getSurveyModal,
}

module.surveySettingsButton = surveySettingsButton

_annotate("end")
return module
