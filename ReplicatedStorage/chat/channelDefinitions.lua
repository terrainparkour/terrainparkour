--!strict
--2021 reviewed mostly

--eval 9.24.22

local textUtil = require(game.ReplicatedStorage.util.textUtil)
local enums = require(game.ReplicatedStorage.util.enums)
local text = require(game.ReplicatedStorage.util.text)
local grantBadge = require(game.ServerScriptService.grantBadge)

local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local playerdata = require(game.ServerScriptService.playerdata)
local rdb = require(game.ServerScriptService.rdb)

local badgeEnums = require(game.ReplicatedStorage.util.badgeEnums)
local serverwarping = require(game.ServerScriptService.serverwarping)
local channelCommands = require(game.ReplicatedStorage.chat.channelCommands)

local sendMessageModule = require(game.ReplicatedStorage.chat.sendMessage)
local sm = sendMessageModule.sendMessage

local module = {}

--looks like this is a way to shuffle around pointers to actual channel objects.
local channelsFromExternal = nil
module.sendChannels = function(channels)
	-- print("received channels.")
	channelsFromExternal = channels
end

local function Usage(channel)
	if channel == nil then
		warn("Nil channel")
		return
	end
	sm(channel, sendMessageModule.usageCommandDesc)
end

local function GrandCmdlineBadge(userId: number)
	grantBadge.GrantBadge(userId, badgeEnums.badges.CmdLine)
end

--if hardcoded admin user, allow the command.
local function CheckInternalAdminCmd(speaker, message)
	if speaker.UserId == enums.objects.TerrainParkour or speaker.UserId == -1 then
		local parts = textUtil.stringSplit(message, " ")

		local cmd: string = parts[1]

		if #parts == 1 then
			object = ""
		end
		if #parts >= 2 then
			object = parts[2]
		end

		--coalesc later parts.
		for index, el in ipairs(parts) do
			if index == 1 or index == 2 then
				continue
			end
			if el == nil then
				continue
			end
			object = object .. " " .. el
		end

		if cmd == "rw" then
			local rndSign: string = rdb.getRandomSignName()
			local res = serverwarping.WarpToSignName(speaker, rndSign)
			return true
		end

		--commands targeting a player
		if cmd == "ban" or cmd == "unban" or cmd == "softban" or cmd == "hardban" then
			return channelCommands.anyBan(cmd, object)
		end

		--commands targeting a sign
		if cmd == "warp" then
			return channelCommands.warp(cmd, object, speaker)
		end

		return false
	end
	return false
end

