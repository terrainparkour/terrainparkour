--!strict

--eval 9.25.22
--generic getters for player information for use by commands or UIs or LBs

local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local enums = require(game.ReplicatedStorage.util.enums)

local rdb = require(game.ServerScriptService.rdb)
local remoteDbInternal = require(game.ServerScriptService.remoteDbInternal)

local badgeCheckers = require(game.ServerScriptService.badgeCheckersSecret)
local PlayersService = game:GetService("Players")
local tt = require(game.ReplicatedStorage.types.gametypes)

local module = {}

module.getGameStats = function()
	local todayRuns = remoteDbInternal.remoteGet("getTotalRunCountByDay", {})["count"]
	local allTimeRuns = remoteDbInternal.remoteGet("getTotalRunCount", {})["count"]
	local totalRaces = remoteDbInternal.remoteGet("getTotalRaceCount", {})["count"]
	local text = tostring(todayRuns) .. " runs today\n"
	text = text .. tostring(allTimeRuns) .. " runs have been done ever!\n"
	text = text .. tostring(totalRaces) .. " different races have been discovered."
	return text
end

module.getNonTop10RacesByUserId = function(userId: number, kind: string): tt.getNonTop10RacesByUser
	local stats: tt.getNonTop10RacesByUser = remoteDbInternal.remoteGet("getNonTop10RacesByUser", { userId = userId })
	return stats
end

module.getNonWRsByToSignIdAndUserId = function(to: string, signId: number, userId: number, kind: string)
	local stats: tt.getNonTop10RacesByUser =
		remoteDbInternal.remoteGet("getNonWRsByToSignIdAndUserId", { userId = userId, to = to, signId = signId })
	return stats
end

--kind is just a description for debugging.
module.getPlayerStatsByUserId = function(userId: number, kind: string): tt.afterData_getStatsByUser
	local stats: tt.afterData_getStatsByUser = remoteDbInternal.remoteGet("getStatsByUser", { userId = userId })
	stats.kind = kind
	local totalSignCount = rdb.getGameSignCount()
	stats.totalSignCount = totalSignCount
	return stats
end

module.convertStatsToDescriptionLine = function(data)
	local text = data.userTotalFindCount .. " signs found "

	if data.races > 0 then
		text = text .. " / " .. data.races .. " races"
	end
	if data.runs > 0 then
		text = text .. " / " .. data.runs .. " runs"
	end
	if data.top10s > 0 then
		text = text .. " / " .. data.top10s .. " top10s"
	end
	if data.userTotalWRCount > 0 then
		text = text .. " / " .. data.userTotalWRCount .. " World Records"
	end
	if data.userCompetitiveWRCount > 0 then
		text = text .. " / " .. data.userCompetitiveWRCount .. " Competitive WRs."
	end
	return text
end

module.getPlayerDescriptionLine = function(userId: number)
	local data: tt.afterData_getStatsByUser = module.getPlayerStatsByUserId(userId, "desc line")
	return module.convertStatsToDescriptionLine(data)
end

module.getPlayerDescriptionMultiline = function(userId: number)
	local data: tt.afterData_getStatsByUser = module.getPlayerStatsByUserId(userId, "desc multiline")
	local text: string = "\n"
		.. data.userTotalFindCount
		.. " signs found\n"
		.. data.runs
		.. " runs\n"
		.. data.races
		.. " races\n"
		.. data.top10s
		.. " top10s\n"
		.. data.userTotalWRCount
		.. " World Records\n"
		.. data.userTix
		.. " Tix!"
	return text
end

module.getSignWRLeader = function(signId: number)
	local leaders = remoteDbInternal.remoteGet("getSignWRLeader", { signId = signId })
	return leaders.res
end

module.getRelatedSigns = function(signId: number, userId: number)
	local res = remoteDbInternal.remoteGet("getRelatedSigns", { signId = signId, userId = userId })
	return res
end

module.getFinderLeaders = function()
	local leaders = remoteDbInternal.remoteGet("getFinderLeaders", {})
	return leaders
end

local clickSignRemoteFunction: RemoteFunction =
	game:GetService("ReplicatedStorage"):WaitForChild("RemoteFunctions"):WaitForChild("ClickSignRemoteFunction")

local function serverInvokeClickSignRemote(player: Player, signId: number)
	local got = 0
	local relatedSignData = {}

	local signWRLeaderData: { tt.signWrStatus }
	local s1, e1 = pcall(function()
		relatedSignData = module.getRelatedSigns(signId, player.UserId)
		got = got + 1
	end)

	if not s1 then
		warn("failed to get related signs." .. e1)
		relatedSignData = {}
		got = got + 1
	end

	local s2, e2 = pcall(function()
		signWRLeaderData = module.getSignWRLeader(signId)
		got = got + 1
	end)

	if not s2 then
		warn("failed to get sign WR Data." .. e2)
		signWRLeaderData = {}
		got = got + 1
	end
	badgeCheckers.checkBadgeGrantingFromSignWrLeaderData(signWRLeaderData, player.UserId)

	while true do
		if got == 2 then
			local res = {
				signWRLeaderData = signWRLeaderData,
				relatedSignData = relatedSignData,
			}
			return res
		end
	end
end

