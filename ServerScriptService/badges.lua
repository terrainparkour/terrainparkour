--!strict

-- badges.lua serverside.
-- important to implement lots of caches here!

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}
local tt = require(game.ReplicatedStorage.types.gametypes)
local badgeEnums = require(game.ReplicatedStorage.util.badgeEnums)
local badgeSorts = require(game.ReplicatedStorage.util.badgeSorts)
local rdb = require(game.ServerScriptService.rdb)
local remotes = require(game.ReplicatedStorage.util.remotes)
local playerData2 = require(game.ServerScriptService.playerData2)

local BadgeService: BadgeService = game:GetService("BadgeService")

-- the actual truth. either we know they have it, they don't have it.
-- changing assumptions 2024.09: we *always* know this complete info and just consult this dictionary.
local badgeStatusesRAM: { [number]: { [number]: boolean? } } = {}

-- boolean for if the data getter, running in a separate thread, is done.
local userIdHasDataPrepared: { [number]: boolean } = {}

-- deb is a map of userId to whether we're actively debouncing their badge lookup work right now.
local deb = {}
local function ensureBadgeDataGotten(userId: number, kind: string): boolean
	if userIdHasDataPrepared[userId] then
		return true
	end
	if userIdHasDataPrepared[userId] == nil then
		userIdHasDataPrepared[userId] = false
	end
	local username = playerData2.GetUsernameByUserId(userId)

	-- we are the first caller so we set debouncing for this guy to be true.
	if deb[userId] == nil or deb[userId] == false then
		deb[userId] = true
		-- and we will do the work
	else
		-- we wait for the other task to finish, so never do work ourselves.
		while deb[userId] do
			_annotate(
				string.format(
					"waiting to get the right to set up ensureBadgeDataGotten for %s, kind: %s",
					username,
					kind
				)
			)
			task.wait(0.1)
		end
		-- we should actually be done now so probably just return.
		-- and then just assume that everyhting is okay
		_annotate(
			string.format("well, someone unblocked this user so I'm assuming they're done. %s %s", username, kind)
		)
		-- at least lets return the other function
		if not userIdHasDataPrepared[userId] then
			annotater.Error(
				string.format(
					"someone else released setup lock but we failed. Returning %s",
					tostring(userIdHasDataPrepared[userId])
				)
			)
			return userIdHasDataPrepared[userId]
		end
	end

	_annotate(string.format("Doing initial user badge data loading for: %s %s", username, kind))
	deb[userId] = true

	local request: tt.postRequest = {
		remoteActionName = "getBadgeStatusesByUser",
		data = { userId = userId, kind = string.format("initial user setup %s %s", username, kind) },
	}
	local res: { tt.jsonBadgeStatus } = rdb.MakePostRequest(request)
	_annotate(string.format("loaded %d loaded user badge statuses from db for user %s %s", #res, username, kind))
	-- got them, now we apply them to
	if badgeStatusesRAM[userId] == nil then
		badgeStatusesRAM[userId] = {}
	end
	for _, el in ipairs(res) do
		badgeStatusesRAM[userId][el.badgeAssetId] = el.hasBadge
	end

	-- now kick off paginated checking.
	task.spawn(function()
		-- okay we got the known ones from my db.
		-- now, let's check the rest from roblox.
		local actualCheckCount = 0
		while true do
			local badgeAssetIdsToCheck = {}
			local fullerAssetIdsToCheckData: { [number]: { assetId: number, name: string, hasBadge: boolean? } } = {}
			for _, badge in pairs(badgeEnums.badges) do
				-- we know the status already.
				if badgeStatusesRAM[userId][badge.assetId] ~= nil then
					continue
				end

				--we prepare two data structures. one to send to the roblox api and one to prepare and later save to my db.
				table.insert(badgeAssetIdsToCheck, badge.assetId)
				actualCheckCount += 1
				-- set it to false, we'll find out later.
				badgeStatusesRAM[userId][badge.assetId] = false
				fullerAssetIdsToCheckData[badge.assetId] = {
					assetId = badge.assetId,
					name = badge.name,
					hasBadge = false,
				}

				if #badgeAssetIdsToCheck >= 10 then
					-- it only can do 10 at a time, so break and get it.
					break
				end
			end

			if #badgeAssetIdsToCheck == 0 then
				_annotate(string.format("none more to check, for user %s %s", username, kind))
				-- we have done all the badges, so we done
				break
			end

			_annotate(
				string.format("hitting roblox for %d badge ownership statuses for %s", #badgeAssetIdsToCheck, username)
			)
			local useUserId = userId
			if userId < 0 then
				useUserId = -1 * userId
			end
			local badgeAssetIdsTheUserDoesHave
			local badgeCallSuccess, err = pcall(function()
				badgeAssetIdsTheUserDoesHave = BadgeService:CheckUserBadgesAsync(useUserId, badgeAssetIdsToCheck)
			end)
			if not badgeCallSuccess then
				annotater.Error(string.format("failed to check roblox badges for user %s %s %s", username, kind, err))
				task.wait(12)
				continue
			end

			-- set it in ram here and also update the full data so we can save that to db.
			for _, el in ipairs(badgeAssetIdsTheUserDoesHave) do
				badgeStatusesRAM[userId][el] = true
				fullerAssetIdsToCheckData[el].hasBadge = true
			end

			local request2: tt.postRequest = {
				remoteActionName = "multiPostUserBadgeStatus",
				data = {
					userId = userId,
					validatedBadgeInfos = fullerAssetIdsToCheckData,
				},
			}
			rdb.MakePostRequest(request2)
			task.wait(7)
		end
		_annotate(
			string.format(
				"ending spawn which checked roblox status after actually checking roblox for %d user %s %s",
				actualCheckCount,
				username,
				kind
			)
		)
		userIdHasDataPrepared[userId] = true
		deb[userId] = false
		--leaving spawned task. The user's data is now totally prepared.
	end)
	-- okay, wait a while for them to be done.
	-- i.e. many interested parties will be calling this "ensure its done" method.
	-- all those guys should still wait. The first one will kick off checker then wait here.
	-- the others will wait above and then return
	local waited = 0
	while not userIdHasDataPrepared[userId] do
		waited += task.wait(5)
		annotater.Error(
			string.format("Have waited so far %0.1f seconds to prepare badge data for user: %s", waited, username)
		)
		if waited > 100 then
			annotater.Error(string.format("giving up waiting for this user's badge setup to bv done %s", username))
			return false
		end
	end
	if userIdHasDataPrepared[userId] == false then
		annotater.Error(
			string.format(
				"within badges, exited wait with nil for user data preparation after time %0.1f seconds for user %s",
				waited,
				username
			),
			userId
		)
	elseif userIdHasDataPrepared[userId] == nil then
		annotater.Error(
			string.format(
				"within badges, exited wait with nil for user data preparation after time %0.1f seconds for user %s",
				waited,
				username
			),
			userId
		)
	end
	deb[userId] = false
	return userIdHasDataPrepared[userId]
end

--2022.05 - adding new layer - positive only badge grant cache on remote server
-- true, false or nil?
module.UserHasBadge = function(userId: number, badge: tt.badgeDescriptor, kind: string): boolean?
	local prepared = ensureBadgeDataGotten(userId, "UserHasBadge " .. badge.name)
	local username = playerData2.GetUsernameByUserId(userId)
	if not prepared then
		annotater.Error(string.format("was unable to prepare badge data for player: %s %s", username, kind), userId)
		return nil
	end
	return badgeStatusesRAM[userId][badge.assetId]
end

module.SaveBadgeOwnershipStatusToMyDBAndRAM = function(
	userId: number,
	badgeAssetId: number,
	badgeName: string,
	hasBadge: boolean
)
	local thingToSave = {}
	thingToSave[badgeAssetId] = {
		assetId = badgeAssetId,
		name = badgeName,
		hasBadge = hasBadge,
	}
	local request: tt.postRequest = {
		remoteActionName = "multiPostUserBadgeStatus",
		data = {
			userId = userId,
			validatedBadgeInfos = thingToSave,
		},
	}
	badgeStatusesRAM[userId][badgeAssetId] = hasBadge
	local res: tt.jsonBadgeStatus = rdb.MakePostRequest(request)[1]
	return res
end

--for a given badgeClass, how to lookup relevant detail from stats to calculate progress?
--very annoying to have to create this type of matching classes
local function getProgressForStatsKindAndNumber(el: tt.badgeDescriptor, stats: tt.lbUserStats): number?
	if el.baseNumber == nil then
		return nil
	end

	if el.badgeClass == "top10s" then
		return math.min(stats.top10s, el.baseNumber)
	elseif el.badgeClass == "tix" then
		return math.min(stats.userTix, el.baseNumber)
	elseif el.badgeClass == "finds" then
		return math.min(stats.findCount, el.baseNumber)
	elseif el.badgeClass == "wrs" then
		return math.min(stats.wrCount, el.baseNumber)
	elseif el.badgeClass == "cwrs" then
		return math.min(stats.cwrs, el.baseNumber)
	elseif el.badgeClass == "races" then
		return math.min(stats.userTotalRaceCount, el.baseNumber)
	elseif el.badgeClass == "runs" then
		return math.min(stats.userTotalRunCount, el.baseNumber)
	elseif el.badgeClass == "cwrTop10s" then
		return math.min(stats.cwrTop10s, el.baseNumber)
	end

	annotater.Error(string.format("fail badgeClass progress lookup for %s", el.badgeClass))
	return 0
end

-- relies on badges being sorted such that badgeStatus is sequential for cases where
-- badgeClass and baseNumber is defined
--uses this fact to skip out of calculating level N+1 if level N of sequential class badges fails
-- 2024.09: I should multiget the badgeStatus status from MY server, so I avoid killing Roblox.
-- WARNING: if anything about badge setup fails, we will just not return any badge info.
-- this can be improved by modifying ensureBadgeDataGotten to return a more meaningful set of data, distinguishing between whether my db is down, roblox badge service is, or  both.
-- given that 99% of the data will be stored by me in the future, this would be helpful if (when) badge service is flaky.
module.GetAllBadgeProgressDetailsForUserId = function(userId: number, kind: string): { tt.badgeProgress }
	local prepared = ensureBadgeDataGotten(userId, "getAllBadgeProgressDetailsForUserId " .. kind)
	local username = playerData2.GetUsernameByUserId(userId)
	if not prepared then
		_annotate(
			string.format(
				"getAllBadgeProgressDetailsForUserId: wasn't able to ever get user prepared, so bailing. %s",
				username
			)
		)
		return {}
	end

	-- local completeClasses: { [string]: boolean } = {}
	local allBadges: { tt.badgeDescriptor } = {}
	for _, thebadge in pairs(badgeEnums.badges) do
		table.insert(allBadges, thebadge)
	end
	table.sort(allBadges, badgeSorts.BadgeSort)
	local ii = 0

	local stats: tt.lbUserStats = playerData2.GetStatsByUserId(userId, "badge progress")
	local badgeStatuses: { tt.badgeProgress } = {}
	local knownGotBadgeCount = 0 --for 100 badge badge gramt
	for _, badgeDescriptor: tt.badgeDescriptor in pairs(allBadges) do
		ii += 1
		local userHasBadge: boolean? = badgeStatusesRAM[userId][badgeDescriptor.assetId]
		if userHasBadge == nil then
			annotater.Error(
				string.format(
					"getAllBadgeProgressDetailsForUserId: user %s has nil badge status for %d which should never happen",
					username,
					badgeDescriptor.assetId
				)
			)
			return {}
		end
		--calculate progress

		local progress: number? = nil
		if badgeDescriptor.baseNumber ~= nil then
			progress = getProgressForStatsKindAndNumber(badgeDescriptor, stats)
		end

		local badgeStatus: tt.badgeProgress = {
			badge = badgeDescriptor,
			got = userHasBadge,
			progress = progress,
			baseNumber = badgeDescriptor.baseNumber,
		}
		table.insert(badgeStatuses, badgeStatus)

		if userHasBadge then
			knownGotBadgeCount += 1
		end
	end

	table.sort(badgeStatuses, badgeSorts.BadgeStatusSort)
	_annotate("complete entire badge status gotten.")

	return badgeStatuses
end

--for a bunch of users at once.
local getBadgeProgressForUserIds = function(
	userIdsInServer: { number },
	kind: string
): { [number]: { tt.badgeProgress } }
	local res: { [number]: { tt.badgeProgress } } = {}
	for _, oUserId: number in ipairs(userIdsInServer) do
		local badgeProgress = module.GetAllBadgeProgressDetailsForUserId(oUserId, kind)
		res[oUserId] = badgeProgress
	end
	return res
end

module.getBadgeCountByUser = function(userId: number, kind: string): number
	local username = playerData2.GetUsernameByUserId(userId)
	local prepared = ensureBadgeDataGotten(userId, "getBadgeCountByUser " .. kind)
	if not prepared then
		_annotate(string.format("getBadgeCountByUser: wasn't able to ever get user prepared, so bailing. %s", username))
		return 0
	end
	local hasBadgeCount = 0

	for _, hasBadge in pairs(badgeStatusesRAM[userId]) do
		if hasBadge then
			hasBadgeCount += 1
		end
	end
	return hasBadgeCount
end

module.Init = function()
	_annotate("init")
	local BadgeProgressFunction = remotes.getRemoteFunction("BadgeProgressFunction") :: RemoteFunction
	BadgeProgressFunction.OnServerInvoke = function(_: Player, userIdsInServer: { number }, kind: string): any
		return getBadgeProgressForUserIds(userIdsInServer, kind)
	end
	_annotate("init done")
end

_annotate("end")
return module
