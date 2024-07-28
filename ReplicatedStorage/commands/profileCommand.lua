--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local tt = require(game.ReplicatedStorage.types.gametypes)
local sg = require(game.ReplicatedStorage.commands.profileSguiCreator)

local module = {}

local function prepayerData(targetUserId): tt.playerProfileData
	local res: tt.playerProfileData
	return res
end

module.profileCommand = function(targetUserId: number, localPlayer: Player)
	local data = prepayerData(targetUserId)
	sg.createSgui(localPlayer, data)
end

_annotate("end")
return module
