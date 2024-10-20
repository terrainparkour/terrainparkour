--!strict

local Players = game:GetService("Players")

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local colors = require(game.ReplicatedStorage.util.colors)

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

module.createAvatarPortraitPopup = function(userId: number, parentFrame: Frame): Frame
	local portraitCell = Instance.new("Frame")
	portraitCell.Size = UDim2.fromScale(1, 1)
	portraitCell.BackgroundTransparency = 1
	portraitCell.Name = "PortraitCell"
	portraitCell.Parent = parentFrame

	local img = Instance.new("ImageLabel")
	img.Size = UDim2.new(1, 0, 1, 0)
	img.BackgroundColor3 = colors.defaultGrey
	img.Name = "PortraitImage"
	img.Parent = portraitCell
	img.BorderMode = Enum.BorderMode.Outline
	img.ScaleType = Enum.ScaleType.Crop
	img.BorderSizePixel = 1
	local content = module.getThumbnailContent(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
	img.Image = content

	local avatarImages = Instance.new("Frame")
	avatarImages.Size = UDim2.new(0, 420, 0, 420)
	avatarImages.Position = UDim2.new(0, -440, 0, 0)
	avatarImages.Parent = portraitCell
	avatarImages.Visible = false

	local vv = Instance.new("UIListLayout")
	vv.FillDirection = Enum.FillDirection.Vertical
	vv.Parent = avatarImages
	vv.Name = "avatarVV"

	local allContents = {
		module.getThumbnailContent(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420),
	}
	for _, content in pairs(allContents) do
		local largeImg = Instance.new("ImageLabel")
		largeImg.Size = UDim2.new(1, 0, 1, 0)
		largeImg.BackgroundColor3 = colors.defaultGrey
		largeImg.Visible = true
		largeImg.ZIndex = 10
		largeImg.Image = content
		largeImg.Name = "LargeAvatarImage_" .. tostring(userId)
		largeImg.Parent = avatarImages
	end

	portraitCell.MouseEnter:Connect(function()
		avatarImages.Visible = true
	end)
	portraitCell.MouseLeave:Connect(function()
		avatarImages.Visible = false
	end)

	return portraitCell
end

_annotate("end")
return module
