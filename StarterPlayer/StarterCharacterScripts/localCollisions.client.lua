--!strict

--constantly sets collidability of player torso
--removing this spams server with fewer update hits - which makes run timing less accurate

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

if false then
	local RunService = game:GetService("RunService")
	local PlayerService = game:GetService("Players")

	local char = PlayerService.LocalPlayer.Character
	RunService.Stepped:Connect(function(time, step)
		local lt: Part = char:FindFirstChild("LowerTorso")
		if lt ~= nil then
			lt.CanCollide = true
		end

		local ut: Part = char:FindFirstChild("UpperTorso")
		if ut ~= nil then
			ut.CanCollide = true
		end
	end)
end
_annotate("end")
