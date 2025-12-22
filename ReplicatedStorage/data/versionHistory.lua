--!strict

-- versionHistory.lua
-- Derives version release dates from changelog.lua's structured release data.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local changelog = require(game.ReplicatedStorage.util.changelog)

export type VersionEntry = {
	version: string,
	timestamp: number, -- Unix timestamp when version was released
	notes: string?, -- Brief description extracted from changelog
}

local module = {}

-- Cache parsed version history (computed once on first access)
local cachedVersionHistory: { VersionEntry }? = nil

-- Convert version number (e.g., 410) to version string (e.g., "v0.4.10")
local function versionNumberToString(versionNum: number): string
	local major = math.floor(versionNum / 100)
	local minor = versionNum % 100
	return string.format("v%d.%02d", major, minor)
end

-- Parse date string "YYYY-MM-DD" to Unix timestamp
local function parseDateToTimestamp(dateStr: string): number?
	local year, month, day = dateStr:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
	if year and month and day then
		return os.time({
			year = tonumber(year) :: number,
			month = tonumber(month) :: number,
			day = tonumber(day) :: number,
			hour = 12, -- Noon to avoid timezone edge cases
			min = 0,
			sec = 0,
		})
	end
	return nil
end

-- Build version history from changelog's structured releases
local function buildVersionHistory(): { VersionEntry }
	local entries: { VersionEntry } = {}

	for versionNum, release in pairs(changelog.releases) do
		if release.date then
			local timestamp = parseDateToTimestamp(release.date)
			if timestamp then
				-- Extract first line of notes as description
				local firstLine = release.notes:match("^([^\n]+)")
				table.insert(entries, {
					version = versionNumberToString(versionNum),
					timestamp = timestamp,
					notes = firstLine,
				})
			end
		end
	end

	-- Sort oldest first
	table.sort(entries, function(a, b)
		return a.timestamp < b.timestamp
	end)

	return entries
end

-- Get all version releases as a sorted array (oldest first)
function module.GetVersionHistory(): { VersionEntry }
	if not cachedVersionHistory then
		cachedVersionHistory = buildVersionHistory()
	end
	return cachedVersionHistory :: { VersionEntry }
end

-- Get version releases within a time range (for chart markers)
function module.GetVersionsInRange(startTime: number, endTime: number): { VersionEntry }
	local all = module.GetVersionHistory()
	local result: { VersionEntry } = {}

	for _, entry in ipairs(all) do
		if entry.timestamp >= startTime and entry.timestamp <= endTime then
			table.insert(result, entry)
		end
	end

	return result
end

-- Find which version was active at a given timestamp
function module.GetVersionAtTime(timestamp: number): string?
	local all = module.GetVersionHistory()
	local activeVersion: string? = nil

	for _, entry in ipairs(all) do
		if entry.timestamp <= timestamp then
			activeVersion = entry.version
		else
			break
		end
	end

	return activeVersion
end

_annotate("end")
return module
