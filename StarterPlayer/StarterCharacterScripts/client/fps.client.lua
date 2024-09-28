--!strict

-- serverEvents.lua on the client.
-- listens on client for events, and calls into drawing methods.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local avg = {}
local lastPrintTime = tick()

local RunService = game:GetService("RunService")

-- RunService.Heartbeat:Connect(function(dt: number)
-- 	local fps = math.floor(1 / dt)
-- 	table.insert(avg, fps)

-- 	local count = 0
-- 	local total = 0
-- 	for _, value in avg do
-- 		count += 1
-- 		total += value
-- 	end
-- 	total /= count

-- 	if #avg > 20 then
-- 		table.remove(avg, 1)
-- 	end

-- 	local currentTime = tick()
-- 	if currentTime - lastPrintTime >= 10 then
-- 		lastPrintTime = currentTime
-- 		-- if total > 100 then
-- 		-- 	print(string.format("%d FPS", math.floor(total)))
-- 		-- end
-- 	end
-- end)

_annotate("end")
