--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local notify = require(game.ReplicatedStorage.notify)
local badges = require(game.ServerScriptService.badges)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local config = require(game.ReplicatedStorage.config)

local leaderboardBadgeEvents = require(game.ServerScriptService.leaderboardBadgeEvents)
local PlayersService = game:GetService("Players")

local tt = require(game.ReplicatedStorage.types.gametypes)
local badgeEnums = require(game.ReplicatedStorage.util.badgeEnums)

local BadgeService: BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")

local handleBadgeAwardPostActions = function(
	badge: tt.badgeDescriptor,
	userId: number,
	badgeStatus: tt.jsonBadgeStatus
): nil
	if badgeStatus.badgeTotalGrantCount == 1 then
		if badgeStatus.badgeAssetId ~= badgeEnums.badges.FirstBadgeWinner.assetId then
			module.GrantBadge(userId, badgeEnums.badges.FirstBadgeWinner)
		end
	end

	local text: string =
		string.format("You were %s to get the '%s' Badge!", badgeStatus.badgeTotalGrantCount + 1, badgeStatus.badgeName)
	tpUtil.getCardinalEmoji(badgeStatus.badgeTotalGrantCount + 1)

	local player = PlayersService:GetPlayerByUserId(userId)
	local badgeOptions: tt.badgeOptions = { userId = userId, text = text, kind = "badge received" }
	notify.notifyPlayerAboutBadge(player, badgeOptions)

	local doOthersAlreadyHaveThisBadge = {}
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer.UserId == userId then
			continue
		end
		doOthersAlreadyHaveThisBadge[otherPlayer.UserId] = badges.UserHasBadge(
			otherPlayer.UserId,
			badge,
			string.format("otherPlayer check during grant of %s to %s", badge.name, userId)
		)
	end

	local username = player.Name
	local thisUserbadgeCount = badges.getBadgeCountByUser(userId, "grantBadge")

	for _, otherPlayer in ipairs(PlayersService:GetPlayers()) do
		--tell everyone about badge get
		if otherPlayer.UserId == userId then
			continue
		end

		local relativeDescriptor = ""
		if doOthersAlreadyHaveThisBadge[otherPlayer.UserId] then
			relativeDescriptor = " Which you already have!"
		else
			relativeDescriptor = " Which you do not have!"
		end

		local otherText = string.format(
			"%s was %s to get badge: '%s'%s",
			username,
			tpUtil.getCardinalEmoji(badgeStatus.badgeTotalGrantCount + 1),
			badge.name,
			relativeDescriptor
		)
		leaderboardBadgeEvents.updateBadgeLb(player, otherPlayer.UserId, thisUserbadgeCount)

		notify.notifyPlayerAboutBadge(otherPlayer, { userId = userId, text = otherText, kind = "badge received" })
	end

	if thisUserbadgeCount >= 100 then
		module.GrantBadge(userId, badgeEnums.badges.BadgeFor100Badges)
	end
end

-- return whether the user actually got the newly granted badge.
-- public function for anyone to make a user get the badge.
module.GrantBadge = function(userId: number, badge: tt.badgeDescriptor)
	local has =
		badges.UserHasBadge(userId, badge, string.format("checking during grant of %s to %s", badge.name, userId))
	if has then
		_annotate(string.format("GrantBadge %s but user already has badge %s", userId, badge.name))
		return false
	end

	-- somehow the user ownership status is null.
	if has == nil then
		-- we failed to prepare data for this user at all.
		annotater.Error(
			string.format("GrantBadge to user: %s but user ownership status is nil. %s", userId, badge.name)
		)
		if config.isInStudio() then
			_annotate("in studio, has is nil, why are we bailing" .. badge.name)
		else
			warn("failed to grant badge " .. tostring(userId) .. "  " .. badge.name)
		end
		return false
	end

	local s, e = pcall(function()
		local granted = BadgeService:AwardBadge(userId, badge.assetId)
		if not granted then
			annotater.Error(string.format("BadgeService Failed to grant badge %s to user %s", badge.name, userId))
		end
	end)

	if not s then
		annotater.Error(string.format("BadgeService Error awarding badge %s to user %s", badge.name, userId))
		return false
	end

	local myDbRes = badges.SaveBadgeOwnershipStatusToMyDBAndRAM(userId, badge.assetId, badge.name, true)

	handleBadgeAwardPostActions(badge, userId, myDbRes)

	return true
end

_annotate("end")
return module
