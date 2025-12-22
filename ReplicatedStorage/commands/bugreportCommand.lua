--!strict

-- bugreportCommand.lua :: ReplicatedStorage.commands.bugreportCommand
-- SERVER-ONLY: Allows users to submit bug reports.
-- Usage: /bugreport <description of the bug>

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)
local rdb = require(game.ServerScriptService.rdb)
local textUtil = require(game.ReplicatedStorage.util.textUtil)
local tt = require(game.ReplicatedStorage.types.gametypes)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "any",
	AutocompleteVisible = true,
}

function module.Execute(player: Player, parts: { string }): boolean
	if #parts == 0 then
		commandUtils.SendMessage("Usage: /bugreport <description of the bug>", player)
		commandUtils.SendMessage("Example: /bugreport The timer doesn't stop when I reach the sign", player)
		return true
	end

	local text = textUtil.stringJoin(" ", parts)
	if #text == 0 then
		commandUtils.SendMessage("Usage: /bugreport <description of the bug>", player)
		return true
	end

	local request: tt.postRequest = {
		remoteActionName = "submitBugReport",
		data = {
			userId = player.UserId,
			text = text,
		},
	}

	_annotate(string.format("Submitting bug report for user %d: %s", player.UserId, text:sub(1, 50)))
	local response: any = rdb.MakePostRequest(request)

	if not response then
		commandUtils.SendMessage("Failed to submit bug report. Please try again later.", player)
		return false
	end

	if response.error then
		commandUtils.SendMessage(response.message or "Failed to submit bug report.", player)
		return true
	end

	if response.success then
		commandUtils.SendMessage(response.message or "Bug report submitted. Thank you!", player)
		commandUtils.GrantFixmeBadge(player.UserId)
		return true
	end

	commandUtils.SendMessage("Unexpected error submitting bug report.", player)
	return false
end

_annotate("end")
return module
