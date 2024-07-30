--!strict

-- GUI on client for server event.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local colors = require(game.ReplicatedStorage.util.colors)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local gt = require(game.ReplicatedStorage.gui.guiTypes)
local serverEventEnums = require(game.ReplicatedStorage.enums.serverEventEnums)
local remotes = require(game.ReplicatedStorage.util.remotes)

local ServerEventRemoteFunction = remotes.getRemoteFunction("ServerEventRemoteFunction")

local module = {}

--create server event, wait for ui to pop, then display a simple modal for success or failure.

--TODO make this into an ephemeral notification.
local CreateServerEventButtonClicked = function(localPlayer: Player): ScreenGui
	local userId = localPlayer.UserId
	local sg = Instance.new("ScreenGui")
	sg.Name = "CreateServerEventButtonClickedSgui"

	local outerFrame = Instance.new("Frame")
	outerFrame.Parent = sg
	outerFrame.Size = UDim2.new(0.3, 0, 0.15, 0)
	outerFrame.Position = UDim2.new(0.35, 0, 0.4, 0)
	local vv2 = Instance.new("UIListLayout")
	vv2.FillDirection = Enum.FillDirection.Vertical
	vv2.Parent = outerFrame

	local res = ServerEventRemoteFunction:InvokeServer(serverEventEnums.messageTypes.CREATE, { userId = userId })

	local tl = guiUtil.getTl("XXXResults", UDim2.new(1, 0, 1, 0), 0, outerFrame, colors.defaultGrey, 2)
	local par = tl.Parent :: TextLabel
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
	task.spawn(function()
		local amt = 0.035
		while true do
			tb.BackgroundTransparency = tb.BackgroundTransparency + amt
			tb.TextTransparency = tb.TextTransparency + amt
			outerFrame.BackgroundTransparency = outerFrame.BackgroundTransparency + amt
			par.BackgroundTransparency = par.BackgroundTransparency + amt
			tl.BackgroundTransparency = tl.BackgroundTransparency + amt
			tl.TextTransparency = tl.TextTransparency + amt
			wait(0.01)
			if tb.BackgroundTransparency >= 1 then
				break
			end
			local waitTime = wait(0.01)
			amt = 0.035 * waitTime / 0.01
		end
		sg:Destroy()
	end)
	return sg
end

local serverEventButton: gt.actionButton = {
	name = "Create Server Event",
	contentsGetter = CreateServerEventButtonClicked,
	hoverHint = "Create new server event",
	shortName = " Random Race ",
	getActive = function()
		return true
	end,
	widthPixels = 75,
}

module.serverEventButton = serverEventButton

_annotate("end")
return module
