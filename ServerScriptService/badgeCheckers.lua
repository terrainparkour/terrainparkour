--!strict

--checkers to grant specific badges.
--NOTE this should be excluded from checkin.
--eval 9.24.22

local enums = require(game.ReplicatedStorage.util.enums)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)

local PlayersService = game:GetService("Players")
local tt = require(game.ReplicatedStorage.types.gametypes)
local badgeEnums = require(game.ReplicatedStorage.util.badgeEnums)
local grantBadge = require(game.ServerScriptService.grantBadge)

local module = {}

module.CrowdedHouseChecker = function(joiner: Player)
	local players = PlayersService:GetPlayers()
	if #players > 8 then
		for _, player in ipairs(players) do
			grantBadge.GrantBadge(player.UserId, badgeEnums.badges.CrowdedHouse)
		end
	end
	if #players > 16 then
		for _, player in ipairs(players) do
			grantBadge.GrantBadge(player.UserId, badgeEnums.badges.MegaHouse)
		end
	end
end

local boottime = tick()

spawn(function()
	while true do
		local uptimeTicks = tick() - boottime
		local hours = math.floor(uptimeTicks / 3600)
		if hours >= 3 then
			for _, player in ipairs(PlayersService:GetPlayers()) do
				grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ThisOldHouse)
			end
		end
		if hours >= 12 then
			for _, player in ipairs(PlayersService:GetPlayers()) do
				grantBadge.GrantBadge(player.UserId, badgeEnums.badges.AncientHouse)
			end
		end
		wait(60)
	end
end)

module.BumpedCreatorChecker = function(joiner: Player)
	--wehn I join, spam something
	if joiner.UserId == enums.objects.TerrainParkour then
		spawn(function()
			while true do
				wait(2)
				local terrainParkour = PlayersService:GetPlayerByUserId(enums.objects.TerrainParkour)
				if terrainParkour == nil then
					break
				end

				local char = terrainParkour.Character
				if char == nil then
					continue
				end
				local hum: Humanoid = char:FindFirstChild("Humanoid")
				if hum == nil then
					continue
				end
				local rootPart: Part = char:FindFirstChild("HumanoidRootPart")
				if rootPart == nil then
					continue
				end
				local tpPos = rootPart.Position
				if tpPos == nil then
					continue
				end
				for _, player in ipairs(PlayersService:GetPlayers()) do
					if player.UserId == joiner.UserId then
						continue
					end
					if player == nil then
						continue
					end
					if player.Character == nil then
						continue
					end
					local hum2: Humanoid = player.Character:FindFirstChild("Humanoid")
					if hum2 == nil then
						continue
					end
					local rp2: Part = player.Character:FindFirstChild("HumanoidRootPart")
					if rp2 == nil then
						continue
					end
					local playerPos = rp2.Position

					local dist: number = tpUtil.getDist(tpPos, playerPos)
					if dist < 40 then
						grantBadge.GrantBadge(player.UserId, badgeEnums.badges.BumpedCreator)
					end
				end
			end
		end)
	end
end

module.MetCreatorChecker = function(joiner: Player)
	wait(4)
	if joiner.UserId == enums.objects.TerrainParkour then
		for _, player in ipairs(PlayersService:GetPlayers()) do
			grantBadge.GrantBadge(player.UserId, badgeEnums.badges.MetCreator)
		end
	else
		--if someone joins while I is in game, grant it.
		for _, player in ipairs(PlayersService:GetPlayers()) do
			if player.UserId == enums.objects.TerrainParkour then
				grantBadge.GrantBadge(joiner.UserId, badgeEnums.badges.MetCreator)
			end
		end
	end
end

