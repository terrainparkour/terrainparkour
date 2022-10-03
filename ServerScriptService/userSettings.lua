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

local userSettingsCache: { [number]: { [string]: tt.userSettingValue } } = {}

--this serves both as a ui definition for the button
--and as a hook to look them up on serverside.
--everyone's setting will stay false unless they modify it at which point it'll be saved.
module.getUserSettings = function(player: Player, domain: string): any
	local userId = player.UserId

	local settings: { tt.userSettingValue } = {
		{ name = "enable alphafree", domain = settingEnums.settingDomains.Marathons },
		{ name = "enable alphaordered", domain = settingEnums.settingDomains.Marathons },
		{ name = "enable alphareverse", domain = settingEnums.settingDomains.Marathons },
		{ name = "enable alphabeticalallletters", domain = settingEnums.settingDomains.Marathons },

		{ name = "enable find4", domain = settingEnums.settingDomains.Marathons },
		{ name = "enable find10", domain = settingEnums.settingDomains.Marathons },
		{ name = "enable find20", domain = settingEnums.settingDomains.Marathons },
		{ name = "enable find40", domain = settingEnums.settingDomains.Marathons },
		{ name = "enable find100", domain = settingEnums.settingDomains.Marathons },
		{ name = "enable find200", domain = settingEnums.settingDomains.Marathons },
		{ name = "enable find300", domain = settingEnums.settingDomains.Marathons },
		{ name = "enable find380", domain = settingEnums.settingDomains.Marathons },
		{ name = "enable find10s", domain = settingEnums.settingDomains.Marathons },
		{ name = "enable find10t", domain = settingEnums.settingDomains.Marathons },
		{ name = "enable exactly40letters", domain = settingEnums.settingDomains.Marathons },
		{ name = "enable exactly100letters", domain = settingEnums.settingDomains.Marathons },
		{ name = "enable exactly200letters", domain = settingEnums.settingDomains.Marathons },
		{ name = "enable exactly500letters", domain = settingEnums.settingDomains.Marathons },
		{ name = "enable exactly1000letters", domain = settingEnums.settingDomains.Marathons },
		{ name = "enable signsofeverylength", domain = settingEnums.settingDomains.Marathons },
		{ name = "enable findsetevolution", domain = settingEnums.settingDomains.Marathons },
		{ name = "enable findsetsingleletter", domain = settingEnums.settingDomains.Marathons },
		{ name = "enable findsetfirstcontest", domain = settingEnums.settingDomains.Marathons },
		{ name = "enable findsetlegacy", domain = settingEnums.settingDomains.Marathons },
		{ name = "enable findsetcave", domain = settingEnums.settingDomains.Marathons },
		{ name = "enable findsetaofb", domain = settingEnums.settingDomains.Marathons },
		{ name = "enable findsetthreeletter", domain = settingEnums.settingDomains.Marathons },

		{ name = "have you played trackmania", domain = settingEnums.settingDomains.Surveys },
		{
			name = "have you played roblox for more than 5 years",
			domain = settingEnums.settingDomains.Surveys,
		},
		{ name = "should the game have more badges", domain = settingEnums.settingDomains.Surveys },
		{ name = "have you found the chomik", domain = settingEnums.settingDomains.Surveys },
		{ name = "should the game have more signs", domain = settingEnums.settingDomains.Surveys },
		{ name = "should the game have more new areas", domain = settingEnums.settingDomains.Surveys },
		{ name = "should the game have more marathons", domain = settingEnums.settingDomains.Surveys },
		{ name = "should the game have more water areas", domain = settingEnums.settingDomains.Surveys },
		{ name = "should the game have more surveys", domain = settingEnums.settingDomains.Surveys },
		{ name = "should the game have more settings", domain = settingEnums.settingDomains.Surveys },
		{
			name = "should the game disable popups of other user activity",
			domain = settingEnums.settingDomains.Surveys,
		},
		{ name = "do you play find the chomiks", domain = settingEnums.settingDomains.Surveys },
		{ name = "do you play jtoh", domain = settingEnums.settingDomains.Surveys },
		{ name = "do you know who shedletsky is", domain = settingEnums.settingDomains.Surveys },
		{ name = "blame john", domain = settingEnums.settingDomains.Surveys },
		{ name = "birb", domain = settingEnums.settingDomains.Surveys },
		{ name = "cold mold on a slate plate", domain = settingEnums.settingDomains.Surveys },
		{ name = "have you played for more than a year", domain = settingEnums.settingDomains.Surveys },
		{ name = "have you played among us", domain = settingEnums.settingDomains.Surveys },
		{ name = "have you played factorio", domain = settingEnums.settingDomains.Surveys },
		{ name = "have you played slay the spire", domain = settingEnums.settingDomains.Surveys },

		--a real impactful user setting
		{ name = "hide leaderboard", domain = settingEnums.settingDomains.UserSettings },
		{ name = "shorten contest digit display", domain = settingEnums.settingDomains.UserSettings, value = true },
	}

	--if missing, one-time get.
	if userSettingsCache[userId] == nil then
		userSettingsCache[userId] = {}
		local got = rdb.getSettingsForUser(userId)
		for _, setting in pairs(got.res) do
			userSettingsCache[userId][setting.name] = setting
		end
	end

	for _, setting in ipairs(settings) do
		local exisetting = userSettingsCache[userId][setting.name]

		if exisetting ~= nil then
			setting.value = exisetting.value
		end
	end
	return settings
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
	local userSettingsFunction = rf.getRemoteFunction("GetUserSettingsFunction") :: RemoteFunction
	userSettingsFunction.OnServerInvoke = module.getUserSettings

	local canUserSettingsChangedFunction = rf.getRemoteFunction("UserSettingsChangedFunction")
	if canUserSettingsChangedFunction ~= nil then
		local userSettingsChangedFunction = canUserSettingsChangedFunction :: RemoteFunction
		userSettingsChangedFunction.OnServerInvoke = function(player: Player, setting: tt.userSettingValue)
			return userChangedSettingFromUI(player.UserId, setting)
		end
	end
end

return module
