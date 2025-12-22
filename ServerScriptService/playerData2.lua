--!strict

-- playerData2.lua on the server.
--generic getters for player information for use by commands or UIs or LBs

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local tt = require(game.ReplicatedStorage.types.gametypes)
local tpUtil: typeof(require(game.ReplicatedStorage.util.tpUtil)) = require(game.ReplicatedStorage.util.tpUtil)
local enums = require(game.ReplicatedStorage.util.enums)

local textUtil = require(game.ReplicatedStorage.util.textUtil)
local colors = require(game.ReplicatedStorage.util.colors)
local rdb = require(game.ServerScriptService.rdb)
local settingsServer = require(game.ServerScriptService.settingsServer)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local notify = require(game.ReplicatedStorage.notify)

local PlayersService = game:GetService("Players")

-- In-memory tracking of last activity timestamp per user (for idle time column)
local lastActivityTimestamps: { [number]: number } = {}

-- In-memory tracking of previous ranks for rank improvement notifications
local previousRanks: { [number]: { findRank: number?, cwrRank: number?, wrRank: number? } } = {}

-- Call this when a user does something meaningful (run finish, sign find, etc.)
module.UpdateUserActivity = function(userId: number)
	lastActivityTimestamps[userId] = tick()
end

module.GetUserLastActivity = function(userId: number): number?
	return lastActivityTimestamps[userId]
end

