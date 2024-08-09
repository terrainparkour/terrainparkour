--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local colors = require(game.ReplicatedStorage.util.colors)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local tt = require(game.ReplicatedStorage.types.gametypes)
local gt = require(game.ReplicatedStorage.gui.guiTypes)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local settings = require(game.ReplicatedStorage.settings)
local settingSort = require(game.ReplicatedStorage.settingSort)

local PlayersService = game:GetService("Players")

local module = {}

local function makeRowFrame(setting: tt.userSettingValue, player: Player, n: number): Frame
	local fr = Instance.new("Frame")
	fr.Name = string.format("33-%04d", n) .. "setting." .. setting.name
	fr.Size = UDim2.new(1, 0, 0, 30)
	local vv = Instance.new("UIListLayout")
	vv.FillDirection = Enum.FillDirection.Horizontal
	vv.SortOrder = Enum.SortOrder.Name
	vv.Parent = fr
	local domainTl = guiUtil.getTl("0", UDim2.new(0.22, 0, 1, 0), 4, fr, colors.defaultGrey, 1)
	domainTl.TextScaled = false
	domainTl.Text = setting.domain
	domainTl.FontSize = Enum.FontSize.Size18
	domainTl.TextXAlignment = Enum.TextXAlignment.Center
	domainTl.TextYAlignment = Enum.TextYAlignment.Center

	local nameTl = guiUtil.getTl("1", UDim2.new(0.52, 0, 1, 0), 4, fr, colors.defaultGrey, 1)
	nameTl.Text = setting.name
	nameTl.TextXAlignment = Enum.TextXAlignment.Left
	local usecolor: Color3
	if setting.value then
		usecolor = colors.greenGo
	else
		usecolor = colors.redStop
	end
	local toggleButton = guiUtil.getTb("SettingToggle" .. setting.name, UDim2.new(0.26, 0, 1, 0), 0, fr, usecolor, 1)
	if setting.value then
		toggleButton.Text = "Yes"
	else
		toggleButton.Text = "No"
	end
	--just get marathon settings.

	local settings = require(game.ReplicatedStorage.settings)
	toggleButton.Activated:Connect(function()
		if toggleButton.Text == "No" then
			toggleButton.Text = "Yes"
			toggleButton.BackgroundColor3 = colors.greenGo
			local par = toggleButton.Parent :: TextLabel
			par.BackgroundColor3 = colors.greenGo
			setting.value = true
			settings.setSetting(setting)
		else
			toggleButton.Text = "No"
			toggleButton.BackgroundColor3 = colors.redStop
			local par = toggleButton.Parent :: TextLabel
			par.BackgroundColor3 = colors.redStop
			setting.value = false
			settings.setSetting(setting)
		end
	end)

	return fr
end

--we already have clientside stuff whic hgets initial settings value.
local getUserSettingsModal = function(localPlayer: Player): ScreenGui
	local userId = localPlayer.UserId
	local screenGui = Instance.new("ScreenGui")
	screenGui.IgnoreGuiInset = true
	screenGui.Name = "SettingsSgui"

	--just get marathon settings.
	local userSettings: { [string]: tt.userSettingValue } =
		settings.getSettingByDomain(settingEnums.settingDomains.USERSETTINGS)

	local outerFrame = Instance.new("Frame")
	outerFrame.Parent = screenGui
	outerFrame.Size = UDim2.new(0.4, 0, 0.5, 0)
	outerFrame.Position = UDim2.new(0.3, 0, 0.3, 0)
	local vv = Instance.new("UIListLayout")
	vv.FillDirection = Enum.FillDirection.Vertical
	vv.Parent = outerFrame
	vv.Name = "getrUserSettingsModal-vv"

	local headerFrame = Instance.new("Frame")
	headerFrame.Parent = outerFrame
	headerFrame.Name = "01.Settings.Header"
	headerFrame.Size = UDim2.new(1, 0, 0, 45)
	local hh = Instance.new("UIListLayout")
	hh.FillDirection = Enum.FillDirection.Horizontal
	hh.Parent = headerFrame
	hh.Name = "SettingsModalHeaderHH"
	local typeTl = guiUtil.getTl("1", UDim2.new(0.22, 0, 1, 0), 4, headerFrame, colors.blueDone, 1)
	typeTl.Text = "Domain"

	local nameTl = guiUtil.getTl("2", UDim2.new(0.52, 0, 1, 0), 4, headerFrame, colors.blueDone, 1)
	nameTl.Text = "Name"

	local valueTl = guiUtil.getTl("3", UDim2.new(0.26, 0, 1, 0), 4, headerFrame, colors.blueDone, 1)
	valueTl.Text = "Value"

	--scrolling setting frame
	local frameName = "SettingsModal"
	local scrollingFrame = Instance.new("ScrollingFrame")
	scrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollingFrame.ScrollBarThickness = 10
	scrollingFrame.Name = frameName
	scrollingFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	scrollingFrame.Parent = outerFrame
	scrollingFrame.Size = UDim2.new(1, 0, 1, -60)
	scrollingFrame.VerticalScrollBarInset = Enum.ScrollBarInset.Always
	scrollingFrame.CanvasSize = UDim2.new(1, 0, 1, 0)
	local vv = Instance.new("UIListLayout")
	vv.FillDirection = Enum.FillDirection.Vertical
	vv.Parent = scrollingFrame

	local player: Player = PlayersService:GetPlayerByUserId(userId)
	local ii = 0
	local settings = {}
	for _, setting in pairs(userSettings) do
		table.insert(settings, setting)
	end
	table.sort(settings, settingSort.SettingSort)

	for _, setting in pairs(settings) do
		ii += 1
		local rowFrame = makeRowFrame(setting, player, ii)
		rowFrame.Parent = scrollingFrame
	end

	local tb = guiUtil.getTbSimple()
	tb.Text = "Close"
	tb.Name = "ZZZMarathonSettingsCloseButton"
	tb.Size = UDim2.new(1, 0, 0, 40)
	tb.BackgroundColor3 = colors.redStop
	tb.Parent = outerFrame
	tb.Activated:Connect(function()
		screenGui:Destroy()
	end)
	return screenGui
end

local userSettingsButton: gt.button = {
	name = "Settings",
	contentsGetter = getUserSettingsModal,
}

module.userSettingsButton = userSettingsButton

_annotate("end")
return module
