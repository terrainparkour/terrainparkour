--!strict

-- commandParsins.lua
-- originally this also included lots of implementations.
-- but now they're moved to channelComamnds.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local textUtil = require(game.ReplicatedStorage.util.textUtil)
local enums = require(game.ReplicatedStorage.util.enums)
local text = require(game.ReplicatedStorage.util.text)
local grantBadge = require(game.ServerScriptService.grantBadge)
local config = require(game.ReplicatedStorage.config)
local tt = require(game.ReplicatedStorage.types.gametypes)

local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local playerData2 = require(game.ServerScriptService.playerData2)
local rdb = require(game.ServerScriptService.rdb)

local badgeEnums = require(game.ReplicatedStorage.util.badgeEnums)
local channelCommands = require(game.ReplicatedStorage.chat.commands.channelCommands)
local signProfileCommand = require(game.ReplicatedStorage.commands.signProfileCommand)
local showSignsCommand = require(game.ReplicatedStorage.commands.showSignsCommand)

local sendMessageModule = require(game.ReplicatedStorage.chat.sendMessage)
local sendMessage = sendMessageModule.sendMessage
local PlayersService = game:GetService("Players")

-- COMMANDS

--TODO would be nice to fix this up, including return types.
local getTixBalanceByUsername = function(username: string)
	local request: tt.postRequest = {
		remoteActionName = "getTixBalanceByUsername",
		data = { username = username },
	}
	local res = rdb.MakePostRequest(request)
	return res
end

local getMarathonKindLeaders = function(marathonKind: string)
	local request: tt.postRequest = {
		remoteActionName = "getMarathonKindLeaders",
		data = { marathonKind = marathonKind },
	}
	local res = rdb.MakePostRequest(request)
	return res
end

local getMarathonKinds = function()
	local request: tt.postRequest = {
		remoteActionName = "getMarathonKinds",
		data = {},
	}
	local res = rdb.MakePostRequest(request)
	return res
end
--other

--looks like this is a way to shuffle around pointers to actual channel objects.

local function Usage(channel)
	if channel == nil then
		warn("Nil channel")
		return
	end
	sendMessage(channel, sendMessageModule.usageCommandDesc)
end

local function GrandCmdlineBadge(userId: number)
	grantBadge.GrantBadge(userId, badgeEnums.badges.CmdLine)
end

--if hardcoded admin user, allow the command.
local function CheckInternalAdminCmd(speaker, message)
	if speaker.UserId == enums.objects.TerrainParkourUserId or speaker.UserId == -1 or speaker.UserId == -2 then
		local parts = textUtil.stringSplit(message, " ")

		local cmd: string = parts[1]
		local object = ""
		if #parts == 1 then
			object = ""
		end

		object = textUtil.coalesceFrom(parts, 2)

		--commands targeting a player
		if cmd == "ban" or cmd == "unban" or cmd == "softban" or cmd == "hardban" then
			return channelCommands.anyBan(cmd, object)
		end

		--commands targeting a sign
		if cmd == "warp" then
			return channelCommands.AdminOnlyWarp(cmd, object, speaker)
		end

		return false
	end
	return false
end