local function checkUserTotalFindCount(userId: number, res: tt.pyUserFoundSign)
	local userFindCount = res.userTotalFindCount
	if userFindCount >= 3 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.FoundThree)
		if userFindCount >= 9 then
			grantBadge.GrantBadge(userId, badgeEnums.badges.FoundNine)
			if userFindCount >= 18 then
				grantBadge.GrantBadge(userId, badgeEnums.badges.FoundEighteen)
				if userFindCount >= 27 then
					grantBadge.GrantBadge(userId, badgeEnums.badges.FoundTwentySeven)
					if userFindCount >= 36 then
						grantBadge.GrantBadge(userId, badgeEnums.badges.FoundThirtySix)
						if userFindCount >= 50 then
							grantBadge.GrantBadge(userId, badgeEnums.badges.FoundFifty)
							if userFindCount >= 70 then
								grantBadge.GrantBadge(userId, badgeEnums.badges.FoundSeventy)
								if userFindCount >= 99 then
									grantBadge.GrantBadge(userId, badgeEnums.badges.FoundNinetyNine)
									if userFindCount >= 120 then
										grantBadge.GrantBadge(userId, badgeEnums.badges.FoundHundredTwenty)
										if userFindCount >= 140 then
											grantBadge.GrantBadge(userId, badgeEnums.badges.FoundHundredForty)
											if userFindCount >= 200 then
												grantBadge.GrantBadge(userId, badgeEnums.badges.FoundTwoHundred)
												if userFindCount >= 300 then
													grantBadge.GrantBadge(userId, badgeEnums.badges.FoundThreeHundred)
													if userFindCount >= 400 then
														grantBadge.GrantBadge(
															userId,
															badgeEnums.badges.FoundFourHundred
														)
														if userFindCount >= 450 then
															grantBadge.GrantBadge(
																userId,
																badgeEnums.badges.FoundFourHundredFifty
															)
															if userFindCount >= 500 then
																grantBadge.GrantBadge(
																	userId,
																	badgeEnums.badges.FoundFiveHundred
																)
																if userFindCount >= 550 then
																	grantBadge.GrantBadge(
																		userId,
																		badgeEnums.badges.FoundFiveHundredFifty
																	)
																end
															end
														end
													end
												end
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end

	if res.signTotalFinds == 1 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.FirstFinderOfSign)
	end
	if res.signTotalFinds == 5 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.FifthFinderOfSign)
	end
	if res.signTotalFinds == 100 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.HundredthFinderOfSign)
	end
end

local function checkUserTotalTop10Count(userId: number, userTop10Count: number)
	if userTop10Count >= 10 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.TenTop10s)
		if userTop10Count >= 100 then
			grantBadge.GrantBadge(userId, badgeEnums.badges.HundredTop10s)
			if userTop10Count >= 1000 then
				grantBadge.GrantBadge(userId, badgeEnums.badges.ThousandTop10s)
			end
		end
	end
end

local function checkUserCompetitiveWrCount(userId: number, userCompetitiveWRCount: number)
	if userCompetitiveWRCount >= 1 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.LeadCompetitiveRace)
		if userCompetitiveWRCount >= 10 then
			grantBadge.GrantBadge(userId, badgeEnums.badges.Lead10CompetitiveRace)
			if userCompetitiveWRCount >= 50 then
				grantBadge.GrantBadge(userId, badgeEnums.badges.Lead50CompetitiveRace)
				if userCompetitiveWRCount >= 250 then
					grantBadge.GrantBadge(userId, badgeEnums.badges.Lead250CompetitiveRace)
					if userCompetitiveWRCount >= 1000 then
						grantBadge.GrantBadge(userId, badgeEnums.badges.Lead1000CompetitiveRace)
					end
				end
			end
		end
	end
end

local function checkUserTotalWRCount(userId: number, userWRCount: number)
	if userWRCount >= 5 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.FiveWrs)
		if userWRCount >= 25 then
			grantBadge.GrantBadge(userId, badgeEnums.badges.TwentyFiveWrs)
			if userWRCount >= 50 then
				grantBadge.GrantBadge(userId, badgeEnums.badges.FiftyWrs)
				if userWRCount >= 99 then
					grantBadge.GrantBadge(userId, badgeEnums.badges.NinetyNineWrs)
					if userWRCount >= 250 then
						grantBadge.GrantBadge(userId, badgeEnums.badges.TwoHundredFiftyWrs)
						if userWRCount >= 500 then
							grantBadge.GrantBadge(userId, badgeEnums.badges.FiveHundredWrs)
							if userWRCount >= 1000 then
								grantBadge.GrantBadge(userId, badgeEnums.badges.ThousandWrs)
								if userWRCount >= 2000 then
									grantBadge.GrantBadge(userId, badgeEnums.badges.TwokWrs)
									if userWRCount >= 4000 then
										grantBadge.GrantBadge(userId, badgeEnums.badges.FourkWrs)
										if userWRCount >= 8000 then
											grantBadge.GrantBadge(userId, badgeEnums.badges.EightkWrs)
											if userWRCount >= 16000 then
												grantBadge.GrantBadge(userId, badgeEnums.badges.SixteenkWrs)
												if userWRCount >= 32000 then
													grantBadge.GrantBadge(userId, badgeEnums.badges.ThirtyTwokWrs)
												end
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
end

