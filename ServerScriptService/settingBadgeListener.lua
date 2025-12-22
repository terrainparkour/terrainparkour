--!strict

-- settingBadgeListener.lua :: ServerScriptService.settingBadgeListener
-- Listens for setting changes and grants badges. Separate from settingsServer to avoid require cycles.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local grantBadge = require(game.ServerScriptService.grantBadge)
local badgeEnums = require(game.ReplicatedStorage.util.badgeEnums)
local remotes = require(game.ReplicatedStorage.util.remotes)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local tt = require(game.ReplicatedStorage.types.gametypes)
local notify = require(game.ReplicatedStorage.notify)
local usernameCache = require(game.ServerScriptService.usernameCache)

local PlayersService = game:GetService("Players")

local SettingChangedBindableEvent = remotes.getBindableEvent("SettingChangedBindableEvent")

local module = {}

module.Init = function()
	SettingChangedBindableEvent.Event:Connect(function(userId: number, domain: string, surveyCount: number, setting: tt.userSettingValue?)
		_annotate(string.format("Setting changed for userId=%d domain=%s surveyCount=%d", userId, domain, surveyCount))

		-- Grant TakeSurvey badge for any setting change
		grantBadge.GrantBadge(userId, badgeEnums.badges.TakeSurvey)

		-- Grant SurveyKing badge if they've answered 20+ surveys
		if surveyCount > 20 then
			grantBadge.GrantBadge(userId, badgeEnums.badges.SurveyKing)
		end

		-- Grant PinnedBadgeColumn badge when user enables the pinned badge column in leaderboard
		if setting and setting.name == settingEnums.settingDefinitions.LEADERBOARD_ENABLE_PINNED_BADGE.name then
			if setting.booleanValue == true then
				grantBadge.GrantBadge(userId, badgeEnums.badges.PinnedBadgeColumn)
			end
		end

		-- Grant BadgePinner badge when user pins a badge (sets a non-empty pinned badge)
		if setting and setting.name == settingEnums.settingDefinitions.PINNED_BADGE.name then
			if setting.stringValue and setting.stringValue ~= "" then
				grantBadge.GrantBadge(userId, badgeEnums.badges.BadgePinner)

				-- Notify other players about the badge pin
				local username = usernameCache.GetUsernameByUserId(userId)
				local notifyText = string.format("%s pinned the badge '%s'", username, setting.stringValue)
				for _, otherPlayer in ipairs(PlayersService:GetPlayers()) do
					if otherPlayer.UserId ~= userId then
						notify.notifyPlayerAboutActionResult(otherPlayer, {
							userId = userId,
							text = notifyText,
							kind = "badge pinned",
							warpToSignId = 0,
						})
					end
				end
			end
		end
	end)

	_annotate("Setting badge listener initialized")
end

_annotate("end")
return module
