--!strict
-- environment.lua @ ReplicatedStorage.environment
-- Centralized environment detection using PlaceId (public, non-sensitive).
-- Replaces the pattern of checking for gitignored doNotCheckInGameIdentifier.
-- NOTE: This module must have NO dependencies to avoid cyclic requires.
-- Do not add annotater or other modules that might chain back to hostSecret.

-- Production PlaceId (public, visible in Roblox URLs)
local PRODUCTION_PLACE_ID = 868107368
local _DEVELOPMENT_PLACE_ID = 1501984055

local module = {}

-- Environment types
export type Environment = "studio" | "production" | "test"

-- Detect environment based on game context
-- Studio: JobId is empty (not published)
-- Production: PlaceId matches the live game
-- Test: Published but not the production PlaceId
local function detectEnvironment(): Environment
	-- Studio detection (matches config.IsInStudio)
	if game.JobId == "" or game.JobId == "00000000-0000-0000-0000-000000000000" then
		return "studio"
	end

	-- Production detection via PlaceId
	if game.PlaceId == PRODUCTION_PLACE_ID then
		return "production"
	end

	-- Anything else is a test/dev published game
	return "test"
end

-- Cache the result (doesn't change during runtime)
local cachedEnvironment: Environment = detectEnvironment()

-- Public API
module.GetEnvironment = function(): Environment
	return cachedEnvironment
end

module.IsStudio = function(): boolean
	return cachedEnvironment == "studio"
end

module.IsProduction = function(): boolean
	return cachedEnvironment == "production"
end

module.IsTest = function(): boolean
	return cachedEnvironment == "test"
end

-- For backward compatibility with doNotCheckInGameIdentifier.useTestDb()
-- Returns true if NOT production (i.e., studio or test environments)
module.UseTestDb = function(): boolean
	return cachedEnvironment ~= "production"
end

return module
