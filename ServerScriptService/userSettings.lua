--!strict
--eval 9.25.22

local rdb = require(game.ServerScriptService.rdb)
local tt = require(game.ReplicatedStorage.types.gametypes)

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
		{ name = "enable alphafree", domain = "Marathons", value = false },
		{ name = "enable alphaordered", domain = "Marathons", value = false },
		{ name = "enable alphareverse", domain = "Marathons", value = false },
		{ name = "enable alphabeticalallletters", domain = "Marathons", value = false },

		{ name = "enable find4", domain = "Marathons", value = false },
		{ name = "enable find10", domain = "Marathons", value = false },
		{ name = "enable find20", domain = "Marathons", value = false },
		{ name = "enable find40", domain = "Marathons", value = false },
		{ name = "enable find100", domain = "Marathons", value = false },
		{ name = "enable find200", domain = "Marathons", value = false },
		{ name = "enable find300", domain = "Marathons", value = false },
		{ name = "enable find380", domain = "Marathons", value = false },
		{ name = "enable find10s", domain = "Marathons", value = false },
		{ name = "enable find10t", domain = "Marathons", value = false },
		{ name = "enable exactly40letters", domain = "Marathons", value = false },
		{ name = "enable exactly100letters", domain = "Marathons", value = false },
		{ name = "enable exactly200letters", domain = "Marathons", value = false },
		{ name = "enable exactly500letters", domain = "Marathons", value = false },
		{ name = "enable exactly1000letters", domain = "Marathons", value = false },
		{ name = "enable signsofeverylength", domain = "Marathons", value = false },
		{ name = "enable findsetevolution", domain = "Marathons", value = false },
		{ name = "enable findsetsingleletter", domain = "Marathons", value = false },
		{ name = "enable findsetfirstcontest", domain = "Marathons", value = false },
		{ name = "enable findsetlegacy", domain = "Marathons", value = false },
		{ name = "enable findsetcave", domain = "Marathons", value = false },
		{ name = "enable findsetaofb", domain = "Marathons", value = false },
		{ name = "enable findsetthreeletter", domain = "Marathons", value = false },

		{ name = "have you played trackmania", domain = "Surveys", value = false },
		{ name = "have you played roblox for more than 5 years", domain = "Surveys", value = false },
		{ name = "should the game have more badges", domain = "Surveys", value = false },
		{ name = "have you found the chomik", domain = "Surveys", value = false },
		{ name = "should the game have more signs", domain = "Surveys", value = false },
		{ name = "should the game have more new areas", domain = "Surveys", value = false },
		{ name = "should the game have more marathons", domain = "Surveys", value = false },
		{ name = "should the game have more water areas", domain = "Surveys", value = false },
		{ name = "should the game have more surveys", domain = "Surveys", value = false },
		{ name = "should the game have more settings", domain = "Surveys", value = false },
		{ name = "should the game disable popups of other user activity", domain = "Surveys", value = false },
		{ name = "do you play find the chomiks", domain = "Surveys", value = false },
		{ name = "do you play jtoh", domain = "Surveys", value = false },
		{ name = "do you know who shedletsky is", domain = "Surveys", value = false },
		{ name = "blame john", domain = "Surveys", value = false },
		{ name = "birb", domain = "Surveys", value = false },
		{ name = "cold mold on a slate plate", domain = "Surveys", value = false },
		{ name = "hide leaderboard", domain = "UserSettings", value = false },
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
