--!strict

-- chatFormatting.lua :: ReplicatedStorage.ChatSystem.chatFormatting
-- SERVER-ONLY: Centralized utilities for formatting chat messages with consistent color schemes.
-- Priority: self (yellow) > friends (light blue/cyan) > group member (gold) > default (white)

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local Players = game:GetService("Players")

local colors = require(game.ReplicatedStorage.util.colors)
local enums = require(game.ReplicatedStorage.util.enums)
local messageFormatter = require(game.ReplicatedStorage.ChatSystem.messageFormatter)

export type UserColorContext = {
	speakerUserId: number,
	userIdsInServer: { [number]: boolean },
	friendCache: { [number]: boolean }?,
	groupMemberCache: { [number]: boolean }?,
}

type Module = {
	CreateContext: (speaker: Player) -> UserColorContext,
	GetUserColor: (userId: number, context: UserColorContext) -> Color3,
	FormatUsername: (username: string, userId: number, context: UserColorContext) -> string,
	FormatUsernameSimple: (username: string, userId: number, speakerUserId: number, userIdsInServer: { [number]: boolean }) -> string,
}

local module: Module = {} :: Module

-- Cache for friend status (speaker -> target -> isFriend)
local friendStatusCache: { [number]: { [number]: boolean } } = {}

-- Cache for group membership
local groupMemberCache: { [number]: boolean } = {}

local function isFriend(speakerId: number, targetId: number): boolean
	if speakerId == targetId then
		return false
	end
	
	-- Check cache first
	if friendStatusCache[speakerId] and friendStatusCache[speakerId][targetId] ~= nil then
		return friendStatusCache[speakerId][targetId]
	end
	
	-- Initialize cache for this speaker if needed
	if not friendStatusCache[speakerId] then
		friendStatusCache[speakerId] = {}
	end
	
	-- Get the speaker player object
	local speaker = Players:GetPlayerByUserId(speakerId)
	if not speaker then
		friendStatusCache[speakerId][targetId] = false
		return false
	end
	
	-- Check friendship via API
	local success, result = pcall(function()
		return speaker:IsFriendsWith(targetId)
	end)
	
	local isFriendResult = success and result == true
	friendStatusCache[speakerId][targetId] = isFriendResult
	return isFriendResult
end

local function isGroupMember(userId: number): boolean
	-- Check cache first
	if groupMemberCache[userId] ~= nil then
		return groupMemberCache[userId]
	end
	
	-- Get the player object
	local player = Players:GetPlayerByUserId(userId)
	if not player then
		-- Can't check group membership without player in server
		-- Don't cache this - they might join later
		return false
	end
	
	-- Check group membership via API
	local success, result = pcall(function()
		return player:IsInGroup(enums.objects.ninjaParkourGroupId)
	end)
	
	local isInGroup = success and result == true
	groupMemberCache[userId] = isInGroup
	return isInGroup
end

-- Create a context object for a speaker (caches lookups for efficiency)
function module.CreateContext(speaker: Player): UserColorContext
	local userIdsInServer: { [number]: boolean } = {}
	for _, serverPlayer in ipairs(Players:GetPlayers()) do
		userIdsInServer[serverPlayer.UserId] = true
	end
	
	return {
		speakerUserId = speaker.UserId,
		userIdsInServer = userIdsInServer,
		friendCache = {},
		groupMemberCache = {},
	}
end

-- Get the appropriate color for a user based on their relationship to the speaker
-- Priority: self > friend > group member > default
function module.GetUserColor(userId: number, context: UserColorContext): Color3
	-- Self = yellow
	if userId == context.speakerUserId then
		return colors.meColor
	end
	
	-- Friend in server = cyan/teal (blue+green merged)
	if context.userIdsInServer[userId] then
		if isFriend(context.speakerUserId, userId) then
			return colors.friendInServerColor
		end
		
		-- Group member = gold
		if isGroupMember(userId) then
			return colors.groupMemberColor
		end
	end
	
	-- Default = white
	return colors.white
end

-- Format a username with the appropriate color
function module.FormatUsername(username: string, userId: number, context: UserColorContext): string
	local color = module.GetUserColor(userId, context)
	return messageFormatter.formatWithColor(username, color)
end

-- Simple version for one-off usage without creating a full context
function module.FormatUsernameSimple(
	username: string,
	userId: number,
	speakerUserId: number,
	userIdsInServer: { [number]: boolean }
): string
	local context: UserColorContext = {
		speakerUserId = speakerUserId,
		userIdsInServer = userIdsInServer,
	}
	return module.FormatUsername(username, userId, context)
end

-- Clear caches when players leave (to avoid stale data)
Players.PlayerRemoving:Connect(function(player: Player)
	local userId = player.UserId
	
	-- Clear this player's friend cache
	friendStatusCache[userId] = nil
	
	-- Clear this player from others' friend caches
	for speakerId, cache in pairs(friendStatusCache) do
		cache[userId] = nil
	end
	
	-- Clear group membership cache
	groupMemberCache[userId] = nil
end)

_annotate("end")
return module

