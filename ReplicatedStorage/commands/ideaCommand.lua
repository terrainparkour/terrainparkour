--!strict

-- ideaCommand.lua :: ReplicatedStorage.commands.ideaCommand
-- SERVER-ONLY: Allows users to submit feature ideas and suggestions.
-- Usage: /idea <your idea or suggestion>

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
		commandUtils.SendMessage("Usage: /idea <your idea or suggestion>", player)
		commandUtils.SendMessage("Example: /idea A marathon that goes through all the caves", player)
		return true
	end

	local text = textUtil.stringJoin(" ", parts)
	if #text == 0 then
		commandUtils.SendMessage("Usage: /idea <your idea or suggestion>", player)
		return true
	end

	local request: tt.postRequest = {
		remoteActionName = "submitIdea",
		data = {
			userId = player.UserId,
			text = text,
		},
	}

	_annotate(string.format("Submitting idea for user %d: %s", player.UserId, text:sub(1, 50)))
	local response: any = rdb.MakePostRequest(request)

	if not response then
		commandUtils.SendMessage("Failed to submit idea. Please try again later.", player)
		return false
	end

	if response.error then
		commandUtils.SendMessage(response.message or "Failed to submit idea.", player)
		return true
	end

	if response.success then
		commandUtils.SendMessage(response.message or "Idea submitted. Thank you!", player)
		commandUtils.GrantBrightIdeaBadge(player.UserId)
		return true
	end

	commandUtils.SendMessage("Unexpected error submitting idea.", player)
	return false
end

_annotate("end")
return module

