--!strict

-- changelogCommand.lua :: ReplicatedStorage.commands.changelogCommand
-- SERVER-ONLY: Displays release history. Query by version number or search text.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)

local changelog = require(game.ReplicatedStorage.util.changelog)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "any",
	AutocompleteVisible = true,
	Aliases = { "changes", "releases" },
}

local function formatVersion(versionNum: number): string
	local major = math.floor(versionNum / 100)
	local minor = versionNum % 100
	return string.format("0.%d.%d", major, minor)
end

local function getSortedVersions(): { number }
	local versions: { number } = {}
	for ver, _ in pairs(changelog.releases) do
		table.insert(versions, ver)
	end
	table.sort(versions)
	return versions
end

local function listVersions(player: Player): ()
	local versions = getSortedVersions()
	local lines: { string } = { "Available versions:" }
	for _, ver in ipairs(versions) do
		local release = changelog.releases[ver]
		local notes = release.notes
		local firstLine = notes:match("^[^\n]+") or notes
		if #firstLine > 50 then
			firstLine = firstLine:sub(1, 47) .. "..."
		end
		local dateStr = release.date or "?"
		table.insert(lines, string.format("  %s [%s]: %s", formatVersion(ver), dateStr, firstLine))
	end
	table.insert(lines, "Usage: /changelog <version> or /changelog search <term>")
	commandUtils.SendMessage(table.concat(lines, "\n"), player)
end

local function showVersion(player: Player, versionNum: number): ()
	local release = changelog.releases[versionNum]
	if not release then
		commandUtils.SendMessage(string.format("Version %d not found.", versionNum), player)
		return
	end
	local dateStr = if release.date then " (" .. release.date .. ")" else ""
	local header = string.format("=== Version %s%s ===", formatVersion(versionNum), dateStr)
	commandUtils.SendMessage(header .. "\n" .. release.notes, player)
end

local function searchChangelog(player: Player, searchTerm: string): ()
	local lowerTerm = searchTerm:lower()
	local matches: { string } = {}
	local versions = getSortedVersions()

	for _, ver in ipairs(versions) do
		local release = changelog.releases[ver]
		local notes = release.notes
		if notes:lower():find(lowerTerm, 1, true) then
			local firstLine = notes:match("^[^\n]+") or notes
			if #firstLine > 45 then
				firstLine = firstLine:sub(1, 42) .. "..."
			end
			local dateStr = release.date or "?"
			table.insert(matches, string.format("  %s [%s]: %s", formatVersion(ver), dateStr, firstLine))
		end
	end

	if #matches == 0 then
		commandUtils.SendMessage(string.format("No changelog entries match '%s'.", searchTerm), player)
		return
	end

	local header = string.format("Versions mentioning '%s':", searchTerm)
	commandUtils.SendMessage(header .. "\n" .. table.concat(matches, "\n"), player)
end

function module.Execute(player: Player, parts: { string }): boolean
	_annotate(string.format("changelog command from %s, args=%d", player.Name, #parts))

	if #parts == 0 then
		listVersions(player)
		return true
	end

	local firstArg = parts[1]:lower()

	if firstArg == "search" then
		if #parts < 2 then
			commandUtils.SendMessage("Usage: /changelog search <term>", player)
			return true
		end
		local searchTerm = table.concat(parts, " ", 2)
		searchChangelog(player, searchTerm)
		return true
	end

	local versionNum = tonumber(firstArg)
	if versionNum then
		showVersion(player, versionNum)
		return true
	end

	searchChangelog(player, table.concat(parts, " "))
	return true
end

_annotate("end")
return module

