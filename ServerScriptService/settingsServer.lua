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
local enums = require(game.ReplicatedStorage.util.enums)
local rdb = require(game.ServerScriptService.rdb)
local tt = require(game.ReplicatedStorage.types.gametypes)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local grantBadge = require(game.ServerScriptService.grantBadge)
local badgeEnums = require(game.ReplicatedStorage.util.badgeEnums)
local lua2Json = require(game.ReplicatedStorage.util.lua2Json)

local HttpService = game:GetService("HttpService")

local remotes = require(game.ReplicatedStorage.util.remotes)

local GetUserSettingsFunction: RemoteFunction = remotes.getRemoteFunction("GetUserSettingsFunction")
local UserSettingsChangedFunction: RemoteFunction = remotes.getRemoteFunction("UserSettingsChangedFunction")

local module = {}

local userSettingsCache: { [number]: { [string]: tt.userSettingValue } } = {}

--when the server is setting up a user's settings, we get the ones from the db and filter for the ones that are still live (i.e. have  adefinition)
-- THEN we add fake ones, from the definitions file, for ones which ARE defined but do NOT have a db entry yet.
local function copySetting(setting: tt.userSettingValue): tt.userSettingValue
	if setting.kind == settingEnums.settingKinds.BOOLEAN then
		local res: tt.userSettingValue = {
			name = setting.name,
			domain = setting.domain,
			kind = setting.kind,
			booleanValue = setting.defaultBooleanValue,
		}
		return res
	elseif setting.kind == settingEnums.settingKinds.STRING then
		local res: tt.userSettingValue = {
			name = setting.name,
			domain = setting.domain,
			kind = setting.kind,
			stringValue = setting.defaultStringValue,
		}
		return res
	elseif setting.kind == settingEnums.settingKinds.LUA then
		local res: tt.userSettingValue = {
			name = setting.name,
			domain = setting.domain,
			kind = setting.kind,
			luaValue = setting.defaultLuaValue,
		}
		return res
	else
		annotater.Error("unknown kind " .. setting.kind)
		error("unknown kind " .. setting.kind)
	end
end

local getAllSettingsForUser = function(userId: number)
	local request: tt.postRequest = {
		remoteActionName = "getAllSettingsForUser",
		data = { userId = userId },
	}
	local res = rdb.MakePostRequest(request)

	for a, b in ipairs(res) do
		if b.kind == settingEnums.settingKinds.LUA then
			-- we have to reconvert it back to lua!
			local theVal = b.luaValue
			-- local tt = type(theVal)
			local theVal2 = HttpService:JSONDecode(theVal)
			b.luaValue = lua2Json.StringTable2Lua(theVal2)
		end
	end
	-- if one of them is actually a lua setting but stored in a string setting, we need to adjust the place the value is stored.
	return res
end

local getOrCreateBooleanSetting = function(setting: tt.userSettingValue)
	local request: tt.postRequest = {
		remoteActionName = "getOrCreateBooleanSetting",
		data = {
			setting = setting,
		},
	}

	return rdb.MakePostRequest(request)
end

local getOrCreateStringSetting = function(setting: tt.userSettingValue)
	local request: tt.postRequest = {
		remoteActionName = "getOrCreateStringSetting",
		data = {
			setting = setting,
		},
	}
	return rdb.MakePostRequest(request)
end

-- this JUST creates the setting, NOT the userSetting.
local getOrCreateLuaSetting = function(setting: tt.userSettingValue)
	local request: tt.postRequest = {
		remoteActionName = "getOrCreateLuaSetting",
		data = {
			setting = setting,
		},
	}

	return rdb.MakePostRequest(request)
end

local debounceInnerSetup = false

local function doesSettingHaveDefinition(setting: tt.userSettingValue): boolean
	for _, aSettingDefinition: tt.userSettingValue in pairs(settingEnums.settingDefinitions) do
		if aSettingDefinition.name == setting.name then
			return true
		end
	end
	return false
end

local updateLuaSettingForUser = function(userId: number, setting: tt.userSettingValue): tt.setSettingResponse
	local modifiedSetting: tt.userSettingValue = {
		name = setting.name,
		domain = setting.domain,
		kind = setting.kind,
		luaValue = HttpService:JSONEncode(lua2Json.Lua2StringTable(setting.luaValue)),
	}

	local request: tt.postRequest = {
		remoteActionName = "updateLuaSettingForUser",
		data = {
			userId = userId,
			setting = modifiedSetting,
		},
	}

	return rdb.MakePostRequest(request)
