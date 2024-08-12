--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local httpservice = require(game.ServerScriptService.httpService)
local HttpService = game:GetService("HttpService")
-- local vscdebug = require(game.ReplicatedStorage.vscdebug)

local textUtil = require(game.ReplicatedStorage.util.textUtil)

local host
local s, c = pcall(function()
	host = require(game.ServerScriptService.hostSecret)
end)
if not s then
	print("you are running the test version; host remote calls will not work.")
	host = nil
end

local enums = require(game.ReplicatedStorage.util.enums)
local notify = require(game.ReplicatedStorage.notify)
local tt = require(game.ReplicatedStorage.types.gametypes)
local config = require(game.ReplicatedStorage.config)

local module = {}

local function getRemoteUrl(path: string)
	local url = "http://" .. host.HOST .. "terrain/" .. path
	return url
end

-- maps object/verb to path for communication into urls.py
local function getPath(kind: string, data: any)
	local stringdata = textUtil.getStringifiedTable(data)
	if kind == "robloxUserJoined" then
		local uu = data.username
		if data.userId == enums.objects.TerrainParkourUserId then
			uu = "TerrainParkour"
		end
		local useBoolean = ""
		if stringdata.isMobile == "true" then
			useBoolean = "true"
		else
			useBoolean = "false"
		end
		return kind
			.. "/"
			.. tostring(stringdata.userId)
			.. "/"
			.. uu
			.. "/"
			.. enums.gameVersion
			.. "/"
			.. useBoolean
			.. "/"
	elseif kind == "getOrCreateBooleanSetting" then
		local safeDomain = HttpService:UrlEncode(stringdata.domain)
		local safeName = HttpService:UrlEncode(stringdata.name)
		return kind .. "/" .. safeDomain .. "/" .. safeName .. "/"
	elseif kind == "robloxUserJoinedFirst" then
		return kind
			.. "/"
			.. stringdata.userId
			.. "/"
			.. stringdata.username
			.. "/"
			.. enums.gameVersion
			.. "/"
			.. tostring(stringdata.isMobile)
			.. "/"
	elseif kind == "beckon" then
		return kind .. "/" .. tostring(stringdata.userId)
	elseif kind == "getAwardsByUser" then
		return kind .. "/" .. tostring(stringdata.username)
	elseif kind == "getBadgesByUser" then
		-- only optimistically cache positives, nothing about negatives.
		return kind .. "/" .. tostring(stringdata.userId)
	elseif kind == "saveUserBadgeGrant" then
		-- also serves to notify the server about the existence of badges
		return kind .. "/" .. stringdata.userId .. "/" .. stringdata.badgeAssetId .. "/" .. stringdata.badgeName
	elseif kind == "getMarathonKinds" then
		return kind .. "/"
	elseif kind == "getSettingsForUser" then
		return kind .. "/" .. stringdata.userId
	elseif kind == "updateSettingForUser" then
		return kind
			.. "/"
			.. stringdata.settingName
			.. "/"
			.. stringdata.domain
			.. "/"
			.. stringdata.userId
			.. "/"
			.. stringdata.value
	elseif kind == "getMarathonKindLeaders" then
		return kind .. "/" .. stringdata.marathonKind
	elseif kind == "userFinishedMarathon" then
		return kind
			.. "/"
			.. stringdata.userId
			.. "/"
			.. stringdata.orderedSigns
			.. "/"
			.. stringdata.runMilliseconds
			.. "/"
			.. stringdata.marathonKind
			.. "/"
	elseif kind == "userLeft" then
		return kind .. "/" .. stringdata.userId .. "/"
	elseif kind == "userFoundSign" then
		return kind .. "/" .. stringdata.userId .. "/" .. stringdata.signId .. "/"
	elseif kind == "userSentMessage" then
		return kind .. "/"
	elseif kind == "setUserBanLevel" then
		return kind .. "/" .. stringdata.userId .. "/" .. stringdata["banLevel"] .. "/"
	elseif kind == "getUserBanLevel" then
		return kind .. "/" .. stringdata.userId .. "/"
	elseif kind == "getFoundSignIds" then
		return kind .. "/" .. stringdata.userId .. "/"
	elseif kind == "userDied" then
		return kind
			.. "/"
			.. stringdata.userId
			.. "/"
			.. stringdata.x
			.. "/"
			.. stringdata.y
			.. "/"
			.. stringdata.z
			.. "/"
	elseif kind == "userQuit" then
		return kind
			.. "/"
			.. stringdata.userId
			.. "/"
			.. stringdata.x
			.. "/"
			.. stringdata.y
			.. "/"
			.. stringdata.z
			.. "/"
	elseif kind == "userReset" then
		return kind
			.. "/"
			.. stringdata.userId
			.. "/"
			.. stringdata.x
			.. "/"
			.. stringdata.y
			.. "/"
			.. stringdata.z
			.. "/"
	elseif kind == "userFinishedRun" then
		return kind
			.. "/"
			.. stringdata.userId
			.. "/"
			.. stringdata.startId
			.. "/"
			.. stringdata.endId
			.. "/"
			.. stringdata.runMilliseconds
			.. "/"

		---stats DAY
	elseif kind == "getPopular" then
		return kind .. "/" .. stringdata.userId .. "/" .. stringdata.otherUserIdsInServer .. "/"
	elseif kind == "getNew" then
		return kind .. "/" .. stringdata.userId .. "/" .. stringdata.otherUserIdsInServer .. "/"
	elseif kind == "getContests" then
		return kind .. "/" .. stringdata.userId .. "/" .. stringdata.otherUserIdsInServer .. "/"
	elseif kind == "getContestNames" then
		return kind .. "/" .. stringdata.userId .. "/"
	elseif kind == "getSingleContest" then
		return kind .. "/" .. stringdata.userId .. "/" .. stringdata.otherUserIdsInServer .. "/" .. stringdata.contestId

		---stats SIGN
	elseif kind == "getTotalFindCountBySign" then
		return kind .. "/" .. stringdata.signId .. "/"

		--stats USER
	elseif kind == "getUserSignFinds" then
		return kind .. "/" .. stringdata.userId .. "/"
	elseif kind == "getTotalRunCount" then
		return kind .. "/"
	elseif kind == "getTotalRaceCount" then
		return kind .. "/"
	elseif kind == "getNonTop10RacesByUser" then
		return kind .. "/" .. stringdata.userId .. "/"
	elseif kind == "getNonWRsByToSignIdAndUserId" then
		return kind .. "/" .. stringdata.userId .. "/" .. stringdata.to .. "/" .. stringdata.signId
	elseif kind == "getStatsByUser" then
		return kind .. "/" .. stringdata.userId .. "/"
	elseif kind == "getTotalFindCountByUser" then
		return kind .. "/" .. stringdata.userId .. "/"
	elseif kind == "getRaceInfoByUser" then
		return kind .. "/" .. stringdata.userId .. "/" .. stringdata.startId .. "/" .. stringdata.endId .. "/"
	elseif kind == "getTotalRunCountByDay" then
		return kind .. "/"
	elseif kind == "getTotalRaceCountByDay" then
		return kind .. "/"
	elseif kind == "getTotalRunCountByUserAndDay" then
		return kind .. "/" .. stringdata.userId .. "/"
	elseif kind == "getTotalFindCountByDay" then
		return kind .. "/"
	elseif kind == "dynamicRunFrom" then
		return kind
			.. "/"
			.. stringdata.userId
			.. "/"
			.. stringdata.startSignId
			.. "/"
			.. stringdata.targetSignIds
			.. "/"
		--metadata
	elseif kind == "setSignPosition" then
		return kind
			.. "/"
			.. stringdata.signId
			.. "/"
			.. HttpService:UrlEncode(stringdata.name)
			.. "/"
			.. stringdata.x
			.. "/"
			.. stringdata.y
			.. "/"
			.. stringdata.z
			.. "/"

		--for listing known signs.
	elseif kind == "getKnownSignIds" then
		return kind .. "/"
	elseif kind == "getSignProfileForUser" then
		return kind .. "/" .. stringdata.username .. "/" .. stringdata.signId .. "/"

		--stats RACE
	elseif kind == "getTotalRunCountByUserAndRace" then
		return kind .. "/" .. stringdata.userId .. "/" .. stringdata.startId .. "/" .. stringdata.endId .. "/"
	elseif kind == "getTotalRunCountByUser" then
		return kind .. "/" .. stringdata.userId .. "/"
	elseif kind == "getTotalRunCountByRace" then
		return kind .. "/" .. stringdata.startId .. "/" .. stringdata.endId .. "/"
	elseif kind == "getTotalBestRunCountByRace" then
		return kind .. "/" .. stringdata.startId .. "/" .. stringdata.endId .. "/"

		--probably not working
	elseif kind == "getTotalRaceCountByUser" then
		return kind .. "/" .. stringdata.userId .. "/"

		--STATS for billboard - not used
	elseif kind == "getListWrsToday" then
		return kind .. "/"

		--summary
	elseif kind == "getBestTimesByRace" then
		return kind .. "/" .. stringdata.startId .. "/" .. stringdata.endId .. "/" .. stringdata.userIdsCsv .. "/"

		-- elseif kind=='getNearestNineAndUserStatus' then
		-- 	return kind..'/'..stringdata.signId..'/'..stringdata.userId..'/'

		-- elseif kind=='getInteresting' then
		-- 	return kind..'/'..stringdata.signId..'/'..stringdata.userId..'/'
	elseif kind == "getRelatedSigns" then
		return kind .. "/" .. stringdata.signId .. "/" .. stringdata.userId .. "/"
	elseif kind == "getFinderLeaders" then
		return kind .. "/"
	elseif kind == "getWRLeaders" then
		return kind .. "/"
	elseif kind == "getSignWRLeader" then
		return kind .. "/" .. stringdata.signId .. "/"
	elseif kind == "getSignStartLeader" then
		return kind .. "/" .. stringdata.signId .. "/"
	elseif kind == "getSignEndLeader" then
		return kind .. "/" .. stringdata.signId .. "/"

		--events
	elseif kind == "getUpcomingEvents" then
		return kind .. "/"
	elseif kind == "getEphemeralEvents" then
		return kind .. "/"
	elseif kind == "getCurrentEvents" then
		return kind .. "/"
		--tix
	elseif kind == "getTixBalanceByUsername" then
		return kind .. "/" .. stringdata.username .. "/"
	end

	error(string.format("bad input. kind=%s data=%s", tostring(kind), tostring(data)))
	return "BAD FALLTHROUGH."
