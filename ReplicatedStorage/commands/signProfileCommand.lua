--!strict

-- signProfileCommand.lua :: ReplicatedStorage.commands.signProfileCommand
-- SERVER-ONLY: Fetch and display sign profile data for a user on a specific sign.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local remotes = require(game.ReplicatedStorage.util.remotes)
local tt = require(game.ReplicatedStorage.types.gametypes)
local rdb = require(game.ServerScriptService.rdb)

local ShowClientSignProfileEvent = remotes.getRemoteEvent("ShowClientSignProfileEvent")

type Module = {
	signProfileCommand: (subjectUsername: string, signId: number, player: Player) -> (),
}

local module: Module = {} :: Module

local function getSignProfileForUser(username: string, signId: number)
	local data = { username = username, signId = signId }
	local request: tt.postRequest = {
		remoteActionName = "getSignProfileForUser",
		data = data,
	}
	return rdb.MakePostRequest(request)
end

local function prepareSignProfileData(username: string, signId: number): tt.playerSignProfileData
	_annotate(string.format("prepareSignProfileData username: %s, signId: %d", username, signId))
	local res: tt.playerSignProfileData = getSignProfileForUser(username, signId)
	return res
end

module.signProfileCommand = function(subjectUsername: string, signId: number, player: Player)
	local data = prepareSignProfileData(subjectUsername, signId)
	if data and data.username and data.signId then
		ShowClientSignProfileEvent:FireClient(player, data)
	end
end

_annotate("end")
return module
