--!strict
--eval 9.24.22

--9.24.22 is this even used? no.

--monitors locations of players continuously

local module = {}
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local enums = require(game.ReplicatedStorage.util.enums)
local rdb = require(game.ServerScriptService.rdb)
local serverwarping = require(game.ServerScriptService.serverwarping)

local playerLocations: { Vector3 } = {}

module.init = function()
	--this is disabled now.
	spawn(function()
		while true do
			wait(1)
			for _, player in ipairs(game.Players:GetPlayers()) do
				if not player.Character then
					continue
				else
					local root: Part = player.Character:FindFirstChild("HumanoidRootPart")
					if root then
						playerLocations[player.UserId] = Vector3.new(
							tpUtil.noe(root.Position.X),
							tpUtil.noe(root.Position.Y),
							tpUtil.noe(root.Position.Z)
						)
					end
				end
			end
		end
	end)
end

module.getLocation = function(userId: number): Vector3
	return playerLocations[userId]
end

--for hacking sign found status.
local forceSpawnJumpingToUnfound = false
if forceSpawnJumpingToUnfound then
	spawn(function()
		local PlayersService = game:GetService("Players")
		wait(3)
		local players = PlayersService:GetPlayers()
		local lp = nil
		for _, player in pairs(players) do
			lp = player
			break
		end
		local ii = 1
		local unfound = rdb.getUserSignFinds(enums.objects.TerrainParkour)
		local foundMap = {}
		for signId, _ in pairs(unfound) do
			foundMap[signId] = true
		end

		while true do
			ii = ii + 1
			if foundMap[ii] then
				continue
			end
			local bad = false
			local sn = tpUtil.signId2signName(ii)
			if false then --if skip un warpable as part of rr..
				for _, name in ipairs(enums.ExcludeSignNamesFromStartingAt) do
					if sn == name then
						bad = true
						break
					end
				end
				if bad then
					continue
				end
			end
			serverwarping.WarpToSignId(lp, ii, false)

			wait(2.5)
		end
	end)
end
return module
