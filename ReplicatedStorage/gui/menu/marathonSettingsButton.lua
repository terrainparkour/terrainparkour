--!strict

--eval 9.24.22

local colors = require(game.ReplicatedStorage.util.colors)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local tt = require(game.ReplicatedStorage.types.gametypes)
local gt = require(game.ReplicatedStorage.gui.guiTypes)
local rf = require(game.ReplicatedStorage.util.remotes)

local PlayersService = game:GetService("Players")

local module = {}
local userSettingsChangedFunction = rf.getRemoteFunction("UserSettingsChangedFunction") :: RemoteFunction

local function makeSettingRowFrame(setting: tt.userSettingValue, player: Player, n: number): Frame
	local fr = Instance.new("Frame")
	fr.Name = string.format("33-%04d", n) .. "setting." .. setting.name
	fr.Size = UDim2.new(1, 0, 0, 30)
	local vv = Instance.new("UIListLayout")
	vv.FillDirection = Enum.FillDirection.Horizontal
	vv.SortOrder = Enum.SortOrder.Name
	vv.Parent = fr
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

	local localFunctions = require(game.ReplicatedStorage.localFunctions)
	toggleButton.Activated:Connect(function()
		if toggleButton.Text == "No" then
			toggleButton.Text = "Yes"
			toggleButton.BackgroundColor3 = colors.greenGo
			local par = toggleButton.Parent :: TextLabel
			par.BackgroundColor3 = colors.greenGo
			setting.value = true
			localFunctions.notifySettingChange(player, setting)
			userSettingsChangedFunction:InvokeServer(setting)
		else
			toggleButton.Text = "No"
			toggleButton.BackgroundColor3 = colors.redStop
			local par = toggleButton.Parent :: TextLabel
			par.BackgroundColor3 = colors.redStop
			setting.value = false
			localFunctions.notifySettingChange(player, setting)
			userSettingsChangedFunction:InvokeServer(setting)
		end
	end)

	return fr
end

--we already have clientside stuff whic hgets initial settings value.
local getSettingsModal = function(localPlayer: Player): ScreenGui
	local userId = localPlayer.UserId
	local sg = Instance.new("ScreenGui")
	sg.Name = "SettingsSgui"

	local userSettingsFunction: RemoteFunction = rf.getRemoteFunction("GetUserSettingsFunction")
	local userSettings: { tt.userSettingValue } = userSettingsFunction:InvokeServer("Marathon")

	local outerFrame = Instance.new("Frame")
	outerFrame.Parent = sg
	outerFrame.Size = UDim2.new(0.4, 0, 0.5, 0)
	outerFrame.Position = UDim2.new(0.3, 0, 0.3, 0)
	local vv2 = Instance.new("UIListLayout")
	vv2.FillDirection = Enum.FillDirection.Vertical
	vv2.Parent = outerFrame

	local headerFrame = Instance.new("Frame")
	headerFrame.Parent = outerFrame
	headerFrame.Name = "1"
	headerFrame.Size = UDim2.new(1, 0, 0, 20)
	local vv = Instance.new("UIListLayout")
	vv.FillDirection = Enum.FillDirection.Horizontal
	vv.Parent = headerFrame
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
	vv.FillDirection = Enum.FillDirection.Vertical
	vv.Parent = scrollingFrame

	local player: Player = PlayersService:GetPlayerByUserId(userId)
	for ii, setting in ipairs(userSettings) do
		if setting.domain ~= "Marathons" then
			continue
		end
		local rowFrame = makeSettingRowFrame(setting, player, ii)
		rowFrame.Parent = scrollingFrame
	end

	local tb = guiUtil.getTbSimple()
	tb.Text = "Close"
	tb.Name = "ZZZMarathonSettingsCloseButton"
	tb.Size = UDim2.new(1, 0, 0, 40)
	tb.BackgroundColor3 = colors.redStop
	tb.Parent = outerFrame
	tb.Activated:Connect(function()
		sg:Destroy()
	end)
	return sg
end

local marathonSettingsButton: gt.actionButton = {
	name = "Marathon Settings",
	contentsGetter = getSettingsModal,
	hoverHint = "Configure Marathons",
	shortName = "+ Marathon",
	getActive = function()
		return true
	end,
}

module.marathonSettingsButton = marathonSettingsButton

return module