end

local updateStringSettingForUser = function(userId: number, setting: tt.userSettingValue): tt.setSettingResponse
	local request: tt.postRequest = {
		remoteActionName = "updateStringSettingForUser",
		data = {
			userId = userId,
			setting = setting,
		},
	}

	return rdb.MakePostRequest(request)
end

local updateBooleanSettingForUser = function(userId: number, setting: tt.userSettingValue): tt.setSettingResponse
	local request: tt.postRequest = {
		remoteActionName = "updateBooleanSettingForUser",
		data = {
			userId = userId,
			setting = setting,
		},
	}
	return rdb.MakePostRequest(request)
end

--just call this to get settings and it will handle caching.
--src is just for debugging.
local innerSetupSettings = function(player: Player, src: string): { [string]: tt.userSettingValue }
	while debounceInnerSetup do
		_annotate("settings.innersetup.wait " .. src)
		wait(0.05)
	end
	debounceInnerSetup = true
	local userId = player.UserId

	-- if missing, set up the cache.
	if userSettingsCache[userId] == nil then
		_annotate("innerSetupSettings there was no cache for this user., userId=" .. userId)
		userSettingsCache[userId] = {}
		local got = getAllSettingsForUser(userId) :: { [string]: tt.userSettingValue }
		if not got then
			annotater.Error("not got.")

			return {}
		end
		local actuallyDefinedSettings: { [string]: tt.userSettingValue } = {}
		local gotCt = 0
		for _, returnedSettingFromRemoteDb in pairs(got) do
			if doesSettingHaveDefinition(returnedSettingFromRemoteDb) then
				gotCt += 1
				actuallyDefinedSettings[returnedSettingFromRemoteDb.name] = returnedSettingFromRemoteDb
			else
				_annotate(
					string.format(
						"innerSetupSettings got setting that isn't actually defined. Possibly just a deprecated one left over in the db. %s. kind=%s",
						returnedSettingFromRemoteDb.name,
						returnedSettingFromRemoteDb.kind
					)
				)
				continue
			end
		end

		_annotate(string.format("innerSetupSettings got %d settings for user from db. userId=%d", gotCt, userId))
		-- note this allows settings from db which no longer exist in code. hmm.
		for _, setting in pairs(actuallyDefinedSettings) do
			-- _annotate(
			-- 	string.format(
			-- 		"innerSetupSettings got setting: %s %s. kind=%s bool=%s str=%s",
			-- 		setting.name,
			-- 		setting.domain,
			-- 		tostring(setting.kind),
			-- 		tostring(setting.booleanValue),
			-- 		tostring(setting.stringValue)
			-- 	)
			-- )
			userSettingsCache[userId][setting.name] = setting
		end

		--filling in cache now.
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
	_annotate(string.format("Returning settings combined real & filled-in from defaults"))
	return userSettingsCache[userId]
end

local getUserSettingByName = function(player: Player, settingName: string): tt.userSettingValue
	local userSettings = innerSetupSettings(player, "getUserSettingByName " .. settingName)
	_annotate("trying to find a setting by name: " .. settingName)
	for _, s in userSettings do
		-- _annotate(
		-- 	string.format(
		-- 		"evaluating setting: %s %s. kind=%s bool=%s str=%s",
		-- 		s.name,
		-- 		s.domain,
		-- 		tostring(s.kind),
		-- 		tostring(s.booleanValue),
		-- 		tostring(s.stringValue)
		-- 	)
		-- )
		if s.name == settingName then
			return s
		end
	end
	annotater.Error("missing setting of name " .. settingName)
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
	_annotate("userSettings get by domain=" .. domain)
	for _, s in pairs(userSettings) do
		_annotate(
			string.format(
				"evaluating setting for domain inclusion:: name=%s domain=%s kind=%s bool=%s str=%s",
				s.name,
				s.domain,
				tostring(s.kind),
				tostring(s.booleanValue),
				tostring(s.stringValue)
			)
		)
		if s.domain == domain then
			_annotate("included it.")
			res[s.name] = s
		else
			_annotate("did not include it.")
		end
	end
	return res
