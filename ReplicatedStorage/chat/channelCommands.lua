--!strict

--2022.03 pulled out commands from channel definitions
--eval 9.21

local textUtil = require(game.ReplicatedStorage.util.textUtil)
local grantBadge = require(game.ServerScriptService.grantBadge)
local enums = require(game.ReplicatedStorage.util.enums)
local text = require(game.ReplicatedStorage.util.text)
local config = require(game.ReplicatedStorage.config)

local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local playerdata = require(game.ServerScriptService.playerdata)
local rdb = require(game.ServerScriptService.rdb)
local remoteDbInternal = require(game.ServerScriptService.remoteDbInternal)
local badges = require(game.ServerScriptService.badges)
local leaderboardBadgeEvents = require(game.ServerScriptService.leaderboardBadgeEvents)
local badgeEnums = require(game.ReplicatedStorage.util.badgeEnums)
local banning = require(game.ServerScriptService.banning)
local serverwarping = require(game.ServerScriptService.serverwarping)
local tt = require(game.ReplicatedStorage.types.gametypes)
local PopularResponseTypes = require(game.ReplicatedStorage.types.PopularResponseTypes)
local popular = require(game.ServerScriptService.data.popular)
local sendMessageModule = require(game.ReplicatedStorage.chat.sendMessage)
local sm = sendMessageModule.sendMessage

local PlayersService = game:GetService("Players")

local module = {}

local function Usage(channel)
	sm(channel, sendMessageModule.usageCommandDesc)
end

local function GrandCmdlineBadge(userId: number)
	grantBadge.GrantBadge(userId, badgeEnums.badges.CmdLine)
end

local function GrandUndocumentedCommandBadge(userId: number)
	grantBadge.GrantBadge(userId, badgeEnums.badges.UndocumentedCommand)
	GrandCmdlineBadge(userId)
end

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
			sm(channel, res)
			GrandCmdlineBadge(speaker.UserId)
			return true
		end
	end

	--target player not in server.
	if not target then
		local res = "Player not found in server."
		sm(channel, res)
		return true
	end

	print("fallthrough.")
	return false
end

module.awards = function(speaker: Player, channel: any, username: string): boolean
	local data: { tt.userAward } = remoteDbInternal.remoteGet("getAwardsByUser", { username = username })["res"]
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
	sm(channel, msg)
	return true
end

module.wrs = function(speaker: Player, channel): boolean
	local data = remoteDbInternal.remoteGet("getWRLeaders", {})
	sm(channel, "Top World Record Holders:")
	local playersInServer = {}
	for _, player in ipairs(PlayersService:GetPlayers()) do
		playersInServer[player.UserId] = true
	end
	local function getter(userId: number): any
		local data2 = playerdata.getPlayerStatsByUserId(userId, "wrs_command")
		return { rank = data.wrRank, count = data2.userTotalWRCount }
	end
	local res = text.generateTextForRankedList(data.res, playersInServer, speaker.UserId, getter)
	for _, el in ipairs(res) do
		sm(channel, el.message, el.options)
	end

	GrandCmdlineBadge(speaker.UserId)
	return true
end

module.missingTop10s = function(speaker: Player, channel): boolean
	sm(channel, "NonTop10 races for: " .. speaker.Name)
	local data: tt.getNonTop10RacesByUser = playerdata.getNonTop10RacesByUserId(speaker.UserId, "nontop10_command")
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
	local totext = to and "to" or "from"
	sm(channel, "NonWR races " .. totext .. " " .. signName .. " for: " .. speaker.Name)
	local data: tt.getNonTop10RacesByUser =
		playerdata.getNonWRsByToSignIdAndUserId(to, signId, speaker.UserId, "nonwr_command")
	for _, runDesc in ipairs(data.raceDescriptions) do
		channel:SendSystemMessage(" * " .. runDesc, {
			Font = Enum.Font.Code,
		})
	end
	GrandCmdlineBadge(speaker.UserId)
	return true
end

module.badges = function(speaker: Player, channel): boolean
	local res = badges.getBadgeAttainment(speaker.UserId, "cmdline")
	sm(channel, "Badge status for: " .. speaker.Name)
	local gotStr = "Got badges:"
	local ungotStr = "Not got badges:"
	local gotct = 0
	local ungotct = 0
	for _, bd in ipairs(res) do
		if bd.got then
			gotct += 1
			gotStr = gotStr .. ", " .. bd.badge.name
		else
			ungotct += 1
			ungotStr = ungotStr .. ", " .. bd.badge.name
		end
	end

	sm(channel, gotStr)
	sm(channel, ungotStr)

	local total = "Got: " .. gotct .. " Not got: " .. ungotct
	sm(channel, total)

	local badgecount = badges.getBadgeCountByUser(speaker.UserId)
	for _, otherPlayer: Player in ipairs(PlayersService:GetPlayers()) do
		leaderboardBadgeEvents.updateBadgeLb(speaker.UserId, otherPlayer, badgecount)
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

