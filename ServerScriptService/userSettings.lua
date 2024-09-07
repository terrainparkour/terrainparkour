--!strict

-- userSettings.lua settings

-- TODO product goals 2022.10
-- get all settings for user
-- get all by domain
-- get single setting
-- theoretically more efficient to have scoping
-- v2 goal: control defaults / rollouts dynamically from server?

-- 2022.10 summary of settings control flows
-- initial load: callers ask for things. comes here, overlay defaults on values stored in server
-- user changes setting - shows up here for saving, AND UI in localscript changing it directly notifies other localscripts what's going on via settings

--centralized, in-memory user-settings cache
-- product of: 1) get all from server 2) combine with default 3) return.
-- note: CAN be incomplete for a user if the request were only for one domain or setting value.
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local rdb = require(game.ServerScriptService.rdb)
local tt = require(game.ReplicatedStorage.types.gametypes)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local grantBadge = require(game.ServerScriptService.grantBadge)
local badgeEnums = require(game.ReplicatedStorage.util.badgeEnums)

local remotes = require(game.ReplicatedStorage.util.remotes)

local GetUserSettingsFunction: RemoteFunction = remotes.getRemoteFunction("GetUserSettingsFunction")
local userSettingsChangedFunction: RemoteFunction = remotes.getRemoteFunction("UserSettingsChangedFunction")

local module = {}

local userSettingsCache: { [number]: { [string]: tt.userSettingValue } } = {}

--copy a setting based on template default.
local function copySetting(setting: tt.userSettingValue): tt.userSettingValue
	if setting.kind == "boolean" then
		local res: tt.userSettingValue = {
			name = setting.name,
			domain = setting.domain,
			kind = setting.kind,
			booleanValue = setting.defaultBooleanValue,
		}
		return res
	elseif setting.kind == "string" then
		local res: tt.userSettingValue = {
			name = setting.name,
			domain = setting.domain,
			kind = setting.kind,
			stringValue = setting.defaultStringValue,
		}
		return res
	else
		error("unknown kind " .. setting.kind)
	end
end

local debounceInnerSetup = false

local function isSettingDefined(setting: tt.userSettingValue): boolean
	for a, b in pairs(settingEnums.settingDefinitions) do
		if b.name == setting.name then
			return true
		end
	end
	return false
end

