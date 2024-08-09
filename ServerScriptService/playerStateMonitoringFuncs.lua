--!strict

--2022 log joins, quits, quitlocation, etc.
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

-- local notify = require(game.ReplicatedStorage.notify)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local locationMonitor = require(game.ReplicatedStorage.locationMonitor)
local vscdebug = require(game.ReplicatedStorage.vscdebug)

local rdb = require(game.ServerScriptService.rdb)
local remoteDbInternal = require(game.ServerScriptService.remoteDbInternal)

local badgeCheckersSecret = require(game.ServerScriptService.badgeCheckersSecret)

local module = {}

local PlayersService = game:GetService("Players")

module.PreloadFinds = function(player)
	--artificially send signId1 just to warm up cache.
	rdb.hasUserFoundSign(player.UserId, 1)
end

module.BackfillBadges = function(player: Player): nil
	badgeCheckersSecret.BackfillBadges(player)
end

module.LogJoin = function(player: Player): nil
	local isMobile = true
	local pc = #PlayersService:GetPlayers()
	local UserInputService = game:GetService("UserInputService")
	isMobile = UserInputService.TouchEnabled
		and not UserInputService.KeyboardEnabled
		and not UserInputService.MouseEnabled
	--this won't work from server.
	if pc == 1 then
		remoteDbInternal.remoteGet(
			"robloxUserJoinedFirst",
			{ userId = player.UserId, username = player.Name, isMobile = isMobile }
		)
	else
		remoteDbInternal.remoteGet(
			"robloxUserJoined",
			{ userId = player.UserId, username = player.Name, isMobile = isMobile }
		)
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
	remoteDbInternal.remoteGet("userQuit", {
		userId = player.UserId,
		x = tpUtil.noe(loc.X),
		y = tpUtil.noe(loc.Y),
		z = tpUtil.noe(loc.Z),
	})
end

module.LogPlayerLeft = function(player)
	remoteDbInternal.remoteGet("userLeft", { userId = player.UserId })
end

_annotate("end")
return module
