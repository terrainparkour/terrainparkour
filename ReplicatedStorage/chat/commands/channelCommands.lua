--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local textUtil = require(game.ReplicatedStorage.util.textUtil)
local grantBadge = require(game.ServerScriptService.grantBadge)
local enums = require(game.ReplicatedStorage.util.enums)
local text = require(game.ReplicatedStorage.util.text)
local config = require(game.ReplicatedStorage.config)
local colors = require(game.ReplicatedStorage.util.colors)
local badgeEnums = require(game.ReplicatedStorage.util.badgeEnums)
local grantBadge = require(game.ServerScriptService.grantBadge)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local playerData2 = require(game.ServerScriptService.playerData2)
local rdb = require(game.ServerScriptService.rdb)
local badges = require(game.ServerScriptService.badges)
local leaderboardBadgeEvents = require(game.ServerScriptService.leaderboardBadgeEvents)
local badgeEnums = require(game.ReplicatedStorage.util.badgeEnums)
local banning = require(game.ServerScriptService.banning)
local serverWarping = require(game.ServerScriptService.serverWarping)
local tt = require(game.ReplicatedStorage.types.gametypes)
local PopularResponseTypes = require(game.ReplicatedStorage.types.PopularResponseTypes)
local popular = require(game.ServerScriptService.data.popularRaces)
local sendMessageModule = require(game.ReplicatedStorage.chat.sendMessage)
local sendMessage = sendMessageModule.sendMessage

local PlayersService = game:GetService("Players")

local module = {}

local function Usage(channel)
	sendMessage(channel, sendMessageModule.usageCommandDesc)
end

local function GrandCmdlineBadge(userId: number)
	grantBadge.GrantBadge(userId, badgeEnums.badges.CmdLine)
end

local function GrandUndocumentedCommandBadge(userId: number)
	grantBadge.GrantBadge(userId, badgeEnums.badges.UndocumentedCommand)
	GrandCmdlineBadge(userId)
end

-- local freedomBuffer = {}
-- module.freedom = function(speaker: Player, channel)
-- 	freedomBuffer = {}
-- end

module.hint = function(speaker: Player, channel, parts: { string }): boolean
	local target: string
	if #parts == 1 then
		target = speaker.Name
	end
	if #parts == 2 then
		local ctarget = tpUtil.looseGetPlayerFromUsername(parts[2])
		if ctarget == nil then
			return false
		end
		target = ctarget.Name
	end
	if target then
		local res = text.describeRemainingSigns(target, true, 100)
		if res ~= "" then
			sendMessage(channel, res)
			GrandCmdlineBadge(speaker.UserId)
			return true
		end
	end

	--target player not in server.
	if not target then
		local res = "Player not found in server."
		sendMessage(channel, res)
		return true
	end

	_annotate("fallthrough.")
	return false
end

module.awards = function(speaker: Player, channel: any, username: string): boolean
	local request: tt.postRequest = {
		remoteActionName = "getAwardsByUser",
		data = {
			username = username,
			userId = speaker.UserId,
		},
	}
	local data: { tt.userAward } = rdb.MakePostRequest(request)
	local res = {}

	if #data > 0 then
		table.insert(res, "Awards for " .. username)
		for ii, el in ipairs(data) do
			local item = string.format("%d - %s in %s", ii, el.awardName, el.contestName)
			table.insert(res, item)
		end
	else
		table.insert(res, "No awards for that person.")
	end

	local msg = textUtil.stringJoin("\n", res)
	sendMessage(channel, msg)
	return true
end

module.wrs = function(speaker: Player, channel): boolean
	local request: tt.postRequest = {
		remoteActionName = "getWRLeaders",
		data = {
			userId = speaker.UserId,
		},
	}
	local data = rdb.MakePostRequest(request)
	sendMessage(channel, "Top World Record Holders (including CWRs):")
	local playersInServer = {}
	for _, player in ipairs(PlayersService:GetPlayers()) do
		playersInServer[player.UserId] = true
	end
	local function getter(userId: number): any
		local data2: tt.lbUserStats = playerData2.GetStatsByUserId(userId, "wrs_command")
		return { rank = data2.wrRank, count = data2.wrCount }
	end
	local res = text.generateTextForRankedList(data, playersInServer, speaker.UserId, getter)
	for _, el in ipairs(res) do
		sendMessage(channel, el.message, el.options)
	end

	GrandCmdlineBadge(speaker.UserId)
	return true
