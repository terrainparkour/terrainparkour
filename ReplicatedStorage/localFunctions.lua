--!strict

--eval 9.25.22

--localfunctions used for local script communication about settings changes.
--if you care, register to listen
--and the settings ui will spam you

--TODO what happens if you call this from server context?

--i.e. one local ui to another.  this is likely not the ideal method.

local tt = require(game.ReplicatedStorage.types.gametypes)
local remotes = require(game.ReplicatedStorage.util.remotes)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)

local module = {}

--local listeners send callbacks here for notification when other local settings changers change a setting, or when server receives the change.
--TODO why do i have both methods?
--TODO this is unsafe for player death but because of the way name overlapping works, we just replace re-registrations
local settingChangeFunctions: { [string]: (tt.userSettingValue) -> nil } = {}
module.registerLocalSettingChangeReceiver = function(func: (tt.userSettingValue) -> nil, name: string)
	if settingChangeFunctions[name] ~= nil then
		warn("reregistering setting change warning for " .. name)
	end
	settingChangeFunctions[name] = func
end

--also just tell registered scripts this change happened
local function localNotifySettingChange(setting: tt.userSettingValue)
	for name: string, otherFunc: (tt.userSettingValue) -> nil in pairs(settingChangeFunctions) do
		otherFunc(setting)
	end
end

local getUserSettingsFunction: RemoteFunction = remotes.getRemoteFunction("GetUserSettingsFunction")

module.getSettingByName = function(settingName: string): tt.userSettingValue
	local req: settingEnums.settingRequest = { settingName = settingName, includeDistributions = false }
	return getUserSettingsFunction:InvokeServer(req)
end

module.getSettingByDomain = function(domain: string): { [string]: tt.userSettingValue }
	local req: settingEnums.settingRequest = { domain = domain, includeDistributions = false }
	return getUserSettingsFunction:InvokeServer(req)
end

local userSettingsChangedFunction = remotes.getRemoteFunction("UserSettingsChangedFunction") :: RemoteFunction

module.setSetting = function(setting: tt.userSettingValue)
	userSettingsChangedFunction:InvokeServer(setting)
	localNotifySettingChange(setting)
end

return module
