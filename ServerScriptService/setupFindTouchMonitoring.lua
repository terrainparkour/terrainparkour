--!strict
-- setup sign touch events on the server.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local PlayerService = game:GetService("Players")
local tt = require(game.ReplicatedStorage.types.gametypes)
local lbUpdaterServer = require(game.ServerScriptService.lbUpdaterServer)
local enums = require(game.ReplicatedStorage.util.enums)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local notify = require(game.ReplicatedStorage.notify)
local badgeCheckers = require(game.ServerScriptService.badgeCheckersSecret)
local banning = require(game.ServerScriptService.banning)
local rdb = require(game.ServerScriptService.rdb)
local playerData2 = require(game.ServerScriptService.playerData2)
local MessageDispatcher = require(game.ReplicatedStorage.ChatSystem.messageDispatcher)

local module = {}

-- save the find in the db.
local userFoundSign = function(userId: number, signId: number): tt.dcFindResponse?
	local player: Player? = PlayerService:GetPlayerByUserId(userId)
	_annotate(string.format("userFoundSign: calling API for userId=%d signId=%d", userId, signId))
	local request: tt.postRequest = {
		remoteActionName = "userFoundSign",
		data = { userId = userId, signId = signId },
	}
	local raw: any = rdb.MakePostRequest(request)

	-- check if response indicates ban
	if raw and raw.banned == true then
		_annotate(string.format("userFoundSign: user %d is banned", userId))
		if player then
			MessageDispatcher.SendSystemMessageToPlayer(
				player,
				"Chat",
				"You are banned. Please find another game to play."
			)
		end
		return nil
	end

	local dcFindResponse: tt.dcFindResponse = raw :: tt.dcFindResponse
	_annotate(
		string.format(
			"userFoundSign: API returned foundNew=%s signName=%s",
			tostring(dcFindResponse.foundNew),
			dcFindResponse.signName
		)
	)
	return dcFindResponse
end

local function doNewFind(player: Player, signId: number, sign: Part)
	--update players with notes - you found X, other person found X

	task.spawn(function()
		local userId = player.UserId
		_annotate(string.format("doNewFind: starting for userId=%d signId=%d signName=%s", userId, signId, sign.Name))
		playerData2.ImmediatelySetUserFoundSignInCache(userId, signId)
		_annotate(string.format("doNewFind: cached sign find, calling API"))
		local dcFindResponse: tt.dcFindResponse? = userFoundSign(userId, signId)

		if not dcFindResponse then
			_annotate(string.format("doNewFind: user is banned, aborting"))
			return
		end

		-- send notification immediately so UI popup isn't blocked by stats/badge data
		_annotate(
			string.format("doNewFind: sending notification to player foundNew=%s", tostring(dcFindResponse.foundNew))
		)
		notify.notifyPlayerOfSignFind(player, dcFindResponse)
		_annotate(string.format("doNewFind: notification sent"))

		-- fetch stats for leaderboard updates (this can happen async)
		_annotate(string.format("doNewFind: fetching stats for leaderboard updates"))
		local lbUserStats: tt.lbUserStats = playerData2.GetStatsByUserId(player.UserId, "doNewFind")
		_annotate(string.format("doNewFind: stats fetched, updating leaderboards"))

		--update all players leaderboards.
		for _, otherPlayer in ipairs(PlayerService:GetPlayers()) do
			lbUpdaterServer.SendUpdateToPlayer(otherPlayer, lbUserStats)
		end
		_annotate(string.format("doNewFind: leaderboards updated, spawning badge check"))
		task.spawn(function()
			badgeCheckers.CheckBadgeGrantingAfterFind(userId, signId, dcFindResponse)
		end)
		_annotate(string.format("doNewFind: complete"))
	end)
end

--store it in cache, send a remoteevent to persist it
-- so, we also actually do find monitoring on server.
-- and also tell the user through an event.
--when serverside notices a sign has been touched:
local function touchedSignServer(hit: BasePart, sign: Part)
	--as soon as server receives the hit, note down the hit.

	--lots of validation on the touch.
	if not hit:IsA("MeshPart") then
		return false
	end

	local hitParent: Instance? = hit.Parent
	if not hitParent then
		return false
	end

	local player: Player? = tpUtil.getPlayerForUsername(hitParent.Name)
	if not player then
		return false
	end
	local targetPlayer: Player = player :: Player

	local userId: number = targetPlayer.UserId

	local signId: number? = enums.name2signId[sign.Name]
	if signId == nil then
		return false
	end

	--exclude dead players from touching a sign.
	local character: Model? = targetPlayer.Character or targetPlayer.CharacterAdded:Wait()
	if not character then
		return false
	end
	local humInstance: Instance? = character:WaitForChild("Humanoid")
	if not humInstance or not humInstance:IsA("Humanoid") then
		return false
	end
	local hum: Humanoid = humInstance :: Humanoid

	if hum.Health <= 0 then
		return false
	end

	local state = hum:GetState()
	if state == Enum.HumanoidStateType.Dead then
		return false
	end

	if banning.getBanLevel(targetPlayer.UserId) > 0 then
		MessageDispatcher.SendSystemMessageToPlayer(
			targetPlayer,
			"Chat",
			"You are banned. Please find another game to play."
		)
		return false
	end

	--validation end, the find is real.
	local newFind = not playerData2.HasUserFoundSign(userId, signId)
	if newFind then
		_annotate(
			string.format(
				"touchedSignServer: userId=%d signId=%d signName=%s newFind=true, calling doNewFind",
				userId,
				signId,
				sign.Name
			)
		)
		doNewFind(targetPlayer, signId, sign)
	end
	return true
end

module.Init = function()
	_annotate("init")
	local signsFolder: Instance? = game.Workspace:WaitForChild("Signs")
	if not signsFolder or not signsFolder:IsA("Folder") then
		warn("setupFindTouchMonitoring.Init: Signs folder not found")
		return
	end
	for _, signInstance in ipairs(signsFolder:GetChildren()) do
		if not signInstance:IsA("Part") then
			continue
		end
		local sign: Part = signInstance :: Part
		local signId = enums.name2signId[sign.Name]
		if signId == nil then
			warn("Sign minssing from enum" .. tostring(sign.Name))
			continue
		end
		--this is necessary for tracking finds.
		sign.Touched:Connect(function(hit)
			touchedSignServer(hit, sign)
		end)
	end
	_annotate("init done")
end

_annotate("end")
return module