local function checkUserTotalRaceCount(userId: number, userTotalRaceCount: number)
	if userTotalRaceCount >= 3 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.TotalRaceCount1)
		if userTotalRaceCount >= 13 then
			grantBadge.GrantBadge(userId, badgeEnums.badges.TotalRaceCount2)
			if userTotalRaceCount >= 31 then
				grantBadge.GrantBadge(userId, badgeEnums.badges.TotalRaceCount3)
				if userTotalRaceCount >= 113 then
					grantBadge.GrantBadge(userId, badgeEnums.badges.TotalRaceCount4)
					if userTotalRaceCount >= 311 then
						grantBadge.GrantBadge(userId, badgeEnums.badges.TotalRaceCount5)
						if userTotalRaceCount >= 1331 then
							grantBadge.GrantBadge(userId, badgeEnums.badges.TotalRaceCount6)
							if userTotalRaceCount >= 3113 then
								grantBadge.GrantBadge(userId, badgeEnums.badges.TotalRaceCount7)
								if userTotalRaceCount >= 13131 then
									grantBadge.GrantBadge(userId, badgeEnums.badges.TotalRaceCount8)
									if userTotalRaceCount >= 33333 then
										grantBadge.GrantBadge(userId, badgeEnums.badges.TotalRaceCount9)
										if userTotalRaceCount >= 131313 then
											grantBadge.GrantBadge(userId, badgeEnums.badges.TotalRaceCount10)
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
end

local function checkUserTotalRunCount(userId: number, userTotalRunCount: number)
	if userTotalRunCount >= 2 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.TotalRunCount1)
		if userTotalRunCount >= 6 then
			grantBadge.GrantBadge(userId, badgeEnums.badges.TotalRunCount2)
			if userTotalRunCount >= 26 then
				grantBadge.GrantBadge(userId, badgeEnums.badges.TotalRunCount3)
				if userTotalRunCount >= 62 then
					grantBadge.GrantBadge(userId, badgeEnums.badges.TotalRunCount4)
					if userTotalRunCount >= 226 then
						grantBadge.GrantBadge(userId, badgeEnums.badges.TotalRunCount5)
						if userTotalRunCount >= 622 then
							grantBadge.GrantBadge(userId, badgeEnums.badges.TotalRunCount6)
							if userTotalRunCount >= 2226 then
								grantBadge.GrantBadge(userId, badgeEnums.badges.TotalRunCount7)
								if userTotalRunCount >= 6222 then
									grantBadge.GrantBadge(userId, badgeEnums.badges.TotalRunCount8)
									if userTotalRunCount >= 22666 then
										grantBadge.GrantBadge(userId, badgeEnums.badges.TotalRunCount9)
										if userTotalRunCount >= 62222 then
											grantBadge.GrantBadge(userId, badgeEnums.badges.TotalRunCount10)
											if userTotalRunCount >= 222666 then
												grantBadge.GrantBadge(userId, badgeEnums.badges.TotalRunCount11)
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
end

local function checkUserTixSum(userId: number, tixSum: number)
	if tixSum >= 300 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.ThreeHundredTix)
		if tixSum >= 1000 then
			grantBadge.GrantBadge(userId, badgeEnums.badges.ThousandTix)
			if tixSum >= 3000 then
				grantBadge.GrantBadge(userId, badgeEnums.badges.ThreeThousandTix)
				if tixSum >= 7000 then
					grantBadge.GrantBadge(userId, badgeEnums.badges.SevenThousandTix)
					if tixSum >= 14000 then
						grantBadge.GrantBadge(userId, badgeEnums.badges.Tix14k)
						if tixSum >= 25000 then
							grantBadge.GrantBadge(userId, badgeEnums.badges.Tix25k)
							if tixSum >= 49000 then
								grantBadge.GrantBadge(userId, badgeEnums.badges.Tix49k)
							end
						end
					end
				end
			end
		end
	end
