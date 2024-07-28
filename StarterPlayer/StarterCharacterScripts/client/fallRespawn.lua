--!strict

--the idea is that we'd teleport you to start if you fell, so you wouldn't feel like you were dying.
--TODO not working.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local isfalling = false
local fallst = 0

local startPos = CFrame.new(Vector3.new(129.003, 56.5, -227.003))
local function repop()
	local char = script.Parent
	local hr: Part = char:FindFirstChild("HumanoidRootPart")
	hr.CFrame = startPos
	--it should also kill the race.
end

local function checkFalling()
	if isfalling then
		local gap = tick() - fallst
		if gap > 3 then
			isfalling = false
			fallst = 0
			repop()
		end
		task.spawn(function()
			wait(0.2)
			checkFalling()
		end)
	end
end

local function freefalling()
	if isfalling then
		checkFalling()
	else
		isfalling = true
		fallst = tick()
	end
end

local function touched(player)
	if isfalling then
		isfalling = false
		fallst = 0
	end
end

--disable til fixed.
if false then
	game.Players.LocalPlayer.Character.Humanoid.FreeFalling:connect(freefalling)
	game.Players.LocalPlayer.Character.Humanoid.Jumping:connect(freefalling)
	game.Players.LocalPlayer.Character.Humanoid.Touched:connect(touched)
	game.Players.LocalPlayer.Character.Humanoid.Running:connect(touched)
end
_annotate("end")

return {}
