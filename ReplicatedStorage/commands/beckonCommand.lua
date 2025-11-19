--!strict

-- beckonCommand.lua :: ReplicatedStorage.commands.beckonCommand
-- SERVER-ONLY: Invites others to join the server.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local PlayersService = game:GetService("Players")

local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)
local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)

local badgeEnums = require(game.ReplicatedStorage.util.badgeEnums)
local config = require(game.ReplicatedStorage.config)
local tt = require(game.ReplicatedStorage.types.gametypes)
local grantBadge = require(game.ServerScriptService.grantBadge)
local rdb = require(game.ServerScriptService.rdb)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "any",
	AutocompleteVisible = true,
}

local _beckontimes: { [number]: number } = {}

function module.Execute(player: Player, _parts: { string }): boolean
	if _beckontimes[player.UserId] then
		local gap = tick() - _beckontimes[player.UserId]
		local limit = 180
		if config.IsInStudio() then
			limit = 3
		end
		if gap < limit then
			commandUtils.SendMessage("You can beckon every 3 minutes.", player)
			return true
		end
	end
	_beckontimes[player.UserId] = tick() :: number
	local players = PlayersService:GetPlayers()
	local occupancySentence = "The only one in the server."
	if #players == 1 then
		occupancySentence = "The only one in the server."
	elseif #players == 2 then
		occupancySentence = " The server has 1 other player, too."
	else
		occupancySentence = string.format(" The server has %d other players, too.", #players - 1)
	end
	local mat = "*unknown material"
	local character: Model? = player.Character or player.CharacterAdded:Wait() :: Model
	if not character then
		annotater.Error("no character.")
		return true
	end
	local hum: Humanoid? = character:FindFirstChild("Humanoid") :: Humanoid
	if hum ~= nil then
		mat = hum.FloorMaterial.Name
	end
	local message = string.format(
		"%s beckons you to join the server. He is standing on %s, %s",
		player.Name,
		mat,
		occupancySentence
	)
	local request: tt.postRequest = {
		remoteActionName = "beckon",
		data = { userId = player.UserId, message = message, jobIdAlpha = game.JobId },
	}
	local res = rdb.MakePostRequest(request)
	if res then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.Beckoner)
	end

	commandUtils.SendMessage(player.Name .. " beckons distant friends to join.", player)

	return true
end

_annotate("end")
return module

