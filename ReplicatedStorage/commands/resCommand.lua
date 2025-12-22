--!strict

-- resCommand.lua :: ReplicatedStorage.commands.resCommand
-- SERVER-ONLY: Shows run results between two signs.
-- Stateful: running /res with no arguments repeats the last query for that player.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local Players = game:GetService("Players")

local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)

local runResultsCommand = require(game.ReplicatedStorage.commands.runResultsCommand)
local tt = require(game.ReplicatedStorage.types.gametypes)
local playerData2 = require(game.ServerScriptService.playerData2)
local textUtil = require(game.ReplicatedStorage.util.textUtil)

-- Module internals
local lastQueryByPlayer: { [number]: string } = {}

local function cleanupPlayer(player: Player)
	lastQueryByPlayer[player.UserId] = nil
end

Players.PlayerRemoving:Connect(cleanupPlayer)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "any",
	AutocompleteVisible = true,
}

function module.Execute(player: Player, parts: { string }): boolean
	local rest: string
	if not commandUtils.RequireArguments(parts, 1) then
		local lastQuery = lastQueryByPlayer[player.UserId]
		if lastQuery then
			rest = lastQuery
			_annotate(string.format("res command: userId=%d repeating last query: %s", player.UserId, rest))
		else
			commandUtils.SendMessage("Usage: /res <sign1> <sign2> (run with no args to repeat last query)", player)
			return true
		end
	else
		rest = textUtil.stringJoin(" ", parts)
	end
	local res: tt.RaceParseResult = commandUtils.ParseRaceFromInput(rest, player.UserId)
	if res.error ~= "" then
		commandUtils.SendMessage(res.error, player)
		return true
	end

	-- Remember this query for repeat invocation
	lastQueryByPlayer[player.UserId] = rest

	local hasSign1 = playerData2.HasUserFoundSign(player.UserId, res.signId1)
	local hasSign2 = playerData2.HasUserFoundSign(player.UserId, res.signId2)
	if not hasSign1 or not hasSign2 then
		local missing = {}
		if not hasSign1 then
			table.insert(missing, res.signName1)
		end
		if not hasSign2 then
			table.insert(missing, res.signName2)
		end
		_annotate(
			string.format(
				"res command: userId=%d missing signs: %s (signId1=%d hasSign1=%s, signId2=%d hasSign2=%s)",
				player.UserId,
				table.concat(missing, ", "),
				res.signId1,
				tostring(hasSign1),
				res.signId2,
				tostring(hasSign2)
			)
		)
		commandUtils.SendMessage(string.format("You haven't found: %s", table.concat(missing, ", ")), player)
		return true
	end

	commandUtils.GrantCmdlineBadge(player.UserId)
	local result = runResultsCommand.SendRunResults(player, res.signId1, res.signId2)
	if result.raceNotFound then
		commandUtils.SendMessage(string.format("No one has run %s-%s yet. Be the first!", res.signName1, res.signName2), player)
	end
	return result.success
end

_annotate("end")
return module
