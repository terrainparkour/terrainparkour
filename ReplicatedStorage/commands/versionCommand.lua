--!strict

-- versionCommand.lua :: ReplicatedStorage.commands.versionCommand
-- SERVER-ONLY: Shows server version.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)
local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)

local enums = require(game.ReplicatedStorage.util.enums)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "any",
	AutocompleteVisible = true,
}

local safeRequire = require

function module.Execute(player: Player, _parts: { string }): boolean
	local testMessage = ""
	local moduleScript = ReplicatedStorage:FindFirstChild("doNotCheckInGameIdentifier")
	if not moduleScript or not moduleScript:IsA("ModuleScript") then
		error("doNotCheckInGameIdentifier ModuleScript missing; cannot determine environment")
	end
	local moduleValue = safeRequire(moduleScript :: ModuleScript)
	local useTestDbFn = (moduleValue :: { useTestDb: () -> boolean }).useTestDb
	if typeof(useTestDbFn) ~= "function" then
		error("doNotCheckInGameIdentifier missing useTestDb()")
	end
	if useTestDbFn() then
		testMessage = " TEST VERSION, db will be wiped"
	end

	local message = string.format("Terrain Parkour - Version %s%s", enums.gameVersion, testMessage)
	commandUtils.SendMessage(message, player)
	commandUtils.GrantUndocumentedCommandBadge(player.UserId)
	return true
end

_annotate("end")
return module