end

local function checkClosenessOfRunCount(userId: number, num: number, tie: boolean)
	-- print("closeness: " .. tostring(num))
	if num == 1 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.WinBy001)
	end
	if num == -1 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.LoseBy001)
	end
	if tie == true then
		grantBadge.GrantBadge(userId, badgeEnums.badges.TieForFirst)
	end
end

--numerological stuff about run milliseconds
local function checkNumerologicalRun(userId: number, runMilliseconds: number)
	local perm = runMilliseconds % 1000
	if perm == 0 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.RoundRun)
	end
	if perm == 333 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.Run333)
	end
	if perm == 555 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.Run555)
	end
	if perm == 777 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.Run777)
	end
	if perm == 999 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.Run999)
	end
	if runMilliseconds == 1234 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.CountVonCount)
	end
end

local function checkKnockdowns(userId, afterRunData: tt.pyUserFinishedRunResponse)
	--figure out who you knocked down.
	local seenMe = false
	for _, runEntry in ipairs(afterRunData.runEntries) do
		if runEntry.place == 0 then
			continue
		end
		if runEntry.userId == userId then
			seenMe = true --seenme, skip forward
			continue
		end
		if not seenMe then
			continue
		end
		--we will continue here evaluating later people.
		if runEntry.userId == enums.objects.TerrainParkour then
			print(runEntry)
			if runEntry.place == 2 then --knocked creator down to 2
				grantBadge.GrantBadge(userId, badgeEnums.badges.DethroneCreator)
				-- elseif runEntry.place == 11 then
				-- 	grantBadge.GrantBadge(userId, badgeEnums.badges.KnockedOutCreator)
			else --knocked creator down
				grantBadge.GrantBadge(userId, badgeEnums.badges.PushDownCreator)
			end
		else --someone else is only knocked out if their rank is 11, and
			-- if runEntry.place == 11 then
			-- 	grantBadge.GrantBadge(userId, badgeEnums.badges.KnockedSomeoneOut)
			-- end
		end
	end
end

