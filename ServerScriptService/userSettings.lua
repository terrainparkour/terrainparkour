--!strict

-- userSettings settings lookup on server

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

local getUserSettingsFunction: RemoteFunction = remotes.getRemoteFunction("GetUserSettingsFunction")
local userSettingsChangedFunction: RemoteFunction = remotes.getRemoteFunction("UserSettingsChangedFunction")

local module = {}

local userSettingsCache: { [number]: { [string]: tt.userSettingValue } } = {}

--2022.10
--note these are filled in and returned to users when the user has no stored value.
--note "value" means default here.
local defaultSettingsValues: { tt.userSettingValue } = {
	--a real impactful user setting
	{
		name = settingEnums.settingNames.HIDE_LEADERBOARD,
		domain = settingEnums.settingDomains.USERSETTINGS,
		value = false,
	},
	{
		name = settingEnums.settingNames.ROTATE_PLAYER_ON_WARP_WHEN_DESTINATION,
		domain = settingEnums.settingDomains.USERSETTINGS,
		value = true,
	},
	{
		name = settingEnums.settingNames.SHORTEN_CONTEST_DIGIT_DISPLAY,
		domain = settingEnums.settingDomains.USERSETTINGS,
		value = true,
	},
	{
		name = settingEnums.settingNames.ENABLE_DYNAMIC_RUNNING,
		domain = settingEnums.settingDomains.USERSETTINGS,
		value = true,
	},
	{
		name = settingEnums.settingNames.X_BUTTON_IGNORES_CHAT,
		domain = settingEnums.settingDomains.USERSETTINGS,
		value = true,
	},
	{
		name = settingEnums.settingNames.HIGHLIGHT_ON_RUN_COMPLETE_WARP,
		domain = settingEnums.settingDomains.USERSETTINGS,
		value = true,
	},
	{
		name = settingEnums.settingNames.HIGHLIGHT_ON_KEYBOARD_1_TO_WARP,
		domain = settingEnums.settingDomains.USERSETTINGS,
		value = true,
	},
	{
		name = settingEnums.settingNames.HIGHLIGHT_AT_ALL,
		domain = settingEnums.settingDomains.USERSETTINGS,
		value = true,
	},

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
	{ name = "enable find500", domain = settingEnums.settingDomains.MARATHONS },
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
	{ name = "should the game have more ice", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "should the game have fewer signs", domain = settingEnums.settingDomains.SURVEYS },
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
	{ name = "have you beaten factorio", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "have you played slay the spire", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "have you beaten slay the spire ascension 20", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "more special signs", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "more limited signs", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "moveable signs", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "more lava", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "more ice", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "more players", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "more advertisements", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "more sounds", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "more music", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "more configuration options", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "more UIs", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "more commands", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "more user generated content", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "Verv will get better", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "you like ai", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "you have tried midjourney", domain = settingEnums.settingDomains.SURVEYS },
	{ name = "you have used chatGPT", domain = settingEnums.settingDomains.SURVEYS },
}

--copy a setting based on template default.
local function copySetting(setting: tt.userSettingValue): tt.userSettingValue
	local res: tt.userSettingValue = { name = setting.name, domain = setting.domain, value = setting.value }
	return res
end

local debounceInnerSetup = false

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
		end
	end

	debounceInnerSetup = false
	return userSettingsCache[userId]
end

local getUserSettingByName = function(player: Player, settingName: string): tt.userSettingValue
	local userSettings = innerSetupSettings(player, "getUserSettingByName " .. settingName)
	for _, s in userSettings do
		if s.name == settingName then
			return s
		end
	end
	error("missing setting of name " .. settingName)
end

local getUserSettingsByDomain = function(player: Player, domain: string): { [string]: tt.userSettingValue }
	local userSettings = innerSetupSettings(player, "getUserSettingsByDomain " .. domain)
	local res = {}
	for _, s in pairs(userSettings) do
		if s.domain == domain then
			res[s.name] = s
		end
	end
	return res
end

module.getUserSettingsRouter = function(player: Player, data: settingEnums.settingRequest): any
	if data.includeDistributions then
		if data.domain == settingEnums.settingDomains.SURVEYS then
			local got = rdb.getSurveyResults(player.UserId)

			return got
		else
			error("cant get distributions for other settings.")
		end
	end
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

	local res = rdb.updateSettingForUser(userId, setting.value, setting.name, setting.domain)
	userSettingsCache[userId][setting.name] = setting

	grantBadge.GrantBadge(userId, badgeEnums.badges.TakeSurvey)
	local ct = 0
	for _, item: tt.userSettingValue in userSettingsCache[userId] do
		if item.domain ~= settingEnums.settingDomains.SURVEYS then
			continue
		end
		if item.value ~= nil then
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
	getUserSettingsFunction.OnServerInvoke = module.getUserSettingsRouter

	userSettingsChangedFunction.OnServerInvoke = function(player: Player, setting: tt.userSettingValue)
		return userChangedSettingFromUI(player.UserId, setting)
	end
end

_annotate("end")
return module
