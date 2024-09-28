--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local notify = require(game.ReplicatedStorage.notify)
local badges = require(game.ServerScriptService.badges)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local config = require(game.ReplicatedStorage.config)

local leaderboardBadgeEvents = require(game.ServerScriptService.leaderboardBadgeEvents)
local PlayersService = game:GetService("Players")
local BadgeService: BadgeService = game:GetService("BadgeService")
local tt = require(game.ReplicatedStorage.types.gametypes)
local badgeEnums = require(game.ReplicatedStorage.util.badgeEnums)

local rdb = require(game.ServerScriptService.rdb)

local Players = game:GetService("Players")
local module = {}

-- return whether the user actually got the newly granted badge.
-- public function for anyone to make a user get the badge.
module.GrantBadge = function(userId: number, badge: tt.badgeDescriptor)
	local has =
		badges.UserHasBadge(userId, badge, string.format("checking during grant of %s to %s", badge.name, userId))
	if has then
		_annotate(string.format("GrantBadge %s but user already has badge %s", userId, badge.name))
		return false
	end

	if has == nil then
		if config.isInStudio() then
			_annotate("in studio, has is nil, why are we bailing" .. badge.name)
		else
			warn("failed to grant badge " .. tostring(userId) .. "  " .. badge.name)
		end
		return false
	end

	-- we fill in other players status on that badge, too, so we can tell like "player got it, which you had already or didn't"
	local otherPlayerHasBadgeMap = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.UserId == userId then
			continue
		end
		otherPlayerHasBadgeMap[player.UserId] = badges.UserHasBadge(
			player.UserId,
			badge,
			string.format("otherPlayer check during grant of %s to %s", badge.name, userId)
		)
	end

	--first time per instance, we
	local saveBadgeStatusRes
	if config.isInStudio() then
		badges.SetConfirmedBadgeOwnershipStatus(userId, badge.assetId, true)
		saveBadgeStatusRes = badges.SaveUserBadgeStatusToMyDb(userId, badge.assetId, badge.name)
	else
		local res = BadgeService:AwardBadge(userId, badge.assetId)

		if not res then
			_annotate(
				"failed to award badge in BadgeService on prod. so not saving to my db or telling user/others about it."
			)
			return false
		end
		badges.SetConfirmedBadgeOwnershipStatus(userId, badge.assetId, true)
		saveBadgeStatusRes = badges.SaveUserBadgeStatusToMyDb(userId, badge.assetId, badge.name)
	end

	if saveBadgeStatusRes.priorAwardCount == 0 and badge.assetId ~= badgeEnums.badges.FirstBadgeWinner.assetId then
		module.GrantBadge(userId, badgeEnums.badges.FirstBadgeWinner)
	end

	if not saveBadgeStatusRes.priorAwardCount then
		saveBadgeStatusRes.priorAwardCount = 0
	end

	local text: string = string.format(
		"You were %s to get the '%s' Badge!",
		tpUtil.getCardinalEmoji(saveBadgeStatusRes.priorAwardCount + 1),
		badge.name
	)
	local badgeOptions: tt.badgeOptions = { userId = userId, text = text, kind = "badge received" }

	local player = PlayersService:GetPlayerByUserId(userId)
	notify.notifyPlayerAboutBadge(player, badgeOptions)

	local thisUserbadgeCount = badges.getBadgeCountByUser(player.UserId, "grantBadge")
	for _, otherPlayer in ipairs(PlayersService:GetPlayers()) do
		--tell everyone about badge get
		local relativeDescriptor = ""
		if otherPlayer.UserId == player.UserId and not config.isInStudio() then
			continue
		end
		if otherPlayerHasBadgeMap then
			relativeDescriptor = " Which you do not have!"
			if otherPlayerHasBadgeMap[otherPlayer.UserId] then
				relativeDescriptor = " Which you already have!"
			end
		end

		local fakeStudio = ""
		if config.isInStudio() and otherPlayer.UserId == player.UserId then
			fakeStudio = "\nFalse other recipient (studio only)"

			--this is about badge awarding, whether the viewer has it I think? weird the text directly talks about me as the subject.
		end

		local otherText = string.format(
			"%s was %s to get badge: '%s'%s%s",
			player.Name,
			tpUtil.getCardinalEmoji(saveBadgeStatusRes.priorAwardCount + 1),
			badge.name,
			relativeDescriptor,
			fakeStudio
		)
		leaderboardBadgeEvents.updateBadgeLb(player, otherPlayer.UserId, thisUserbadgeCount)

		notify.notifyPlayerAboutBadge(otherPlayer, { userId = userId, text = otherText, kind = "badge received" })
	end

	if thisUserbadgeCount >= 100 then
		module.GrantBadge(userId, badgeEnums.badges.BadgeFor100Badges)
	end

	return true
end

_annotate("end")
return module