clickSignRemoteFunction.OnServerInvoke = function(player: Player, signId: number): any
	return serverInvokeClickSignRemote(player, signId)
end

--whats the difference between this and "+s"
--2021: add top leaders for starts.
module.describeSignText = function(userId: number, signname: string): string
	local signId = tpUtil.looseSignName2SignId(signname)
	if signId == nil then
		return "unknown"
	end
	if not rdb.hasUserFoundSign(userId, signId) then
		return "You haven't found this sign yet, so can't look up information on it."
	end
	local realSignName = enums.signId2name[signId]
	local signFindCount = remoteDbInternal.remoteGet("getTotalFindCountBySign", { signId = signId })["count"]

	local fromleaders = remoteDbInternal.remoteGet("getSignStartLeader", { signId = signId })
	local toleaders = remoteDbInternal.remoteGet("getSignEndLeader", { signId = signId })

	local counts: { [string]: { to: number, from: number, username: string } } = {}
	local text = "\nSign Leader for "
		.. realSignName
		.. "!\n"
		.. tostring(signFindCount)
		.. " players have found "
		.. realSignName
		.. "\nrank name total (from/to)"
	for _, leader in ipairs(fromleaders.res) do
		local username: string
		if leader.userId < 0 then
			username = "player" .. leader.userId
		else
			username = rdb.getUsernameByUserId(leader.userId)
		end
		if counts[username] == nil then
			counts[username] = { to = 0, from = 0, username = username }
		end

		counts[username].from = counts[username].from + leader.count
	end

	for _, leader in ipairs(toleaders.res) do
		local username: string
		if leader.userId < 0 then
			username = "player" .. leader.userId
		else
			username = rdb.getUsernameByUserId(leader.userId)
		end
		if counts[username] == nil then
			counts[username] = { to = 0, from = 0, username = username }
		end
		counts[username].to = counts[username].to + leader.count
	end
	local tbl = {}
	for username, item in pairs(counts) do
		table.insert(tbl, item)
	end
	table.sort(tbl, function(a, b)
		return a.to + a.from > b.to + b.from
	end)

	for ii, item in ipairs(tbl) do
		text = text
			.. "\n"
			.. ii
			.. ". "
			.. item.username
			.. " - "
			.. item.to + item.from
			.. " "
			.. "("
			.. item.from
			.. "/"
			.. item.to
			.. ")"
	end
	return text
end

module.getCommonFoundSignNames = function(): any
	local res = {} --signId : bool
	local playerCount = 0
	for _, player in ipairs(PlayersService:GetPlayers()) do
		local base = rdb.getUserSignFinds(player.UserId)
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
	local userFinds = rdb.getUserSignFinds(requiredFinderUserId)
	for signId: number, _ in pairs(userFinds) do
		local name = tpUtil.signId2signName(signId)
		local bad = false
		for ii, badname in ipairs(enums.ExcludeSignNamesFromStartingAt) do
			if badname == name then
				bad = true
				break
			end
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
		local otherPlayerFounds = rdb.getUserSignFinds(serverPlayer.UserId)
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

--later this should be an autocompleter
--signnames = "A-B"
module.describeRaceHistoryMultilineText = function(signId1: number, signId2: number): string
	if signId1 == signId2 then
		return "Nice try mister. You can't race from a sign to itself."
	end

	if signId1 == nil or signId2 == nil then
		return "unknown"
	end

	local real1: string = enums.signId2name[signId1]
	local real2: string = enums.signId2name[signId2]

	local sign1: Part = game.Workspace:FindFirstChild("Signs"):FindFirstChild(real1) :: Part
	local sign2: Part = game.Workspace:FindFirstChild("Signs"):FindFirstChild(real2) :: Part
	if sign1 == nil or sign2 == nil then
		warn("no such sign")
		return ""
	end
	local runEntries = remoteDbInternal.remoteGet("getBestTimesByRace", { startId = signId1, endId = signId2 })["res"]

	local dist = tpUtil.getDist(sign1.Position, sign2.Position)
	local topList = string.format("Top Runs for the race from: %s to %s (%0.1fd)\n", real1, real2, dist)
	for ii = 1, 11 do
		local res = runEntries[ii]
		if not res then
			break
		end
		local placeText = tostring(ii)
		local speed = dist / res.runMilliseconds * 1000
		local row =
			string.format("%s: %s - %s - (%0.1fd/s)", placeText, tpUtil.fmtms(res.runMilliseconds), res.username, speed)
		topList = topList .. row .. "\n"
	end
	local runCount =
		remoteDbInternal.remoteGet("getTotalRunCountByRace", { startId = signId1, endId = signId2 })["count"]
	if runCount == 0 then
		return "Nobody has ever run the race from " .. real1 .. " to " .. real2 .. "!  You can be the first!"
	end

	if runCount == 1 then
		topList = topList .. "This race has only been run once!"
	else
		local runnerCount =
			remoteDbInternal.remoteGet("getTotalBestRunCountByRace", { startId = signId1, endId = signId2 })["count"]
		topList = topList
			.. "This race has been run "
			.. tostring(runCount)
			.. " times, by "
			.. tostring(runnerCount)
			.. " racers!"
	end

	return topList
end

return module
