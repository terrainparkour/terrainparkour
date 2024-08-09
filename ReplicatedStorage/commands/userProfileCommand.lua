--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local tt = require(game.ReplicatedStorage.types.gametypes)
local userProfileSguiCreator = require(game.ReplicatedStorage.commands.userProfileSguiCreator)

local module = {}

local function prepayerData(targetUserId): tt.playerProfileData
	local res: tt.playerProfileData
	return res
end

module.UserProfileCommand = function(targetUserId: number, localPlayer: Player)
	local data = prepayerData(targetUserId)
	userProfileSguiCreator.createSgui(localPlayer, data)
end

_annotate("end")
return module
