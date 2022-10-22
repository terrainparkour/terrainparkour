--!strict

--eval 9.21

local colors = require(game.ReplicatedStorage.util.colors)

local thumbnails = require(game.ReplicatedStorage.thumbnails)
local config = require(game.ReplicatedStorage.config)
local guiUtil = require(game.ReplicatedStorage.gui.guiUtil)
local tt = require(game.ReplicatedStorage.types.gametypes)
local enums = require(game.ReplicatedStorage.util.enums)

local PlayersService = game:GetService("Players")

repeat game:GetService("RunService").RenderStepped:wait() until game.Players.LocalPlayer.Character ~= nil
local localPlayer = PlayersService.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local module = {}

local isMobile = false
if
	UIS.TouchEnabled
	and not UIS.KeyboardEnabled
	and not UIS.MouseEnabled
	and not UIS.GamepadEnabled
	and not GuiService:IsTenFootInterface()
then
	isMobile = true
	-- mobile device, busted
end

module.notify = function(options: tt.ephemeralNotificationOptions, warpWrapper: tt.warperWrapper)
	--no mobile player-side notifications
	if isMobile then
		return
	end

	if config.isInStudio() then --already updated upstream
		print("legacy notifier: " .. options.kind)
		print(options)
	end

	local sg = Instance.new("ScreenGui")
	sg.Parent = playerGui
	local sgName = "EphemeralNotificationSgui"
	sg.Name = sgName

	local frame = Instance.new("Frame")
	local ephemeralNotificationFrame = "ephemeralNotificationFrame"
	frame.Name = ephemeralNotificationFrame
	frame.Size = UDim2.new(0.20, 0, 0.14, 0)
	frame.Position = UDim2.new(0.77, 0, 0.84, 0)
	frame.Parent = sg

	local firstRowFrame = Instance.new("Frame")
	firstRowFrame.Parent = frame
	local showWarp = false
	if options.warpToSignId ~= 0 and options.warpToSignId ~= nil and options.warpToSignId ~= "" then
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
	local useUserId = tonumber(options.userId)
	if useUserId < 1 then
		useUserId = 261
	end
	local content = thumbnails.getThumbnailContent(useUserId, Enum.ThumbnailType.AvatarBust)
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
		warpTl.Font = Enum.Font.Gotham
		warpTl.BackgroundColor3 = colors.lightBlue
		warpTl.Size = UDim2.new(1, 0, 0.2, 0)

		warpTl.Position = UDim2.new(0, 0, 0.8, 0)
		warpTl.ZIndex = 2
		warpTl.Parent = frame
		warpTl.Activated:Connect(function()
			warpWrapper.requestWarpToSign(options.warpToSignId)
		end)
	end

	guiUtil.setupKillOnClick(sg, warpName)
end

return module
