--!strict

-- adminWarpCommand.lua :: ReplicatedStorage.commands.adminWarpCommand
-- SERVER-ONLY: Admin-only warp command.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)

local tt = require(game.ReplicatedStorage.types.gametypes)
local serverWarping = require(game.ServerScriptService.serverwarping)
local tpUtil: typeof(require(game.ReplicatedStorage.util.tpUtil)) = require(game.ReplicatedStorage.util.tpUtil)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "private",
	ChannelRestriction = "any",
	AutocompleteVisible = false,
}

function module.Execute(player: Player, parts: { string }): boolean
	if #parts < 1 then
		return false
	end
	local object = parts[1]

	local signId = tpUtil.looseSignName2SignId(object)
	if signId then
		local request: tt.serverWarpRequest = {
			kind = "sign",
			signId = signId,
		}

		serverWarping.RequestClientToWarpToWarpRequest(player, request)
	else
		local targetPlayer = tpUtil.looseGetPlayerFromUsername(object)
		if targetPlayer == nil then
			_annotate(string.format("server command warp tried to warp but couldn't find player based on data: %s", object))
			return false
		end

		-- Use kind="player" which has terrain checking and admin bypass
		local request: tt.serverWarpRequest = {
			kind = "player",
			targetUserId = targetPlayer.UserId,
		}
		serverWarping.RequestClientToWarpToWarpRequest(player, request)
	end
	return true
end

_annotate("end")
return module