--parsing admin commands.
--return true => don't type command
local function DataAdminFunc(speakerName: string, message: string, channelName: string, channels)
	if string.sub(message, 1, 1) ~= "/" then
		return false
	end

	local channel

	--i should look up the channel. doh.
	if channelName == "All" then
		channel = channels.All
	end
	if channelName == "Data" then
		channel = channels.Data
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

	if verb == "challenge" then
		return channelCommands.challenge(speaker, channel, parts)
	end

	if verb == "random" then
		return channelCommands.random(speaker, channel)
	end

	--the new version which scopes race start to those signs found by most people in server.
	--this method is not guaranteed to work if there are people hanging around with no found signs at all.
	if verb == "randomrace" or verb == "rr" then
		local ret = channelCommands.randomRace(speaker, channel)
		if ret ~= nil then
			return ret
		end
	end

	if verb == "common" then
		return channelCommands.common(speaker, channel)
	end
	if verb == "finders" then
		return channelCommands.finders(speaker, channel)
	end
	if verb == "badges" then
		return channelCommands.badges(speaker, channel)
	end
	if verb == "version" then
		return channelCommands.version(speaker, channel)
	end
	if verb == "uptime" then
		return channelCommands.uptime(speaker, channel)
	end

	-- if verb == "longest" then
	-- 	return channelCommands.longest(speaker, channel)
	-- end
	if verb == "chomik" then
		return channelCommands.chomik(speaker, channel)
	end

	if verb == "wrs" then
		return channelCommands.wrs(speaker, channel)
	end

	if verb == "missing" then
		return channelCommands.missingTop10s(speaker, channel)
	end

	if verb == "nonwrs" then
		local to: string
		local signId: number = 0
		if parts[2] == "to" then
			to = "true"
		elseif parts[2] == "from" then
			to = "false"
		else
			--both to and from
			signId = tpUtil.looseSignName2SignId(parts[2])
			to = "both"
		end

		if signId == 0 then
			signId = tpUtil.looseSignName2SignId(parts[3])
			if not signId then
				return false
			end
		end
		return channelCommands.missingWrs(speaker, to, signId, channel)
	end

	if verb == "hint" then
		return channelCommands.hint(speaker, channel, parts)
	end

	if verb == "marathons" then
		GrandCmdlineBadge(speaker.UserId)
		local res = rdb.getMarathonKinds()
		sm(channel, res["message"])
		return true
	end

	if verb == "marathon" then
		GrandCmdlineBadge(speaker.UserId)
		if parts[2] == nil or parts[2] == "" then
			return false
		end
		local res = rdb.getMarathonKindLeaders(parts[2])
		sm(channel, res["message"])
		return true
	end

	if verb == "awards" then
		GrandCmdlineBadge(speaker.UserId)
		local username: string = ""
		if parts[2] == nil or parts[2] == "" then
			username = speaker.Name
		else
			username = parts[2]
		end
		channelCommands.awards(speaker, channel, username)
		return true
	end

	if verb == "tix" then
		local target
		if #parts == 1 then
			target = speaker.Name
		end
		if #parts == 2 then
			target = parts[2]
		end
		local res = rdb.getTixBalanceByUsername(target)
		if res.success then
			sm(channel, res.message)
			GrandCmdlineBadge(speaker.UserId)
		end
		if not res.success then
			if res.message then
				sm(channel, res.message)
			end
		end
		return true
	end

	if verb == "events" then
		module.ShowEvents(channelName, speaker.UserId)
		return true
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
				local res = "could not find player "
				sm(channel, res)
				return true
			end
		end
		local res = text.describeRemainingSigns(target, false, 500)
		if res ~= "" then
			sm(channel, res)
			GrandCmdlineBadge(speaker.UserId)
			return true
		end
	end

	--falling through to interpreting the command as a player name.
	local messageplayer = tpUtil.looseGetPlayerFromUsername(message:lower())
	if messageplayer then
		local playerDescription = playerdata.getPlayerDescriptionMultiline(messageplayer.UserId)
		if playerDescription ~= "unknown" then
			local res = messageplayer.Name .. " stats: " .. playerDescription
			sm(channel, res)
			GrandCmdlineBadge(speaker.UserId)
			return true
		end
	end

	--lookup a sign
	local signtext = playerdata.describeSignText(speaker.UserId, message:lower())
	if signtext ~= "unknown" then
		sm(channel, signtext)
		GrandCmdlineBadge(speaker.UserId)
		return true
	end

	--lookup a race (NAMEPREFIX-NAMEPREFIX) sign names
	local signParts = textUtil.stringSplit(message:lower(), "-")
	if #signParts == 2 then
		local s1 = signParts[1]
		local s2 = signParts[2]

		local signId1 = tpUtil.looseSignName2SignId(s1)
		local signId2 = tpUtil.looseSignName2SignId(s2)

		if not rdb.hasUserFoundSign(speaker.UserId, signId1) or not rdb.hasUserFoundSign(speaker.UserId, signId2) then
			sm(channel, "You haven't found one of those signs.")
			GrandCmdlineBadge(speaker.UserId)
			return true
		end

		local scoretext = playerdata.describeRaceHistoryMultilineText(signId1, signId2)
		if scoretext ~= "unknown" then
			sm(channel, scoretext)
			GrandCmdlineBadge(speaker.UserId)
			return true
		end
	end

	--red highlight their message failure
	Usage(channel)
	return true --there are no other admin commands.
end

export type channelDefinition = {
	Name: string,
	AutoJoin: boolean,
	WelcomeMessage: string,
	adminFunc: any,
	adminFuncName: string,
	noTalkingInChannel: boolean,
	BackupChats: boolean,
}

local joinMessages = {
	"Speedrunning scavenger hunt",
	"Asymptotic complete runs",
	"Quest for 1000 signs",
	"No invisible walls",
	"Just one more race",
}
local joinMessage = joinMessages[math.random(#joinMessages)]

--define the channels for processing and metadata
module.getChannelDefinitions = function(): { channelDefinition }
	local res: { channelDefinition } = {}
	local doNotCheckInGameIdentifier = require(game.ReplicatedStorage:FindFirstChild("doNotCheckInGameIdentifier"))
	if doNotCheckInGameIdentifier.useTestDb() then
		joinMessage =
			"WARNING. This is the test game. Records and other items will be WIPED.  No guarantee of progress.  Also things will be broken.  WARNING\nWARNING.\nz to FallDown"
	end

	local serverTime = os.date("Server Time: %H:%M %d-%m-%Y", tick())

	table.insert(res, {
		Name = "All",
		AutoJoin = true,
		WelcomeMessage = "Welcome to Terrain Parkour!"
			.. "\nVersion: "
			.. enums.gameVersion
			.. "\n"
			.. serverTime
			.. "\n"
			.. joinMessage,
		adminFunc = DataAdminFunc,
		adminFuncName = "AllAdminFunc",
		noTalkingInChannel = false,
		BackupChats = true,
	})

	table.insert(res, {
		Name = "Data",
		AutoJoin = true,
		WelcomeMessage = sendMessageModule.usageCommandDesc,
		adminFunc = DataAdminFunc,
		adminFuncName = "DataAdminFunc",
		noTalkingInChannel = true,
	})

	table.insert(res, {
		Name = "Racers",
		AutoJoin = true,
		WelcomeMessage = "This channel shows joins and leaves!",
		noTalkingInChannel = true,
	})
	return res
end

module.getChannel = function(name)
	while true do
		wait(1)
		if channelsFromExternal ~= nil then
			break
		end
	end
	for k, v in pairs(channelsFromExternal) do
		if v.Name == name then
			return v
		end
	end
	warn("no channel.")
	return nil
end

return module
