--!strict

--localfunctions used for local script communication about settings changes.
--if you care, register to listen
--and the settings ui will spam you

--TODO what happens if you call this from server context?
-- TODO 2024 - doesn't it seem like these settings changes should really be communicated via a bindable event? rather than my custom registrartion/monitoring system?

--i.e. one local ui to another.  this is likely not the ideal method.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local tt = require(game.ReplicatedStorage.types.gametypes)
local remotes = require(game.ReplicatedStorage.util.remotes)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)

local module = {}

--local listeners send callbacks here for notification when other local settings changers change a setting, or when server receives the change.
--TODO why do i have both methods?
--TODO this is unsafe for player death but because of the way name overlapping works, we just replace re-registrations

-- this NAME is just a placeholder for managing the settings handlers? rather than being the actual in-db name.
local settingChangeFunctions: { [string]: (tt.userSettingValue) -> nil } = {}
module.registerLocalSettingChangeReceiver = function(func: (tt.userSettingValue) -> nil, name: string)
	-- let's make sure we're registering a setting which exists in the enums and things.

	local exi = false
	for settingCodeName, textName in pairs(settingEnums.settingNames) do
		if textName == name then
			exi = true
			break
		end
	end

	if not exi then
		warn("trying to register a setting change receiver with a name that doesn't exist: " .. name)
		return
	end
	settingChangeFunctions[name] = func
end

--also just tell registered scripts this change happened
local function LocalNotifySettingChange(setting: tt.userSettingValue)
	for name: string, funcWhichCaresAboutThisSettingChange: (tt.userSettingValue) -> nil in
		pairs(settingChangeFunctions)
	do
		if setting.name == name then
			funcWhichCaresAboutThisSettingChange(setting)
		end
	end
end

local GetUserSettingsFunction: RemoteFunction = remotes.getRemoteFunction("GetUserSettingsFunction")

--2024 is this safe to globally just use? like, in the chat toggler can I hit this and get some kind of useful or at least
-- not super slow/not missing data way to get the current value?
module.getSettingByName = function(settingName: string): tt.userSettingValue
	local req: settingEnums.settingRequest = { settingName = settingName, includeDistributions = false }
	return GetUserSettingsFunction:InvokeServer(req)
end

module.getSettingByDomain = function(domain: string): { [string]: tt.userSettingValue }
	local req: settingEnums.settingRequest = { domain = domain, includeDistributions = false }
	return GetUserSettingsFunction:InvokeServer(req)
end

local UserSettingsChangedFunction = remotes.getRemoteFunction("UserSettingsChangedFunction") :: RemoteFunction

module.setSetting = function(setting: tt.userSettingValue)
	UserSettingsChangedFunction:InvokeServer(setting)
	LocalNotifySettingChange(setting)
end

_annotate("end")
return module
