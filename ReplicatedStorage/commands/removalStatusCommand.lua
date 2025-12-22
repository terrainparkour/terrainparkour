--!strict

-- removalStatusCommand.lua :: ReplicatedStorage.commands.removalStatusCommand
-- SERVER-ONLY: Shows user's removal request history and recent activity.
-- Usage: /removalStatus

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

local function formatResolution(resolution: string): string
	if resolution == "pending" then
		return "pending"
	elseif resolution == "accepted" then
		return "ACCEPTED"
	elseif resolution == "cancelled" then
		return "cancelled"
	elseif resolution == "rejected" then
		return "rejected"
	elseif resolution == "rejected_suspicious" then
		return "rejected (suspicious)"
	elseif resolution == "rejected_legitimate" then
		return "rejected (legitimate)"
	elseif resolution == "rejected_duplicate" then
		return "rejected (duplicate)"
	end
	return resolution
end

local function formatPlace(place: number?): string
	if not place then
		return ""
	end
	return string.format(" #%d", place)
end

function module.Execute(player: Player, _parts: { string }): boolean
	local req = {
		remoteActionName = "getUserRemovalRequestHistory",
		data = {
			userId = player.UserId,
		},
	}

	_annotate(string.format("Getting removal request history for user %d", player.UserId))
	local response: any = rdb.MakePostRequest(req)

	if response.error then
		commandUtils.SendMessage("Failed to fetch removal request history.", player)
		return false
	end

	if not response.success then
		commandUtils.SendMessage("Failed to fetch removal request history.", player)
		return false
	end

	local summary = response.summary
	local requests = response.requests

	-- Show summary
	commandUtils.SendMessage(
		string.format(
			"Removal Requests: %d total (%d pending, %d accepted, %d rejected)",
			summary.total,
			summary.pending,
			summary.accepted,
			summary.rejected
		),
		player
	)

	if summary.recentlyProcessed > 0 then
		commandUtils.SendMessage(string.format("%d request(s) processed in last 24 hours:", summary.recentlyProcessed), player)
	end

	-- Show recent activity first
	for _, removalReq in ipairs(requests) do
		if removalReq.isRecent then
			local status = formatResolution(removalReq.resolution)
			commandUtils.SendMessage(string.format("  [NEW] %s %s: %s", removalReq.raceName, removalReq.timeFormatted, status), player)
		end
	end

	-- Show pending requests with current place and cancel option
	local pendingShown = 0
	for _, removalReq in ipairs(requests) do
		if removalReq.resolution == "pending" and pendingShown < 10 then
			local placeStr = formatPlace(removalReq.currentPlace)
			local duplicateStr = ""
			if removalReq.duplicateCount and removalReq.duplicateCount > 1 then
				duplicateStr = string.format(" (%dx)", removalReq.duplicateCount)
			end
			commandUtils.SendMessage(
				string.format("  [PENDING] #%d: %s %s%s%s", removalReq.id, removalReq.raceName, removalReq.timeFormatted, placeStr, duplicateStr),
				player
			)
			pendingShown = pendingShown + 1
		end
	end

	if summary.pending > 0 then
		commandUtils.SendMessage("Cancel a pending request: /cancelRemoval <id>", player)
	end

	-- If no requests at all
	if summary.total == 0 then
		commandUtils.SendMessage("You have no removal requests. Use /requestRemoval <race> to submit one.", player)
	end

	commandUtils.GrantCmdlineBadge(player.UserId)
	return true
end

_annotate("end")
return module