module.warp = function(cmd, object, speaker): boolean
	local res = serverwarping.WarpToSignName(speaker, object)
	if not res then
		local num: number = tonumber(object) :: number
		res = serverwarping.WarpToSignId(speaker, num, false)
		if not res then
			res = serverwarping.WarpToUsername(speaker, object)
		end
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
	sm(channel, serverTime)
	GrandUndocumentedCommandBadge(speaker.UserId)
	return true
end

module.chomik = function(speaker: Player, channel: any): boolean
	local root = speaker.Character:FindFirstChild("HumanoidRootPart")
	local signs: Folder = game.Workspace:FindFirstChild("Signs")
	local chomik: Part = signs:FindFirstChild("Chomik")
	local dist = tpUtil.getDist(root.Position, chomik.Position)
	local message = string.format("The Chomik is %dd away", dist)
	sm(channel, message)
	GrandCmdlineBadge(speaker.UserId)
	return true
end

-- module.longest = function(speaker: Player, channel: any)
-- 	local data = remotedb.remoteGet("getCustomList", { kind = "longest" })
-- 	channel:SendSystemMessage("Today's longest runs:")
-- 	local ret = ""
-- 	for _, el in ipairs(data.res) do
-- 		channel:SendSystemMessage(el.message, el.options)
-- 		ret = ret .. el
-- 	end

-- 	channel:SendSystemMessage(ret)

-- 	GrandUndocumentedBadge(speaker.UserId)
-- 	return true
-- end

module.version = function(speaker: Player, channel: any): boolean
	local doNotCheckInGameIdentifier = require(game.ReplicatedStorage:FindFirstChild("doNotCheckInGameIdentifier"))
	local tt = ""
	if doNotCheckInGameIdentifier.useTestDb() then
		tt = " TEST VERSION, db will be wiped"
	end

	local message = string.format("Terrain Parkour - Version %s%s", enums.gameVersion, tt)
	sm(channel, message)
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
	sm(channel, message)
	GrandUndocumentedCommandBadge(speaker.UserId)
	return true
end

module.today = function(speaker: Player, channel): boolean
	local res = playerdata.getGameStats()
	sm(channel, res)
	GrandCmdlineBadge(speaker.UserId)
	return true
end

module.meta = function(speaker: Player, channel): boolean
	local res = "Principles of Terrain Parkour:\n\tNo Invisible Walls\n\tJust One More Race"
	sm(channel, res)
	GrandCmdlineBadge(speaker.UserId)
	return true
end

module.closest = function(speaker: Player, channel): boolean
	local root = speaker.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		warn("no humanoid in describe clsoest!")
		return false
	end
	local playerPos = root.Position
	local bestsign = nil
	local bestdist = nil
	for _, sign: Part in ipairs(workspace:WaitForChild("Signs"):GetChildren()) do
		local signId = tpUtil.looseSignName2SignId(sign.Name)
		if signId == nil then
			warn("bad.")
			continue
		end
		if not rdb.hasUserFoundSign(speaker.UserId, signId :: number) then
			continue
		end
		local dist = tpUtil.getDist(sign.Position, playerPos)
		if bestdist == nil or dist < bestdist then
			bestdist = dist
			bestsign = sign
		end
	end

	local message = ""
	if bestsign == nil then
		message = "You have not found any signs."
	else
		message = "The closest found sign to " .. speaker.Name .. " is " .. bestsign.Name .. "!"
	end

	sm(channel, message)
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
		local res = rdb.DoMissingRunLookup(params)
		local message = ""
		if res == nil then
			warn("miss res")
			message = "No result."
			sm(channel, message)
		else
			message = res[1].startSignName .. "-" .. res[1].endSignName
			sm(channel, message)
		end
		GrandCmdlineBadge(speaker.UserId)
	else
		warn("invalid params")
		warn(params)
		return false
	end
end

module.challenge = function(speaker: Player, channel, parts): boolean
	if parts[2] == nil or parts[2] == "" then
		Usage(channel)
		return true
	end
	local res = text.describeChallenge(parts)
	if res ~= "" then
		sm(channel, res)
		GrandCmdlineBadge(speaker.UserId)
		--successfully showed challenge
		return true
	else
		Usage(channel)
		return false
	end
end

module.random = function(speaker: Player, channel): boolean
	local rndSign = rdb.getRandomFoundSignName(speaker.UserId) or ""
	local res = "Random Sign You've found: " .. rndSign .. "."
	sm(channel, res)
	GrandCmdlineBadge(speaker.UserId)
	return true
end

