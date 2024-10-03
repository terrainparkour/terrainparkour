--!strict

-- errorReporting. required by annotater, and used on both server and client.

local module = {}

local lua2Json = require(game.ReplicatedStorage.util.lua2Json)
local tt = require(game.ReplicatedStorage.types.gametypes)

local enums = require(game.ReplicatedStorage.util.enums)

local config = require(game.ReplicatedStorage.config)

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ErrorMessageEvent

local SERVER = "server"
local CLIENT = "client"
local NOTSET = "notset"

export type robloxError = {
	code: string,
	kind: string,
	version: string,
	data: any,
	message: string,
	userId: number?,
}

----------------- UTIL----------------------

local function isServer()
	return RunService:IsServer()
end

local function isClient()
	return RunService:IsClient()
end

-------------STORAGE  and SENDING-----------------------------------
-- we store them here in ram and then loop to send them.
local theErrors: { tt.robloxServerError } = {}

-- without consulting any rate limiting data, just send the accumulated errors every 20 seconds
local periodicallySendErrors = function()
	local posting = require(game.ServerScriptService.posting)
	while true do
		if #theErrors > 1 then
			local request: tt.postRequest = {
				remoteActionName = "reportServerErrors",
				data = { errors = theErrors },
			}
			local res = posting.MakePostRequest(request)["res"]
			theErrors = {}
		end
		task.wait(20)
	end
end

-- a direct remote logging functino to store the error on my server.
local doError = function(err: robloxError)
	if isServer() then
		local preparedError = { rawMessage = HttpService:JSONEncode(lua2Json.Lua2StringTable(err)) }
		table.insert(theErrors, preparedError)
	elseif isClient() then
		ErrorMessageEvent:FireServer(err)
	else
		error("you are neither server nor client. you should not be calling this.")
	end
end

-- callers only call this and it sets their game version then sends it on.
-- the subsequentFunction will figure out if the sender is a client or server.
-- if client, will set client and relay
-- if we're on the game server already, we'll just send it to the cloud.
module.Error = function(msg: string, userId: number?, data: any?)
	local kind = isServer() and SERVER or CLIENT
	local extendedError: robloxError = {
		code = NOTSET,
		kind = kind,
		version = enums.gameVersion,
		data = {},
		message = msg,
		userId = nil,
	}
	return doError(extendedError)
end

local innitted = false
module.Init = function()
	if innitted then
		return
	end
	innitted = true

	-- receive the event from the client and send it.
	local remotes = require(game.ReplicatedStorage.util.remotes)
	ErrorMessageEvent = remotes.getRemoteEvent("ErrorMessageEvent")

	if isServer() then
		task.spawn(periodicallySendErrors)
		ErrorMessageEvent.OnServerEvent:Connect(function(player, err: robloxError)
			err.userId = player.UserId
			doError(err)
		end)
	end

	if config.isInStudio() then
		if isServer() then
			module.Error("test error sent from server")
		else
			module.Error("test error sent from client")
		end
	end
end

return module
