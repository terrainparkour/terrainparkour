--!strict

--generic getters for player information for use by commands or UIs or LBs
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local enums = require(game.ReplicatedStorage.util.enums)
local emojis = require(game.ReplicatedStorage.enums.emojis)
local remoteDbInternal = require(game.ServerScriptService.remoteDbInternal)
local textUtil = require(game.ReplicatedStorage.util.textUtil)
local colors = require(game.ReplicatedStorage.util.colors)

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
	local rdb = require(game.ServerScriptService.rdb)
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

	local badgeCheckers = require(game.ServerScriptService.badgeCheckersSecret)
	badgeCheckers.checkBadgeGrantingFromSignWrLeaderData(signWRLeaderData, player.UserId)

	while true do
		if got == 2 then
			local res = {
				signWRLeaderData = signWRLeaderData,
				relatedSignData = relatedSignData,
			}
			return res
		end
		wait(0.3)
	end
end

clickSignRemoteFunction.OnServerInvoke = function(player: Player, signClickMessage: tt.signClickMessage): any
	if signClickMessage.leftClick then
		return serverInvokeClickSignRemote(player, signClickMessage.signId)
	else
		local signProfileCommand = require(game.ReplicatedStorage.commands.signProfileCommand)
		signProfileCommand.signProfileCommand(player.Name, signClickMessage.signId, player)
	end
end

module.getCommonFoundSignNames = function(): any
	local res = {} --signId : bool
	local playerCount = 0
	local rdb = require(game.ServerScriptService.rdb)
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
	local rdb = require(game.ServerScriptService.rdb)
	local userFinds = rdb.getUserSignFinds(requiredFinderUserId)
	for signId: number, _ in pairs(userFinds) do
		local name = tpUtil.signId2signName(signId)
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
module.describeRaceHistoryMultilineText = function(
	signId1: number,
	signId2: number,
	playerUserId: number,
	userIdsInServer: { number }
): { { message: string, options: {} | nil } }
	if signId1 == signId2 then
		return { { message = "Nice try mister. You can't race from a sign to itself." } }
	end

	if signId1 == nil or signId2 == nil then
		return { { message = "unknown" } }
	end

	local real1: string = enums.signId2name[signId1]
	local real2: string = enums.signId2name[signId2]

	local sign1: Part = game.Workspace:FindFirstChild("Signs"):FindFirstChild(real1) :: Part
	local sign2: Part = game.Workspace:FindFirstChild("Signs"):FindFirstChild(real2) :: Part
	local dist

	--protect dev plcae
	if sign1 == nil or sign2 == nil then
		warn("no such sign")
		dist = 987654
		-- return ""
	else
		dist = tpUtil.getDist(sign1.Position, sign2.Position)
	end
	local runEntries = remoteDbInternal.remoteGet(
		"getBestTimesByRace",
		{ startId = signId1, endId = signId2, userIdsCsv = textUtil.stringJoin(",", userIdsInServer) }
	)["res"]
	local headerRow = string.format("Top Runs for the race from: %s to %s (%0.1fd)\n", real1, real2, dist)
	local entries = {}
	table.insert(entries, { message = headerRow, options = { ChatColor = colors.white } })
	for ii, entry in ipairs(runEntries) do
		if not entry then
			break
		end
		local placeText = tpUtil.getCardinalEmoji(ii)
		if ii > 10 then
			placeText = emojis.emojis.BOMB
		end
		local speed = dist / entry.runMilliseconds * 1000
		local row = string.format(
			"%s %s - %s - (%0.1fd/s)",
			placeText,
			tpUtil.fmtms(entry.runMilliseconds),
			entry.username,
			speed
		)
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

	local runCount =
		remoteDbInternal.remoteGet("getTotalRunCountByRace", { startId = signId1, endId = signId2 })["count"]
	if runCount == 0 then
		return {
			{
				message = "Nobody has ever run the race from "
					.. real1
					.. " to "
					.. real2
					.. "!  You can be the first!",
			},
		}
	end

	if runCount == 1 then
		table.insert(entries, { message = "This race has only been run once!", options = { ChatColor = colors.white } })
	else
		local runnerCount =
			remoteDbInternal.remoteGet("getTotalBestRunCountByRace", { startId = signId1, endId = signId2 })["count"]
		local last = "This race has been run "
			.. tostring(runCount)
			.. " times, by "
			.. tostring(runnerCount)
			.. " racers!"
		table.insert(entries, { message = last, options = { ChatColor = colors.white } })
	end

	return entries
end

_annotate("end")
return module
