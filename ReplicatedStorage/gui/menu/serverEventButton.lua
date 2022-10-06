--!strict

--eval 9.24.22
local vscdebug = require(game.ReplicatedStorage.vscdebug)

local colors = require(game.ReplicatedStorage.util.colors)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local tt = require(game.ReplicatedStorage.types.gametypes)
local gt = require(game.ReplicatedStorage.gui.guiTypes)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local serverEventEnums = require(game.ReplicatedStorage.enums.serverEventEnums)
local remotes = require(game.ReplicatedStorage.util.remotes)

local PlayersService = game:GetService("Players")

local module = {}

--create server event, wait for ui to pop, then display a simple modal for success or failure.

--TODO make this into an ephemeral notification.
local CreateServerEventButtonClicked = function(localPlayer: Player): ScreenGui
	local userId = localPlayer.UserId
	local sg = Instance.new("ScreenGui")
	sg.Name = "SettingsSgui"

	local outerFrame = Instance.new("Frame")
	outerFrame.Parent = sg
	outerFrame.Size = UDim2.new(0.3, 0, 0.15, 0)
	outerFrame.Position = UDim2.new(0.35, 0, 0.4, 0)
	local vv2 = Instance.new("UIListLayout")
	vv2.FillDirection = Enum.FillDirection.Vertical
	vv2.Parent = outerFrame

	local serverEventRemoteFunction = remotes.getRemoteFunction("ServerEventRemoteFunction")

	local res = serverEventRemoteFunction:InvokeServer(serverEventEnums.messageTypes.CREATE, { userId = userId })

	local tl = guiUtil.getTl("XXXResults", UDim2.new(1, 0, 1, 0), 0, outerFrame, colors.defaultGrey, 2)

	tl.Text = res.message

	local tb = guiUtil.getTbSimple()
	tb.Text = "Close"
	tb.Name = "ZZZCloseButton"
	tb.Size = UDim2.new(1, 0, 0, 40)
	tb.BackgroundColor3 = colors.redStop
	tb.Parent = outerFrame
	tb.Activated:Connect(function()
		sg:Destroy()
	end)
	return sg
end

local serverEventButton: gt.actionButton = {
	name = "Create Server Event",
	contentsGetter = CreateServerEventButtonClicked,
	hoverHint = "Create new server event",
	shortName = " +Random Race ",
	getActive = function()
		return true
	end,
	widthPixels = 180,
}

module.serverEventButton = serverEventButton

return module
