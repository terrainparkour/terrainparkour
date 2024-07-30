--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local remotes = require(game.ReplicatedStorage.util.remotes)
local remoteDbInternal = require(game.ServerScriptService.remoteDbInternal)
local textUtil = require(game.ReplicatedStorage.util.textUtil)
local ContestResponseTypes = require(game.ReplicatedStorage.types.ContestResponseTypes)
local grantBadge = require(game.ServerScriptService.grantBadge)
local badgeEnums = require(game.ReplicatedStorage.util.badgeEnums)

local module = {}

local function GetSingleContest(
	player: Player,
	userIds: { number },
	contestId: number
): { ContestResponseTypes.Contest }
	local userIdsInServer = {}
	for _, userId in ipairs(userIds) do
		table.insert(userIdsInServer, tostring(userId))
	end
	local joined = textUtil.stringJoin(",", userIdsInServer)
	local contest: { ContestResponseTypes.Contest } = remoteDbInternal.remoteGet(
		"getSingleContest",
		{ userId = player.UserId, otherUserIdsInServer = joined, contestId = contestId }
	)["res"]

	return contest
end

local function checkContestBadgeGranting(player: Player, contest)
	--if user has joined all races, award badge
	local bad = true
	local completed = 0

	for _, el in ipairs(contest.races) do
		bad = true
		for _, el2 in ipairs(el.runners) do
			if el2.userId == player.UserId then
				bad = false
				completed += 1
				break
			end
		end
		if bad then
			break
		end
		bad = false
	end
	if not bad then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
end

local function checkLeadContestBadgeGranting(player: Player, contest)
	if
		contest ~= nil
		and contest.leaders ~= nil
		and contest.leaders["1"] ~= nil
		and contest.leaders["1"].userId == player.UserId
	then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.LeadContest)
	end
end

local function GetContests(player: Player, userIds: { number }): { ContestResponseTypes.Contest }
	local userIdsInServer = {}
	for _, userId in ipairs(userIds) do
		table.insert(userIdsInServer, tostring(userId))
	end
	local joined = textUtil.stringJoin(",", userIdsInServer)
	local contests: { ContestResponseTypes.Contest } =
		remoteDbInternal.remoteGet("getContests", { userId = player.UserId, otherUserIdsInServer = joined })["res"]

	--award badge if in first place
	for _, contest in pairs(contests) do
		checkLeadContestBadgeGranting(player, contest)
		checkContestBadgeGranting(player, contest)
	end

	return contests
end

module.Init = function()
	local func = remotes.getRemoteFunction("GetContestsFunction") :: RemoteFunction
	func.OnServerInvoke = function(player: Player, userIds: { number }): any
		return GetContests(player, userIds)
	end

	local func2 = remotes.getRemoteFunction("GetSingleContestFunction") :: RemoteFunction
	func2.OnServerInvoke = function(player: Player, userIds: { number }, contestId: number): any
		return GetSingleContest(player, userIds, contestId)
	end
end

_annotate("end")
return module
