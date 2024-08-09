--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local BadgeService: BadgeService = game:GetService("BadgeService")
local tt = require(game.ReplicatedStorage.types.gametypes)
local badgeEnums = require(game.ReplicatedStorage.util.badgeEnums)
local badgeSorts = require(game.ReplicatedStorage.util.badgeSorts)
local rdb = require(game.ServerScriptService.rdb)
local remotes = require(game.ReplicatedStorage.util.remotes)

local module = {}

--userid - cached value for has badge.
--do we know if this includes negativity?
local grantedBadges: { [number]: { [number]: boolean } } = {}

module.setGrantedBadge = function(userId: number, badgeId: number)
	grantedBadges[userId][badgeId] = true
end

--only one lookup at a time
local badgeLookupLocks = {}

--userid:{badgeId:true only if present}
local positiveBadgeAttainments: { [number]: { [number]: boolean } } = {}

--2022.05 - adding new layer - positive only badge grant cache on remote server
--effectively multigetBadgeGrants
module.UserHasBadge = function(userId: number, badge: tt.badgeDescriptor): boolean?
	if positiveBadgeAttainments[userId] ~= nil then
		if positiveBadgeAttainments[userId][badge.assetId] then
			return true
		end
	end
	if not grantedBadges[userId] then
		_annotate("\treset grantedBadges cache." .. userId)
		grantedBadges[userId] = {}
	end
	if badgeLookupLocks[userId] == nil then
		badgeLookupLocks[userId] = {}
	end
	while true do
		if not badgeLookupLocks[userId][badge.assetId] then
			break
		end
		_annotate("waiting on lookup.\t" .. badge.name)
		wait(1)
		--TODO very suspicious. what is this?
	end
	if grantedBadges[userId][badge.assetId] == nil then
		badgeLookupLocks[userId][badge.assetId] = true
		local s, e = pcall(function()
			local res = BadgeService:UserHasBadgeAsync(userId, badge.assetId)
			if res then --these will fill it in, and later it'll be re-fed upstream.
				task.spawn(function()
					_annotate("saving to remote " .. badge.name)
					rdb.saveUserBadgeGrant(userId, badge.assetId, badge.name)
				end)
			end
			grantedBadges[userId][badge.assetId] = res
			badgeLookupLocks[userId][badge.assetId] = false
		end)
		if e then
			badgeLookupLocks[userId][badge.assetId] = nil
			_annotate(string.format("Nil out. %s %s", badge.name, e))
			return nil
		end
	end
	if grantedBadges[userId][badge.assetId] == nil then
		error("nil still.")
	end
	return grantedBadges[userId][badge.assetId]
end

--for a given badgeClass, how to lookup relevant detail from stats to calculate progress?
--very annoying to have to create this type of matching classes
local function getProgressForStatsKindAndNumber(el: tt.badgeDescriptor, stats: tt.afterData_getStatsByUser): number
	if el.badgeClass == "top10s" then
		return math.min(stats.top10s, el.baseNumber)
	end
	if el.badgeClass == "tix" then
		return math.min(stats.userTix, el.baseNumber)
	end
	if el.badgeClass == "finds" then
		return math.min(stats.userTotalFindCount, el.baseNumber)
	end
	if el.badgeClass == "wrs" then
		return math.min(stats.userTotalWRCount, el.baseNumber)
	end
	if el.badgeClass == "cwrs" then
		return math.min(stats.userCompetitiveWRCount, el.baseNumber)
	end
	if el.badgeClass == "races" then
		return math.min(stats.races, el.baseNumber)
	end
	if el.badgeClass == "runs" then
		return math.min(stats.runs, el.baseNumber)
	end
	warn("fail badgeClass progress lookup.")
	return 0
end

--for a bunch of users at once.
module.getBadgeAttainmentsForUserIds = function(
	userIdsInServer: { number },
	rationale: string
): { [number]: { tt.badgeAttainment } }
	local res: { [number]: { tt.badgeAttainment } } = {}
	for _, oUserId: number in ipairs(userIdsInServer) do
		local badgeAttainments = module.getBadgeAttainmentForUserId(oUserId, rationale)
		res[oUserId] = badgeAttainments
	end
	return res
end

-- local globalBadgeGrantCountsByAssetId: { [number]: number } = {}

--relies on badges being sorted such that attainment is sequential for cases where badgeClass and baseNumber is defined
--uses this fact to skip out of calculating level N+1 if level N of sequential class badges fails
module.getBadgeAttainmentForUserId = function(userId: number, rationale: string): { tt.badgeAttainment }
	--if type is identical to last, and last was a no, just return false.

	--list of "attainments"
	if positiveBadgeAttainments[userId] == nil then
		local pos: { tt.pyUserBadgeGrant } = rdb.getBadgesByUser(userId)
		local map: { [number]: boolean } = {}
		for _, el in ipairs(pos) do
			-- globalBadgeGrantCountsByAssetId[el.badgeAssetId] = el.badgeTotalGrantCount
			map[el.badgeAssetId] = true
		end
		positiveBadgeAttainments[userId] = map
	end

	local completeClasses: { [string]: boolean } = {}
	local res = {}
	for _, thebadge in pairs(badgeEnums.badges) do
		table.insert(res, thebadge)
	end
	table.sort(res, badgeSorts.BadgeSort)
	local ii = 0
	local playerdata = require(game.ServerScriptService.playerdata)
	local stats: tt.afterData_getStatsByUser = playerdata.getPlayerStatsByUserId(userId, "badge_progress")
	local attainments: { tt.badgeAttainment } = {}
	local knownGotBadgeCount = 0 --for 100 badge badge gramt
	for _, badge: tt.badgeDescriptor in pairs(res) do
		ii += 1
		if completeClasses[badge.badgeClass] then
			--artificially set them having it false.
			grantedBadges[userId][badge.assetId] = false
		end
		local userHasBadge: boolean? = module.UserHasBadge(userId, badge)
		if userHasBadge == nil then
			break
		end
		--calculate progress

		local progress = -1 --guard value
		if badge.baseNumber ~= nil then
			progress = getProgressForStatsKindAndNumber(badge, stats)
		end
		local attainment: tt.badgeAttainment = {
			badge = badge,
			got = userHasBadge,
			progress = progress,
			baseNumber = badge.baseNumber,
		}
		table.insert(attainments, attainment)
		if not userHasBadge then
			if badge.baseNumber ~= nil then
				completeClasses[badge.badgeClass] = true
			end
		end

		if userHasBadge then
			knownGotBadgeCount += 1
		end
	end

	table.sort(attainments, badgeSorts.BadgeAttainmentSort)
	--note they are in the right order now.

	return attainments
end

module.getBadgeCountByUser = function(userId: number): number
	local allBadges: { tt.badgeAttainment } = module.getBadgeAttainmentForUserId(userId, "badgeCount")
	local hasBadgeCount = 0

	for _, attainment in ipairs(allBadges) do
		if attainment.got then
			hasBadgeCount += 1
		end
	end
	return hasBadgeCount
end

local badgeAttainmentsFunction = remotes.getRemoteFunction("BadgeAttainmentsFunction") :: RemoteFunction
badgeAttainmentsFunction.OnServerInvoke = function(player: Player, userIdsInServer: { number }, rationale: string): any
	return module.getBadgeAttainmentsForUserIds(userIdsInServer, rationale)
end

_annotate("end")
return module
