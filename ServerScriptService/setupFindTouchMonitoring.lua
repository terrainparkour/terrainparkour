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

local module = {}

-- save the find in the db.
local userFoundSign = function(userId: number, signId: number): tt.dcFindResponse
	local request: tt.postRequest = {
		remoteActionName = "userFoundSign",
		data = { userId = userId, signId = signId },
	}
	local raw: tt.dcFindResponse = rdb.MakePostRequest(request)
	return raw
end

local function doNewFind(player: Player, signId: number, sign: Part)
	--update players with notes - you found X, other person found X

	task.spawn(function()
		local userId = player.UserId
		playerData2.ImmediatelySetUserFoundSignInCache(userId, signId)
		local dcFindResponse: tt.dcFindResponse = userFoundSign(userId, signId)

		local lbUserStats: tt.lbUserStats = playerData2.GetStatsByUserId(player.UserId, "doNewFind")

		notify.notifyPlayerOfSignFind(player, dcFindResponse)

		--update all players leaderboards.
		for _, otherPlayer in ipairs(PlayerService:GetPlayers()) do
			lbUpdaterServer.SendUpdateToPlayer(otherPlayer, lbUserStats)
		end
		task.spawn(function()
			badgeCheckers.CheckBadgeGrantingAfterFind(userId, signId, dcFindResponse)
		end)
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

	local player: Player = tpUtil.getPlayerForUsername(hit.Parent.Name)
	if not player then
		return false
	end

	local userId: number = player.UserId
	if userId == nil then
		return false
	end

	local signId: number = enums.name2signId[sign.Name]
	if signId == nil then
		return false
	end

	--exclude dead players from touching a sign.
	local hum: Humanoid = player.Character:WaitForChild("Humanoid") :: Humanoid
	local character = player.Character or player.CharacterAdded:Wait()
	if not character then
		return false
	end

	if not hum or hum.Health <= 0 then
		return false
	end

	local state = hum:GetState()
	if state == Enum.HumanoidStateType.Dead then
		return false
	end

	if banning.getBanLevel(player.UserId) > 0 then
		return false
	end

	--validation end, the find is real.
	local newFind = not playerData2.HasUserFoundSign(userId, signId)
	if newFind then
		doNewFind(player, signId, sign)
	end
end

module.Init = function()
	_annotate("init")
	for _, sign: Part in ipairs(game.Workspace:WaitForChild("Signs"):GetChildren()) do
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
