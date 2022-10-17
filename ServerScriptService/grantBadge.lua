--!strict

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

--userid - cached value for has badge.
--do we know if this includes negativity?
-- local grantedBadges: { [number]: { [number]: boolean } } = {}

--return whether the user actually got the newly granted badge.
module.GrantBadge = function(userId: number, badge: tt.badgeDescriptor)
	if badge == nil then
		error("bad badge")
		return
	end
	if badge.assetId == nil then
		error("bad badge.assetId")
		return
	end

	local has = badges.UserHasBadge(userId, badge)
	if has == true then
		return false
	end

	if has == nil then
		if config.isInStudio() then
			print("in studio, has is nil, why are we bailing" .. badge.name)
		end
		warn("failed to grant badge " .. tostring(userId) .. "  " .. badge.name)
		return false
	end

	local otherPlayerHasBadgeMap = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.UserId == userId and not config.isInStudio() then
			continue
		end
		otherPlayerHasBadgeMap[player.UserId] = badges.UserHasBadge(player.UserId, badge)
	end

	--first time per instance, we
	local res = BadgeService:AwardBadge(userId, badge.assetId)
	if not res then
		if not config.isInStudio() then
			return false
		end
	end

	local saveBadgeGrantRes = rdb.saveUserBadgeGrant(userId, badge.assetId, badge.name)
	spawn(function()
		if saveBadgeGrantRes.priorAwardCount == 0 and badge.assetId ~= badgeEnums.badges.FirstBadgeWinner.assetId then
			module.GrantBadge(userId, badgeEnums.badges.FirstBadgeWinner)
		end
	end)

	badges.setGrantedBadge(userId, badge.assetId)
	local text: string = string.format(
		"You were %s to get the '%s' Badge!",
		tpUtil.getCardinal(saveBadgeGrantRes.priorAwardCount + 1),
		badge.name
	)
	local badgeOptions: tt.badgeOptions = { userId = userId, text = text, kind = "badge received" }

	local player = PlayersService:GetPlayerByUserId(userId)
	notify.notifyPlayerAboutBadge(player, badgeOptions)

	local userBadgeCount = badges.getBadgeCountByUser(player.UserId)
	for _, otherPlayer in ipairs(PlayersService:GetPlayers()) do
		--tell everyone about badge get
		local relativeDescriptor = ""
		if otherPlayer.UserId == player.UserId and not config.isInStudio() then
			continue
		end
		if otherPlayerHasBadgeMap then
			relativeDescriptor = " which you do not have!"
			if otherPlayerHasBadgeMap[otherPlayer.UserId] then
				relativeDescriptor = " which you already have!"
			end
		end

		local fakeStudio = ""
		if config.isInStudio() and otherPlayer.UserId == player.UserId then
			fakeStudio = "\nFalse other recipient (studio only)"
		end

		local otherText = string.format(
			"%s was %s to get badge %s%s%s",
			player.Name,
			tpUtil.getCardinal(saveBadgeGrantRes.priorAwardCount + 1),
			badge.name,
			relativeDescriptor,
			fakeStudio
		)
		leaderboardBadgeEvents.updateBadgeLb(player.UserId, otherPlayer, userBadgeCount)

		notify.notifyPlayerAboutBadge(otherPlayer, { userId = userId, text = otherText, kind = "badge received" })
	end

	if userBadgeCount >= 100 then
		module.GrantBadge(userId, badgeEnums.badges.BadgeFor100Badges)
	end

	return true
end

return module