-- Check if ranks improved and notify the player
-- A rank "improves" when it goes from a higher number to a lower number (e.g., #15 → #14)
-- Only notifies if the previous rank was tracked (not on first load)
module.CheckAndNotifyRankImprovements = function(userId: number, newStats: tt.lbUserStats)
	local player = PlayersService:GetPlayerByUserId(userId)
	if not player then
		return
	end

	local prev = previousRanks[userId]
	if not prev then
		-- First time seeing this user, just store their ranks
		previousRanks[userId] = {
			findRank = newStats.findRank,
			cwrRank = newStats.cwrRank,
			wrRank = newStats.wrRank,
		}
		return
	end

	-- Check findRank improvement
	if prev.findRank and newStats.findRank and newStats.findRank > 0 and prev.findRank > newStats.findRank then
		local text = string.format("Congratulations! Find Rank: #%d → #%d", prev.findRank, newStats.findRank)
		notify.notifyPlayerAboutActionResult(player, {
			userId = userId,
			text = text,
			kind = "rank improvement",
			warpToSignId = 0,
		})
		_annotate(string.format("Notified userId=%d of findRank improvement: %d → %d", userId, prev.findRank, newStats.findRank))
	end

	-- Check cwrRank improvement
	if prev.cwrRank and newStats.cwrRank and newStats.cwrRank > 0 and prev.cwrRank > newStats.cwrRank then
		local text = string.format("Congratulations! CWR Rank: #%d → #%d", prev.cwrRank, newStats.cwrRank)
		notify.notifyPlayerAboutActionResult(player, {
			userId = userId,
			text = text,
			kind = "rank improvement",
			warpToSignId = 0,
		})
		_annotate(string.format("Notified userId=%d of cwrRank improvement: %d → %d", userId, prev.cwrRank, newStats.cwrRank))
	end

	-- Check wrRank improvement
	if prev.wrRank and newStats.wrRank and newStats.wrRank > 0 and prev.wrRank > newStats.wrRank then
		local text = string.format("Congratulations! WR Rank: #%d → #%d", prev.wrRank, newStats.wrRank)
		notify.notifyPlayerAboutActionResult(player, {
			userId = userId,
			text = text,
			kind = "rank improvement",
			warpToSignId = 0,
		})
		_annotate(string.format("Notified userId=%d of wrRank improvement: %d → %d", userId, prev.wrRank, newStats.wrRank))
	end

	-- Update stored ranks
	previousRanks[userId] = {
		findRank = newStats.findRank,
		cwrRank = newStats.cwrRank,
		wrRank = newStats.wrRank,
	}
end

module.getGameStats = function()
	local request: tt.postRequest = {
		remoteActionName = "getTotalRunCountByDay",
		data = {},
	}
	local todayRuns = rdb.MakePostRequest(request)["count"]

	local request2: tt.postRequest = {
		remoteActionName = "getTotalRunCount",
		data = {},
	}
	local allTimeRuns = rdb.MakePostRequest(request2)["count"]

	local request3: tt.postRequest = {
		remoteActionName = "getTotalRaceCount",
		data = {},
	}
	local totalRaces = rdb.MakePostRequest(request3)["count"]

	local text = tostring(todayRuns) .. " runs today\n"
	text = text .. tostring(allTimeRuns) .. " runs have been done ever!\n"
	text = text .. tostring(totalRaces) .. " different races have been discovered."
	return text
end

module.getNonTop10RacesByUserId = function(userId: number, kind: string): tt.getNonTop10RacesByUser
	local request: tt.postRequest = {
		remoteActionName = "getNonTop10RacesByUser",
		data = { userId = userId },
	}
	local stats: tt.getNonTop10RacesByUser = rdb.MakePostRequest(request)
	return stats
end

module.getNonWRsByToSignIdAndUserId = function(to: string, signId: number, userId: number, kind: string)
	local request: tt.postRequest = {
		remoteActionName = "getNonWRsByToSignIdAndUserId",
		data = { userId = userId, to = to, signId = signId },
	}
	local stats: tt.getNonTop10RacesByUser = rdb.MakePostRequest(request)
	return stats
end

local userIdStatsCache: { [number]: { time: number, userstats: tt.lbUserStats } } = {}
local getStatsDebounce = false

local function normalizeLbUserStats(payload: any, context: string): tt.lbUserStats
	if typeof(payload) ~= "table" then
		annotater.Error("lbUserStats payload invalid", {
			context = context,
			payloadType = typeof(payload),
		})
		error(string.format("lbUserStats payload invalid: %s", context))
	end

	local currentUserId = payload.userId
	if typeof(currentUserId) ~= "number" then
		annotater.Error("lbUserStats.userId not numeric", {
			context = context,
			rawUserId = currentUserId,
		})
		error(string.format("lbUserStats.userId invalid: %s", context))
	end

	return payload :: tt.lbUserStats
end
--kind is just a description for debugging.
module.GetStatsByUserId = function(userId: number, kind: string): tt.lbUserStats
	while getStatsDebounce do
		task.wait(0.1)
		_annotate("waiting for getSTats. debounce to clear. " .. kind)
	end
	getStatsDebounce = true
	local thisTick = tick()
	if userIdStatsCache[userId] then
		if thisTick - userIdStatsCache[userId].time < 2 then
			_annotate("used cache to return a user's stats." .. kind)
			getStatsDebounce = false
			return userIdStatsCache[userId].userstats
		else
			_annotate("cache was too old. " .. kind)
			userIdStatsCache[userId] = nil
		end
	else
		_annotate("cache was empty. " .. kind)
	end
	_annotate(string.format("did not use cache to return a user's stats %s", kind))
	local request: tt.postRequest = {
		remoteActionName = "getStatsByUserId",
		data = { userId = userId, kind = kind },
	}
	local stats: tt.lbUserStats = normalizeLbUserStats(rdb.MakePostRequest(request), "GetStatsByUserId:" .. kind)
	userIdStatsCache[userId] = { time = thisTick, userstats = stats }
	stats.kind = kind
	-- serverPatchedInTotalSignCount now comes from Python backend (Sign.objects.count())

	-- Add warpPermission from user settings (defaults to "none" if not set)
	local warpPermissionValue = settingsServer.GetSettingValueByUserId(userId, settingEnums.settingDefinitions.WARP_TO_PERMISSION.name)
	stats.warpPermission = if warpPermissionValue then tostring(warpPermissionValue) else "none"

	-- Add pinnedBadge from user settings
	local pinnedBadgeValue = settingsServer.GetSettingValueByUserId(userId, settingEnums.settingDefinitions.PINNED_BADGE.name)
	stats.pinnedBadge = if pinnedBadgeValue then tostring(pinnedBadgeValue) else ""

	-- Add latest badge received (fetched from DB)
	local latestBadgeRequest: tt.postRequest = {
		remoteActionName = "getLatestBadgeReceived",
		data = { userId = userId },
	}
	local latestBadgeResponse = rdb.MakePostRequest(latestBadgeRequest)
	if latestBadgeResponse and latestBadgeResponse.badgeName then
		stats.latestBadge = latestBadgeResponse.badgeName
		stats.latestBadgeAssetId = latestBadgeResponse.badgeAssetId
		stats.latestBadgeEarnedAt = latestBadgeResponse.earnedAt
	else
		stats.latestBadge = nil
		stats.latestBadgeAssetId = nil
		stats.latestBadgeEarnedAt = nil
	end

	-- Add idle status sharing preference
	local shareIdleValue = settingsServer.GetSettingValueByUserId(userId, settingEnums.settingDefinitions.SHARE_IDLE_STATUS.name)
	stats.shareIdleStatus = if shareIdleValue == true then true else false

	-- Add last activity timestamp (only if user shares idle status)
	if stats.shareIdleStatus then
		stats.lastActivityTimestamp = lastActivityTimestamps[userId] or tick()
	else
		stats.lastActivityTimestamp = nil
	end

	getStatsDebounce = false
	return stats
end

module.GetPlayerStatsByUsername = function(username: string, kind: string): tt.lbUserStats
	local request: tt.postRequest = {
		remoteActionName = "getStatsByUsername",
		data = { username = username },
	}
	local stats: tt.lbUserStats = normalizeLbUserStats(rdb.MakePostRequest(request), "GetPlayerStatsByUsername:" .. kind)
	stats.kind = kind
	-- serverPatchedInTotalSignCount now comes from Python backend (Sign.objects.count())
	return stats
end

module.GetPlayerDescriptionLine = function(userId: number)
	local data: tt.lbUserStats = module.GetStatsByUserId(userId, "desc line")
	local text = data.findCount .. " signs found "
	if data.findRank > 0 then
		text = text .. " / Find Rank: " .. tpUtil.getCardinal(data.findRank)
	end
	if data.userTix > 0 then
		text = text .. " / " .. data.userTix .. " Tix!"
	end
	if data.cwrs > 0 then
		text = text .. " / " .. data.cwrs .. " Competitive WRs."
	end
	if data.cwrRank > 0 then
		text = text .. " / CWR Rank: " .. tpUtil.getCardinal(data.cwrRank)
	end
	if data.cwrTop10s > 0 then
		text = text .. " / " .. data.cwrTop10s .. " CWR Top 10s"
	end
	if data.wrCount > 0 then
		text = text .. " / " .. data.wrCount .. " World Records"
	end
	if data.wrRank > 0 then
		text = text .. " / WR Rank: " .. tpUtil.getCardinal(data.wrRank)
	end
	if data.top10s > 0 then
		text = text .. " / " .. data.top10s .. " top10s"
	end

	if data.userTotalRaceCount > 0 then
		text = text .. " / " .. data.userTotalRaceCount .. " user total races"
	end
	if data.userTotalRunCount > 0 then
		text = text .. " / " .. data.userTotalRunCount .. " user total runs"
	end

	if data.awardCount > 0 then
		text = text .. " / " .. data.awardCount .. " awards"
	end

	return text
end

module.FormatMultilineText = function(data: tt.lbUserStats)
	local text: string = data.findCount
		.. " signs found - "
		.. data.cwrs
		.. " cwrs - "
		.. data.cwrTop10s
		.. " cwrTop10s - "
		.. tpUtil.getCardinal(data.cwrRank)
		.. " cwrrank - "
		.. data.wrCount
		.. " wrs - "
		.. tpUtil.getCardinal(data.wrRank)
		.. " wrrank - "
		.. data.top10s
		.. " top10s - "
		.. data.userTix
		.. " tix - "
		.. data.userTotalRunCount
		.. " runs - "
		.. data.userTotalRaceCount
		.. " races - "
		.. data.daysInGame
		.. " days in game - "
		.. (data.awardCount or "")
		.. " awards. "
	return text
end

module.GetPlayerDescriptionMultilineByUserId = function(userId: number)
	local data: tt.lbUserStats = module.GetStatsByUserId(userId, "desc multiline")
	return module.FormatMultilineText(data)
end

module.getPlayerDescriptionMultilineByUsername = function(username: string)
	local data: tt.lbUserStats = module.GetPlayerStatsByUsername(username, "desc multiline")
	return module.FormatMultilineText(data)
end

module.getSignWRLeader = function(signId: number)
	local request: tt.postRequest = {
		remoteActionName = "getSignWRLeader",
		data = { signId = signId },
	}
	local leaders = rdb.MakePostRequest(request)
	return leaders
end

module.getRelatedSignsForSignLeaderLeftClick = function(signId: number, userId: number)
	local request: tt.postRequest = {
		remoteActionName = "getRelatedSignsForSignLeaderLeftClick",
		data = { signId = signId, userId = userId },
	}
	local res = rdb.MakePostRequest(request)
	return res
end

module.getFinderLeaders = function()
	local request: tt.postRequest = {
		remoteActionName = "getFinderLeaders",
		data = {},
	}
	local leaders = rdb.MakePostRequest(request)
	return leaders
end

--cache of all, maintained locally and gotten only once.
--userid => table?
local findCache: { [number]: { [number]: boolean } } = {}
module.GetUserSignFinds = function(userId: number, kind: string): { [number]: boolean }
	if findCache[userId] == nil then
		_annotate(string.format("GetUserSignFinds: CACHE MISS userId=%d kind=%s, fetching from backend", userId, kind))
		local request: tt.postRequest = {
			remoteActionName = "getUserSignFinds",
			data = { userId = userId, kind = kind },
		}
		local raw = rdb.MakePostRequest(request)
		findCache[userId] = {}
		local count = 0
		for strSignId, val in pairs(raw) do
			local num = tonumber(strSignId)
			if num then
				findCache[userId][num] = true
				count = count + 1
			end
		end
		_annotate(string.format("GetUserSignFinds: loaded %d finds for userId=%d", count, userId))
	end
	return findCache[userId]
end

module.getCommonFoundSignNames = function(): any
	local res = {} --signId : bool
	local playerCount = 0
	for _, player in ipairs(PlayersService:GetPlayers()) do
		local base = module.GetUserSignFinds(player.UserId, "getCommonFoundSignNames")
		for signId: number, _ in pairs(base) do
			if res[signId] == nil then
				res[signId] = 0
			end
			res[signId] = res[signId] + 1
		end
		playerCount += 1
	end
	local signNames = {}
	for signId, count in pairs(res) do
		if count == playerCount then
			local signName = tpUtil.signId2signName(signId)
			table.insert(signNames, signName)
		end
	end
	table.sort(signNames)
	return signNames
end

module.getCommonFoundSignIdsExcludingNoobs = function(requiredFinderUserId)
	local targetFounds = {}
	local userFinds = module.GetUserSignFinds(requiredFinderUserId, "userFinds. getCommonFoundSignIdsExcludingNoobs")
	for signId: number, _ in pairs(userFinds) do
		local _name = tpUtil.signId2signName(signId)
		local bad = false
		local sign = tpUtil.signId2Sign(signId)
		if not tpUtil.SignCanBeHighlighted(sign) then
			bad = true
		end
		if bad then
			continue
		end
		targetFounds[signId] = true
	end
	for _, serverPlayer in pairs(PlayersService:GetPlayers()) do
		if serverPlayer.UserId == requiredFinderUserId then
			continue
		end
		local otherPlayerFounds = module.GetUserSignFinds(serverPlayer.UserId, " serverPlayer getCommonFoundSignIdsExcludingNoobs")
		if #otherPlayerFounds <= 5 then
			continue
		end
		for signId: number, _ in pairs(targetFounds) do
			if otherPlayerFounds[signId] then
				continue
			end
			--exclude signs someone (non-noob) has not found.
			targetFounds[signId] = false
		end
	end
	local res = {}

	for signId, val in pairs(targetFounds) do
		if not val then
			continue
		end
		table.insert(res, signId)
	end
	return res
end

--always instant from server-side since we preload and keep cache of finds from the point the user joins
module.HasUserFoundSign = function(userId: number, signId: number)
	local finds = module.GetUserSignFinds(userId, "HasUserFoundSign")
	local res = finds[signId]
	return res
end

--before sending upstream call to let the db the user found a sign, also set it in the user sign find cache
module.ImmediatelySetUserFoundSignInCache = function(userId, signId)
	findCache[userId][signId] = true
end

--later this should be an autocompleter
--signnames = "A-B"
module.describeRaceHistoryMultilineText = function(signId1: number, signId2: number, playerUserId: number, userIdsInServer: { number }): { { message: string, options: { ChatColor: Color3? }? } }
	if signId1 == signId2 then
		return { { message = "Nice try mister. You can't race from a sign to itself." } }
	end

	if signId1 == nil or signId2 == nil then
		return { { message = "unknown" } }
	end

	local real1: string = enums.signId2name[signId1]
	local real2: string = enums.signId2name[signId2]

	local signsFolder: Instance? = game.Workspace:FindFirstChild("Signs")
	if not signsFolder or not signsFolder:IsA("Folder") then
		warn("playerData2: Signs folder not found")
		return {}
	end
	local sign1Instance: Instance? = signsFolder:FindFirstChild(real1)
	local sign2Instance: Instance? = signsFolder:FindFirstChild(real2)
	local dist: number

	--protect dev place
	if not sign1Instance or not sign1Instance:IsA("Part") or not sign2Instance or not sign2Instance:IsA("Part") then
		warn("no such sign")
		dist = 987654
		-- return ""
	else
		local sign1: Part = sign1Instance :: Part
		local sign2: Part = sign2Instance :: Part
		dist = tpUtil.getDist(sign1.Position, sign2.Position)
	end

	local request: tt.postRequest = {
		remoteActionName = "getBestTimesByRace",
		data = { startSignId = signId1, endSignId = signId2, userIdsCsv = textUtil.stringJoin(",", userIdsInServer) },
	}
	local runEntries = rdb.MakePostRequest(request)

	local headerRow = string.format("Top Runs for the race from: %s to %s (%0.1fd)\n", real1, real2, dist)
	local entries: { { message: string, options: { ChatColor: Color3? }? } } = {}
	table.insert(entries, { message = headerRow, options = { ChatColor = colors.white } })
	for ii, entry in ipairs(runEntries) do
		if not entry then
			break
		end
		local placeText = tpUtil.getCardinalEmoji(ii)
		local speed = dist / entry.runMilliseconds * 1000
		local row = string.format("%s %s - %s - (%0.1fd/s)", placeText, tpUtil.fmtms(entry.runMilliseconds), entry.username, speed)
		local options = { ChatColor = colors.white }
		if playerUserId == entry.userId then
			options.ChatColor = colors.meColor
		end

		for _, u in pairs(userIdsInServer) do
			if u == entry.userId then
				options.ChatColor = colors.greenGo
				break
			end
		end
		table.insert(entries, { message = row, options = options })
	end

	local countRequest: tt.postRequest = {
		remoteActionName = "getTotalRunCountByRace",
		data = { startSignId = signId1, endSignId = signId2 },
	}
	local runCount = rdb.MakePostRequest(countRequest)["count"]
	if runCount == 0 then
		return {
			{
				message = "Nobody has ever run the race from " .. real1 .. " to " .. real2 .. "!  You can be the first!",
			},
		}
	end

	if runCount == 1 then
		table.insert(entries, { message = "This race has only been run once!", options = { ChatColor = colors.white } })
	else
		local runnerRequest: tt.postRequest = {
			remoteActionName = "getTotalBestRunCountByRace",
			data = { startSignId = signId1, endSignId = signId2 },
		}
		local runnerCount = rdb.MakePostRequest(runnerRequest)["count"]
		local last = "This race has been run " .. tostring(runCount) .. " times, by " .. tostring(runnerCount) .. " racers!"
		table.insert(entries, { message = last, options = { ChatColor = colors.white } })
	end

	return entries
end

_annotate("end")
return module
