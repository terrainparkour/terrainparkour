--!strict

--eval 9.24.22

local notify = require(game.ReplicatedStorage.notify)
local badges = require(game.ServerScriptService.badges)

local config = require(game.ReplicatedStorage.config)

local leaderboardBadgeEvents = require(game.ServerScriptService.leaderboardBadgeEvents)
local PlayersService = game:GetService("Players")
local BadgeService: BadgeService = game:GetService("BadgeService")
local tt = require(game.ReplicatedStorage.types.gametypes)
local badgeEnums = require(game.ReplicatedStorage.util.badgeEnums)

local rdb = require(game.ServerScriptService.rdb)

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

	if config.isInStudio() then
		badges.setGrantedBadge(userId, badge.assetId)
		print("in studio, would have granted badge." .. badge.name)
		spawn(function()
			-- annotate("saving to remote " .. badge.name)
			rdb.saveUserBadgeGrant(userId, badge.assetId, badge.name)
		end)
		local text: string = "You got the '" .. badge.name .. "' Badge!"
		local badgeOptions: tt.badgeOptions = { userId = userId, text = text, kind = "badge received" }

		local player = PlayersService:GetPlayerByUserId(userId)
		notify.notifyPlayerAboutBadge(player, badgeOptions)

		local otherText = userId .. " got badge '" .. badge.name .. "'!"
		local badgecount = badges.getBadgeCountByUser(userId)
		for _, otherPlayer in ipairs(PlayersService:GetPlayers()) do
			--tell everyone about badgecount
			leaderboardBadgeEvents.updateBadgeLb(userId, otherPlayer, badgecount)
			if otherPlayer.UserId == userId then
				continue
			end
			notify.notifyPlayerAboutBadge(otherPlayer, { userId = userId, text = otherText, kind = "badge received" })
		end
		return true
	end

	--first time per instance, we
	local res = BadgeService:AwardBadge(userId, badge.assetId)
	if not res then
		return false
	end
	spawn(function()
		rdb.saveUserBadgeGrant(userId, badge.assetId, badge.name)
		-- annotate("save badge. " .. badge.name)
	end)

	badges.setGrantedBadge(userId, badge.assetId)
	local text: string = "You got the '" .. badge.name .. "' Badge!"
	local badgeOptions: tt.badgeOptions = { userId = userId, text = text, kind = "badge received" }

	local player = PlayersService:GetPlayerByUserId(userId)
	notify.notifyPlayerAboutBadge(player, badgeOptions)
	local otherText = player.Name .. " got badge '" .. badge.name .. "'!"
	local badgecount = badges.getBadgeCountByUser(player.UserId)
	for _, otherPlayer in ipairs(PlayersService:GetPlayers()) do
		--tell everyone about badgecount
		leaderboardBadgeEvents.updateBadgeLb(player.UserId, otherPlayer, badgecount)
		if otherPlayer.UserId == player.UserId then
			continue
		end
		notify.notifyPlayerAboutBadge(otherPlayer, { userId = userId, text = otherText, kind = "badge received" })
	end

	if badgecount >= 100 then
		module.GrantBadge(userId, badgeEnums.badges.BadgeFor100Badges)
	end

	return true
end

return module
