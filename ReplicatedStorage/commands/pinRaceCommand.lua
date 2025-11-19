--!strict

-- pinRaceCommand.lua :: ReplicatedStorage.commands.pinRaceCommand
-- SERVER-ONLY: Pin or unpin races to a player's leaderboard via server commands or remote events.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local tt = require(game.ReplicatedStorage.types.gametypes)
local _remotes = require(game.ReplicatedStorage.util.remotes)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local leaderboardServer = require(game.ServerScriptService.leaderboardServer)
local playerData2 = require(game.ServerScriptService.playerData2)
local userSettings = require(game.ServerScriptService.settingsServer)

type pinRaceResult = {
	success: boolean,
	message: string,
	setting: tt.userSettingValue?,
}

type Module = {
	PinRace: (player: Player, signId1: number, signId2: number) -> pinRaceResult,
	UnpinRace: (speaker: Player) -> pinRaceResult,
}

local module: Module = {} :: Module

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
			message = "failed to set setting",
		}
	end

	leaderboardServer.UpdateAllAboutPlayerImmediate(player)
	return {
		success = true,
		message = string.format("%s pinned race %s-%s to their leaderboard.", player.Name, signName1, signName2),
		setting = setting, -- Client updates cache from this response
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
		setting = setting, -- Client updates cache from this response
	}
end

_annotate("end")
return module
