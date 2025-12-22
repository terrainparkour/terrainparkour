--!strict

--[[
	Centralized friendship cache for Roblox friend lookups.
	
	Usage:
		local friendshipCache = require(game.ReplicatedStorage.util.friendshipCache)
		
		-- Check if a userId is friends with the local player
		if friendshipCache.isFriend(someUserId) then
			-- use colors.friendColor or colors.friendInServerColor
		end
		
		-- Clear cache when player leaves (call from server or client as appropriate)
		friendshipCache.clearPlayer(userId)
	
	Notes:
		- Caches IsFriendsWith() calls to avoid repeated API hits
		- Cache is per-player (checks against LocalPlayer on client)
		- Returns false on API errors (fail-closed)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

-- Cache: userId -> isFriend (for the local player's perspective)
local friendCache: { [number]: boolean } = {}

-- Track if we've attempted lookup (distinguish "not friend" from "not yet checked")
local attemptedLookup: { [number]: boolean } = {}

--[[
	Check if a userId is friends with the local player.
	Returns cached result if available, otherwise performs lookup and caches.
	
	@param userId: The userId to check friendship with
	@return boolean: true if friend, false if not friend or on error
]]
function module.isFriend(userId: number): boolean
	-- Can't be friends with yourself
	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		return false
	end

	if userId == localPlayer.UserId then
		return false
	end

	-- Return cached result if we've already looked this up
	if attemptedLookup[userId] then
		return friendCache[userId] or false
	end

	-- Mark as attempted before the call (prevent duplicate calls)
	attemptedLookup[userId] = true

	-- Perform the lookup
	local success, result = pcall(function()
		return localPlayer:IsFriendsWith(userId)
	end)

	if success and result == true then
		friendCache[userId] = true
		return true
	else
		friendCache[userId] = false
		return false
	end
end

--[[
	Check if a userId is friends with a specific player (server-side use).
	
	@param checker: The player doing the check
	@param targetUserId: The userId to check friendship with
	@return boolean: true if friend, false if not friend or on error
]]
function module.isFriendWith(checker: Player, targetUserId: number): boolean
	if checker.UserId == targetUserId then
		return false
	end

	local success, result = pcall(function()
		return checker:IsFriendsWith(targetUserId)
	end)

	return success and result == true
end

--[[
	Clear cached friendship data for a specific player.
	Call this when a player leaves the server to free memory.
	
	@param userId: The userId to clear from cache
]]
function module.clearPlayer(userId: number)
	friendCache[userId] = nil
	attemptedLookup[userId] = nil
end

--[[
	Clear the entire friendship cache.
	Useful for debugging or if friendship state may have changed.
]]
function module.clearAll()
	table.clear(friendCache)
	table.clear(attemptedLookup)
end

--[[
	Prefetch friendship status for a list of userIds.
	Useful when you know you'll need to check multiple users (e.g., leaderboard).
	
	@param userIds: Array of userIds to prefetch
]]
function module.prefetch(userIds: { number })
	for _, userId in ipairs(userIds) do
		-- isFriend handles caching internally
		module.isFriend(userId)
	end
end

-- Auto-cleanup when players leave (client-side)
if RunService:IsClient() then
	Players.PlayerRemoving:Connect(function(player)
		module.clearPlayer(player.UserId)
	end)
end

_annotate("end")
return module