end

module.cwrs = function(speaker: Player, channel): boolean
	sendMessage(channel, "Top Competitive World Record Holders:")
	local request: tt.postRequest = {
		remoteActionName = "getCWRLeaders",
		data = {
			userId = speaker.UserId,
		},
	}
	local data = rdb.MakePostRequest(request)
	local tot = 0
	local a = data.totalCwrCountA
	local b = data.totalCwrCountB
	local message = ""
	if a and b then
		if a == b then
			message = string.format("%d total", a)
		else
			message = string.format("%d total, or maybe %d?", a, b)
		end
	end
	sendMessage(channel, message)

	local playersInServer = {}
	for _, player in ipairs(PlayersService:GetPlayers()) do
		playersInServer[player.UserId] = true
	end

	local function getter(userId: number): any
		local data2 = playerData2.GetStatsByUserId(userId, "cwrs_command")
		return { rank = data2.cwrRank, count = data2.cwrs }
	end

	local res = text.generateTextForRankedList(data.leaders, playersInServer, speaker.UserId, getter)
	for _, el in ipairs(res) do
		sendMessage(channel, el.message, el.options)
	end

	GrandCmdlineBadge(speaker.UserId)
	return true
end

--e.g. (sign leaders for X with highlights, to/from WR summaries)
module.describeSingleSign = function(speaker: Player, signId: number, channel)
	local userIdsInServer = {}
	for _, player in ipairs(PlayersService:GetPlayers()) do
		userIdsInServer[player.UserId] = true
	end
	if config.isInStudio() then
		userIdsInServer[enums.objects.BrouhahahaUserId] = true
	end
	local request: tt.postRequest = {
		remoteActionName = "getTotalFindCountBySign",
		data = { signId = signId },
	}
	local signTotalFinds = rdb.MakePostRequest(request)["count"]
	local signName = enums.signId2name[signId]
	if not playerData2.HasUserFoundSign(speaker.UserId, signId) then
		local ret = string.format(
			"You haven't found %s yet, so can't look up information on it. But %d people have found it.",
			signName,
			signTotalFinds
		)
		sendMessage(channel, ret)
		return
	end

	type signLeader = { userId: number, count: number }

	local request: tt.postRequest = {
		remoteActionName = "getSignStartLeader",
		data = { signId = signId },
	}
	local fromleaders: { signLeader } = rdb.MakePostRequest(request)
	local request: tt.postRequest = {
		remoteActionName = "getSignEndLeader",
		data = { signId = signId },
	}
	local toleaders: { signLeader } = rdb.MakePostRequest(request)
	local counts: { [string]: { to: number, from: number, username: string, inServer: boolean } } = {}
	local text = "\nSign Leader for "
		.. signName
		.. "!\n"
		.. tostring(signTotalFinds)
		.. " players have found "
		.. signName
		.. "\nrank name total (from/to)"
	sendMessage(channel, text)
	for _, leader in ipairs(fromleaders) do
		local username: string
		if leader.userId < 0 then
			username = "TestUser" .. leader.userId
		else
			username = playerData2.GetUsernameByUserId(leader.userId)
		end
		if counts[username] == nil then
			counts[username] = { to = 0, from = 0, username = username, inServer = false }
		end
		if userIdsInServer[leader.userId] then
			counts[username].inServer = true
		end

		counts[username].from = counts[username].from + leader.count
	end

	for _, leader in ipairs(toleaders) do
		local username: string

		if leader.userId < 0 then
			username = "TestUser" .. leader.userId
		else
			username = playerData2.getUsernameByUserId(leader.userId)
		end
		if counts[username] == nil then
			counts[username] = { to = 0, from = 0, username = username, inServer = false }
		end
		if userIdsInServer[leader.userId] then
			counts[username].inServer = true
		end
		counts[username].to = counts[username].to + leader.count
	end
	local tbl = {}
	for username, item in pairs(counts) do
		table.insert(tbl, item)
	end
	table.sort(tbl, function(a, b)
		return a.to + a.from > b.to + b.from
	end)

	for ii, item in ipairs(tbl) do
		local options = { ChatColor = colors.white }
		if item.inServer then
			options.ChatColor = colors.greenGo
		end
		local line = string.format("%d. %s - %d (%d/%d)", ii, item.username, item.to + item.from, item.from, item.to)
		sendMessage(channel, line, options)
	end
