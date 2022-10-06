--!strict

--eval 9.24.22

local module = {}

local thumbnailMaps: { [Enum.ThumbnailType]: { [number]: string } } = {}
thumbnailMaps[Enum.ThumbnailType.HeadShot] = {}
thumbnailMaps[Enum.ThumbnailType.AvatarBust] = {}

module.getThumbnailContent = function(userId: number, ttype, x: number?, y: number?): string
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

return module