--bucket for most things.
local function checkRunDistanceAndTimeStuff(
	userId: number,
	afterRunData: tt.pyUserFinishedRunResponse,
	startSignId: number,
	endSignId: number
): nil
	local badgeTick = tick()
	local startSign: Part = game.Workspace:FindFirstChild("Signs"):FindFirstChild(enums.signId2name[startSignId])
	local endSign: Part = game.Workspace:FindFirstChild("Signs"):FindFirstChild(enums.signId2name[endSignId])
	local dist = tpUtil.getDist(startSign.Position, endSign.Position)
	local fall = startSign.Position.Y - endSign.Position.Y
	dist = math.floor(dist)

	--was the nth unique runner to run a race
	--question - is this first line necessary?   if not, it would mean any "10 person has run" race would be suitable.
	if afterRunData.userRaceRunCount == 1 then
		if afterRunData.totalRacersOfThisRaceCount == 10 then
			grantBadge.GrantBadge(userId, badgeEnums.badges.RaceRunner10)
		end
		if afterRunData.totalRacersOfThisRaceCount == 40 then
			grantBadge.GrantBadge(userId, badgeEnums.badges.RaceRunner40)
		end
		if afterRunData.totalRacersOfThisRaceCount == 100 then
			grantBadge.GrantBadge(userId, badgeEnums.badges.RaceRunner100)
		end
		if afterRunData.totalRacersOfThisRaceCount == 200 then
			grantBadge.GrantBadge(userId, badgeEnums.badges.RaceRunner200)
		end
		if afterRunData.totalRacersOfThisRaceCount == 500 then
			grantBadge.GrantBadge(userId, badgeEnums.badges.RaceRunner500)
		end
		if afterRunData.totalRacersOfThisRaceCount == 1000 then
			grantBadge.GrantBadge(userId, badgeEnums.badges.RaceRunner1000)
		end
		if afterRunData.totalRacersOfThisRaceCount == 2000 then
			grantBadge.GrantBadge(userId, badgeEnums.badges.RaceRunner2000)
		end
	end

	--did the nth run of a race, repeats allowed.
	if afterRunData.totalRunsOfThisRaceCount == 10 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.RaceRuns10)
	end
	if afterRunData.totalRunsOfThisRaceCount == 40 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.RaceRuns40)
	end
	if afterRunData.totalRunsOfThisRaceCount == 100 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.RaceRuns100)
	end
	if afterRunData.totalRunsOfThisRaceCount == 200 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.RaceRuns200)
	end
	if afterRunData.totalRunsOfThisRaceCount == 500 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.RaceRuns500)
	end
	if afterRunData.totalRunsOfThisRaceCount == 1000 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.RaceRuns1000)
	end
	if afterRunData.totalRunsOfThisRaceCount == 2000 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.RaceRuns2000)
	end

	local hour = tonumber(os.date("%H", badgeTick))
	local minute = tonumber(os.date("%M", badgeTick))
	local date = tonumber(os.date("%d", badgeTick))
	local month = tonumber(os.date("%m", badgeTick))
	local year = tonumber(os.date("%Y", badgeTick))

	-- print(year, month, date, hour, minute)

	if math.floor(afterRunData.thisRunMilliseconds / 1000) == year then
		grantBadge.GrantBadge(userId, badgeEnums.badges.YearRun)
	end

	if minute == 1 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.Minute)
	end

	if minute == 59 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.FiftyNine)
	end

	if hour == minute then
		grantBadge.GrantBadge(userId, badgeEnums.badges.SpecialTime)
	end

	if hour == 0 and (endSign.Name == "Midnight" or startSign.Name == "Midnight") then
		grantBadge.GrantBadge(userId, badgeEnums.badges.Midnight)
	end

	if date == hour and date == minute then
		grantBadge.GrantBadge(userId, badgeEnums.badges.TripleContemporaneous)
	end

	if date == month then
		grantBadge.GrantBadge(userId, badgeEnums.badges.LunaFecha)
	end

	local playerdata = require(game.ServerScriptService.playerdata)
	local finderLeaders = playerdata.getFinderLeaders()

	-- print("usertotal file count " .. afterRunData.userTotalFindCount .. "-=" .. enums.signCount)
	if afterRunData.userTotalFindCount == enums.signCount then
		grantBadge.GrantBadge(userId, badgeEnums.badges.MaxFind)
	end
	--get ultimate lead
	if finderLeaders["res"][1].userId == userId then
		grantBadge.GrantBadge(userId, badgeEnums.badges.FindLeader)
	end

	if afterRunData.userTotalFindCount >= math.floor(enums.signCount / 2) then
		grantBadge.GrantBadge(userId, badgeEnums.badges.HalfFind)
	end

	if afterRunData.userTotalFindCount >= enums.signCount - 1 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.UnoFind)
	end

	if (startSign.Name == "凹" and endSign.Name == "凸") or (startSign.Name == "凸" and endSign.Name == "凹") then
		grantBadge.GrantBadge(userId, badgeEnums.badges.Hieroglyph)
	end
	if startSign.Name == "Loch" and endSign.Name == "Ararat" then --hi yt
		grantBadge.GrantBadge(userId, badgeEnums.badges.ScottishNoah)
	end
	if startSign.Name == "Landscape" and endSign.Name == "Acrobatics" then
		grantBadge.GrantBadge(userId, badgeEnums.badges.LandscapeAcrobatics)
	end
	if
		startSign.Name == "Frog King" and endSign.Name == "Sandking"
		or startSign.Name == "Sandking" and endSign.Name == "Frog King"
	then
		grantBadge.GrantBadge(userId, badgeEnums.badges.Royalty)
	end

	if startSign.Name == "Roblox" and endSign.Name == "Studio" then
		grantBadge.GrantBadge(userId, badgeEnums.badges.RobloxStudio)
	end
	if startSign.Name == "Terrain" and endSign.Name == "Parkour" then
		grantBadge.GrantBadge(userId, badgeEnums.badges.TrainParkour)
	end
	if startSign.Name == "Napoleon" and endSign.Name == "Josephine" then
		grantBadge.GrantBadge(userId, badgeEnums.badges.FirstEmpire)
	end
	if (startSign.Name == "💀" or startSign.Name == "人") and (endSign.Name == "💀" or endSign.Name == "人") then
		grantBadge.GrantBadge(userId, badgeEnums.badges.Unicode)
	end
	local unicodeSigns: { [string]: number } = {
		["💀"] = 2,
		["人"] = 3,
		["დიუნი"] = 5,
		["الكثيب"] = 6,
		["෴☃❽"] = 7,
		["凸"] = 429,
		["凹"] = 430,
		["👍"] = 437,
		["🔥"] = 438,
	}
	if unicodeSigns[startSign.Name] ~= nil and unicodeSigns[endSign.Name] ~= nil then
		grantBadge.GrantBadge(userId, badgeEnums.badges.Orthography)
	end

	if (startSign.Name == "💀" or startSign.Name == "人") and (endSign.Name == "💀" or endSign.Name == "人") then
		grantBadge.GrantBadge(userId, badgeEnums.badges.Unicode)
	end

	if startSign.Name == "Terrain" and endSign.Name == "Obby" then
		grantBadge.GrantBadge(userId, badgeEnums.badges.TerrainObby)
	end
	if dist == math.floor(afterRunData.thisRunMilliseconds / 1000) then
		grantBadge.GrantBadge(userId, badgeEnums.badges.TimeAndSpace)
	end
	if dist > 1000 and dist == math.floor(afterRunData.thisRunMilliseconds / 1000) then
		grantBadge.GrantBadge(userId, badgeEnums.badges.TimeAndSpaceLargeScale)
	end
	if dist > 1000 then
		if afterRunData.userRaceRunCount > 1 then
			grantBadge.GrantBadge(userId, badgeEnums.badges.RepeatRun)
		end
		if afterRunData.userRaceRunCount >= 8 then
			grantBadge.GrantBadge(userId, badgeEnums.badges.SpecializeRun)
		end
		if afterRunData.userRaceRunCount >= 25 then
			grantBadge.GrantBadge(userId, badgeEnums.badges.GrindRun)
		end
		if afterRunData.userRaceRunCount >= 50 then
			grantBadge.GrantBadge(userId, badgeEnums.badges.FocusRun)
		end
		if afterRunData.userRaceRunCount >= 100 then
			grantBadge.GrantBadge(userId, badgeEnums.badges.GuruRun)
		end
	end
	if afterRunData.userRaceRunCount >= 50 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.CrazyRun)
	end
	if afterRunData.userRaceRunCount >= 3 and dist > 5000 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.Triathlon)
	end
	if afterRunData.userRaceRunCount >= 10 and dist > 5000 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.IronMan)
	end

	if fall > 2100 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.LongFall)
	end
	if fall < -2100 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.LongClimb)
	end
	if dist > 6000 and dist <= 8000 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.LongRun)
	end
	if dist > 8000 and dist <= 10000 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.VeryLongRun)
	end
	if dist > 10000 and dist <= 12000 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.HyperLongRun)
	end

	if dist > 12000 and dist <= 14000 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.MegaLongRun)
	end

	if dist > 14000 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.ExtremeLongRun)
	end

	if dist == 1337 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.EliteRun)
		if afterRunData.thisRunPlace == 1 then
			grantBadge.GrantBadge(userId, badgeEnums.badges.WinEliteRun)
		end
	end

	if dist == 1984 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.WinstonSmith)
	end

	if dist == 1337 * 2 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.DoubleEliteRun)
	end

	if dist == 2001 or dist == 2010 then --clarke then
		grantBadge.GrantBadge(userId, badgeEnums.badges.SciFiRun)
	end

	if #afterRunData.runEntries >= 10 then
		if dist > 6000 then
			grantBadge.GrantBadge(userId, badgeEnums.badges.CompetititiveLongRun)
			if afterRunData.thisRunPlace == 1 then
				grantBadge.GrantBadge(userId, badgeEnums.badges.WinCompetititiveLongRun)
			end
		end
		if afterRunData.thisRunPlace == 1 then
			grantBadge.GrantBadge(userId, badgeEnums.badges.WinCompetititiveRun)
		end
	end
	if afterRunData.thisRunMilliseconds > 1001000 then
		grantBadge.GrantBadge(userId, badgeEnums.badges.SuperSlowRun)
	end
