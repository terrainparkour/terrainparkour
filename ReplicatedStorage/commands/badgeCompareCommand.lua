--!strict

-- badgeCompareCommand.lua :: ReplicatedStorage.commands.badgeCompareCommand
-- SERVER-ONLY: Compare badges between two users and prompt the client to show a comparison modal.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local PlayersService = game:GetService("Players")

local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)

local badges = require(game.ServerScriptService.badges)
local playerData2 = require(game.ServerScriptService.playerData2)
local remotes = require(game.ReplicatedStorage.util.remotes)
local tpUtil: typeof(require(game.ReplicatedStorage.util.tpUtil)) = require(game.ReplicatedStorage.util.tpUtil)
local usernameCache = require(game.ServerScriptService.usernameCache)
local tt = require(game.ReplicatedStorage.types.gametypes)

local ServerToClientEvent = remotes.getRemoteEvent("ServerToClientEvent")

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "any",
	AutocompleteVisible = true,
}

local function resolveUserIdFromToken(token: string, requestingPlayer: Player): (number?, string?)
	if token == nil or token == "" then
		return nil, "missing name"
	end

	local lower = string.lower(token)

	-- Prefer in-server loose match
	local inServer = tpUtil.looseGetPlayerFromUsername(lower)
	if inServer then
		return inServer.UserId, inServer.Name
	end

	-- Allow numeric userIds for power users
	local numericId = tonumber(token)
	if numericId then
		local s, _ = pcall(function()
			return usernameCache.GetUsernameByUserId(numericId)
		end)
		if s then
			return numericId, usernameCache.GetUsernameByUserId(numericId)
		end
	end

	-- Exact Roblox username (case-insensitive)
	local ok, userIdOrErr = pcall(function()
		return PlayersService:GetUserIdFromNameAsync(token)
	end)
	if ok and typeof(userIdOrErr) == "number" then
		local username = usernameCache.GetUsernameByUserId(userIdOrErr)
		return userIdOrErr, username
	end

	_annotate(string.format("Failed to resolve badgecompare token '%s' from player %s (%d)", token, requestingPlayer.Name, requestingPlayer.UserId))
	return nil, "unknown player " .. token
end

local function collectBadgeSet(userId: number): { [number]: tt.badgeDescriptor }
	local progress = badges.GetAllBadgeProgressDetailsForUserId(userId, "badgecompare")
	local owned: { [number]: tt.badgeDescriptor } = {}
	for _, badgeStatus in ipairs(progress) do
		if badgeStatus.got then
			owned[badgeStatus.badge.assetId] = badgeStatus.badge
		end
	end
	return owned
end

local function buildUserSummary(userId: number): tt.badgeCompareUserSummary
	local stats = playerData2.GetStatsByUserId(userId, "badgecompare")
	local username = usernameCache.GetUsernameByUserId(userId)
	local badgeCount = badges.getBadgeCountByUser(userId, "badgecompare")

	return {
		userId = userId,
		username = username,
		badgeCount = badgeCount,
		latestBadgeName = stats.latestBadge,
		latestBadgeAssetId = stats.latestBadgeAssetId,
	}
end

local function asBadgeList(map: { [number]: tt.badgeDescriptor }): { tt.badgeCompareBadgeEntry }
	local res: { tt.badgeCompareBadgeEntry } = {}
	for _, descriptor in pairs(map) do
		table.insert(res, {
			name = descriptor.name,
			assetId = descriptor.assetId,
			iconImageId = descriptor.iconImageId,
			badgeClass = descriptor.badgeClass,
			hint = descriptor.hint,
		})
	end
	table.sort(res, function(a, b)
		return string.lower(a.name) < string.lower(b.name)
	end)
	return res
end

function module.Execute(player: Player, parts: { string }): boolean
	if not parts or (#parts < 1) then
		commandUtils.SendMessage("Usage: /badgecompare <A> <B>  or  /badgecompare <B>", player)
		return true
	end

	local tokenA: string
	local tokenB: string

	if #parts == 1 then
		tokenA = player.Name
		tokenB = parts[1]
	else
		tokenA = parts[1]
		tokenB = parts[2]
	end

	local userIdA, usernameAOrErr = resolveUserIdFromToken(tokenA, player)
	if not userIdA then
		commandUtils.SendMessage("Could not find player: " .. (usernameAOrErr or tokenA), player)
		return true
	end

	local userIdB, usernameBOrErr = resolveUserIdFromToken(tokenB, player)
	if not userIdB then
		commandUtils.SendMessage("Could not find player: " .. (usernameBOrErr or tokenB), player)
		return true
	end

	if userIdA == userIdB then
		commandUtils.SendMessage("Reflected Glory.", player)
		return true
	end

	_annotate(string.format("badgecompare between %d and %d requested by %s", userIdA, userIdB, player.Name))

	-- Collect badge ownership sets
	local ownedA = collectBadgeSet(userIdA)
	local ownedB = collectBadgeSet(userIdB)

	local sharedCount = 0
	for assetId, _ in pairs(ownedA) do
		if ownedB[assetId] ~= nil then
			sharedCount += 1
		end
	end

	local uniqueA: { [number]: tt.badgeDescriptor } = {}
	local uniqueB: { [number]: tt.badgeDescriptor } = {}

	for assetId, descriptor in pairs(ownedA) do
		if ownedB[assetId] == nil then
			uniqueA[assetId] = descriptor
		end
	end

	for assetId, descriptor in pairs(ownedB) do
		if ownedA[assetId] == nil then
			uniqueB[assetId] = descriptor
		end
	end

	local notification: tt.badgeCompareNotification = {
		kind = "badgeCompare",
		userA = buildUserSummary(userIdA),
		userB = buildUserSummary(userIdB),
		sharedBadgeCount = sharedCount,
		onlyA = asBadgeList(uniqueA),
		onlyB = asBadgeList(uniqueB),
	}

	ServerToClientEvent:FireClient(player, notification)
	commandUtils.GrantCmdlineBadge(player.UserId)
	return true
end

_annotate("end")
return module
