--!strict

local Players = game:GetService("Players")

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local colors = require(game.ReplicatedStorage.util.colors)

local UserInputService = game:GetService("UserInputService")

local module = {}

local thumbnailMaps: { [number]: { [Enum.ThumbnailType]: { [Enum.ThumbnailSize]: string } } } = {}

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
		portraitCell.MouseEnter:Connect(function()
			local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
			local avatarImagesGui = Instance.new("ScreenGui")
			avatarImagesGui.Name = "AvatarImagesGui"
			avatarImagesGui.ResetOnSpawn = false
			avatarImagesGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			avatarImagesGui.Parent = playerGui

			local attribute = Instance.new("BoolValue")
			attribute.Parent = avatarImagesGui
			attribute.Name = "DismissableWithX"
			attribute.Value = true

			local avatarImages = Instance.new("Frame")
			avatarImages.Size = UDim2.fromScale(1, 1)
			avatarImages.BackgroundTransparency = 1
			avatarImages.Name = "AvatarImages"
			avatarImages.Parent = avatarImagesGui

			local largeImg = Instance.new("ImageLabel")
			largeImg.Size = UDim2.fromOffset(420, 420)
			largeImg.BackgroundColor3 = colors.defaultGrey
			largeImg.Image = content
			largeImg.Name = "LargeAvatarImage_" .. tostring(userId)
			largeImg.Parent = avatarImages
			local mouseLocation = UserInputService:GetMouseLocation()
			local newPositionX = mouseLocation.X - largeImg.Size.X.Offset - 100
			local newPositionY = mouseLocation.Y - (largeImg.Size.Y.Offset / 2)

			-- Ensure the popup stays within the screen bounds
			local screenSize = workspace.CurrentCamera.ViewportSize
			newPositionX = math.max(0, math.min(newPositionX, screenSize.X - largeImg.Size.X.Offset))
			newPositionY = math.max(0, math.min(newPositionY, screenSize.Y - largeImg.Size.Y.Offset))

			largeImg.Position = UDim2.fromOffset(newPositionX, newPositionY)
		end)

		portraitCell.MouseLeave:Connect(function()
			local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
			local avatarImagesGui = playerGui:FindFirstChild("AvatarImagesGui")
			if avatarImagesGui then
				avatarImagesGui:Destroy()
			end
		end)
	end

	return portraitCell
end

_annotate("end")
return module
