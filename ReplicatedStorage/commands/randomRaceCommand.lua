--!strict

-- randomRaceCommand.lua :: ReplicatedStorage.commands.randomRaceCommand
-- SERVER-ONLY: Starts a random race between two signs.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local PlayersService = game:GetService("Players")

local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)
local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)

local config = require(game.ReplicatedStorage.config)
local enums = require(game.ReplicatedStorage.util.enums)
local tt = require(game.ReplicatedStorage.types.gametypes)
local playerData2 = require(game.ServerScriptService.playerData2)
local serverWarping = require(game.ServerScriptService.serverWarping)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "any",
	AutocompleteVisible = true,
	Aliases = { "rr" },
}

local runTimeInSecondsWithoutBump = 50
local _lastRandomSignId1: number = 0
local _lastRandomSignId2: number = 0
local _lastRandomTicks: number = 0

function module.Execute(player: Player, _parts: { string }): boolean
	local actualRunTime = runTimeInSecondsWithoutBump
	if config.IsInStudio() then
		actualRunTime = 1
	end
	local candidateSignId1: number?
	local candidateSignId2: number?
	local myTick = tick()
	local reusingRace = false

	if _lastRandomTicks ~= 0 and myTick - _lastRandomTicks < actualRunTime then
		candidateSignId1 = _lastRandomSignId1
		candidateSignId2 = _lastRandomSignId2
		_lastRandomTicks = myTick
		reusingRace = true
		return true
	else
		reusingRace = false
		local signIdChoices = playerData2.getCommonFoundSignIdsExcludingNoobs(player.UserId)

		local signFolder = game.Workspace:FindFirstChild("Signs")
		if config.IsInStudio() then
			if not signFolder or not signFolder:IsA("Folder") then
				return false
			end
			local signFolderTyped = signFolder :: Folder
			local existingSignIdChoices = {}
			for _, signId in ipairs(signIdChoices) do
				local sn = tpUtil.signId2signName(signId)
				if not sn then
					continue
				end
				if not signFolderTyped:FindFirstChild(sn) then
					continue
				end
				table.insert(existingSignIdChoices, signId)
			end
			signIdChoices = existingSignIdChoices
		end

		if #signIdChoices < 1 then
			return false
		end

		local tries = 0
		while true do
			candidateSignId1 = signIdChoices[math.random(#signIdChoices)]
			candidateSignId2 = signIdChoices[math.random(#signIdChoices)]

			if candidateSignId1 == nil then
				_annotate("bad sign 1")
				continue
			end
			if candidateSignId2 == nil then
				_annotate("bad sign can 2id.")
				continue
			end

			if candidateSignId2 ~= candidateSignId1 then
				_annotate(string.format("diff, keeping serverRace.. %d %d", candidateSignId1, candidateSignId2))
				break
			end
			tries = tries + 1
			if tries > 20 then
				warn("failure to gen rr race sign.")
				break
			end
			_annotate("stuck in starting server event")
		end
		_lastRandomTicks = myTick
	end

	if candidateSignId1 ~= nil and candidateSignId2 ~= nil then
		_lastRandomSignId1 = candidateSignId1
		_lastRandomSignId2 = candidateSignId2
		local userIdsInServer = {}
		for _, serverPlayer in ipairs(PlayersService:GetPlayers()) do
			table.insert(userIdsInServer, serverPlayer.UserId)
		end
		if config.IsInStudio() then
			table.insert(userIdsInServer, enums.objects.BrouhahahaUserId)
		end

		local entries = playerData2.describeRaceHistoryMultilineText(
			candidateSignId1,
			candidateSignId2,
			player.UserId,
			userIdsInServer
		)

		if not reusingRace then
			for _, el in pairs(entries) do
				commandUtils.SendMessage(el.message, player)
			end
		end
		local userJoinMes = player.Name
			.. " joined the random race from "
			.. tpUtil.signId2signName(candidateSignId1)
			.. " to "
			.. tpUtil.signId2signName(candidateSignId2)
			.. '. Use "/rr" to join too!'
		commandUtils.SendMessage(userJoinMes, player)
		commandUtils.GrantCmdlineBadge(player.UserId)

		local request: tt.serverWarpRequest = {
			kind = "sign",
			signId = candidateSignId1,
			highlightSignId = candidateSignId2,
		}
		serverWarping.RequestClientToWarpToWarpRequest(player, request)
		if not reusingRace then
			task.spawn(function()
				while true do
					if candidateSignId1 ~= _lastRandomSignId1 or candidateSignId2 ~= _lastRandomSignId2 then
						return
					end
					if tick() - _lastRandomTicks > actualRunTime then
						commandUtils.SendMessage("Next race ready to start.", player)
						break
					end
					task.wait(1)
				end
			end)
		end

		return true
	end

	annotater.Error("fell through generating rr?")
	return false
end

_annotate("end")
return module
