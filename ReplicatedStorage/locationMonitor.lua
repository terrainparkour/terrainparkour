--!strict

--monitors locations of players continuously

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)

local playerLocations: { Vector3 } = {}

module.Init = function()
	--this is disabled now.
	task.spawn(function()
		--_annotate("starting player location monitor.")
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

_annotate("end")
return module
