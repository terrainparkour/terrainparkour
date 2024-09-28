--!strict

local Players = game:GetService("Players")

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
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
			warn("bad thub size: " .. tostring(tsize))
		end
		-- local content = "rbxthumb://type = "
		-- 	.. tostring(ttype)
		-- 	.. "&id="
		-- 	.. userId
		-- 	.. "&w="
		-- 	.. tostring(width)
		-- 	.. "&h="
		-- 	.. tonumber(width)
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

_annotate("end")
return module
