--!strict

-- commandParsins.lua
-- originally this also included lots of implementations.
-- but now they're moved to channelComamnds.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local sendMessageModule = require(game.ReplicatedStorage.chat.sendMessage)
local sendMessage = sendMessageModule.sendMessage
local userSettings = require(game.ServerScriptService.settingsServer)
local playerData2 = require(game.ServerScriptService.playerData2)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)

-- local settings = require(game.ReplicatedStorage.settings)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local tt = require(game.ReplicatedStorage.types.gametypes)

local leaderboardServer = require(game.ServerScriptService.leaderboardServer)

local module = {}
module.PinRace = function(speaker: Player, channel: TextChannel, text: string)
	local ret: tt.RaceParseResult = tpUtil.AttemptToParseRaceFromInput(text)
	if ret.error ~= "" then
		sendMessage(channel, ret.error)
		return true
	end

	if
		not playerData2.HasUserFoundSign(speaker.UserId, ret.signId1)
		or not playerData2.HasUserFoundSign(speaker.UserId, ret.signId2)
	then
		sendMessage(channel, "You must find both signs to pin a race")
		return true
	end
	_annotate(string.format("speaker.Name=%s would pin: %s %s", speaker.Name, ret.signId1, ret.signId2))
	local val = string.format("%d-%d", ret.signId1, ret.signId2)
	local setting: tt.userSettingValue = {
		name = settingEnums.settingDefinitions.LEADERBOARD_PINNED_RACE.name,
		domain = settingEnums.settingDomains.LEADERBOARD,
		kind = settingEnums.settingKinds.STRING,
		stringValue = val,
	}

	local res = userSettings.SetSettingFromServer(speaker, setting)
	if not res then
		sendMessage(channel, string.format("failed to set setting: %s", res.error))
		return true
	end

	sendMessage(
		channel,
		string.format("%s pinned race %s-%s to their leaderboard.", speaker.Name, ret.signname1, ret.signname2)
	)

	-- interesting, so we just force redraw here, rather than having the other client monitor it.
	-- that makes sense cause player A doesn't monitor player B's personal setting changes
	leaderboardServer.UpdateAllAboutPlayerImmediate(speaker)
end

module.UnpinRace = function(speaker: Player, channel: TextChannel)
	local setting: tt.userSettingValue = {
		name = settingEnums.settingDefinitions.LEADERBOARD_PINNED_RACE.name,
		domain = settingEnums.settingDomains.LEADERBOARD,
		kind = settingEnums.settingKinds.STRING,
		stringValue = "",
	}
	local res = userSettings.SetSettingFromServer(speaker, setting)
	if not res then
		sendMessage(channel, string.format("failed to set setting: %s", res.error))
		return true
	end
	leaderboardServer.UpdateAllAboutPlayerImmediate(speaker)
end

_annotate("end")
return module