end

module.missingTop10s = function(speaker: Player, channel): boolean
	sendMessage(channel, "NonTop10 races for: " .. speaker.Name)
	local data: tt.getNonTop10RacesByUser = playerData2.getNonTop10RacesByUserId(speaker.UserId, "nontop10_command")
	for _, runDesc in ipairs(data.raceDescriptions) do
		channel:SendSystemMessage(" * " .. runDesc, {
			Font = Enum.Font.Code,
		})
	end
	GrandCmdlineBadge(speaker.UserId)
	return true
end

module.missingWrs = function(speaker: Player, to: string, signId: number, channel): boolean
	local signName = tpUtil.signId2signName(signId)
	local totext = to
	if to == "both" then
		totext = "to/from"
	end
	sendMessage(channel, "NonWR races " .. totext .. " " .. signName .. " for: " .. speaker.Name)
	local data: tt.getNonTop10RacesByUser =
		playerData2.getNonWRsByToSignIdAndUserId(to, signId, speaker.UserId, "nonwr_command")
	for _, runDesc in ipairs(data.raceDescriptions) do
		channel:SendSystemMessage(" * " .. runDesc, {
			Font = Enum.Font.Code,
		})
	end
	GrandCmdlineBadge(speaker.UserId)
	return true
end

local function getClosestSignToPlayer(player: Player): Instance?
	local character: Model? = player.Character or player.CharacterAdded:Wait() :: Model
	if not character then
		return nil
	end
	local root: Part? = character:FindFirstChild("HumanoidRootPart") :: Part
	if not root then
		return nil
	end
	local playerPos = root.Position
	local bestSign = nil
	local bestdist = nil
	for _, sign: Part in ipairs(workspace:WaitForChild("Signs"):GetChildren()) do
		local signId = tpUtil.looseSignName2SignId(sign.Name)
		if not playerData2.HasUserFoundSign(player.UserId, signId :: number) then
			continue
		end
		local dist = tpUtil.getDist(sign.Position, playerPos)
		if bestdist == nil or dist < bestdist then
			bestdist = dist
			bestSign = sign
		end
	end
	return bestSign
end

-- module.RemoveUserTopRun = function(speaker: Player, channel, argumentToCommand): boolean
-- 	local res: tt.RaceParseResult = tpUtil.AttemptToParseRaceFromInput(argumentToCommand)

-- 	if res.error then
-- 		sendMessage(channel, res.error)
-- 		return true
-- 	end
-- 	local res = module.RemoveUserTopRun(speaker.UserId, res.signId1, res.signId2)

-- 	return true
-- end

