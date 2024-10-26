--!strict

-- settings.lua in replicated storage.
-- settings used for local script communication about settings changes.
-- if you care, register to listen
-- and the settings ui will spam you

-- TODO what happens if you call this from server context?
-- TODO 2024 - doesn't it seem like these settings changes should really be communicated via a bindable event? rather than my custom registrartion/monitoring system?
-- 2024: I broke something about marathons where when a user is toggling a marathon on/off, we are failing to tell the marathon UI about it.

--i.e. one local ui to another.  this is likely not the ideal method.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local tt = require(game.ReplicatedStorage.types.gametypes)
local remotes = require(game.ReplicatedStorage.util.remotes)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local GetUserSettingsFunction: RemoteFunction = remotes.getRemoteFunction("GetUserSettingsFunction")
local UserSettingsChangedFunction = remotes.getRemoteFunction("UserSettingsChangedFunction") :: RemoteFunction
local localPlayer = game:GetService("Players").LocalPlayer
local module = {}

--local listeners send callbacks here for notification when other local settings changers change a setting, or when server receives the change.
--TODO why do i have both methods?
--TODO this is unsafe for player death but because of the way name overlapping works, we just replace re-registrations

-- listen to all setting changes by name
local settingChangeMonitoringFunctions: { [string]: (tt.userSettingValue) -> nil } = {}

-- listen by domain.
local domainSettingChangeMonitoringFunctions: { [string]: (tt.userSettingValue) -> nil } = {}

module.Reset = function()
	_annotate("RESET settings monitor functions!!")
	settingChangeMonitoringFunctions = {}
	domainSettingChangeMonitoringFunctions = {}
end

-- HandleMarathonSettingsChanged
-- if you care about an entire domain of settings, register the function here
module.RegisterFunctionToListenForDomain = function(func: (tt.userSettingValue) -> nil, listeningDomainName: string)
	local exi = false
	for _, domainName in pairs(settingEnums.settingDomains) do
		if domainName == listeningDomainName then
			exi = true
			break
		end
	end

	if not exi then
		_annotate(
			"trying to register a setting domain change receiver with a name that doesn't exist: "
				.. listeningDomainName
		)

		annotater.Error(
			string.format(
				"trying to register a setting domain change receiver with a name that doesn't exist: %s",
				listeningDomainName
			)
		)

		return
	end
	_annotate(string.format("successfully registered domain listnerer for: %s %s", listeningDomainName, tostring(func)))
	domainSettingChangeMonitoringFunctions[listeningDomainName] = func
end

-- anyone who wants to be told that a specific setting has changed can register here by saying like:
-- when this setting changes, call this function.
-- big problem: I think this can only have one handle listening per setting. Easy to fix, just haven't done it yet. watch out if things are confusing.
-- source is your unique source id so we can muli-monitor.
module.RegisterFunctionToListenForSettingName = function(
	func: (tt.userSettingValue) -> nil,
	name: string,
	source: string
)
	-- let's make sure we're registering a setting which exists in the enums and things.
	_annotate(string.format("Register setting listener for: %s", name))
	local exi = false
	for _, setting in pairs(settingEnums.settingDefinitions) do
		if setting.name == name then
			exi = true
			break
		end
	end

	if not exi then
		_annotate("trying to register a setting change receiver with a name that doesn't exist: " .. name)
		warn("trying to register a setting change receiver with a name that doesn't exist: " .. name)
		return
	end

	local nameKey = name .. "|" .. source

	if settingChangeMonitoringFunctions[nameKey] ~= nil then
		_annotate(string.format("trying to reset monitoring for setting which is already monitored. %s", name))
		annotater.Error(string.format("trying to reset monitoring for setting which is already monitored. %s", name))
		return
	end

	settingChangeMonitoringFunctions[nameKey] = func
	_annotate(string.format("registered: %s to listen to setting named: %s", nameKey, name))
end

--also just tell registered scripts this change happened
local function LocalNotifySettingChange(setting: tt.userSettingValue)
	if setting.kind == settingEnums.settingKinds.BOOLEAN then
		_annotate(string.format("LocalNotifySettingChange: %s %s", setting.name, tostring(setting.booleanValue)))
	elseif setting.kind == settingEnums.settingKinds.STRING then
		_annotate(string.format("LocalNotifySettingChange: %s %s", setting.name, tostring(setting.stringValue)))
	end
	for nameKey: string, funcWhichCaresAboutThisSettingChange: (tt.userSettingValue) -> nil in
		pairs(settingChangeMonitoringFunctions)
	do
		local name = nameKey:split("|")[1]
		if setting.name == name then
			_annotate("APPLY " .. tostring(name) .. " " .. tostring(funcWhichCaresAboutThisSettingChange))
			funcWhichCaresAboutThisSettingChange(setting)
		end
	end

	for domainName, funcWhichCaresAboutThisSettingChange in pairs(domainSettingChangeMonitoringFunctions) do
		if setting.domain == domainName then
			funcWhichCaresAboutThisSettingChange(setting)
		end
	end
end

--2024 is this safe to globally just use? like, in the chat toggler can I hit this and get some kind of useful or at least
-- not super slow/not missing data way to get the current value?
module.GetSettingByName = function(settingName: string): tt.userSettingValue
	local req: settingEnums.settingRequest = { settingName = settingName }
	local theSetting = GetUserSettingsFunction:InvokeServer(req)
	return theSetting
end

module.GetSettingByDomain = function(domain: string): { [string]: tt.userSettingValue }
	local req: settingEnums.settingRequest = { domain = domain }
	local theSetting = GetUserSettingsFunction:InvokeServer(req)
	return theSetting
end

module.GetSettingByDomainAndKind = function(domain: string, kind: string): { [string]: tt.userSettingValue }
	local req: settingEnums.settingRequest = { domain = domain, kind = kind }
	local theSetting = GetUserSettingsFunction:InvokeServer(req)
	return theSetting
end

module.SetSetting = function(setting: tt.userSettingValue): tt.setSettingResponse
	local serverRes: tt.setSettingResponse = UserSettingsChangedFunction:InvokeServer(setting)
	if serverRes and serverRes ~= nil then
		LocalNotifySettingChange(setting)
	else
		local error = serverRes and serverRes.error or "nothing returned at all.."
		warn(
			string.format("failed to set setting: %s %s %d %s", setting.name, setting.domain, localPlayer.UserId, error)
		)
	end

	return serverRes
end

_annotate("end")
return module
