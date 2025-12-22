--!strict

-- cancelRemovalCommand.lua :: ReplicatedStorage.commands.cancelRemovalCommand
-- SERVER-ONLY: Allows users to cancel their own pending removal requests.
-- Usage: /cancelRemoval <requestId>

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)
local rdb = require(game.ServerScriptService.rdb)

type Module = {
	Execute: (player: Player, parts: { string }) -> boolean,
	Visibility: string,
	ChannelRestriction: string,
	AutocompleteVisible: boolean,
}

local module: Module = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "any",
	AutocompleteVisible = true,
}

function module.Execute(player: Player, parts: { string }): boolean
	if #parts == 0 then
		commandUtils.SendMessage("Usage: /cancelRemoval <requestId>", player)
		commandUtils.SendMessage("Use /removalStatus to see your pending requests and their IDs.", player)
		return true
	end

	local requestIdStr = parts[1]
	local requestId = tonumber(requestIdStr)

	if not requestId then
		commandUtils.SendMessage("Invalid request ID. Use /removalStatus to see your pending requests.", player)
		return true
	end

	local req = {
		remoteActionName = "cancelRunRemovalRequest",
		data = {
			userId = player.UserId,
			requestId = requestId,
		},
	}

	_annotate(string.format("Cancelling removal request %d for user %d", requestId, player.UserId))
	local response: any = rdb.MakePostRequest(req)

	if response.error then
		commandUtils.SendMessage(response.message or "Failed to cancel request.", player)
		return false
	end

	if not response.success then
		commandUtils.SendMessage(response.message or "Failed to cancel request.", player)
		return false
	end

	commandUtils.SendMessage(response.message, player)
	commandUtils.GrantCmdlineBadge(player.UserId)
	return true
end

_annotate("end")
return module

