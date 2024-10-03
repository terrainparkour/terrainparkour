--!strict

--2022 log joins, quits, quitlocation, etc.
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

-- local notify = require(game.ReplicatedStorage.notify)
local tt = require(game.ReplicatedStorage.types.gametypes)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local locationMonitor = require(game.ReplicatedStorage.locationMonitor)

local rdb = require(game.ServerScriptService.rdb)

local badgeCheckersSecret = require(game.ServerScriptService.badgeCheckersSecret)

local module = {}

local PlayersService = game:GetService("Players")

module.BackfillBadges = function(player: Player): nil
	-- we do this so that the caches for all the badgeStatus and stuff are likely already gotten.
	local s, e = pcall(function()
		badgeCheckersSecret.BackfillBadges(player)
	end)

	if not s then
		if player then
			annotater.Error("Error backfilling badges for " .. player.UserId .. ": " .. e)
		else
			annotater.Error("Error backfilling badges for unknown player: " .. e)
		end
	end
end

module.LogJoin = function(player: Player): nil
	local pc = #PlayersService:GetPlayers()

	if pc == 1 then
		local request: tt.postRequest = {
			remoteActionName = "robloxUserJoinedFirst",
			data = { userId = player.UserId, username = player.Name },
		}
		rdb.MakePostRequest(request)
	else
		local request2: tt.postRequest = {
			remoteActionName = "robloxUserJoined",
			data = { userId = player.UserId, username = player.Name },
		}
		rdb.MakePostRequest(request2)
	end
end

local function remoteLogDeath(character, UserId)
	--we already know where they were here.
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root.Position then
		return
	end

	local request: tt.postRequest = {
		remoteActionName = "userDied",
		data = {
			userId = UserId,
			x = tpUtil.noe(root.Position.X),
			y = tpUtil.noe(root.Position.Y),
			z = tpUtil.noe(root.Position.Z),
		},
	}
	rdb.MakePostRequest(request)
end

module.LogLocationOnDeath = function(player: Player)
	--when a char is recreated, hook into its humanoid.
	player.CharacterAdded:Connect(function(character)
		local humanoid: Humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			remoteLogDeath(character, player.UserId)
		end)
		humanoid.Destroying:Connect(function()
			remoteLogDeath(character, player.UserId)
		end)
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

	local request: tt.postRequest = {
		remoteActionName = "userQuit",
		data = { userId = player.UserId, x = tpUtil.noe(loc.X), y = tpUtil.noe(loc.Y), z = tpUtil.noe(loc.Z) },
	}
	local response = rdb.MakePostRequest(request)
end

module.LogPlayerLeft = function(player)
	local request: tt.postRequest = {
		remoteActionName = "userLeft",
		data = { userId = player.UserId },
	}
	local response = rdb.MakePostRequest(request)
end

_annotate("end")
return module