--parsing admin commands.
--return true => don't type command
module.DataAdminFunc = function(speakerName: string, message: string, channelName: string, channels)
	if string.sub(message, 1, 1) ~= "/" then
		return false
	end

	local channel

	--i should look up the channel. doh.
	if channelName == "All" then
		channel = channels.All
	elseif channelName == "Data" then
		channel = channels.Data
	else
		warn("unset chnnnel.")
		return false
	end

	message = string.sub(message, 2)
	message = string.lower(message)
	if message == "" then
		Usage(channel)
		return true
	end

	local speaker = tpUtil.looseGetPlayerFromUsername(speakerName) :: Player
	if not speaker then
		return true
	end

	local wasInternalAdminCmd = CheckInternalAdminCmd(speaker, message)
	if wasInternalAdminCmd then
		return true
	end
	if message == "cmds" or message == "help" or message == "?" then
		Usage(channel)
		return true
	end

	local parts: { string } = textUtil.stringSplit(message, " ")
	if message == "secret" then
		return channelCommands.secret(speaker, channel)
	end
	if message == "time" then
		return channelCommands.time(speaker, channel)
	end
	if message == "closest" then
		return channelCommands.closest(speaker, channel)
	end
	if message == "today" or message == "stats" then
		return channelCommands.today(speaker, channel)
	end
	if message == "popular" then
		return channelCommands.popular(speaker, channel)
	end
	if message == "meta" then
		return channelCommands.meta(speaker, channel)
	end
	local verb: string = parts[1]
	local argumentToCommand = textUtil.coalesceFrom(parts, 2)

	if verb == "challenge" then
		return channelCommands.challenge(speaker, channel, parts)
	elseif verb == "random" then
		return channelCommands.random(speaker, channel)

		--the new version which scopes race start to those signs found by most people in server.
		--this method is not guaranteed to work if there are people hanging around with no found signs at all.
	elseif verb == "randomrace" or verb == "rr" then
		local ret = channelCommands.randomRace(speaker, channel)
		if ret ~= nil then
			return ret
		end
	elseif verb == "show" then
		local targetUserId = nil
		if parts[2] and parts[2] ~= "" then
			for _, player in ipairs(PlayersService:GetPlayers()) do
				if player.Name:lower() == parts[2]:lower() then
					targetUserId = player.UserId
					break
				end
			end
		end
		return showSignsCommand.ShowSignCommand(speaker, targetUserId)
	elseif verb == "common" then
		return channelCommands.common(speaker, channel)
	elseif verb == "finders" then
		return channelCommands.finders(speaker, channel)
	elseif verb == "badges" then
		return channelCommands.badges(speaker, channel)
	elseif verb == "version" then
		return channelCommands.version(speaker, channel)
	elseif verb == "uptime" then
		return channelCommands.uptime(speaker, channel)
	elseif verb == "pin" then
		local pinRaceCommand = require(game.ReplicatedStorage.chat.commands.pinRaceCommand)
		local userInput = textUtil.coalesceFrom(parts, 2)
		return pinRaceCommand.PinRace(speaker, channel, userInput)
	elseif verb == "unpin" then
		local pinRaceCommand = require(game.ReplicatedStorage.chat.commands.pinRaceCommand)
		return pinRaceCommand.UnpinRace(speaker, channel)
	elseif verb == "chomik" then
		return channelCommands.chomik(speaker, channel)
	elseif verb == "wrs" then
		return channelCommands.wrs(speaker, channel)
	elseif verb == "cwrs" then
		return channelCommands.cwrs(speaker, channel)
	elseif verb == "missing" then
		return channelCommands.missingTop10s(speaker, channel)
	elseif verb == "beckon" then
		return channelCommands.beckon(speaker, channel)
	-- elseif verb == "remove" then
	-- 	return channelCommands.removeRun(speaker, channel, argumentToCommand)
	elseif verb == "nonwrs" then
		local to: string
		local signId: number = 0
		local signName: string = ""
		if parts[2] == "to" then
			signName = textUtil.coalesceFrom(parts, 3)
			to = "true"
		elseif parts[2] == "from" then
			signName = textUtil.coalesceFrom(parts, 3)
			to = "false"
		else
			signName = textUtil.coalesceFrom(parts, 2)
			to = "both"
		end

		signId = tpUtil.looseSignName2SignId(signName)

		if not signId and not config.isInStudio() then
			warn("no sign." .. signName)
			return false
		end

		return channelCommands.missingWrs(speaker, to, signId, channel)
	elseif verb == "hint" then
		return channelCommands.hint(speaker, channel, parts)
	elseif verb == "marathons" then
		GrandCmdlineBadge(speaker.UserId)
		local res = getMarathonKinds()
		sendMessage(channel, res["message"])
		return true
	elseif verb == "marathon" then
		GrandCmdlineBadge(speaker.UserId)
		if parts[2] == nil or parts[2] == "" then
			return false
		end
		local res = getMarathonKindLeaders(parts[2])
		if not res.message then
			res.message = "Couldn't find that marathon."
		end
		sendMessage(channel, res["message"])
		return true
	elseif verb == "awards" then
		GrandCmdlineBadge(speaker.UserId)
		local username: string = ""
		if parts[2] == nil or parts[2] == "" then
			username = speaker.Name
		else
			username = parts[2]
		end
		channelCommands.awards(speaker, channel, username)
		return true
	elseif verb == "tix" then
		local target
		if #parts == 1 then
			target = speaker.Name
		end
		if #parts == 2 then
			target = parts[2]
		end
		local res = getTixBalanceByUsername(target)
		if res.success then
			sendMessage(channel, res.message)
			GrandCmdlineBadge(speaker.UserId)
		end
		if not res.success then
			if res.message then
				sendMessage(channel, res.message)
			end
		end
		return true
	elseif verb == "events" then
		module.ShowEvents(channelName, speaker.UserId)
		return true
	elseif verb == "player" or verb == "p" then
		local playerDescription = playerData2.getPlayerDescriptionMultilineByUsername(parts[2])
		if playerDescription ~= "unknown" then
			local res = "stats: " .. playerDescription
			sendMessage(channel, res)
			GrandCmdlineBadge(speaker.UserId)
			return true
		end

		--this is another way to get the right-click sign UI to pop up.
	elseif verb == "sign" then
		if #parts <= 1 then
			return false
		end

		local subjectUsername: string = speaker.Name
		-- forms of the command: /sign X <info on sign X about you>
		-- /sign X Y <info on sign X about player Y, even if Y is not in server>
		table.remove(parts, 1)

		-- we get the sign name here.
		local signName = textUtil.coalesceFrom(parts, 1)
		local signId = tpUtil.looseSignName2SignId(signName)
		if not signId then
			--multi-word sign. take all the ones before last.
			subjectUsername = parts[#parts]
			table.remove(parts, #parts)
			signName = textUtil.coalesceFrom(parts, 1)
			signId = tpUtil.looseSignName2SignId(signName)
		end
		if not signId then
			signName = textUtil.coalesceFrom(parts, 1)
			signId = tpUtil.looseSignName2SignId(signName)
		end

		if signId and subjectUsername then
			--problem: we have not verified the username here.
			if not playerData2.HasUserFoundSign(speaker.UserId, signId) then
				return true
			end
			signProfileCommand.signProfileCommand(subjectUsername, signId, speaker)
		else
			return false
		end
	end

	if verb == "found" then
		local target: string
		if #parts == 1 then
			target = speakerName
		end
		if #parts == 2 then
			local targetPlayer = tpUtil.looseGetPlayerFromUsername(parts[2])
			if targetPlayer then
				target = targetPlayer.Name
			end
			if not target then
				local res = "Could not find that."
				sendMessage(channel, res)
				return true
			end
		end
		local res = text.describeRemainingSigns(target, false, 500)
		if res ~= "" then
			sendMessage(channel, res)
			GrandCmdlineBadge(speaker.UserId)
			return true
		end
	end

	-- okay now we got a thing like: /<X> and we don't know what X is!
	local coalescedVerb = textUtil.coalesceFrom(parts, 1) --put everything into one word again

	--first look up exact match on player.
	for _, player: Player in ipairs(PlayersService:GetPlayers()) do
		if player.Name:lower() == coalescedVerb then
			local playerDescription = playerData2.GetPlayerDescriptionMultilineByUserId(player.UserId)
			if playerDescription ~= "unknown" then
				local res = player.Name .. " stats: " .. playerDescription
				sendMessage(channel, res)
				GrandCmdlineBadge(speaker.UserId)
				return true
			end
		end
	end

	-- hmm, no, okay maybe it was the prefix of a sign? then look up candidate signs loosely.

	local candidateSignId = tpUtil.looseSignName2SignId(coalescedVerb)
	if candidateSignId ~= nil then
		channelCommands.describeSingleSign(speaker, candidateSignId, channel)
		GrandCmdlineBadge(speaker.UserId)
		return true
	end

	--now treat it as a player prefix (in the server)
	local messageplayer = tpUtil.looseGetPlayerFromUsername(message:lower())
	if messageplayer then
		local playerDescription = playerData2.GetPlayerDescriptionMultilineByUserId(messageplayer.UserId)
		if playerDescription ~= "unknown" then
			local res = messageplayer.Name .. " stats: " .. playerDescription
			sendMessage(channel, res)
			GrandCmdlineBadge(speaker.UserId)
			return true
		end
	end

	-- now treat it as a lookup of a race.
	local res: tt.RaceParseResult = tpUtil.AttemptToParseRaceFromInput(message)
	if res.error ~= "" then
		sendMessage(channel, res.error)
		return true
	end
	if
		not playerData2.HasUserFoundSign(speaker.UserId, res.signId1)
		or not playerData2.HasUserFoundSign(speaker.UserId, res.signId2)
	then
		sendMessage(channel, "You haven't found one of those signs.")
		GrandCmdlineBadge(speaker.UserId)
		return true
	end
	-- okay this is a race UI.

	local userIdsInServer = {}
	for _, player in ipairs(PlayersService:GetPlayers()) do
		table.insert(userIdsInServer, player.UserId)
	end
	if config.isInStudio then
		table.insert(userIdsInServer, enums.objects.BrouhahahaUserId)
	end
	local entries =
		playerData2.describeRaceHistoryMultilineText(res.signId1, res.signId2, speaker.UserId, userIdsInServer)
	for _, el in pairs(entries) do
		sendMessage(channel, el.message, el.options)
	end
	GrandCmdlineBadge(speaker.UserId)
	return true --there are no other admin commands.
end

_annotate("end")
return module