local beckontimes = {}
module.beckon = function(speaker: Player, channel): boolean
	if beckontimes[speaker.UserId] then
		local gap = tick() - beckontimes[speaker.UserId]
		local limit = 180
		if config.isInStudio() then
			limit = 3
		end
		if gap < limit then
			sendMessage(channel, "You can beckon every 3 minutes.")
			return true
		end
	end
	beckontimes[speaker.UserId] = tick()
	local players = PlayersService:GetPlayers()
	local occupancySentence = "The only one in the server."
	if #players == 1 then
		occupancySentence = "The only one in the server."
	elseif #players == 2 then
		occupancySentence = string.format(" The server has 1 other player, too.")
	else
		occupancySentence = string.format(" The server has %d other players, too.", #players - 1)
	end
	local mat = "*unknown material"
	local character: Model? = speaker.Character or speaker.CharacterAdded:Wait() :: Model
	if not character then
		annotater.Error("no character.")
	end
	local hum: Humanoid? = character:FindFirstChild("Humanoid") :: Humanoid
	if hum ~= nil then
		mat = hum.FloorMaterial.Name
	end
	local message = string.format(
		"%s beckons you to join the server. He is standing on %s, %s",
		speaker.Name,
		mat,
		occupancySentence
	)
	local request: tt.postRequest = {
		remoteActionName = "beckon",
		data = { userId = speaker.UserId, message = message, jobIdAlpha = game.JobId },
	}
	local res = rdb.MakePostRequest(request)
	if res then
		grantBadge.GrantBadge(speaker.UserId, badgeEnums.badges.Beckoner)
	end

	sendMessage(channel, speaker.Name .. " beckons distant friends to join.")

	return true
end

module.badges = function(speaker: Player, channel): boolean
	local allBadgeStatuses = badges.getAllBadgeProgressDetailsForUserId(speaker.UserId, "cmdline")
	sendMessage(channel, "Badge status for: " .. speaker.Name)
	local gotStr = "BADGES GOTTEN:"
	local ungotStr = "BADGES NOT GOTTEN:"
	local gotct = 0
	local ungotct = 0

	local allBadgeClasses = {}

	for _, badgeStatus in ipairs(allBadgeStatuses) do
		allBadgeClasses[badgeStatus.badge.badgeClass] = true
		continue
	end
	for badgeClass, _ in pairs(allBadgeClasses) do
		local hasOneThisClass = false
		for _, ba in pairs(allBadgeStatuses) do
			if ba.badge.badgeClass ~= badgeClass then
				continue
			end

			if ba.got then
				if not hasOneThisClass then
					gotStr = gotStr .. "\r\n" .. badgeClass .. ": => "
					hasOneThisClass = true
				end
				gotct += 1
				gotStr = gotStr .. ", " .. ba.badge.name
			else
				ungotct += 1
				ungotStr = ungotStr .. ", " .. ba.badge.name
			end
		end
	end

	sendMessage(channel, gotStr)
	sendMessage(channel, ungotStr)

	local total = "Got: " .. gotct .. " Not got: " .. ungotct
	sendMessage(channel, total)

	local badgecount = badges.getBadgeCountByUser(speaker.UserId, "channelCommands.badges")
	for _, otherPlayer: Player in ipairs(PlayersService:GetPlayers()) do
		leaderboardBadgeEvents.updateBadgeLb(speaker, otherPlayer.UserId, badgecount)
	end
	GrandCmdlineBadge(speaker.UserId)
	return true
end

module.anyBan = function(cmd, object): boolean
	local target = tpUtil.looseGetPlayerFromUsername(object)
	if not target then
		return false
	end
	if cmd == "unban" then
		banning.unBanUser(target.UserId)
	end
	if cmd == "softban" or cmd == "ban" then
		banning.softBanUser(target.UserId)
	end
	if cmd == "hardban" then
		banning.hardBanUser(target.UserId)
	end
	return true
end

-- warp to either a sign or a player by username.
module.AdminOnlyWarp = function(cmd, object, speaker): boolean
	local signId = tpUtil.looseSignName2SignId(object)
	if signId then
		local request: tt.serverWarpRequest = {
			kind = "sign",
			signId = signId,
		}

		serverWarping.RequestClientToWarpToWarpRequest(speaker, request)
	else
		local targetPlayer = tpUtil.looseGetPlayerFromUsername(object)
		if targetPlayer == nil or targetPlayer.Character == nil then
			_annotate(
				string.format("server command %s tried to warp but couldn't find player based on data: %s", cmd, object)
			)
			return false
		end
		_annotate(string.format("WarpToUsername username=%s", object))
		local pos = targetPlayer.Character.PrimaryPart.Position + Vector3.new(10, 20, 10)
		if not pos then
			warn("player not found in workspace")
			return false
		end
		local request: tt.serverWarpRequest = {
			kind = "position",
			position = pos,
		}
		serverWarping.RequestClientToWarpToWarpRequest(speaker, request)
	end
	return true
end

module.secret = function(speaker: Player, channel: any): boolean
	local got = grantBadge.GrantBadge(speaker.UserId, badgeEnums.badges.Secret)
	if got then
		channel.SendSystemMessage(speaker.Name .. " has found the secret badge!")
	end
	return true
end

module.time = function(speaker: Player, channel: any): boolean
	local serverTime = os.date("Server Time - %H:%M %d-%m-%Y", tick())
	sendMessage(channel, serverTime)
	GrandUndocumentedCommandBadge(speaker.UserId)
	return true
end

module.chomik = function(speaker: Player, channel: any): boolean
	local character: Model? = speaker.Character or speaker.CharacterAdded:Wait() :: Model
	if not character then
		annotater.Error("no character.")
	end
	local root = character:WaitForChild("HumanoidRootPart") :: Part
	if not root then
		annotater.Error("no root")
	end
	local signs: Folder = game.Workspace:FindFirstChild("Signs")
	local chomik: Part = signs:FindFirstChild("Chomik") :: Part
	local dist = tpUtil.getDist(root.Position, chomik.Position)
	local message = string.format("The Chomik is %dd away from %s", dist, speaker.Name)
	sendMessage(channel, message)
	GrandCmdlineBadge(speaker.UserId)
	return true
end

local doNotCheckInGameIdentifier = require(game.ReplicatedStorage:FindFirstChild("doNotCheckInGameIdentifier"))
module.version = function(speaker: Player, channel: any): boolean
	local testMessage = ""
	if doNotCheckInGameIdentifier.useTestDb() then
		testMessage = " TEST VERSION, db will be wiped"
	end

	local message = string.format("Terrain Parkour - Version %s%s", enums.gameVersion, testMessage)
	sendMessage(channel, message)
	GrandUndocumentedCommandBadge(speaker.UserId)
	return true
end

local bootTime = tick()

module.uptime = function(speaker: Player, channel: any): boolean
	local uptimeTicks = tick() - bootTime
	local days = 0
	local hours = 0
	local minutes = 0

	if uptimeTicks >= 86400 then
		days = math.floor(uptimeTicks / 86400)
		uptimeTicks = uptimeTicks - days * 86400
	end

	if uptimeTicks >= 3600 then
		hours = math.floor(uptimeTicks / 3600)
		uptimeTicks = uptimeTicks - hours * 3600
	end

	if uptimeTicks >= 60 then
		minutes = math.floor(uptimeTicks / 60)
		uptimeTicks = uptimeTicks - minutes * 60
	end

	local message =
		string.format("Server Uptime:  - %d days %d hours %d minutes %d seconds", days, hours, minutes, uptimeTicks)
	sendMessage(channel, message)
	GrandUndocumentedCommandBadge(speaker.UserId)
	return true
end

module.today = function(speaker: Player, channel): boolean
	local res = playerData2.getGameStats()
	sendMessage(channel, res)
	GrandCmdlineBadge(speaker.UserId)
	return true
end

module.meta = function(speaker: Player, channel): boolean
	local res =
		"Principles of Terrain Parkour:\n\tNo Invisible Walls\n\tJust One More Race\n\tNo Dying\n\tRewards always happen\n\tFairness"
	sendMessage(channel, res)
	GrandCmdlineBadge(speaker.UserId)
	return true
end

module.closest = function(speaker: Player, channel): boolean
	local bestsign: Instance? = getClosestSignToPlayer(speaker)
	local message = ""
	if bestsign == nil then
		message = "You have not found any signs."
	else
		message = "The closest found sign to " .. speaker.Name .. " is " .. bestsign.Name .. "!"
	end

	sendMessage(channel, message)
	GrandCmdlineBadge(speaker.UserId)
	return true
end

--command to show <random> selection of unrun/unwr-ed runs with certain parameters.
--2022.06 incomplete
module.showInteresting = function(speaker: Player, channel, params: tt.missingRunRequestParams): boolean
	if
		params.kind == "unrun-to"
		or params.kind == "unrun-from"
		or params.kind == "unwr-from"
		or params.kind == "unwr-to"
	then
		print("weird can't do missing run lookup?")
		local res = rdb.DoMissingRunLookup(params)
		local message = ""
		if res == nil then
			warn("miss res")
			message = "No result."
			sendMessage(channel, message)
		else
			message = res[1].startSignName .. "-" .. res[1].endSignName
			sendMessage(channel, message)
		end
		GrandCmdlineBadge(speaker.UserId)
	else
		warn("invalid params")
		warn(params)
		return false
	end
	return true
end

module.challenge = function(speaker: Player, channel, parts): boolean
	if parts[2] == nil or parts[2] == "" then
		Usage(channel)
		return true
	end
	local res = text.describeChallenge(parts)
	if res ~= "" then
		sendMessage(channel, res)
		GrandCmdlineBadge(speaker.UserId)
		--successfully showed challenge
		return true
	else
		Usage(channel)
		return false
	end
end

local getRandomFoundSignName = function(userId: number): string
	local items = playerData2.GetUserSignFinds(userId, "getRandomFoundSignName")
	local choices = {}
	for signId: number, found: boolean in pairs(items) do
		if found then
			table.insert(choices, signId)
		end
	end
	local signId = choices[math.random(#choices)]
	local signName = tpUtil.signId2signName(signId)
	if signName == nil or signName == "" then
		warn("bad.")
	end
	return signName
end

module.random = function(speaker: Player, channel): boolean
	local rndSign = getRandomFoundSignName(speaker.UserId) or ""
	local res = "Random Sign You've found: " .. rndSign .. "."
	sendMessage(channel, res)
	GrandCmdlineBadge(speaker.UserId)
	return true
end

--lastrandom caching.
local lastRandomSignId1: number
local lastRandomSignId2: number
local lastRandomTicks: number

-------- CONSTANTS ---------------
local runTimeInSecondsWithoutBump = 50 --todo lengthen  this
-- runTimeInSecondsWithoutBump = 0.1

module.randomRace = function(speaker: Player, channel): boolean
	if config.isInStudio() then
		runTimeInSecondsWithoutBump = 1
	end
	local candidateSignId1: number
	local candidateSignId2: number
	local myTick = tick()
	local reusingRace = false

	--we just redo the last one if it's not out of horizon?
	if lastRandomTicks ~= nil and myTick - lastRandomTicks < runTimeInSecondsWithoutBump then
		--reuse last time signs
		candidateSignId1 = lastRandomSignId1
		candidateSignId2 = lastRandomSignId2
		lastRandomTicks = myTick
		reusingRace = true
		return true
	else
		reusingRace = false
		local signIdChoices = playerData2.getCommonFoundSignIdsExcludingNoobs(speaker.UserId)
		--choices which actually exist in the game:

		--if we are in test mode game, we need to do this filter also:
		local signFolder = game.Workspace:FindFirstChild("Signs")
		if config.isInStudio() then
			local existingSignIdChoices = {}
			for _, signId in ipairs(signIdChoices) do
				local sn = tpUtil.signId2signName(signId)
				if not sn then
					continue
				end
				if not signFolder:FindFirstChild(sn) then
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
				_annotate(string.format("diff, keeping serverRace.. %s %s", candidateSignId1, candidateSignId2))
				break
			end
			tries = tries + 1
			if tries > 20 then
				warn("failure to gen rr race sign.")
				break
			end
			_annotate("stuck in starting server event")
		end
		lastRandomTicks = myTick
	end

	if candidateSignId1 ~= nil and candidateSignId2 ~= nil then
		lastRandomSignId1 = candidateSignId1
		lastRandomSignId2 = candidateSignId2
		local userIdsInServer = {}
		for _, player in ipairs(PlayersService:GetPlayers()) do
			table.insert(userIdsInServer, player.UserId)
		end
		if config.isInStudio then
			table.insert(userIdsInServer, enums.objects.BrouhahahaUserId)
		end

		local entries = playerData2.describeRaceHistoryMultilineText(
			candidateSignId1,
			candidateSignId2,
			speaker.UserId,
			userIdsInServer
		)

		if not reusingRace then
			for _, el in pairs(entries) do
				sendMessage(channel, el.message, el.options)
			end
		end
		local userJoinMes = speaker.Name
			.. " joined the random race from "
			.. tpUtil.signId2signName(candidateSignId1)
			.. " to "
			.. tpUtil.signId2signName(candidateSignId2)
			.. '. Use "/rr" to join too!'
		sendMessage(channel, userJoinMes)
		GrandCmdlineBadge(speaker.UserId)

		local request: tt.serverWarpRequest = {
			kind = "sign",
			signId = candidateSignId1,
			highlightSignId = candidateSignId2,
		}
		serverWarping.RequestClientToWarpToWarpRequest(speaker, request)
		--this thing notifies the channel about 15 second countdown ending.
		if not reusingRace then
			task.spawn(function()
				while true do
					if candidateSignId1 ~= lastRandomSignId1 or candidateSignId2 ~= lastRandomSignId2 then
						return
					end
					if tick() - lastRandomTicks > runTimeInSecondsWithoutBump then
						sendMessage(channel, "Next race ready to start.")
						break
					end
					task.wait(1)
				end
			end)
		end

		return true
	end

	annotater.Error("fell through generating rr?")
end

module.popular = function(speaker: Player, channel): boolean
	--for testing, fake it like these people are also in the server.

	local userIdsInServer = { -2, enums.objects.TerrainParkourUserId }
	userIdsInServer = {}
	for _, player in ipairs(PlayersService:GetPlayers()) do
		table.insert(userIdsInServer, player.UserId)
	end
	local popResults: { PopularResponseTypes.popularRaceResult } = popular.GetPopularRaces(speaker, userIdsInServer)

	local messages: { string } = {}
	table.insert(messages, "Top Recent Runs:")
	for _, rr in ipairs(popResults) do
		local userPlaces = {}
		for _, el in ipairs(rr.userPlaces) do
			local userId = el.userId
			local userPlace = el.place
			local username = playerData2.GetUsernameByUserId(tonumber(userId))
			local usePlace: string = ""

			if userPlace == nil then --did not run at all.
				continue
			end
			if userPlace == 0 then
				usePlace = "DNP	"
			elseif userPlace > 10 then
				usePlace = "DNP"
			else
				usePlace = tpUtil.getCardinalEmoji(userPlace)
			end
			local msg = username .. ":" .. usePlace
			table.insert(userPlaces, msg)
		end
		local placeJoined = textUtil.stringJoin(", ", userPlaces)

		local msg = tostring(rr.ct) .. " " .. rr.startSignName .. "-" .. rr.endSignName .. " - " .. placeJoined
		table.insert(messages, msg)
	end
	local res = textUtil.stringJoin("\n", messages)
	sendMessage(channel, res)
	GrandCmdlineBadge(speaker.UserId)
	return true
end

module.finders = function(speaker: Player, channel): boolean
	local res = playerData2.getFinderLeaders()

	sendMessage(channel, "Top Finders:")
	local playersInServer = {}
	for _, player in ipairs(PlayersService:GetPlayers()) do
		playersInServer[player.UserId] = true
	end
	local function getter(userId: number): any
		local data: tt.lbUserStats = playerData2.GetStatsByUserId(userId, "finders_command")
		return { rank = data.findRank, count = data.findCount }
	end
	local res = text.generateTextForRankedList(res, playersInServer, speaker.UserId, getter)
	for _, el in ipairs(res) do
		sendMessage(channel, el.message, el.options)
	end

	GrandCmdlineBadge(speaker.UserId)
	return true
end

module.common = function(speaker: Player, channel): boolean
	--find the intersection of finds of the top finders in the server
	local signNames = playerData2.getCommonFoundSignNames()
	local res = "Signs everyone in server has found: "

	for _, signName in ipairs(signNames) do
		res = res .. signName .. ", "
	end
	sendMessage(channel, res)
	GrandCmdlineBadge(speaker.UserId)
	return true
end

_annotate("end")
return module
