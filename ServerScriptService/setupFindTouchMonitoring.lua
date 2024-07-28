--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local PlayerService = game:GetService("Players")
--setup sign touch events and also trigger telling user about them.
local tt = require(game.ReplicatedStorage.types.gametypes)
local lbupdater = require(game.ServerScriptService.lbupdater)
local enums = require(game.ReplicatedStorage.util.enums)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local notify = require(game.ReplicatedStorage.notify)
local signInfo = require(game.ReplicatedStorage.signInfo)
local badgeCheckers = require(game.ServerScriptService.badgeCheckersSecret)
local banning = require(game.ServerScriptService.banning)
local rdb = require(game.ServerScriptService.rdb)

local module = {}

local function doNewFind(player: Player, signId: number, sign: Part)
	--update players with notes - you found X, other person found X

	task.spawn(function()
		local userId = player.UserId
		rdb.ImmediatelySetUserFoundSignInCache(userId, signId)
		--handle finding a new sign and also accumulate a bunch of stats on the json response

		local res: tt.pyUserFoundSign = rdb.userFoundSign(userId, signId)
		badgeCheckers.checkBadgeGrantingAfterFind(userId, signId, res)
		--this is kind of weird.  regenerating another partial stat block?
		local options: tt.signFindOptions = {
			kind = "userFoundSign",
			userId = userId,
			lastFinderUserId = res.lastFinderUserId,
			lastFinderUsername = rdb.getUsernameByUserId(res.lastFinderUserId),
			signName = sign.Name,
			totalSignsInGame = signInfo.getSignCountInGameForUserConsumption(),
			userTotalFindCount = res.userTotalFindCount,
			signTotalFinds = res.signTotalFinds,
			findRank = res.findRank,
		}

		notify.notifyPlayerOfSignFind(player, options)

		--update all players leaderboards.
		for _, otherPlayer in ipairs(PlayerService:GetPlayers()) do
			lbupdater.updateLeaderboardForFind(otherPlayer, options)
		end
	end)
end

--store it in cache, send a remoteevent to persist it, and also tell the user through an event.
--when serverside notices a sign has been touched:
local function touchedSignServer(hit: BasePart, sign: Part)
	--as soon as server receives the hit, note down the hit.

	--lots of validation on the touch.
	if not hit:IsA("MeshPart") then
		return false
	end

	local player: Player = tpUtil.getPlayerForUsername(hit.Parent.Name)
	if not player then
		_annotate("there was a hit but not a player?")
		_annotate(hit, hit.Name, hit.Parent.Name)
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
	local character = player.Character or player.WaitForChild("Character")
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
	local newFind = not rdb.hasUserFoundSign(userId, signId)
	if newFind then
		doNewFind(player, signId, sign)
	end
end

module.init = function()
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
end

_annotate("end")
return module