end

local function checkSignBadge(userId: number, signId: number)
	local signName = tpUtil.signId2signName(signId)
	if signName == "POGGOD" then
		grantBadge.GrantBadge(userId, badgeEnums.badges.Poggod)
	end
	if signName == "Chomik" then
		grantBadge.GrantBadge(userId, badgeEnums.badges.Chomik)
	end
	if signName == "Hurdle" then
		grantBadge.GrantBadge(userId, badgeEnums.badges.Hurdle)
	end
end

module.checkBadgeGrantingFromSignWrLeaderData = function(signWRLeaderData: { tt.signWrStatus }, userId: number)
	--if you are leader with more than 5 wrs
	if signWRLeaderData ~= nil and #signWRLeaderData > 0 then
		if signWRLeaderData[1].userId == userId and signWRLeaderData[1].count > 5 then
			grantBadge.GrantBadge(userId, badgeEnums.badges.LeadSign)
		end
	end

	local totalruns = 0
	for _, wd in ipairs(signWRLeaderData) do
		totalruns += wd.count
		if wd.userId == userId then
			if wd.count >= 5 then
				grantBadge.GrantBadge(userId, badgeEnums.badges.SignWrs5)
			end

			if wd.count >= 10 then
				grantBadge.GrantBadge(userId, badgeEnums.badges.SignWrs10)
			end

			if wd.count >= 20 then
				grantBadge.GrantBadge(userId, badgeEnums.badges.SignWrs20)
			end

			if wd.count >= 50 then
				grantBadge.GrantBadge(userId, badgeEnums.badges.SignWrs50)
			end

			if wd.count >= 100 then
				grantBadge.GrantBadge(userId, badgeEnums.badges.SignWrs100)
			end

			if wd.count >= 200 then
				grantBadge.GrantBadge(userId, badgeEnums.badges.SignWrs200)
			end

			if wd.count >= 300 then
				grantBadge.GrantBadge(userId, badgeEnums.badges.SignWrs300)
			end

			if wd.count >= 500 then
				grantBadge.GrantBadge(userId, badgeEnums.badges.SignWrs500)
			end

			if wd.count >= 611 then
				grantBadge.GrantBadge(userId, badgeEnums.badges.SignWrsFeo)
			end

			if wd.count >= 800 then
				grantBadge.GrantBadge(userId, badgeEnums.badges.SignWrs800)
			end
		end
	end

	--leader with more than 10 wrs.
	if #signWRLeaderData > 1 and signWRLeaderData[1] ~= nil then
		if signWRLeaderData[1].userId == userId then
			if signWRLeaderData[1].count >= 10 then
				if totalruns >= 40 then
					grantBadge.GrantBadge(userId, badgeEnums.badges.LeadCompetitiveSign)
				end
			end
		end
	end
