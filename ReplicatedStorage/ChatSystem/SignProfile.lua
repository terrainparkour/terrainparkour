--!strict

-- SignProfile module for handling the sign profile command.
-- This module allows players to view a sign profile by right-clicking on a sign,
-- and it retrieves data from the server before displaying it on the client.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local rdb = require(game.ServerScriptService.rdb)
local tt = require(game.ReplicatedStorage.types.gametypes)

local remotes = require(game.ReplicatedStorage.util.remotes)
local ShowClientSignProfileEvent = remotes.getRemoteEvent("ShowClientSignProfileEvent")

local SignProfile = {}

-- Function to fetch sign profile data for a user.
local function getSignProfileForUser(username: string, signId: number): tt.playerSignProfileData
	local data = { username = username, signId = signId }
	local request: tt.postRequest = {
		remoteActionName = "getSignProfileForUser",
		data = data,
	}
	return rdb.MakePostRequest(request)
end

-- Prepares the sign profile data by retrieving it from the server.
local function prepareSignProfileData(username: string, signId: number): tt.playerSignProfileData
	_annotate(string.format("prepareSignProfileData username: %s, signId: %d", username, signId))
	local res: tt.playerSignProfileData = getSignProfileForUser(username, signId)
	return res
end

-- Main function to execute the sign profile command.
function SignProfile.signProfileCommand(subjectUsername: string, signId: number, player: Player)
	local data = prepareSignProfileData(subjectUsername, signId)
	if data and data.username and data.signId then
		ShowClientSignProfileEvent:FireClient(player, data)
	else
		-- Optionally handle cases where the profile data is not found
		-- When dealing with offline player lookups, responses may be delayed or absent
		-- Handle accordingly if you want to provide feedback or log this issue
		-- player:SendChatMessage("No sign profile found for " .. subjectUsername .. " and signId " .. signId)
	end
end

-- Function to execute the command (to be called from CommandService)
function SignProfile.Execute(player: Player, subjectUsername: string, signId: number)
	SignProfile.signProfileCommand(subjectUsername, signId, player)
	return "Sign profile command executed. Please check your client for the response."
end

_annotate("end")
return SignProfile