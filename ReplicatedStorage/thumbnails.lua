--!strict

local Players = game:GetService("Players")

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local colors = require(game.ReplicatedStorage.util.colors)

local UserInputService = game:GetService("UserInputService")

local module = {}

local avatarPopupGui: ScreenGui? = nil
local avatarPopupImage: ImageLabel? = nil

local POPUP_GUI_NAME = "LeaderboardAvatarPopupGui"

local thumbnailMaps: { [number]: { [Enum.ThumbnailType]: { [Enum.ThumbnailSize]: string } } } = {}

-- Expose function to hide tooltip for use by control buttons
module.HideAvatarPopup = function()
	if avatarPopupGui then
		avatarPopupGui.Enabled = false
	end
end

module.getThumbnailContent = function(userId: number, ttype: Enum.ThumbnailType, tsize: Enum.ThumbnailSize): string
	if thumbnailMaps[userId] == nil then
		thumbnailMaps[userId] = {}
	end
	if thumbnailMaps[userId][ttype] == nil then
		thumbnailMaps[userId][ttype] = {}
	end
	if thumbnailMaps[userId][ttype][tsize] == nil then
		local width = 100
		if tsize == Enum.ThumbnailSize.Size150x150 then
			width = 150
		elseif tsize == Enum.ThumbnailSize.Size420x420 then
			width = 420
		elseif tsize == Enum.ThumbnailSize.Size100x100 then
			width = 100
		elseif tsize == Enum.ThumbnailSize.Size352x352 then
			width = 352
		elseif tsize == Enum.ThumbnailSize.Size48x48 then
			width = 48
		elseif tsize == Enum.ThumbnailSize.Size60x60 then
			width = 60
		else
			annotater.Error("bad thub size: OF " .. tostring(tsize), userId)
			warn("bad thub size: " .. tostring(tsize))
		end
		local tt = tostring(ttype)
		if ttype == Enum.ThumbnailType.HeadShot then
			tt = "AvatarHeadShot"
		elseif ttype == Enum.ThumbnailType.AvatarBust then
			tt = "AvatarBust"
		elseif ttype == Enum.ThumbnailType.AvatarThumbnail then
			tt = "AvatarThumbnail"
		else
			warn("bad thub type: " .. tostring(ttype))
		end
		local content =
			string.format("rbxthumb://type=%s&id=%s&w=%s&h=%s", tt, tostring(userId), tostring(width), tostring(width))
		_annotate((string.format("getting thumbnail: %s", content)))
		thumbnailMaps[userId][ttype][tsize] = content
	end
	return thumbnailMaps[userId][ttype][tsize]
end

module.getBadgeAssetThumbnailContent = function(badgeAssetId: number): string
	if badgeAssetId == nil or badgeAssetId < 0 then
		annotater.Error("bad id.")
	end
	local at = "BadgeIcon"
	local content = "rbxthumb://type=" .. at .. "&id=" .. badgeAssetId .. "&w=150&h=150"
	return content
end

