--!strict

--eval 9.25.22
--2022 log joins, quits, quitlocation, etc.

-- local notify = require(game.ReplicatedStorage.notify)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local locationMonitor = require(game.ReplicatedStorage.locationMonitor)
local vscdebug = require(game.ReplicatedStorage.vscdebug)

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
	if player.Name == "Feodoric" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.SilverContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.BronzeContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.FirstContestParticipation)
	end

	if player.Name:lower() == "redekbo" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.FirstContestParticipation)
	end
	if player.Name == "MyTolc" then
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

	if player.Name == "ppsuk099" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.SecondContestParticipation)
	end

	if player.Name == "SoundBoomer" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.SecondContestParticipation)
	end

	--------------THIRD CONTEST-------------------

	if low == "biosploosh" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if low == "cupcabinet" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end

	if low == "jakub2032" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end

	if low == "quantumghoost" then
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

	if low == "miyanington" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.BronzeContest)
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	if low == "vegetathesaiyan8" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end

	--------------Tenth CONTEST (LONG)-------------------

	if low == "epicurious25" or low == "luldafox" or low == "codycolt05" or low == "tohmrtohm" then
		grantBadge.GrantBadge(player.UserId, badgeEnums.badges.ContestParticipation)
	end
	--------------11th CONTEST -------------------
end

module.LogJoin = function(player: Player): nil
	local pc = #PlayersService:GetPlayers()
	if pc == 1 then
		remoteDbInternal.remoteGet("userJoinedFirst", { userId = player.UserId, username = player.Name })
	else
		remoteDbInternal.remoteGet("userJoined", { userId = player.UserId, username = player.Name })
	end
end

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
			print("logged die")
			remoteLogDeath(character, player.UserId)
		end)
		hum.Destroying:Connect(function()
			print("logged destruction")
			remoteLogDeath(character, player.UserId)
		end)
	end)
end

module.LogQuit = function(player: Player)
	--player may already be gone, so we just use the last tracked loc.
	vscdebug.debug()
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
	print("userLeft" .. player.Name)
	vscdebug.debug()
	remoteDbInternal.remoteGet("userLeft", { userId = player.UserId })
end

return module
