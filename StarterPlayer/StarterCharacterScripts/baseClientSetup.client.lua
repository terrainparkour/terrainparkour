--!strict
--eval 9.25.22

--zoomlevel, jump base etc.
game.Players.LocalPlayer.CameraMaxZoomDistance = 6999

-- game.Players.LocalPlayer.Character.Humanoid.JumpPower = 10
game.Workspace.CurrentCamera.FieldOfView = (70 + (5 * 2))

function setupBanMonitor()
	--2022.04 unclear if works.
	spawn(function()
		while true do
			local lastBanLevel = 0
			local re = require(game.ReplicatedStorage.util.remotes)
			local getBanStatusRemoteFunction = re.getRemoteFunction("GetBanStatusRemoteFunction")
			if getBanStatusRemoteFunction then
				local banLevel = getBanStatusRemoteFunction:InvokeServer()
				if banLevel ~= nil then
					if banLevel == 0 and banLevel ~= lastBanLevel then
						--
					elseif banLevel == 1 then
						runSpeed = 16
						walkSpeed = 43
						afterJumpRunSpeed = 37
						afterSwimmingRunSpeed = 30
					elseif banLevel == 2 then
						runSpeed = 4
						walkSpeed = 12
						afterJumpRunSpeed = 27
						afterSwimmingRunSpeed = 20
					end
				end
				lastBanLevel = banLevel
			end
			wait(20)
		end
	end)
end

local function init()
	setupBanMonitor()
end

init()
