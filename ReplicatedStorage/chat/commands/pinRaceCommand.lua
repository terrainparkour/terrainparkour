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

export type pinRaceResult = {
	success: boolean,
	message: string,
}

module.PinRace = function(player: Player, signId1: number, signId2: number): pinRaceResult
	if
		not playerData2.HasUserFoundSign(player.UserId, signId1)
		or not playerData2.HasUserFoundSign(player.UserId, signId2)
	then
		return {
			success = false,
			message = "You must find both signs to pin a race",
		}
	end
	local signName1 = tpUtil.signId2signName(signId1)
	local signName2 = tpUtil.signId2signName(signId2)
	_annotate(string.format("speaker.Name=%s would pin: %s %s", player.Name, signName1, signName2))
	local val = string.format("%d-%d", signId1, signId2)
	local setting: tt.userSettingValue = {
		name = settingEnums.settingDefinitions.LEADERBOARD_PINNED_RACE.name,
		domain = settingEnums.settingDomains.LEADERBOARD,
		kind = settingEnums.settingKinds.STRING,
		stringValue = val,
	}

	local res: tt.setSettingResponse = userSettings.SetSettingFromServer(player, setting)
	if not res then
		return {
			success = false,
			message = string.format("failed to set setting: %s", res.error),
		}
	end

	-- interesting, so we just force redraw here, rather than having the other client monitor it.
	-- that makes sense cause player A doesn't monitor player B's personal setting changes
	leaderboardServer.UpdateAllAboutPlayerImmediate(player)
	return {
		success = true,
		message = string.format("%s pinned race %s-%s to their leaderboard.", player.Name, signName1, signName2),
	}
end

module.UnpinRace = function(speaker: Player): pinRaceResult
	local setting: tt.userSettingValue = {
		name = settingEnums.settingDefinitions.LEADERBOARD_PINNED_RACE.name,
		domain = settingEnums.settingDomains.LEADERBOARD,
		kind = settingEnums.settingKinds.STRING,
		stringValue = "",
	}
	userSettings.SetSettingFromServer(speaker, setting)
	leaderboardServer.UpdateAllAboutPlayerImmediate(speaker)
	return {
		success = true,
		message = string.format("%s unpinned their leaderboard race.", speaker.Name),
	}
end

_annotate("end")
return module
