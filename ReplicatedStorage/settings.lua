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
end

module.UnregisterFunctionToListenForSettingName = function(name: string, source: string)
	local nameKey = name .. "|" .. source
	if settingChangeMonitoringFunctions[nameKey] then
		settingChangeMonitoringFunctions[nameKey] = nil
	end
end

-- also just tell registered scripts this change happened
local function LocalNotifySettingChange(setting: tt.userSettingValue)
	for nameKey: string, funcWhichCaresAboutThisSettingChange: (tt.userSettingValue) -> nil in
		pairs(settingChangeMonitoringFunctions)
	do
		local name = nameKey:split("|")[1]
		if setting.name == name then
			funcWhichCaresAboutThisSettingChange(setting)
		end
	end

	for domainName, funcWhichCaresAboutThisSettingChange in pairs(domainSettingChangeMonitoringFunctions) do
		if setting.domain == domainName then
			funcWhichCaresAboutThisSettingChange(setting)
		end
	end
end

module.GetSettingByName = function(settingName: string): tt.userSettingValue
	local startTime = tick()
	_annotate(string.format("GetSettingByName START: %s", settingName))
	
	local req: settingEnums.settingRequest = { settingName = settingName }
	local theSetting = GetUserSettingsFunction:InvokeServer(req)
	
	local elapsed = tick() - startTime
	_annotate(string.format("GetSettingByName DONE: %s took %.3fs", settingName, elapsed))
	
	return theSetting
end

module.GetSettingByDomain = function(domain: string): { [string]: tt.userSettingValue }
	local startTime = tick()
	_annotate(string.format("GetSettingByDomain START: %s", domain))
	
	local req: settingEnums.settingRequest = { domain = domain }
	local theSettings = GetUserSettingsFunction:InvokeServer(req)
	
	local elapsed = tick() - startTime
	local count = 0
	for _ in pairs(theSettings) do
		count = count + 1
	end
	_annotate(string.format("GetSettingByDomain DONE: %s took %.3fs (%d settings)", domain, elapsed, count))
	
	return theSettings
end

module.GetSettingByDomainAndKind = function(domain: string, kind: string): { [string]: tt.userSettingValue }
	local startTime = tick()
	_annotate(string.format("GetSettingByDomainAndKind START: %s %s", domain, kind))
	
	local req: settingEnums.settingRequest = { domain = domain, kind = kind }
	local theSettings = GetUserSettingsFunction:InvokeServer(req)
	
	local elapsed = tick() - startTime
	local count = 0
	for _ in pairs(theSettings) do
		count = count + 1
	end
	_annotate(string.format("GetSettingByDomainAndKind DONE: %s %s took %.3fs (%d settings)", domain, kind, elapsed, count))
	
	return theSettings
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