end

--also send actionResults (for others) to notify.
local function afterRemoteDbActions(kind: string, afterData: tt.afterdata)
	if afterData.actionResults == nil then
		return
	end
	if #afterData.actionResults == 0 then
		return
	end
	--we filter my action results out, because those will be handled in the main get/post call return
	--(by addition to the main sign for results.)
	local otherUserActionResults: { tt.actionResult } = {}
	for _, el in ipairs(afterData.actionResults) do
		--we only accept notifyAllExcept ARs.
		-- this means only ones which exclude a single user.
		if el.notifyAllExcept == true then
			table.insert(otherUserActionResults, el)
		else
			table.insert(otherUserActionResults, el)
		end
	end

	notify.handleActionResults(otherUserActionResults)
end

--actual URL construction, etc. method.
module.remoteGet = function(kind: string, data: any): any
	if not host then
		error("no host.")
	end
	local path = getPath(kind, data)
	local url = getRemoteUrl(path)
	local surl: string = host.addSecretStr(url)

	if config.isInStudio() or data.userId == enums.objects.TerrainParkourUserId then
		data.secret = nil
		--clear secret for later printing.
	end
	local st = tick()
	local res = httpservice.httpThrottledJsonGet(surl)
	if config.isInStudio() or data.userId == enums.objects.TerrainParkourUserId then
		_annotate(string.format("DONE %0.3f %s", tick() - st, url))
		_annotate(string.format("remoteDbInternal.remoteGet took: %0.3f %s", tick() - st, url))
	end
	if not res.banned then
		afterRemoteDbActions(kind, res)
	end
	return res
end

--how this works: any post endpoint, send to here for security and jsonification of params
--then it'll be picked up by postsecurity.
module.remotePost = function(kind: string, data: any)
	if not host then
		error("no host.")
	end
	local path = kind .. "/"
	local url = getRemoteUrl(path)
	host.addSecretTbl(data)

	local st: number = tick()
	local res = httpservice.httpThrottledJsonPost(url, data)
	res.userId = tonumber(res.userId)
	if config.isInStudio() or data.userId == enums.objects.TerrainParkourUserId then
		data.secret = nil
		_annotate(string.format("%0.3f kind: " .. kind .. " url:" .. url, tick() - st))
	end

	task.spawn(function()
		if not res.banned then
			afterRemoteDbActions(kind, res)
		end
	end)

	return res
end

_annotate("end")
return module
