--!strict

-- marathonSettingsButton
-- the button that opens the marathon settings from the leaderboard.
-- ideally it'd auto-redraw the marathons but 2024 this seems not to be working.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local settings = require(game.ReplicatedStorage.settings)
local colors = require(game.ReplicatedStorage.util.colors)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local tt = require(game.ReplicatedStorage.types.gametypes)
local gt = require(game.ReplicatedStorage.gui.guiTypes)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local settingSort = require(game.ReplicatedStorage.settingSort)

local PlayersService = game:GetService("Players")

local module = {}

local function makeSettingRowFrame(setting: tt.userSettingValue, player: Player, n: number): Frame
	local fr = Instance.new("Frame")
	fr.Name = string.format("33-%04d", n) .. "setting." .. setting.name
	fr.Size = UDim2.new(1, 0, 0, 30)
	local hh = Instance.new("UIListLayout")
	hh.Name = "settingRowFrameHH"
	hh.FillDirection = Enum.FillDirection.Horizontal
	hh.SortOrder = Enum.SortOrder.Name
	hh.Parent = fr
	local label = guiUtil.getTl("0", UDim2.new(0.2, 0, 1, 0), 4, fr, colors.defaultGrey, 1)
	label.TextScaled = false
	label.Text = setting.domain
	label.FontSize = Enum.FontSize.Size18
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center

	local tl = guiUtil.getTl("1", UDim2.new(0.5, 0, 1, 0), 4, fr, colors.defaultGrey, 1)
	tl.Text = setting.name
	tl.TextXAlignment = Enum.TextXAlignment.Left
	local usecolor: Color3
	if setting.value then
		usecolor = colors.greenGo
	else
		usecolor = colors.redStop
	end
	local toggleButton = guiUtil.getTb("SettingToggle" .. setting.name, UDim2.new(0.3, 0, 1, 0), 0, fr, usecolor)
	if setting.value then
		toggleButton.Text = "Yes"
	else
		toggleButton.Text = "No"
	end

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

--we already have clientside stuff which gets initial settings value.
local getSettingsModal = function(localPlayer: Player): ScreenGui
	local userId = localPlayer.UserId
	local screenGui = Instance.new("ScreenGui")
	screenGui.IgnoreGuiInset = true
	screenGui.Name = "SettingsSgui"

	--just get marathon settings.
	local userSettings: { [string]: tt.userSettingValue } =
		settings.getSettingByDomain(settingEnums.settingDomains.MARATHONS)

	local settings = {}
	for _, setting in pairs(userSettings) do
		table.insert(settings, setting)
	end
	table.sort(settings, settingSort.SettingSort)

	local outerFrame = Instance.new("Frame")
	outerFrame.Parent = screenGui
	outerFrame.Size = UDim2.new(0.4, 0, 0.5, 0)
	outerFrame.Position = UDim2.new(0.3, 0, 0.3, 0)
	local vv = Instance.new("UIListLayout")
	vv.Name = "SettingsModalVV"
	vv.FillDirection = Enum.FillDirection.Vertical
	vv.Parent = outerFrame

	local headerFrame = Instance.new("Frame")
	headerFrame.Parent = outerFrame
	headerFrame.Name = "1"
	headerFrame.Size = UDim2.new(1, 0, 0, 20)
	local hh = Instance.new("UIListLayout")
	hh.FillDirection = Enum.FillDirection.Horizontal
	hh.Parent = headerFrame
	hh.Name = "SettingsModalHeaderHH"
	local tl = guiUtil.getTl("1", UDim2.new(0.2, 0, 0, 20), 4, headerFrame, colors.blueDone, 1)
	tl.Text = "Type"

	local tl = guiUtil.getTl("2", UDim2.new(0.5, 0, 0, 20), 4, headerFrame, colors.blueDone, 1)
	tl.Text = "Name"

	local tl = guiUtil.getTl("3", UDim2.new(0.3, 0, 0, 20), 4, headerFrame, colors.blueDone, 1)
	tl.Text = "Value"

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
	vv.Name = "SettingsModalVV2"
	vv.FillDirection = Enum.FillDirection.Vertical
	vv.Parent = scrollingFrame

	local player: Player = PlayersService:GetPlayerByUserId(userId)
	local ii = 1
	for _, setting in pairs(settings) do
		local rowFrame = makeSettingRowFrame(setting, player, ii)
		rowFrame.Parent = scrollingFrame
		ii += 1
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

local marathonSettingsButton: gt.actionButton = {
	name = "Marathon Settings",
	contentsGetter = getSettingsModal,
	hoverHint = "Configure Marathons",
	shortName = "Marathons",
	getActive = function()
		return true
	end,
	widthXScale = 0.25,
}

module.marathonSettingsButton = marathonSettingsButton

_annotate("end")
return module
