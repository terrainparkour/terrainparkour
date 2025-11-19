--!strict

-- CommandService.lua :: ReplicatedStorage.ChatSystem.CommandService
-- SERVER-ONLY: Routes chat commands to individual command handlers.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local PlayersService = game:GetService("Players")

local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)
local _commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local MessageFormatter = require(game.ReplicatedStorage.ChatSystem.messageFormatter)

local config = require(game.ReplicatedStorage.config)
local enums = require(game.ReplicatedStorage.util.enums)
local tt = require(game.ReplicatedStorage.types.gametypes)
local playerData2 = require(game.ServerScriptService.playerData2)
local textUtil = require(game.ReplicatedStorage.util.textUtil)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)

local adminWarpCommand = require(game.ReplicatedStorage.commands.adminWarpCommand)
local anyBanCommand = require(game.ReplicatedStorage.commands.anyBanCommand)
local describeSingleSignCommand = require(game.ReplicatedStorage.commands.describeSingleSignCommand)

type Module = {
	Commands: { [string]: any },
	ProcessCommand: (self: Module, text: string, player: Player, sourceChannelName: string?) -> any,
}

local CommandService: Module = {} :: Module

-- Load command modules
local helpCmd = require(game.ReplicatedStorage.commands.helpCommand)
local playerCmd = require(game.ReplicatedStorage.commands.playerCommand)
local favoriteCmd = require(game.ReplicatedStorage.commands.favoriteCommand)
local unfavoriteCmd = require(game.ReplicatedStorage.commands.unfavoriteCommand)
local historyCmd = require(game.ReplicatedStorage.commands.historyCommand)
local randomRaceCmd = require(game.ReplicatedStorage.commands.randomRaceCommand)

-- Command registry organized by category for clarity
CommandService.Commands = {
	-- Help and Information
	help = helpCmd,
	meta = require(game.ReplicatedStorage.commands.metaCommand),
	hint = require(game.ReplicatedStorage.commands.hintCommand),
	
	-- Player Information
	player = playerCmd,
	p = playerCmd,
	badges = require(game.ReplicatedStorage.commands.badgesCommand),
	found = require(game.ReplicatedStorage.commands.foundCommand),
	awards = require(game.ReplicatedStorage.commands.awardsCommand),
	
	-- Sign Information
	sign = require(game.ReplicatedStorage.commands.signCommand),
	closest = require(game.ReplicatedStorage.commands.closestCommand),
	show = require(game.ReplicatedStorage.commands.showCommand),
	common = require(game.ReplicatedStorage.commands.commonCommand),
	missing = require(game.ReplicatedStorage.commands.missingCommand),
	
	-- Race/Competition Data
	wrs = require(game.ReplicatedStorage.commands.wrsCommand),
	cwrs = require(game.ReplicatedStorage.commands.cwrsCommand),
	nonwrs = require(game.ReplicatedStorage.commands.nonwrsCommand),
	finders = require(game.ReplicatedStorage.commands.findersCommand),
	popular = require(game.ReplicatedStorage.commands.popularCommand),
	challenge = require(game.ReplicatedStorage.commands.challengeCommand),
	
	-- Personal Management
	favorite = favoriteCmd,
	fav = favoriteCmd,
	unfavorite = unfavoriteCmd,
	unfav = unfavoriteCmd,
	pin = require(game.ReplicatedStorage.commands.pinCommand),
	unpin = require(game.ReplicatedStorage.commands.unpinCommand),
	sf = require(game.ReplicatedStorage.commands.sfCommand),
	
	-- Race Details
	res = require(game.ReplicatedStorage.commands.resCommand),
	history = historyCmd,
	h = historyCmd,
	
	-- Random/Discovery
	random = require(game.ReplicatedStorage.commands.randomCommand),
	randomRace = randomRaceCmd,
	rr = randomRaceCmd,
	
	-- Marathon System
	marathon = require(game.ReplicatedStorage.commands.marathonCommand),
	marathons = require(game.ReplicatedStorage.commands.marathonsCommand),
	
	-- Utility/System
	stats = require(game.ReplicatedStorage.commands.statsCommand),
	time = require(game.ReplicatedStorage.commands.timeCommand),
	uptime = require(game.ReplicatedStorage.commands.uptimeCommand),
	version = require(game.ReplicatedStorage.commands.versionCommand),
	tix = require(game.ReplicatedStorage.commands.tixCommand),
	beckon = require(game.ReplicatedStorage.commands.beckonCommand),
	chomik = require(game.ReplicatedStorage.commands.chomikCommand),
	
	-- Hidden/Special
	secret = require(game.ReplicatedStorage.commands.secretCommand),
	showInteresting = require(game.ReplicatedStorage.commands.showInterestingCommand),
	
	-- Admin Only (Visibility="private" in module)
	ban = anyBanCommand,
	unban = anyBanCommand,
	softban = anyBanCommand,
	hardban = anyBanCommand,
	warp = adminWarpCommand,
}

