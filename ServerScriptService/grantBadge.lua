--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local notify = require(game.ReplicatedStorage.notify)
local badges = require(game.ServerScriptService.badges)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local config = require(game.ReplicatedStorage.config)
local playerData2 = require(game.ServerScriptService.playerData2)

local leaderboardBadgeEvents = require(game.ServerScriptService.leaderboardBadgeEvents)
local PlayersService = game:GetService("Players")

local tt = require(game.ReplicatedStorage.types.gametypes)
local badgeEnums = require(game.ReplicatedStorage.util.badgeEnums)

local BadgeService: BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")

-- return whether the user actually got the newly granted badge.
-- public function for anyone to make a user get the badge.
module.GrantBadge = function(userId: number, badge: tt.badgeDescriptor)
	local username = playerData2.GetUsernameByUserId(userId)
	local has =
		badges.UserHasBadge(userId, badge, string.format("checking during grant of %s to %s", badge.name, username))
	if has then
		_annotate(string.format("GrantBadge %s but user already has badge %s", username, badge.name))
		return
	end

	-- somehow the user ownership status is null.
	if has == nil then
		-- we failed to prepare data for this user at all.
		annotater.Error(
			string.format("GrantBadge to user: %s but user ownership status is nil. %s", username, badge.name),
			userId
		)
		if config.isInStudio() then
			_annotate("in studio, has is nil, why are we bailing" .. badge.name)
		else
			warn("failed to grant badge " .. tostring(userId) .. "  " .. badge.name)
		end
		return
	end

	local s, e = pcall(function()
		local granted = BadgeService:AwardBadge(userId, badge.assetId)
		if not granted then
			annotater.Error(
				string.format("BadgeService Failed to grant badge %s to user %s", badge.name, username),
				userId
			)
		end
	end)

	if not s then
		annotater.Error(string.format("BadgeService Error awarding badge %s to user %s", badge.name, username), userId)
		return
	end

	local myDbRes = badges.SaveBadgeOwnershipStatusToMyDBAndRAM(userId, badge.assetId, badge.name, true)

	if not myDbRes then
		annotater.Error(
			string.format("badgeStatus is nil for badge %s, while trying to grant it to: %s", badge.name, username),
			userId
		)
		return
	end
	if myDbRes.badgeTotalGrantCount == 1 then
		if myDbRes.badgeAssetId ~= badgeEnums.badges.FirstBadgeWinner.assetId then
			module.GrantBadge(userId, badgeEnums.badges.FirstBadgeWinner)
		end
	end

	local text: string =
		string.format("You were %d to get the '%s' Badge!", myDbRes.badgeTotalGrantCount + 1, myDbRes.badgeName)
	tpUtil.getCardinalEmoji(myDbRes.badgeTotalGrantCount + 1)

	local player: Player? = PlayersService:GetPlayerByUserId(userId)
	if not player then
		annotater.Error(string.format("player not found for user: %s", username), userId)
		return
	end
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
			string.format("otherPlayer check during grant of %s to %s", badge.name, username)
		)
	end

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
			tpUtil.getCardinalEmoji(myDbRes.badgeTotalGrantCount + 1),
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

_annotate("end")
return module
