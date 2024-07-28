--!strict
--fps monitor- mostly unreliable
--DISABLED

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local config = require(game.ReplicatedStorage.config)

local frameBuffer = 60
--FPSUnlocker prevention
local RunService = game:GetService("RunService")

local st = tick()
local lastFrames = {}

local function ct()
	local total = 0
	if #lastFrames < frameBuffer then
		return 60
	end
	for _, el in ipairs(lastFrames) do
		total = total + el
	end
	return total / frameBuffer
end

local function HeartbeatUpdate()
	if #lastFrames == frameBuffer then
		table.remove(lastFrames, 1)
	end

	local st2 = tick()
	local frameGap = 1 / (st2 - st)
	table.insert(lastFrames, frameGap)

	local fps = ct()
	if fps > 99 and not config.isInStudio() then
		print("fps " .. tostring(fps))
	end

	st = st2
	-- print(lastFrames)
end
task.spawn(function()
	wait(15)
	RunService.Heartbeat:Connect(HeartbeatUpdate)
end)

task.spawn(function()
	while true do
		wait(10) --
		print("physics FPS" .. tostring(game.Workspace:GetRealPhysicsFPS()))
		break
	end
end)
_annotate("end")
