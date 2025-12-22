--!strict

-- requestRemovalCommand.lua :: ReplicatedStorage.commands.requestRemovalCommand
-- SERVER-ONLY: Allows users to request removal of their run times on a race.
-- Usage: /requestRemoval <startSign>-<endSign>
-- Targets fastest time without a pending request - allows queueing multiple removals.
-- User must type /yes within 60 seconds to confirm; any other command cancels.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)
local rdb = require(game.ServerScriptService.rdb)
local textUtil = require(game.ReplicatedStorage.util.textUtil)
local tt = require(game.ReplicatedStorage.types.gametypes)

type PendingConfirmation = {
	raceId: number,
	raceName: string,
	runMilliseconds: number,
	expiresAt: number,
}

local pendingConfirmations: { [number]: PendingConfirmation } = {}
local CONFIRMATION_TIMEOUT_SECONDS = 60

type Module = {
	Execute: (player: Player, parts: { string }) -> boolean,
	Visibility: string,
	ChannelRestriction: string,
	AutocompleteVisible: boolean,
	HasPendingConfirmation: (userId: number) -> boolean,
	ProcessConfirmation: (player: Player) -> boolean,
}

local module: Module = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "any",
	AutocompleteVisible = true,
	HasPendingConfirmation = function(_userId: number): boolean
		return false
	end,
	ProcessConfirmation = function(_player: Player): boolean
		return false
	end,
}

local function cleanupExpired()
	local now = tick()
	for userId, pending in pairs(pendingConfirmations) do
		if pending.expiresAt < now then
			pendingConfirmations[userId] = nil
		end
	end
end

function module.HasPendingConfirmation(userId: number): boolean
	cleanupExpired()
	return pendingConfirmations[userId] ~= nil
end

function module.ProcessConfirmation(player: Player): boolean
	cleanupExpired()

	local pending = pendingConfirmations[player.UserId]
	if not pending then
		commandUtils.SendMessage("No pending removal request to confirm.", player)
		return false
	end

	pendingConfirmations[player.UserId] = nil

	local req = {
		remoteActionName = "confirmRunRemovalRequest",
		data = {
			userId = player.UserId,
			raceId = pending.raceId,
			runMilliseconds = pending.runMilliseconds,
		},
	}

	_annotate(string.format("Confirming removal request for user %d", player.UserId))
	local response: any = rdb.MakePostRequest(req)

	if response.error then
		if response.alreadySubmitted then
			commandUtils.SendMessage("This request was already submitted.", player)
		else
			commandUtils.SendMessage(response.message or "Failed to submit removal request.", player)
		end
		return false
	end

	if response.success then
		commandUtils.SendMessage(response.message or "Removal request submitted.", player)
		commandUtils.GrantCmdlineBadge(player.UserId)
		return true
	end

	commandUtils.SendMessage("Unexpected error.", player)
	return false
end

function module.Execute(player: Player, parts: { string }): boolean
	if #parts == 0 then
		commandUtils.SendMessage("Usage: /requestRemoval <startSign>-<endSign>", player)
		commandUtils.SendMessage("Requests removal of your fastest time. Costs 3 tix. Submissions never used as evidence against you.", player)
		commandUtils.SendMessage("Example: /requestRemoval tre-cot", player)
		return true
	end

	local rest = textUtil.stringJoin(" ", parts)
	local res: tt.RaceParseResult = commandUtils.ParseRaceFromInput(rest, player.UserId)

	if res.error ~= "" then
		commandUtils.SendMessage(res.error, player)
		return true
	end

	local req = {
		remoteActionName = "submitRunRemovalRequest",
		data = {
			userId = player.UserId,
			startSignId = res.signId1,
			endSignId = res.signId2,
		},
	}

	_annotate(string.format("Checking removal request for user %d on %s-%s", player.UserId, res.signName1, res.signName2))
	local response: any = rdb.MakePostRequest(req)

	if response.error then
		if response.raceNotFound then
			commandUtils.SendMessage(string.format("No one has run %s-%s yet.", res.signName1, res.signName2), player)
		elseif response.alreadySubmitted then
			commandUtils.SendMessage(response.message or "You already have a pending request.", player)
		else
			commandUtils.SendMessage(response.message or "You have no recorded time on this race.", player)
		end
		return true
	end

	if response.needsConfirmation then
		pendingConfirmations[player.UserId] = {
			raceId = response.raceId,
			raceName = response.raceName,
			runMilliseconds = response.runMilliseconds,
			expiresAt = tick() + CONFIRMATION_TIMEOUT_SECONDS,
		}

		local placeText = ""
		if response.place and response.place > 0 then
			placeText = string.format(" (currently #%d)", response.place)
		end

		local cost = response.cost or 3

		-- Note if there are duplicate runs with this exact time
		local duplicateNote = ""
		if response.duplicateCount and response.duplicateCount > 1 then
			duplicateNote = string.format(" (%d runs with this time)", response.duplicateCount)
		end

		-- Show info about existing pending requests on this race
		if response.existingPendingCount and response.existingPendingCount > 0 then
			commandUtils.SendMessage(
				string.format("You have %d pending request(s) on %s: %s", response.existingPendingCount, response.raceName, response.existingPendingTimes),
				player
			)
			commandUtils.SendMessage(
				string.format("Requesting removal of your next fastest time: %s%s%s", response.timeFormatted, placeText, duplicateNote),
				player
			)
		else
			commandUtils.SendMessage(
				string.format("Requesting removal of your fastest time on %s: %s%s%s", response.raceName, response.timeFormatted, placeText, duplicateNote),
				player
			)
		end

		commandUtils.SendMessage(
			string.format("Cost: %d tix. Type /yes to confirm removal of %s (%s), or any other command to cancel.", cost, response.raceName, response.timeFormatted),
			player
		)
		return true
	end

	commandUtils.SendMessage("Unexpected response.", player)
	return false
end

_annotate("end")
return module
