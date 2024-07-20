--!strict

--eval 9.24.22

local module = {}

local thumbnailMaps: { [Enum.ThumbnailType]: { [number]: string } } = {}
thumbnailMaps[Enum.ThumbnailType.HeadShot] = {}
thumbnailMaps[Enum.ThumbnailType.AvatarBust] = {}

module.getThumbnailContent = function(userId: number, ttype, x: number?, y: number?): string
	if userId < 0 then
		userId = 261
	end
	if x == nil then
		x = 100
	end
	if y == nil then
		y = 100
	end
	if thumbnailMaps[ttype][userId] == nil then
		local at = ""
		if ttype == Enum.ThumbnailType.AvatarBust then
			at = "AvatarBust"
		end
		if ttype == Enum.ThumbnailType.HeadShot then
			at = "AvatarHeadShot"
		end
		local content = "rbxthumb://type=" .. at .. "&id=" .. userId .. "&w=" .. tonumber(x) .. "&h=" .. tonumber(y)
		thumbnailMaps[ttype][userId] = content
	end
	return thumbnailMaps[ttype][userId]
end

module.getBadgeAssetThumbnailContent = function(badgeAssetId: number): string
	if badgeAssetId == nil or badgeAssetId < 0 then
		error("bad id.")
	end
	-- local x = 150
	-- local y = 150
	-- local ttype = "badge"
	local at = "BadgeIcon"
	local content = "rbxthumb://type=" .. at .. "&id=" .. badgeAssetId .. "&w=150&h=150"
	return content
end

return module
