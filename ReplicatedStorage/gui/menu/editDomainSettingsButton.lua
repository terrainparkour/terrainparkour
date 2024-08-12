--!strict

-- generic setting editor for all settings in a DOMAIN.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local settings = require(game.ReplicatedStorage.settings)
local colors = require(game.ReplicatedStorage.util.colors)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local tt = require(game.ReplicatedStorage.types.gametypes)
local gt = require(game.ReplicatedStorage.gui.guiTypes)

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
	-- local label = guiUtil.getTl("0", UDim2.new(0.3, 0, 1, 0), 4, fr, colors.defaultGrey, 1)
	-- label.TextScaled = true
	-- label.Text = setting.domain
	-- label.FontSize = Enum.FontSize.Size18
	-- label.TextXAlignment = Enum.TextXAlignment.Center
	-- label.TextYAlignment = Enum.TextYAlignment.Center

	local tl = guiUtil.getTl("1", UDim2.new(0.75, 0, 1, 0), 4, fr, colors.defaultGrey, 1)
	tl.Text = setting.name
	tl.TextXAlignment = Enum.TextXAlignment.Left
	local usecolor: Color3
	if setting.value then
		usecolor = colors.greenGo
	else
		usecolor = colors.redStop
	end
	local toggleButton = guiUtil.getTb("SettingToggle" .. setting.name, UDim2.new(0.25, 0, 1, 0), 0, fr, usecolor)
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

-- a generic thing which makes a general settinsg editor with title and stuff.
local getGenericSettingsEditor = function(domain: string, localPlayer: Player): ScreenGui
	local userId = localPlayer.UserId
	local screenGui = Instance.new("ScreenGui")
	screenGui.IgnoreGuiInset = true
	screenGui.Name = domain .. "SettingEditorSGui"

	local userSettings: { [string]: tt.userSettingValue } = settings.getSettingByDomain(domain)

	local theSettingsToDisplay = {}
	for _, setting in pairs(userSettings) do
		table.insert(theSettingsToDisplay, setting)
	end
	table.sort(theSettingsToDisplay, settingSort.SettingSort)

	local outerFrame = Instance.new("Frame")
	outerFrame.Parent = screenGui
	outerFrame.Size = UDim2.new(0.4, 0, 0.5, 0)
	outerFrame.Position = UDim2.new(0.3, 0, 0.3, 0)
	outerFrame.Name = domain .. "_OuterFrame_"
	local vv = Instance.new("UIListLayout")
	vv.Name = "SettingsModalVV" .. domain
	vv.FillDirection = Enum.FillDirection.Vertical
	vv.SortOrder = Enum.SortOrder.Name
	vv.Parent = outerFrame

	local titleFrame = Instance.new("Frame")
	titleFrame.Parent = outerFrame
	titleFrame.Size = UDim2.new(1, 0, 0, 45)
	titleFrame.Name = "00_Title_" .. domain
	local tl = guiUtil.getTl("0", UDim2.new(1, 0, 0, 45), 2, titleFrame, colors.blueDone, 1)
	tl.Text = domain .. " Settings"

	local headerFrame = Instance.new("Frame")
	headerFrame.Parent = outerFrame
	headerFrame.Name = "01_header_" .. domain
	headerFrame.Size = UDim2.new(1, 0, 0, 20)

	local hh = Instance.new("UIListLayout")
	hh.FillDirection = Enum.FillDirection.Horizontal
	hh.SortOrder = Enum.SortOrder.Name
	hh.Parent = headerFrame
	hh.Name = domain .. "SettingsModalHeaderHH"
	-- local tl = guiUtil.getTl("1", UDim2.new(0.2, 0, 0, 20), 4, headerFrame, colors.blueDone, 1)
	-- tl.Text = "Type"

	local tl = guiUtil.getTl("2", UDim2.new(0.75, 0, 0, 20), 4, headerFrame, colors.blueDone, 1)
	tl.Text = "Name"

	local tl2 = guiUtil.getTl("3", UDim2.new(0.25, 0, 0, 20), 4, headerFrame, colors.blueDone, 1)
	tl2.Text = "Value"

	--scrolling setting frame
	local frameName = "03_" .. domain .. "_SettingsModal"
	local scrollingFrame = Instance.new("ScrollingFrame")
	scrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollingFrame.ScrollBarThickness = 10
	scrollingFrame.Name = frameName
	scrollingFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	scrollingFrame.Parent = outerFrame
	scrollingFrame.Size = UDim2.new(1, 0, 1, -95)
	scrollingFrame.VerticalScrollBarInset = Enum.ScrollBarInset.Always
	scrollingFrame.CanvasSize = UDim2.new(1, 0, 1, 0)
	local vv2 = Instance.new("UIListLayout")
	vv2.Name = "SettingsModalVV2"
	vv2.FillDirection = Enum.FillDirection.Vertical
	vv2.Parent = scrollingFrame

	local player: Player = PlayersService:GetPlayerByUserId(userId)
	local ii = 1
	for _, setting in pairs(theSettingsToDisplay) do
		local rowFrame = makeSettingRowFrame(setting, player, ii)
		rowFrame.Parent = scrollingFrame
		ii += 1
	end

	local tb = guiUtil.getTbSimple()
	tb.Text = "Close"
	tb.Name = "ZZZ_" .. domain .. "_SettingsCloseButton"
	tb.Size = UDim2.new(1, 0, 0, 30)
	tb.BackgroundColor3 = colors.redStop
	tb.Parent = outerFrame
	tb.Activated:Connect(function()
		screenGui:Destroy()
	end)
	return screenGui
end

local function innerMake(domain: string): gt.actionButton
	local innerContentsGetter = function(localPlayer: Player, userIds: { number }): ScreenGui
		return getGenericSettingsEditor(domain, localPlayer)
	end

	-- we prepare a getter for the settings we care about and give it to the guy who will be called
	-- to give the outer manager its buttons.

	local theSettingsButton: gt.actionButton = {
		name = domain .. " Settings",
		contentsGetter = innerContentsGetter,
		hoverHint = "Configure " .. domain,
		shortName = domain,
		getActive = function()
			return true
		end,
		widthXScale = 0.25,
	}
	return theSettingsButton
end

-- local getGenericSettingsEditor: (string) -> gt.actionButton = innerMake

module.getGenericSettingsEditor = innerMake

_annotate("end")
return module