--just call this to get settings and it will handle caching.
--src is just for debugging.
local function innerSetupSettings(player: Player, src: string): { [string]: tt.userSettingValue }
	while debounceInnerSetup do
		_annotate("settings.innersetup.wait " .. src)
		wait(0.05)
	end
	debounceInnerSetup = true
	local userId = player.UserId

	-- if missing, one-time get.
	if userSettingsCache[userId] == nil then
		_annotate("innerSetupSettings there was no cache for this user., userId=" .. userId)
		userSettingsCache[userId] = {}
		local got = rdb.GetSettingsForUser(userId) :: { [string]: tt.userSettingValue }

		local actuallyDefinedSettings: { [string]: tt.userSettingValue } = {}
		for _, returnedSettingFromRemoteDb in pairs(got.res) do
			if isSettingDefined(returnedSettingFromRemoteDb) then
				actuallyDefinedSettings[returnedSettingFromRemoteDb.name] = returnedSettingFromRemoteDb
			else
				_annotate(
					"innerSetupSettings got setting that isn't actually defined? " .. returnedSettingFromRemoteDb.name
				)
				continue
			end
		end

		_annotate(string.format("innerSetupSettings got %d settings for user from db. userId=%d", #got.res, userId))
		-- note this allows settings from db which no longer exist in code. hmm.
		for _, setting in pairs(actuallyDefinedSettings) do
			_annotate(
				string.format(
					"innerSetupSettings got setting: %s %s. kind=%s bool=%s str=%s",
					setting.name,
					setting.domain,
					tostring(setting.kind),
					tostring(setting.booleanValue),
					tostring(setting.stringValue)
				)
			)
			userSettingsCache[userId][setting.name] = setting
		end
		for _, defaultSetting in pairs(settingEnums.settingDefinitions) do
			--if user has no value from db, fill one in in cache at least so callers see it.
			if userSettingsCache[userId][defaultSetting.name] == nil then
				_annotate(
					string.format(
						"innerSetupSettings creating default setting: %s %s",
						defaultSetting.name,
						defaultSetting.domain
					)
				)
				userSettingsCache[userId][defaultSetting.name] = copySetting(defaultSetting)
			end
		end
	end

	debounceInnerSetup = false
	_annotate(
		string.format("Returning settings combined real & filled-in from defaults: %d", #userSettingsCache[userId])
	)
	return userSettingsCache[userId]
end

local getUserSettingByName = function(player: Player, settingName: string): tt.userSettingValue
	local userSettings = innerSetupSettings(player, "getUserSettingByName " .. settingName)
	_annotate("trying to find a setting by name: " .. settingName)
	for _, s in userSettings do
		_annotate(
			string.format(
				"evaluating setting: %s %s. kind=%s bool=%s str=%s",
				s.name,
				s.domain,
				tostring(s.kind),
				tostring(s.booleanValue),
				tostring(s.stringValue)
			)
		)
		if s.name == settingName then
			return s
		end
	end
	error("missing setting of name " .. settingName)
end

-- if you get a missing setting for a user, we just store it in server memory. if they CHANGE it, we actually store to dbserver. otherwise
-- it only exists on the game server. and that's okay?
local getUserSettingsByDomain = function(player: Player, domain: string): { [string]: tt.userSettingValue }
	_annotate("getUserSettingsByDomain " .. domain)
	local userSettings: { [string]: tt.userSettingValue } =
		innerSetupSettings(player, "getUserSettingsByDomain " .. domain)
	local res = {}

	-- note that these are loaded directly from the db, without any attempt currently to coerce them into the list of actually
	-- currently valid settinsg wtihing settingEnums. This is a mistake since during development or change, it would result
	-- in returning settings to user / server code which no longer exist.
	for _, s in pairs(userSettings) do
		_annotate(
			string.format(
				"evaluating setting for domain inclusion:: %s %s. kind=%s bool=%s str=%s",
				s.name,
				s.domain,
				tostring(s.kind),
				tostring(s.booleanValue),
				tostring(s.stringValue)
			)
		)
		if s.domain == domain then
			res[s.name] = s
		end
	end
	return res
end

module.GetUserSettingsRouter = function(player: Player, data: settingEnums.settingRequest): any
	local msg = string.format("GetUserSettingsRouter, request=%s %s", tostring(data.domain), tostring(data.settingName))
	_annotate(msg)
	if data.domain ~= nil and data.domain ~= "" then
		return getUserSettingsByDomain(player, data.domain)
	end

	if data.settingName ~= nil and data.settingName ~= "" then
		return getUserSettingByName(player, data.settingName)
	end

	local userSettings = innerSetupSettings(player, "getUserSettingsRouter.all")
	return userSettings
end

local function userChangedSettingFromUI(userId: number, setting: tt.userSettingValue): any
	if userSettingsCache[userId] == nil then
		error("empty should not happen")
	end

	local res =
		rdb.UpdateSettingForUser(userId, setting.name, setting.domain, setting.booleanValue, setting.stringValue)
	userSettingsCache[userId][setting.name] = setting
	grantBadge.GrantBadge(userId, badgeEnums.badges.TakeSurvey)
	local ct = 0
	for _, item: tt.userSettingValue in userSettingsCache[userId] do
		if item.domain ~= settingEnums.settingDomains.SURVEYS then
			continue
		end
		if item.booleanValue ~= nil then
			ct += 1
		end
		if ct > 20 then
			grantBadge.GrantBadge(userId, badgeEnums.badges.SurveyKing)
			break
		end
	end
	return res
end

module.Init = function()
	GetUserSettingsFunction.OnServerInvoke = module.GetUserSettingsRouter

	userSettingsChangedFunction.OnServerInvoke = function(player: Player, setting: tt.userSettingValue)
		return userChangedSettingFromUI(player.UserId, setting)
	end

	-- TODO this is overkill right now.
	-- on startup I should hit the server for each of these that are new at least.
	for _, setting: tt.userSettingValue in pairs(settingEnums.settingDefinitions) do
		-- hit server for some of them.
		-- MAGIC this just hits the server, creating all missing settings, if needed.
		if setting.domain == settingEnums.settingDomains.LEADERBOARD then
			local data = { domain = setting.domain, name = setting.name }
			if setting.kind == "boolean" then
				rdb.GetOrCreateBooleanSetting(data)
			elseif setting.kind == "string" then
				rdb.GetOrCreateStringSetting(data)
			end
		end
	end
end

_annotate("end")
return module
