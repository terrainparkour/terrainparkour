--!strict

--eval 9.25.22
--2022 log joins, quits, quitlocation, etc.

-- local notify = require(game.ReplicatedStorage.notify)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local locationMonitor = require(game.ReplicatedStorage.locationMonitor)

local timers = require(game.ServerScriptService.timers)
local rdb = require(game.ServerScriptService.rdb)
local remoteDbInternal = require(game.ServerScriptService.remoteDbInternal)

local module = {}

local PlayersService = game:GetService("Players")

module.PreloadFinds = function(player)
	--artificially send signId1 just to warm up cache.
	rdb.hasUserFoundSign(player.UserId, 1)
end

module.BackfillBadges = function(player: Player): nil
	local low = player.Name:lower()
	local grantBadge = require(game.ServerScriptService.grantBadge)
	local badgeEnums = require(game.ReplicatedStorage.util.badgeEnums)
	--first contest
	if player.Name == "Zenkoina" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.GoldContest) --time and place wins
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.SilverContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.BronzeContest) --for week win
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.FirstContestParticipation)
	end
	if player.Name:lower() == "princelypancake" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.SilverContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.BronzeContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.FirstContestParticipation)
	end
	if player.Name == "Feodoric" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.SilverContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.BronzeContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.FirstContestParticipation)
	end
	if player.Name:lower() == "hyperfantasies" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.FirstContestParticipation)
	end
	if player.Name:lower() == "silikon101" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.FirstContestParticipation)
	end
	if player.Name:lower() == "redekbo" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.FirstContestParticipation)
	end
	if player.Name == "MyTolc" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.FirstContestParticipation)
	end
	if player.Name == "platform144" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.FirstContestParticipation)
	end
	if player.Name == "theworldkeepspinning" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.FirstContestParticipation)
	end
	if player.Name == "CaringEnthusiast" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.FirstContestParticipation)
	end
	if player.Name:lower() == "rocknoids23135" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.FirstContestParticipation)
	end

	-----------SECOND CONTEST
	if player.Name == "QuantumGhoost" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.GoldContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.SecondContestParticipation)
	end
	if player.Name == "Hyperfantasies" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.SilverContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.SecondContestParticipation)
	end
	if player.Name == "Zenkoina" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.BronzeContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.SecondContestParticipation)
	end
	if player.Name == "SILIKON101" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.SecondContestParticipation)
	end
	if player.Name == "NHL_play" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.SecondContestParticipation)
	end
	if player.Name == "platform144" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.SecondContestParticipation)
	end
	if player.Name == "ppsuk099" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.SecondContestParticipation)
	end
	if player.Name == "princelypancake" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.SecondContestParticipation)
	end
	if player.Name == "TerrainParkour" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.SecondContestParticipation)
	end
	if player.Name == "SoundBoomer" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.SecondContestParticipation)
	end

	--------------THIRD CONTEST-------------------
	if low == "princelypancake" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.GoldContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if low == "hyperfantasies" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.SilverContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if low == "zenkoina" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.BronzeContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if low == "biosploosh" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if low == "cupcabinet" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if low == "nhl_play" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if low == "jakub2032" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if low == "terrainparkour" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if low == "quantumghoost" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end

	--------------fourth CONTEST-------------------
	if low == "zenkoina" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.GoldContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if low == "nhl_play" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.SilverContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if low == "silikon101" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.BronzeContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if low == "terrainparkour" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end

	--------------fifth CONTEST-------------------
	if low == "zenkoina" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.GoldContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if low == "platform144" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.SilverContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if low == "miyanington" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.BronzeContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if low == "vegetathesaiyan8" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if low == "quantumghoost" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if low == "terrainparkour" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end

	--------------sixth CONTEST-------------------
	if low == "hyperfantasies" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.GoldContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if low == "zenkoina" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.SilverContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if low == "miyanington" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.BronzeContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if
		low == "vegetathesaiyan8"
		or low == "vegetathesaiyan8"
		or low == "silikon101"
		or low == "platform144"
		or low == "blast645"
		or low == "terrainparkour"
	then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	--------------Seventh CONTEST-------------------
	if low == "zenkoina" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.GoldContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if low == "hyperfantasies" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.SilverContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if low == "princelypancake" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.BronzeContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if
		low == "blast645"
		or low == "westangerabbey"
		or low == "silikon101"
		or low == "platform144"
		or low == "blast645"
		or low == "terrainparkour"
	then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	--------------Eighth CONTEST-------------------
	if low == "hyperfantasies" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.GoldContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if low == "zenkoina" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.SilverContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if low == "princelypancake" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.BronzeContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if low == "nhl_play" or low == "biosploosh" or low == "blast645" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	--------------Ninth CONTEST-------------------
	if low == "zenkoina" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.GoldContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if low == "princelypancake" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.SilverContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if low == "blast645" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.BronzeContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	-- if low == "nhl_play" or low == "biosploosh" or low == "blast645" then
	-- 	grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	-- end
	--------------Tenth CONTEST (LONG)-------------------
	if low == "zenkoina" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.GoldContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if low == "hyperfantasies" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.SilverContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if low == "blast645" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.BronzeContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if
		low == "epicurious25"
		or low == "miyanington"
		or low == "nhl_play"
		or low == "bontinz"
		or low == "westangerabbey"
		or low == "luldafox"
		or low == "codycolt05"
		or low == "tohmrtohm"
	then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	--------------11th CONTEST -------------------
	if low == "zenkoina" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.GoldContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if low == "princelypancake" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.SilverContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if low == "nhl_play" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.BronzeContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if
		low == "blast645"
		or low == "terrainparkour"
		or low == "nhl_play"
		or low == "bontinz"
		or low == "princelypancake"
		or low == "zenkoina"
	then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
