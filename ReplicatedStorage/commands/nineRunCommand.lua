--!strict

-- nineRunCommand.lua :: ReplicatedStorage.commands.nineRunCommand
-- SERVER-ONLY: Find a random race with 9 runners that you haven't run.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)
local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)

local rdb = require(game.ServerScriptService.rdb)
local serverWarping = require(game.ServerScriptService.serverwarping)
local tt = require(game.ReplicatedStorage.types.gametypes)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "any",
	AutocompleteVisible = true,
}

function module.Execute(player: Player, _parts: { string }): boolean
	local request: tt.postRequest = {
		remoteActionName = "getNineRunRandom",
		data = {
			userId = player.UserId,
		},
	}

	local res = rdb.MakePostRequest(request)

	if not res then
		commandUtils.SendMessage("Failed to fetch race data", player)
		return false
	end

	if not res.success then
		local message = res.message or "No races with 9 runners that you haven't run"
		commandUtils.SendMessage(message, player)
		return true
	end

	if res.message then
		commandUtils.SendMessage(res.message, player)
	end

	if res.totalCount then
		local countMessage = string.format("Total races with 9 runners you haven't run: %d", res.totalCount)
		commandUtils.SendMessage(countMessage, player)
	end

	if res.startSignId and res.endSignId then
		local warpRequest: tt.serverWarpRequest = {
			kind = "sign",
			signId = res.startSignId,
			highlightSignId = res.endSignId,
		}
		serverWarping.RequestClientToWarpToWarpRequest(player, warpRequest)
	end

	commandUtils.GrantCmdlineBadge(player.UserId)
	return true
end

_annotate("end")
return module
