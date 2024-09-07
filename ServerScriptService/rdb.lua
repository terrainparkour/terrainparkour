--!strict

--RemoteDb Wrappers
--ideally all things which require direct network calls should have sensible normal layers here incl caching
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local PlayersService = game:GetService("Players")

local vscdebug = require(game.ReplicatedStorage.vscdebug)
local textUtil = require(game.ReplicatedStorage.util.textUtil)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local tt = require(game.ReplicatedStorage.types.gametypes)
local remoteDbInternal = require(game.ServerScriptService.remoteDbInternal)
local enums = require(game.ReplicatedStorage.util.enums)
local userDataEnums = require(game.ReplicatedStorage.types.userDataEnums)

local module = {}

------------------HELPER LOGICAL METHODS----------------------------

--cache of all, maintained locally and gotten only once.
--userid => table?
local findCache: { [number]: { [number]: boolean } } = {}
module.getUserSignFinds = function(userId: number): { [number]: boolean }
	if findCache[userId] == nil then
		local raw = remoteDbInternal.remoteGet("getUserSignFinds", { userId = userId })
		findCache[userId] = {}
		for strSignId, val in pairs(raw) do
			local num = tonumber(strSignId)
			if num then
				findCache[userId][num] = true
			end
		end
	end
	return findCache[userId]
end

--always instant from server-side since we preload and keep cache of finds from the point the user joins
module.hasUserFoundSign = function(userId: number, signId: number)
	local finds = module.getUserSignFinds(userId)
	local res = finds[signId]
	return res
end

--before sending upstream call to let the db the user found a sign, also set it in the user sign find cache
module.ImmediatelySetUserFoundSignInCache = function(userId, signId)
	findCache[userId][signId] = true
end

local gameTotalSigncount = nil

-- hmmm this is fake and probably wrong.
module.getServerPatchedInTotalSignCountGameSignCount = function(): number
	if gameTotalSigncount == nil then
		gameTotalSigncount = #(game.Workspace:WaitForChild("Signs"):GetChildren())
	end
	return gameTotalSigncount
end

