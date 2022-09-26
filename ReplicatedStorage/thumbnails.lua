--!strict

--eval 9.24.22

local module = {}

local thumbnailMaps: { [Enum.ThumbnailType]: { [number]: string } } = {}
thumbnailMaps[Enum.ThumbnailType.HeadShot] = {}
thumbnailMaps[Enum.ThumbnailType.AvatarBust] = {}

module.getThumbnailContent = function(userId: number, ttype): string
	if thumbnailMaps[ttype][userId] == nil then
		local at = ""
		if ttype == Enum.ThumbnailType.AvatarBust then
			at = "AvatarBust"
		end
		if ttype == Enum.ThumbnailType.HeadShot then
			at = "AvatarHeadShot"
		end
		local content = "rbxthumb://type=" .. at .. "&id=" .. userId .. "&w=100&h=100"
		thumbnailMaps[ttype][userId] = content
	end
	return thumbnailMaps[ttype][userId]
end

return module