end

module.checkBadgeGrantingAfterRun =
	function(userId: number, afterRunData: tt.pyUserFinishedRunResponse, startSignId: number, endSignId: number): nil
		if
			afterRunData.userTotalRunCount == nil
			or afterRunData.userTotalRaceCount == nil
			or afterRunData.userTotalTop10Count == nil
			or afterRunData.userCompetitiveWRCount == nil
			or afterRunData.userTotalWRCount == nil
		then
			print("ERROR----data after run.")
		end
		spawn(function()
			-- checkSignBadge(userId, afterRunData)
			checkUserTotalRunCount(userId, afterRunData.userTotalRunCount)
			checkUserTotalRaceCount(userId, afterRunData.userTotalRaceCount)
			checkUserTotalTop10Count(userId, afterRunData.userTotalTop10Count)
			checkUserTotalWRCount(userId, afterRunData.userTotalWRCount)
			checkUserCompetitiveWrCount(userId, afterRunData.userCompetitiveWRCount)
			checkUserTixSum(userId, afterRunData.userTix)
			checkClosenessOfRunCount(userId, afterRunData.winGap, afterRunData.tied)
			checkNumerologicalRun(userId, afterRunData.thisRunMilliseconds)
			checkRunDistanceAndTimeStuff(userId, afterRunData, startSignId, endSignId)
			checkKnockdowns(userId, afterRunData)
		end)
	end

--insist on receiving the data you need
module.checkBadgeGrantingAfterFind = function(userId: number, signId: number, res: tt.pyUserFoundSign): nil
	checkSignBadge(userId, signId)
	checkUserTotalFindCount(userId, res)
end

return module
