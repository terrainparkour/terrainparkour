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
-- they are already stringieda t this point so are just raw.
local theErrors: { { rawMessage: string } } = {}

-- without consulting any rate limiting data, just send the accumulated errors every 20 seconds
local periodicallySendErrors = function()
	local posting = require(game.ServerScriptService.posting)
	while true do
		if #theErrors > 1 then
			local request: tt.postRequest = {
				remoteActionName = "reportServerErrors",
				data = { errors = theErrors },
			}
			local _res = posting.MakePostRequest(request)["res"]
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
		warn(string.format("Error: %s", HttpService:JSONEncode(lua2Json.Lua2StringTable(err))))
	elseif isClient() then
		warn(string.format("Error: %s", HttpService:JSONEncode(lua2Json.Lua2StringTable(err))))
		ErrorMessageEvent:FireServer(err)
	else
		error("you are neither server nor client. you should not be calling this.")
	end
end

-- callers only call this and it sets their game version then sends it on.
-- the subsequentFunction will figure out if the sender is a client or server.
-- if client, will set client and relay
-- if we're on the game server already, we'll just send it to the cloud.
-- Error reporting entrypoint.
-- NOTE: This is called via annotater.Error(message, payloadTable?) so the 2nd arg is often a payload table,
-- not a userId. Preserve backward compatibility by accepting:
-- - Error(msg, payloadTable)
-- - Error(msg, userIdNumber, payloadTable)
module.Error = function(msg: string, arg2: any?, arg3: any?)
	local kind = isServer() and SERVER or CLIENT
	local userId: number? = nil
	local data: any = {}

	if type(arg2) == "number" then
		userId = arg2 :: number
		data = if arg3 ~= nil then arg3 else {}
	elseif arg2 ~= nil then
		data = arg2
		if type(arg2) == "table" and type((arg2 :: any).userId) == "number" then
			userId = (arg2 :: any).userId
		end
	end

	local extendedError: robloxError = {
		code = NOTSET,
		kind = kind,
		version = enums.gameVersion,
		data = data,
		message = msg,
		userId = userId,
	}
	return doError(extendedError)
end

-- Wrap a function to capture and forward runtime errors
-- Usage: errorReporting.SafeCall(function() ... end, "contextName")
module.SafeCall = function(fn: () -> (), context: string): (boolean, string?)
	local success, err = pcall(fn)
	if not success then
		local errMsg = tostring(err)
		local kind = isServer() and SERVER or CLIENT
		local extendedError: robloxError = {
			code = "RUNTIME",
			kind = kind,
			version = enums.gameVersion,
			data = { context = context, traceback = debug.traceback() },
			message = string.format("Runtime error in %s: %s", context, errMsg),
			userId = nil,
		}
		doError(extendedError)
		return false, errMsg
	end
	return true, nil
end

-- Wrap a script's main function - logs crash and re-raises for Roblox to handle
-- Usage at end of Scripts: errorReporting.WrapScript(main, script)
module.WrapScript = function(fn: () -> (), scriptRef: LuaSourceContainer)
	local context = scriptRef:GetFullName()
	local success, err = pcall(fn)
	if not success then
		local errMsg = tostring(err)
		local kind = isServer() and SERVER or CLIENT
		local extendedError: robloxError = {
			code = "SCRIPT_CRASH",
			kind = kind,
			version = enums.gameVersion,
			data = { script = context, traceback = debug.traceback() },
			message = string.format("Script crashed: %s - %s", context, errMsg),
			userId = nil,
		}
		doError(extendedError)
		-- Re-raise so Roblox also captures it in their dashboard
		error(err)
	end
end

local innitted = false

local do_studio_only_error_sending_tests = false

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

	if config.IsInStudio() and do_studio_only_error_sending_tests then
		if isServer() then
			module.Error("test error sent from server")
		else
			module.Error("test error sent from client")
		end
	end
end

return module