local function Usage(speaker: Player): ()
	commandUtils.SendMessage(MessageFormatter.usageCommandDesc, speaker)
end

function CommandService:ProcessCommand(commandText: string, player: Player, sourceChannelName: string?): any
	_annotate(string.format("Processing command: '%s' from player: %s", commandText, player.Name))

	local command = commandText:sub(1, 1)

	if command ~= "/" then
		_annotate("Not a command (no leading slash), ignoring")
		return ""
	end

	local message = commandText:sub(2):lower()
	if message == "" then
		_annotate("Empty command, showing usage")
		Usage(player)
		return true
	end

	local parts: { string } = textUtil.stringSplit(message, " ")
	local verb: string = parts[1]
	_annotate(string.format("Command verb: '%s', args: %d", verb, #parts - 1))

	local commandModule = self.Commands[verb]
	if commandModule then
		_annotate(string.format("Info: Found exact command match: '%s'", verb))
		
		-- Check if command requires admin permission
		if commandModule.Visibility == "private" then
			if player.UserId ~= enums.objects.TerrainParkourUserId and player.UserId ~= -1 and player.UserId ~= -2 then
				commandUtils.SendMessage("Permission denied. Admin only command.", player)
				return true
			end
		end
		
		local argParts = {}
		for i = 2, #parts do
			table.insert(argParts, parts[i])
		end
		local result = commandModule.Execute(player, argParts)
		if result == nil then
			result = true
		end
		_annotate(string.format("Info: Command '%s' executed (result=%s)", verb, tostring(result)))
		return result
	end

	_annotate(string.format("No exact match for '%s', trying fallback logic", verb))

	local coalescedVerb = textUtil.coalesceFrom(parts, 1)

	for _, serverPlayer: Player in ipairs(PlayersService:GetPlayers()) do
		if serverPlayer.Name:lower() == coalescedVerb then
			local playerDescription = playerData2.GetPlayerDescriptionMultilineByUserId(serverPlayer.UserId)
			if playerDescription ~= "unknown" then
				local res = serverPlayer.Name .. " stats: " .. playerDescription
				commandUtils.SendMessage(res, player)
				commandUtils.GrantCmdlineBadge(player.UserId)
				return true
			end
		end
	end

	local candidateSignId = tpUtil.looseSignName2SignId(coalescedVerb)
	if candidateSignId ~= nil then
		describeSingleSignCommand.Execute(player, candidateSignId :: number)
		commandUtils.GrantCmdlineBadge(player.UserId)
		return true
	end

	local messageplayer = tpUtil.looseGetPlayerFromUsername(message)
	if messageplayer then
		local playerDescription = playerData2.GetPlayerDescriptionMultilineByUserId(messageplayer.UserId)
		if playerDescription ~= "unknown" then
			local res = messageplayer.Name .. " stats: " .. playerDescription
			commandUtils.SendMessage(res, player)
			commandUtils.GrantCmdlineBadge(player.UserId)
			return true
		end
	end

	local res: tt.RaceParseResult = tpUtil.AttemptToParseRaceFromInput(message)
	if res.error ~= "" then
		commandUtils.SendMessage(res.error, player)
		return true
	end
	if
		not playerData2.HasUserFoundSign(player.UserId, res.signId1)
		or not playerData2.HasUserFoundSign(player.UserId, res.signId2)
	then
		commandUtils.SendMessage("You haven't found one of those signs.", player)
		commandUtils.GrantCmdlineBadge(player.UserId)
		return true
	end

	local userIdsInServer = {}
	for _, oPlayer in ipairs(PlayersService:GetPlayers()) do
		table.insert(userIdsInServer, oPlayer.UserId)
	end
	if config.IsInStudio() then
		table.insert(userIdsInServer, enums.objects.BrouhahahaUserId)
	end
	local entries =
		playerData2.describeRaceHistoryMultilineText(res.signId1, res.signId2, player.UserId, userIdsInServer)
	for _, el in pairs(entries) do
		commandUtils.SendMessage(el.message, player)
	end
	commandUtils.GrantCmdlineBadge(player.UserId)
	return true
end

_annotate("end")
return CommandService
