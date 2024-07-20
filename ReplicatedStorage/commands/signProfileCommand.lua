--!strict

local rdb = require(game.ServerScriptService.rdb)
local tt = require(game.ReplicatedStorage.types.gametypes)

local remotes = require(game.ReplicatedStorage.util.remotes)
local showClientSignProfileEvent = remotes.getRemoteEvent("ShowClientSignProfileEvent")

local module = {}

local function prepareData(userId: number, signId: number): tt.playerSignProfileData
	local res: tt.playerSignProfileData = rdb.getSignProfileForUser(userId, signId)["res"]
	return res
end

module.signProfileCommand = function(subjectUserId: number, signId: number, target: Player)
	local data = prepareData(subjectUserId, signId)
	showClientSignProfileEvent:FireClient(target, data)
end

return module