--!strict
--eval 9.25.22

--settings lookup on server

local rdb = require(game.ServerScriptService.rdb)
local tt = require(game.ReplicatedStorage.types.gametypes)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)

local module = {}

local doAnnotation = false
local function annotate(s: string)
	if doAnnotation then
		print("playerSettings.server: " .. string.format("%.0f", tick()) .. " : " .. s)
	end
end

-- TODO product goals 2022.10
-- get all settings for user
-- get all by domain
-- get single setting
-- theoretically more efficient to have scoping
-- v2 goal: control defaults / rollouts dynamically from server?

-- 2022.10 summary of settings control flows
-- initial load: callers ask for things. comes here, overlay defaults on values stored in server
-- user changes setting - shows up here for saving, AND UI in localscript changing it directly notifies other localscripts what's going on via localFunctions

--centralized, in-memory user-settings cache
-- product of: 1) get all from server 2) combine with default 3) return.
-- note: CAN be incomplete for a user if the request were only for one domain or setting value.
local userSettingsCache: { [number]: { [string]: tt.userSettingValue } } = {}

--2022.10
--note these are filled in and returned to users when the user has no stored value.
--note "value" means default here.
local defaultSettingsValues: { tt.userSettingValue } = {
	{ name = "enable alphafree", domain = settingEnums.settingDomains.MARATHONS },
	{ name = "enable alphaordered", domain = settingEnums.settingDomains.MARATHONS },
	{ name = "enable alphareverse", domain = settingEnums.settingDomains.MARATHONS },
	{ name = "enable alphabeticalallletters", domain = settingEnums.settingDomains.MARATHONS },

	{ name = "enable find4", domain = settingEnums.settingDomains.MARATHONS },
	{ name = "enable find10", domain = settingEnums.settingDomains.MARATHONS },
	{ name = "enable find20", domain = settingEnums.settingDomains.MARATHONS },
	{ name = "enable find40", domain = settingEnums.settingDomains.MARATHONS },
	{ name = "enable find100", domain = settingEnums.settingDomains.MARATHONS },
	{ name = "enable find200", domain = settingEnums.settingDomains.MARATHONS },
	{ name = "enable find300", domain = settingEnums.settingDomains.MARATHONS },
	{ name = "enable find380", domain = settingEnums.settingDomains.MARATHONS },
	{ name = "enable find10s", domain = settingEnums.settingDomains.MARATHONS },
	{ name = "enable find10t", domain = settingEnums.settingDomains.MARATHONS },
	{ name = "enable exactly40letters", domain = settingEnums.settingDomains.MARATHONS },
	{ name = "enable exactly100letters", domain = settingEnums.settingDomains.MARATHONS },
	{ name = "enable exactly200letters", domain = settingEnums.settingDomains.MARATHONS },
	{ name = "enable exactly500letters", domain = settingEnums.settingDomains.MARATHONS },
	{ name = "enable exactly1000letters", domain = settingEnums.settingDomains.MARATHONS },
	{ name = "enable signsofeverylength", domain = settingEnums.settingDomains.MARATHONS },
	{ name = "enable findsetevolution", domain = settingEnums.settingDomains.MARATHONS },
	{ name = "enable findsetsingleletter", domain = settingEnums.settingDomains.MARATHONS },
	{ name = "enable findsetfirstcontest", domain = settingEnums.settingDomains.MARATHONS },
	{ name = "enable findsetlegacy", domain = settingEnums.settingDomains.MARATHONS },
	{ name = "enable findsetcave", domain = settingEnums.settingDomains.MARATHONS },
	{ name = "enable findsetaofb", domain = settingEnums.settingDomains.MARATHONS },
	{ name = "enable findsetthreeletter", domain = settingEnums.settingDomains.MARATHONS },

	{ name = "have you played trackmania", domain = settingEnums.settingDomains.SURVEYS },
	{
		name = "have you played roblox for more than 5 years",
		domain = settingEnums.settingDomains.SURVEYS,
	},
	{ name = "should the game have more badges", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "have you found the chomik", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "should the game have more signs", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "should the game have more new areas", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "should the game have more marathons", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "should the game have more water areas", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "should the game have more surveys", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "should the game have more settings", domain = settingEnums.settingDomains.SURVEYS },
	{
		name = "should the game disable popups of other user activity",
		domain = settingEnums.settingDomains.SURVEYS,
	},
	{ name = "do you play find the chomiks", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "do you play jtoh", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "do you know who shedletsky is", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "blame john", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "birb", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "cold mold on a slate plate", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "have you played for more than a year", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "have you played among us", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "have you played factorio", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "have you played slay the spire", domain = settingEnums.settingDomains.SURVEYS },

	--a real impactful user setting
	{
		name = settingEnums.settingNames.HIDE_LEADERBOARD,
		domain = settingEnums.settingDomains.USERSETTINGS,
		value = false,
	},
	{
		name = settingEnums.settingNames.SHORTEN_CONTEST_DIGIT_DISPLAY,
		domain = settingEnums.settingDomains.USERSETTINGS,
		value = true,
	},
	{
		name = settingEnums.settingNames.ENABLE_DYNAMIC_RUNNING,
		domain = settingEnums.settingDomains.USERSETTINGS,
		value = false,
	},
}

