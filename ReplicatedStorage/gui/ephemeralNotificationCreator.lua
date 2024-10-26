--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local colors = require(game.ReplicatedStorage.util.colors)

local thumbnails = require(game.ReplicatedStorage.thumbnails)
local config = require(game.ReplicatedStorage.config)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local tt = require(game.ReplicatedStorage.types.gametypes)
local enums = require(game.ReplicatedStorage.util.enums)
local warper = require(game.StarterPlayer.StarterPlayerScripts.warper)
local PlayersService = game:GetService("Players")

local localPlayer = PlayersService.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local module = {}

local isTouch = false
if
	UIS.TouchEnabled
	and not UIS.KeyboardEnabled
	and not UIS.MouseEnabled
	and not UIS.GamepadEnabled
	and not GuiService:IsTenFootInterface()
then
	isTouch = true
	-- mobile device, busted
end

module.notify = function(options: tt.ephemeralNotificationOptions)
	--no mobile player-side notifications
	if isTouch then
		return
	end

	if config.isInStudio() then --already updated upstream
		_annotate("legacy notifier: " .. options.kind, options)
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Parent = playerGui
	screenGui.IgnoreGuiInset = true
	local sgName = "EphemeralNotificationSgui"
	screenGui.Name = sgName

	local frame = Instance.new("Frame")
	local ephemeralNotificationFrame = "ephemeralNotificationFrame"
	frame.Name = ephemeralNotificationFrame
	frame.Size = UDim2.new(0.20, 0, 0.14, 0)
	frame.Position = UDim2.new(0.77, 0, 0.84, 0)
	frame.Parent = screenGui

	local firstRowFrame = Instance.new("Frame")
	firstRowFrame.Parent = frame
	local showWarp = false
	if options.warpToSignId ~= 0 and options.warpToSignId ~= nil then
		showWarp = true
	end

	if showWarp then
		firstRowFrame.Size = UDim2.new(1, 0, 0.8, 0)
	else
		firstRowFrame.Size = UDim2.new(1, 0, 1, 0)
	end

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Name = "UILayoutH_ephemeral"
	layout.Parent = firstRowFrame

	local im = Instance.new("ImageLabel")
	im.BorderMode = Enum.BorderMode.Outline
	im.Parent = firstRowFrame
	im.Size = UDim2.new(0.5, 0, 1, 0)
	local useUserId: number = options.userId
	if useUserId == nil or useUserId <= 0 then
		useUserId = 261
	end

	local content =
		thumbnails.getThumbnailContent(useUserId, Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size420x420)
	im.Position = UDim2.new(0, 0, 0.3, 0)
	im.Image = content
	im.Name = "ephemeralImage"
	im.BackgroundColor3 = colors.grey

	local tl = guiUtil.getTl("notifyText", UDim2.new(0.5, 0, 1, 0), 2, firstRowFrame, colors.defaultGrey, 1)
	tl.Text = options.text
	tl.TextXAlignment = Enum.TextXAlignment.Left
	tl.TextYAlignment = Enum.TextYAlignment.Top
	tl.BackgroundTransparency = 0
	tl.TextColor3 = colors.black
	tl.RichText = true

	local warpTl: TextButton = nil
	local warpName: string? = nil
	if showWarp then
		warpTl = Instance.new("TextButton")

		warpTl.Name = "EphemeralWarpTl"
		warpName = warpTl.Name
		local signName = enums.signId2name[options.warpToSignId]
		warpTl.Text = "Warp to " .. signName
		warpTl.TextScaled = true
		warpTl.FontFace = Font.new("rbxasset://fonts/families/Arimo.json")
		warpTl.BackgroundColor3 = colors.warpColor
		warpTl.Size = UDim2.new(1, 0, 0.2, 0)

		warpTl.Position = UDim2.new(0, 0, 0.8, 0)
		warpTl.ZIndex = 20
		warpTl.Parent = frame
		warpTl.Activated:Connect(function()
			warper.WarpToSignId(options.warpToSignId, options.highlightSignId)
		end)
	end

	guiUtil.setupKillOnClick(screenGui, warpName)
end

_annotate("end")
return module