end

module.LogJoin = function(player: Player): nil
	local pc = #PlayersService:GetPlayers()
	local res
	if pc == 1 then
		res = remoteDbInternal.remoteGet("userJoinedFirst", { userId = player.UserId, username = player.Name })
	else
		res = remoteDbInternal.remoteGet("userJoined", { userId = player.UserId, username = player.Name })
	end
end

-- module.sentInitialNotifications = function(player)
-- 	local text = playerdata.getGameStats()
-- 	notify.notifyPlayer(player, { text = text, kind = "initial notifications" })
-- end

-- module.CancelRunOnDeath = function(player: Player)
-- 	player.CharacterAdded:Connect(function(character)
-- 		local hum: Humanoid = character:WaitForChild("Humanoid")
-- 		hum.Died:Connect(function()
-- 			timers.cancelRun(player, "charadd.died")
-- 		end)
-- 	end)

-- 	local character = player:FindFirstChild("Character")
-- 	if character == nil then
-- 		return
-- 	end
-- 	local hum2: Humanoid = character:WaitForChild("Humanoid")
-- 	if hum2 == nil then
-- 		return
-- 	end
-- 	-- hum2.Died:Connect(function()
-- 	timers.cancelRun(player, "died")
-- 	-- end)
-- end

local function remoteLogDeath(character, UserId)
	--we already know where they were here.
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root.Position then
		return
	end
	remoteDbInternal.remoteGet("userDied", {
		userId = UserId,
		x = tpUtil.noe(root.Position.X),
		y = tpUtil.noe(root.Position.Y),
		z = tpUtil.noe(root.Position.Z),
	})
end

module.LogLocationOnDeath = function(player: Player)
	--when a char is recreated, hook into its humanoid.
	player.CharacterAdded:Connect(function(character)
		local hum: Humanoid = character:WaitForChild("Humanoid")
		hum.Died:Connect(function()
			remoteLogDeath(character, player.UserId)
		end)
	end)
	local character = player:FindFirstChild("Character")
	if character == nil then
		return
	end
	local hum: Humanoid = character:WaitForChild("Humanoid")
	if hum == nil then
		return
	end
	hum.Died:Connect(function()
		remoteLogDeath(character, player.UserId)
	end)
end

module.LogQuit = function(player: Player)
	--player may already be gone, so we just use the last tracked loc.
	local loc = locationMonitor.getLocation(player.UserId)
	if loc == nil or loc.X == nil then --already gone so just leave.
		--this led to bugs when we just returned here since we no longer location track for some reason?
		--TODO: this is a hack, just default to this location as having left so we don't have infinitely long sessions.
		return
	end
	remoteDbInternal.remoteGet("userQuit", {
		userId = player.UserId,
		x = tpUtil.noe(loc.X),
		y = tpUtil.noe(loc.Y),
		z = tpUtil.noe(loc.Z),
	})
end

-- module.CancelRunOnPlayerRemove = function(player)
-- 	timers.cancelRun(player, "removed")
-- end

module.LogPlayerLeft = function(player)
	remoteDbInternal.remoteGet("userLeft", { userId = player.UserId })
end

return module