--copy a setting based on template default.
local function copySetting(setting: tt.userSettingValue): tt.userSettingValue
	local res: tt.userSettingValue = { name = setting.name, domain = setting.domain, value = setting.value }
	return res
end

local debounceInnerSetup = false

local function innerSetupSettings(player: Player): { [string]: tt.userSettingValue }
	while debounceInnerSetup do
		print("wait.")
		wait()
	end
	debounceInnerSetup = true
	local userId = player.UserId

	-- if missing, one-time get.
	if userSettingsCache[userId] == nil then
		userSettingsCache[userId] = {}
		local got = rdb.getSettingsForUser(userId)

		-- note this allows settings from db which no longer exist in code. hmm.
		for _, setting in pairs(got.res) do
			userSettingsCache[userId][setting.name] = setting
		end
		for _, defaultSetting in ipairs(defaultSettingsValues) do
			--if user has no value from db, fill one in in cache at least so callers see it.
			if userSettingsCache[userId][defaultSetting.name] == nil then
				userSettingsCache[userId][defaultSetting.name] = copySetting(defaultSetting)
			end

			--TODO optionally should we store these in BE?  might be nice, then we'd know we served fake defaults to a user
		end
	end

	debounceInnerSetup = false
	return userSettingsCache[userId]
end

module.getUserSettingByName = function(player: Player, settingName: string): tt.userSettingValue
	local userSettings = innerSetupSettings(player)
	for _, s in userSettings do
		if s.name == settingName then
			return s
		end
	end
	error("missing setting of name " .. settingName)
end

module.getUserSettingsByDomain = function(player: Player, domain: string): { [string]: tt.userSettingValue }
	local userSettings = innerSetupSettings(player)
	local res = {}
	for _, s in pairs(userSettings) do
		if s.domain == domain then
			res[s.name] = s
		end
	end
	return res
end

module.getUserSettingsRouter = function(player: Player, domain: string?, settingName: string?): any
	if domain ~= nil and domain ~= "" then
		return module.getUserSettingsByDomain(player, domain)
	end

	if settingName ~= nil and settingName ~= "" then
		return module.getUserSettingByName(player, settingName)
	end

	local userSettings = innerSetupSettings(player)
	return userSettings
end

local function userChangedSettingFromUI(userId: number, setting: tt.userSettingValue)
	if userSettingsCache[userId] == nil then
		warn("empty should not happen")
		userSettingsCache[userId] = {}
	end
	rdb.updateSettingForUser(userId, setting.value, setting.name, setting.domain)
	userSettingsCache[userId][setting.name] = setting
end

module.init = function()
	local rf = require(game.ReplicatedStorage.util.remotes)
	local getUserSettingsFunction = rf.getRemoteFunction("GetUserSettingsFunction") :: RemoteFunction
	getUserSettingsFunction.OnServerInvoke = module.getUserSettingsRouter

	local userSettingsChangedFunction = rf.getRemoteFunction("UserSettingsChangedFunction")
	userSettingsChangedFunction.OnServerInvoke = function(player: Player, setting: tt.userSettingValue)
		return userChangedSettingFromUI(player.UserId, setting)
	end
end

return module