end

local filterByKind = function(
	settings: { [string]: tt.userSettingValue },
	kind: string
): { [string]: tt.userSettingValue }
	local res = {}
	for n, el in pairs(settings) do
		if el.kind == kind then
			res[n] = el
		end
	end
	return res
end

local getUserSettingsRouter = function(player: Player, settingRequest: settingEnums.settingRequest): any
	local msg = string.format(
		"GetUserSettingsRouter, domainrequest=%s settingNameRequest=%s",
		tostring(settingRequest.domain),
		tostring(settingRequest.settingName)
	)
	_annotate(msg)
	if settingRequest.domain ~= nil and settingRequest.domain ~= "" then
		local all = getUserSettingsByDomain(player, settingRequest.domain)
		if settingRequest.kind and settingRequest.kind ~= "" then
			all = filterByKind(all, settingRequest.kind)
		end
		return all
	end

	if settingRequest.settingName ~= nil and settingRequest.settingName ~= "" then
		local theSetting = getUserSettingByName(player, settingRequest.settingName)

		if settingRequest.kind and settingRequest.kind ~= "" then
			if theSetting.kind == settingRequest.kind then
				_annotate("setting kind match, so returning a setting named: " .. theSetting.name)
				return theSetting
			else
				_annotate("setting kind mismatch, failed to match kind for setting named: " .. theSetting.name)
				return nil
			end
		end

		-- _annotate("got a setting request with no kind, and got a name match, so returning it.")
		return theSetting
	end
	_annotate("falling through to return all settings. is this ever actually used??")
	local userSettings = innerSetupSettings(player, "getUserSettingsRouter.all")
	return userSettings
end

local function userChangedSettingFromUI(userId: number, setting: tt.userSettingValue): tt.setSettingResponse
	if userSettingsCache[userId] == nil then
		annotater.Error("empty should not happen")
	end
	local res: tt.setSettingResponse
	if setting.kind == settingEnums.settingKinds.BOOLEAN then
		_annotate("sending the update to boolean.")
		res = updateBooleanSettingForUser(userId, setting)
	elseif setting.kind == settingEnums.settingKinds.STRING then
		_annotate("sending the update to string")
		res = updateStringSettingForUser(userId, setting)
	elseif setting.kind == settingEnums.settingKinds.LUA then
		_annotate("sending the update to lua setting")
		res = updateLuaSettingForUser(userId, setting)
	else
		_annotate("unknown setting kind " .. setting.kind)
	end

	-- we should store *the one which was sent to us* not the one that was modified to be put on the wire.
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

module.SetSettingFromServer = function(player: Player, setting: tt.userSettingValue): tt.setSettingResponse
	return userChangedSettingFromUI(player.UserId, setting)
end

module.Init = function()
	_annotate("init")
	GetUserSettingsFunction.OnServerInvoke = getUserSettingsRouter

	UserSettingsChangedFunction.OnServerInvoke = function(player: Player, ...: any): tt.setSettingResponse
		local setting = select(1, ...) :: tt.userSettingValue
		return userChangedSettingFromUI(player.UserId, setting)
	end

	_annotate("init done")
end

local function doRemoteTest()
	local settingName = "ernie5"
	local setting: tt.userSettingValue = {
		name = settingName,
		domain = settingEnums.settingDomains.USERSETTINGS,
		kind = settingEnums.settingKinds.LUA,
		luaValue = {
			name = "test2",
			name2 = "smith2",
			b = true,
			c = { true, false, false, false, true },
			d = Vector3.new(2, 3, 4),
			e = CFrame.new(1, 2, 3),
		},
	}
	userSettingsCache[enums.objects.TerrainParkourUserId] = {}
	userChangedSettingFromUI(enums.objects.TerrainParkourUserId, setting)
	local setting2 =
		getUserSettingByName(game.Players:GetPlayerByUserId(enums.objects.TerrainParkourUserId), settingName)
	_annotate(tostring(setting2.luaValue))

	local allSettings = getAllSettingsForUser(enums.objects.TerrainParkourUserId)
	local regot = nil
	for _, el in pairs(allSettings) do
		if el.name == settingName then
			regot = el
		end
	end
end

-- doRemoteTest()

_annotate("end")
return module
