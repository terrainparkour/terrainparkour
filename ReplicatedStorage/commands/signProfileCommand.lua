--!strict

-- this is the sign profile command, it is used to show the sign profile on sign right-click.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local rdb = require(game.ServerScriptService.rdb)
local tt = require(game.ReplicatedStorage.types.gametypes)

local remotes = require(game.ReplicatedStorage.util.remotes)
local ShowClientSignProfileEvent = remotes.getRemoteEvent("ShowClientSignProfileEvent")

local module = {}

local function prepareSignProfileData(username: string, signId: number): tt.playerSignProfileData
	_annotate(string.format("prepareSignProfileData username: %s, signId: %d", username, signId))
	local res: tt.playerSignProfileData = rdb.getSignProfileForUser(username, signId)["res"]
	return res
end

module.signProfileCommand = function(subjectUsername: string, signId: number, player: Player)
	local data = prepareSignProfileData(subjectUsername, signId)
	if data and data.username and data.signId then
		ShowClientSignProfileEvent:FireClient(player, data)
	else
		-- player:SendChatMessage("No sign profile found for " .. subjectUsername .. " and signId " .. signId)
		--why is this messed up, and we can't or don't give a proper response? because in this case unlike most others,
		-- we are allowing lookup of offline players, which means we don't know the answer until the server replies
	end
end

_annotate("end")
return module
