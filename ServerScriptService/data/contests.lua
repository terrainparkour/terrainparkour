--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local tt = require(game.ReplicatedStorage.types.gametypes)
local remotes = require(game.ReplicatedStorage.util.remotes)
local rdb = require(game.ServerScriptService.rdb)
local textUtil = require(game.ReplicatedStorage.util.textUtil)
local ContestResponseTypes = require(game.ReplicatedStorage.types.ContestResponseTypes)
local grantBadge = require(game.ServerScriptService.grantBadge)
local badgeEnums = require(game.ReplicatedStorage.util.badgeEnums)

local Players = game:GetService("Players")
local module = {}

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

local function GetSingleContest(player: Player, contestId: number): { ContestResponseTypes.Contest }
	local userIdsInServer = {}
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		table.insert(userIdsInServer, tostring(otherPlayer.UserId))
	end
	local joined = textUtil.stringJoin(",", userIdsInServer)

	local request: tt.postRequest = {
		remoteActionName = "getSingleContest",
		data = { userId = player.UserId, otherUserIdsInServer = joined, contestId = contestId },
	}
	local contest: { ContestResponseTypes.Contest } = rdb.MakePostRequest(request)

	return contest
end

local function GetContests(player: Player): { ContestResponseTypes.Contest }
	local userIdsInServer = {}
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		table.insert(userIdsInServer, tostring(otherPlayer.UserId))
	end
	local joined = textUtil.stringJoin(",", userIdsInServer)

	local request: tt.postRequest = {
		remoteActionName = "getContests",
		data = { userId = player.UserId, otherUserIdsInServer = joined },
	}
	local contests: { ContestResponseTypes.Contest } = rdb.MakePostRequest(request)

	--award badge if in first place
	--TODO
	for _, contest in pairs(contests) do
		checkLeadContestBadgeGranting(player, contest)
		checkContestBadgeGranting(player, contest)
	end

	return contests
end

module.Init = function()
	local func = remotes.getRemoteFunction("GetContestsFunction") :: RemoteFunction
	func.OnServerInvoke = function(player: Player): any
		return GetContests(player)
	end

	local func2 = remotes.getRemoteFunction("GetSingleContestFunction") :: RemoteFunction
	func2.OnServerInvoke = function(player: Player, contestId: number): any
		return GetSingleContest(player, contestId)
	end
end

_annotate("end")
return module