module.popular = function(speaker: Player, channel): boolean
	--for testing, fake it like these people are also in the server.

	local userIdsInServer = { -2, enums.objects.TerrainParkour }
	userIdsInServer = {}
	for _, player in ipairs(PlayersService:GetPlayers()) do
		table.insert(userIdsInServer, player.UserId)
	end
	local popResults: { PopularResponseTypes.popularRaceResult } = popular.GetPopular(speaker, userIdsInServer)

	local messages: { string } = {}
	table.insert(messages, "Top Recent Runs:")
	for _, rr in ipairs(popResults) do
		local userPlaces = {}
		for _, el in ipairs(rr.userPlaces) do
			local userId = el.userId
			local userPlace = el.place
			local username = rdb.getUsernameByUserId(tonumber(userId))
			local usePlace: string = ""

			if userPlace == nil then --did not run at all.
				continue
			end
			if userPlace == 0 then
				usePlace = "DNP	"
			elseif userPlace > 10 then
				usePlace = "DNP"
			else
				usePlace = tpUtil.getCardinal(userPlace)
			end
			local msg = username .. ":" .. usePlace
			table.insert(userPlaces, msg)
		end
		local placeJoined = textUtil.stringJoin(", ", userPlaces)

		local msg = tostring(rr.ct) .. " " .. rr.startSignName .. "-" .. rr.endSignName .. " - " .. placeJoined
		table.insert(messages, msg)
	end
	local res = textUtil.stringJoin("\n", messages)
	sm(channel, res)
	GrandCmdlineBadge(speaker.UserId)
	return true
end

module.finders = function(speaker: Player, channel): boolean
	local data = playerdata.getFinderLeaders()

	sm(channel, "Top Finders:")
	local playersInServer = {}
	for _, player in ipairs(PlayersService:GetPlayers()) do
		playersInServer[player.UserId] = true
	end
	local function getter(userId: number): any
		local data: tt.afterData_getStatsByUser = playerdata.getPlayerStatsByUserId(userId, "finders_command")
		return { rank = data.findRank, count = data.userTotalFindCount }
	end
	local res = text.generateTextForRankedList(data.res, playersInServer, speaker.UserId, getter)
	for _, el in ipairs(res) do
		sm(channel, el.message, el.options)
	end

	GrandCmdlineBadge(speaker.UserId)
	return true
end

module.common = function(speaker: Player, channel): boolean
	--find the intersection of finds of the top finders in the server
	local signNames = playerdata.getCommonFoundSignNames()
	local res = "Signs everyone in server has found: "

	for _, signName in ipairs(signNames) do
		res = res .. signName .. ", "
	end
	sm(channel, res)
	GrandCmdlineBadge(speaker.UserId)
	return true
end

--lastrandom caching.
local lastRandomSign1
local lastRandomSign2
local lastRandomTicks
module.randomRace = function(speaker: Player, channel): boolean
	local runTimeInSecondsWithoutBump = 16.6666 --todo lengthen  this
	-- runTimeInSecondsWithoutBump=1
	if config.isInStudio() then
		runTimeInSecondsWithoutBump = 5
	end
	local rndSign1 = nil
	local rndSign2 = nil
	local myTick = tick()
	local reusingRace = false

	if lastRandomTicks ~= nil and myTick - lastRandomTicks < runTimeInSecondsWithoutBump then
		--reuse last time signs
		rndSign1 = lastRandomSign1
		rndSign2 = lastRandomSign2
		lastRandomTicks = myTick
		reusingRace = true
	else
		reusingRace = false
		local choices = playerdata.getCommonFoundSignIdsExcludingNoobs(speaker.UserId)
		if #choices < 1 then
			return false
		end
		local rndSignId1 = choices[math.random(#choices)]
		rndSign1 = tpUtil.signId2signName(rndSignId1)

		--rndsign2 is scoped to the initiator's found set.
		local tries = 0
		while true do
			rndSign2 = rdb.getRandomFoundSignName(speaker.UserId)
			if rndSign2 ~= rndSign1 then
				break
			end
			tries = tries + 1
			if tries > 10 then
				break
			end
		end
		lastRandomSign1 = rndSign1
		lastRandomSign2 = rndSign2
		lastRandomTicks = myTick
	end

	if rndSign1 ~= nil and rndSign2 ~= nil then
		local r1Name = enums.name2signId[rndSign1]
		local r2Name = enums.name2signId[rndSign2]
		local scoretext = playerdata.describeRaceHistoryMultilineText(r1Name, r2Name)
		if scoretext ~= "unknown" then
			if not reusingRace then
				sm(channel, scoretext)
			end
			local userJoinMes = speaker.Name
				.. " joined the random race from "
				.. rndSign1
				.. " to "
				.. rndSign2
				.. '. Use "/rr" to join!'
			sm(channel, userJoinMes)
			GrandCmdlineBadge(speaker.UserId)
			-- local originSignId = tpUtil.looseGetSignId(rndSign)
			-- local originSign = game.Workspace.Signs:FindFirstChild(rndSign)
			serverwarping.WarpToSignName(speaker, rndSign1)

			--this thing notifies the channel about 15 second countdown ending.
			if not reusingRace then
				spawn(function()
					local myS1 = rndSign1
					local myS2 = rndSign2
					while true do
						if myS1 ~= lastRandomSign1 or myS2 ~= lastRandomSign2 then
							return
						end
						if tick() - lastRandomTicks > runTimeInSecondsWithoutBump then
							sm(channel, "Next race ready to start.")
							break
						end
						wait(1)
					end
				end)
			end

			return true
		end
	end
end

return module