module.getRandomFoundSignName = function(userId: number): string
	local items = module.getUserSignFinds(userId)
	local choices = {}
	for signId: number, found: boolean in pairs(items) do
		if found then
			table.insert(choices, signId)
		end
	end
	local signId = choices[math.random(#choices)]
	local signName = tpUtil.signId2signName(signId)
	if signName == nil or signName == "" then
		warn("bad.")
	end
	return signName
end

module.getRandomSignName = function(): string
	local items = game.Workspace:WaitForChild("Signs"):GetChildren()
	local choices = {}
	for _, signPart: Part in pairs(items) do
		table.insert(choices, signPart.Name)
	end
	local signName = choices[math.random(#choices)]
	return signName
end

--set user found sign
module.userFoundSign = function(userId: number, signId: number): tt.pyUserFoundSign
	local res: tt.pyUserFoundSign =
		remoteDbInternal.remoteGet("userFoundSign", { userId = userId, signId = signId }) :: tt.pyUserFoundSign
	return res
end

module.userFinishedRun = function(data: tt.userFinishedRunOptions): tt.pyUserFinishedRunResponse
	local res: tt.pyUserFinishedRunResponse = remoteDbInternal.remotePost(data) :: tt.pyUserFinishedRunResponse
	return res
end

module.userSentMessage = function(data: any): any
	data.remoteActionName = "userSentMessage"
	local res = remoteDbInternal.remotePost(data)
	return res
end

--this is only available on the server unfortunately.
local playerUsernames = {}
module.getUsernameByUserId = function(userId: number)
	if not playerUsernames[userId] then
		--just shortcut this to save time on async lookup.
		if userId < 0 then
			playerUsernames[userId] = "TestUser" .. userId
			return playerUsernames[userId]
		end
		if userId == 0 then
			--missing userid escalate to shedletsky
			userId = 261
		end
		local res
		local s, e = pcall(function()
			res = PlayersService:GetNameFromUserIdAsync(userId)
		end)
		if not s then
			warn(e)
			return "Unknown Username for " .. userId
		end

		playerUsernames[userId] = res
		return res
	end

	return playerUsernames[userId]
end

module.userFinishedMarathon = function(
	userId: number,
	marathonKind: string,
	orderedSigns: string,
	runMilliseconds: number
): tt.pyUserFinishedRunResponse
	local res = remoteDbInternal.remoteGet("userFinishedMarathon", {
		userId = userId,
		marathonKind = marathonKind,
		orderedSigns = orderedSigns,
		runMilliseconds = runMilliseconds,
	})
	return res :: tt.pyUserFinishedRunResponse
end

module.getMarathonKindLeaders = function(marathonKind: string)
	local res = remoteDbInternal.remoteGet("getMarathonKindLeaders", { marathonKind = marathonKind })
	return res
end

module.getMarathonKinds = function()
	local res = remoteDbInternal.remoteGet("getMarathonKinds", {})
	return res
end

--TODO would be nice to fix this up, including return types.
module.GetTixBalanceByUsername = function(username: string)
	local res = remoteDbInternal.remoteGet("getTixBalanceByUsername", { username = username })
	return res
end

module.GetBadgesByUser = function(userId: number): { tt.pyUserBadgeGrant }
	local res = remoteDbInternal.remoteGet("getBadgesByUser", { userId = userId })
	return res["res"]
end

module.SaveUserBadgeGrant = function(userId: number, badgeAssetId: number, badgeName: string)
	local res = remoteDbInternal.remoteGet(
		"saveUserBadgeGrant",
		{ userId = userId, badgeAssetId = badgeAssetId, badgeName = badgeName }
	)
	return res
end

module.UpdateSettingForUser = function(
	userId: number,
	settingName: string,
	domain: string,
	booleanValue: boolean?,
	stringValue: string?
): any
	local combined = {
		userId = userId,
		settingName = settingName,
		domain = domain,
		booleanValue = tostring(booleanValue),
		stringValue = tostring(stringValue),
		remoteActionName = "updateSettingForUser",
	}
	return remoteDbInternal.remotePost(combined)
end

module.GetSettingsForUser = function(userId: number)
	local combined = { userId = userId, remoteActionName = "getSettingsForUser" }
	local res = remoteDbInternal.remotePost(combined)
	return res
end

module.GetKnownSignIds = function(): { [number]: boolean }
	local raw = remoteDbInternal.remoteGet("getKnownSignIds", {})
	local res = {}
	for strSignId, val in pairs(raw) do
		res[tonumber(strSignId)] = true
	end
	return res
end

module.UserDied = function(userId: number, x: number, y: number, z: number)
	return remoteDbInternal.remoteGet("userDied", {
		userId = userId,
		x = tpUtil.noe(x),
		y = tpUtil.noe(y),
		z = tpUtil.noe(z),
	})
end

module.SetSignPosition = function(data: { name: string, signId: number, x: number, y: number, z: number })
	return remoteDbInternal.remoteGet("setSignPosition", data)
end

module.GetOrCreateBooleanSetting = function(data: { domain: string, name: string })
	local combined = {
		domain = data.domain,
		name = data.name,
		remoteActionName = "getOrCreateBooleanSetting",
	}
	return remoteDbInternal.remotePost(combined)
end

module.GetOrCreateStringSetting = function(data: { domain: string, name: string })
	local combined = {
		domain = data.domain,
		name = data.name,
		remoteActionName = "getOrCreateStringSetting",
	}
	return remoteDbInternal.remotePost(combined)
end

--look up dynamic run stats for the signs included, which are likely ones which the user is approaching
module.dynamicRunFrom = function(
	userId: number,
	startSignId: number,
	targetSignIds: { number }
): tt.dynamicRunFromData | nil
	local targetSignIdsString = {}
	for ii, el in ipairs(targetSignIds) do
		table.insert(targetSignIdsString, tostring(el))
	end
	local res: tt.dynamicRunFromData = remoteDbInternal.remoteGet("dynamicRunFrom", {
		userId = userId,
		startSignId = startSignId,
		targetSignIds = textUtil.stringJoin(",", targetSignIdsString),
	})

	if res == nil then
		return nil
	end

	--this has string keys on the wire. how to generally make them show up as number, so types match?
	for k, frame: tt.DynamicRunFrame in ipairs(res.frames) do
		frame.targetSignId = tonumber(frame.targetSignId)
		if frame.myplace ~= nil then
			frame.myplace.place = tonumber(frame.myplace.place)
			frame.myplace.userId = tonumber(frame.myplace.userId)
			frame.myplace.timeMs = tonumber(frame.myplace.timeMs)
		end
		for place, p in pairs(frame.places) do
			p.place = tonumber(p.place)
			p.timeMs = tonumber(p.timeMs)
			p.userId = tonumber(p.userId)
			frame.places[tonumber(place)] = p

			-- its not actually a number at this point
			-- this is rdb cleanup.  TODO find a way to deserialize into a class type.
			-- frame.places[tostring(place)] = nil
		end
	end

	return res
end

module.reportServerError = function(ev: tt.robloxServerError)
	local combined = { ev = ev }
	combined.remoteActionName = "reportServerError"
	local res = remoteDbInternal.remotePost(combined)
	return res
end

module.reportServerEventEnd = function(ev: tt.runningServerEvent, allocations)
	local combined = { ev = ev, allocations = allocations }
	combined.remoteActionName = "reportServerEventEnd"
	local res = remoteDbInternal.remotePost(combined)
	return res
end

module.SendUserData = function(player: Player, data: any)
	data.userId = player.UserId
	data.remoteActionName = "userData"
	remoteDbInternal.remotePost(data)
end

module.beckon = function(userId: number, message: string)
	local data = { remoteActionName = "beckon", userId = userId, message = message }
	remoteDbInternal.remotePost(data)
	local badgeEnums = require(game.ReplicatedStorage.util.badgeEnums)
	local grantBadge = require(game.ServerScriptService.grantBadge)
	grantBadge.GrantBadge(userId, badgeEnums.badges.Beckoner)
end

local function checkBadgesForBadIds()
	local counts = {}
	-- 		_annotate("doing badge duplication check since you're in studio.!")
	local badgeEnums = require(game.ReplicatedStorage.util.badgeEnums)
	for _, el in pairs(badgeEnums.badges) do
		if not counts[el.assetId] then
			counts[el.assetId] = 0
		end
		counts[el.assetId] = counts[el.assetId] + 1
	end

	for a, b in pairs(counts) do
		if b > 1 then
			warn(string.format("badge id %d appears %d times", a, b))
		end
	end
end

module.getSignProfileForUser = function(username: string, signId: number)
	local data = { username = username, signId = signId }
	return remoteDbInternal.remoteGet("getSignProfileForUser", data)
end

local config = require(game.ReplicatedStorage.config)
if config.isInStudio() then
	checkBadgesForBadIds()
end

local testRemoteErrorSending = function()
	local ev: tt.robloxServerError = {
		code = "code",
		version = enums.gameVersion,
		message = "helly.",
		data = "data",
		userId = 123,
	}
	module.reportServerError(ev)
end

if false then
	testRemoteErrorSending()
end

_annotate("end")
return module