module.createAvatarPortraitPopup = function(
	userId: number,
	doPopup: boolean,
	backgroundColor: Color3?,
	borderSizePixel: number?
): Frame
	local portraitCell = Instance.new("Frame")
	portraitCell.Size = UDim2.fromScale(1, 1)
	portraitCell.BackgroundTransparency = 1
	portraitCell.Name = "PortraitCell"
	portraitCell.BorderSizePixel = borderSizePixel or 0
	portraitCell.BorderMode = Enum.BorderMode.Inset

	local img = Instance.new("ImageLabel")
	img.Size = UDim2.new(1, 0, 1, 0)
	img.BackgroundColor3 = backgroundColor or colors.defaultGrey
	img.Name = "PortraitImage"
	img.Parent = portraitCell
	img.BorderMode = Enum.BorderMode.Inset
	img.ScaleType = Enum.ScaleType.Crop
	img.BorderSizePixel = 0
	local content = module.getThumbnailContent(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
	img.Image = content

	if doPopup then
		local function connectImageInput(image: ImageLabel)
			image.InputBegan:Connect(function(input: InputObject)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					if avatarPopupGui then
						avatarPopupGui.Enabled = false
					end
				end
			end)
		end

		local function getOrCreateAvatarPopup(playerGui: PlayerGui?): (ScreenGui?, ImageLabel?)
			if not playerGui then
				return nil, nil
			end

			if avatarPopupGui and avatarPopupGui.Parent ~= playerGui then
				avatarPopupGui:Destroy()
				avatarPopupGui = nil
				avatarPopupImage = nil
			end

			if not avatarPopupGui then
				local newGui = Instance.new("ScreenGui")
				newGui.Name = POPUP_GUI_NAME
				newGui.ResetOnSpawn = false
				newGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

				local attribute = Instance.new("BoolValue")
				attribute.Parent = newGui
				attribute.Name = "DismissableWithX"
				attribute.Value = true

				local container = Instance.new("Frame")
				container.Size = UDim2.fromScale(1, 1)
				container.BackgroundTransparency = 1
				container.Name = "AvatarImages"
				container.Parent = newGui

				local image = Instance.new("ImageLabel")
				image.Size = UDim2.fromOffset(420, 420)
				image.BackgroundColor3 = colors.defaultGrey
				image.BorderSizePixel = 0
				image.Name = "LargeAvatarImage"
				image.ZIndex = 10
				image.Parent = container

				avatarPopupGui = newGui
				avatarPopupImage = image
				connectImageInput(image)
			end

			if avatarPopupGui and avatarPopupGui.Parent ~= playerGui then
				avatarPopupGui.Parent = playerGui
			end

			return avatarPopupGui, avatarPopupImage
		end

		local function hideAvatarPopup()
			if avatarPopupGui then
				avatarPopupGui.Enabled = false
			end
		end

		local function isMouseOverControlButton(cell: Frame): boolean
			local mouseLocation = UserInputService:GetMouseLocation()
			local currentParent: Instance? = cell.Parent

			-- Find the outer frame by traversing up the parent chain
			local outerFrame: Frame? = nil
			while currentParent do
				if currentParent:IsA("Frame") and string.sub(currentParent.Name, 1, 7) == "outer_" then
					outerFrame = currentParent :: Frame
					break
				end
				currentParent = currentParent.Parent
			end

			if not outerFrame then
				return false
			end

			-- Check if mouse is over any control button (resizer, minimizer, pinner)
			local controlButtonNames = { "resizer", "minimizer", "pinner" }
			for _, buttonNameSuffix in ipairs(controlButtonNames) do
				local buttonName = outerFrame.Name .. "_" .. buttonNameSuffix
				local controlButton = outerFrame:FindFirstChild(buttonName)
				if controlButton and controlButton:IsA("GuiObject") then
					local buttonPos = controlButton.AbsolutePosition
					local buttonSize = controlButton.AbsoluteSize
					if
						mouseLocation.X >= buttonPos.X
						and mouseLocation.X <= buttonPos.X + buttonSize.X
						and mouseLocation.Y >= buttonPos.Y
						and mouseLocation.Y <= buttonPos.Y + buttonSize.Y
					then
						return true
					end
				end
			end

			return false
		end

		local function showAvatarPopup()
			-- Don't show tooltip if mouse is over control buttons
			if isMouseOverControlButton(portraitCell) then
				return
			end

			local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
			if not playerGui then
				return
			end

			local popupGui, popupImage = getOrCreateAvatarPopup(playerGui)
			if not popupGui or not popupImage then
				return
			end

			popupGui.Enabled = true
			popupImage.Image = content
			popupImage.Name = "LargeAvatarImage_" .. tostring(userId)
			local mouseLocation = UserInputService:GetMouseLocation()
			local newPositionX = mouseLocation.X - popupImage.Size.X.Offset - 100
			local newPositionY = mouseLocation.Y - (popupImage.Size.Y.Offset / 2)

			local screenSize = workspace.CurrentCamera.ViewportSize
			newPositionX = math.max(0, math.min(newPositionX, screenSize.X - popupImage.Size.X.Offset))
			newPositionY = math.max(0, math.min(newPositionY, screenSize.Y - popupImage.Size.Y.Offset))

			popupImage.Position = UDim2.fromOffset(newPositionX, newPositionY)
		end

		portraitCell.MouseEnter:Connect(function()
			showAvatarPopup()
		end)

		portraitCell.MouseLeave:Connect(function()
			hideAvatarPopup()
		end)

		portraitCell.MouseMoved:Connect(function()
			-- Hide tooltip if mouse moves over a control button
			if isMouseOverControlButton(portraitCell) then
				hideAvatarPopup()
			end
		end)

		portraitCell.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				hideAvatarPopup()
			end
		end)

		portraitCell.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				hideAvatarPopup()
			end
		end)

		if avatarPopupImage then
			connectImageInput(avatarPopupImage)
		end
	end

	return portraitCell
end

_annotate("end")
return module
