--!strict

--copied onto signs which rotate.
--eval 9.24.22

local sendMessageModule = require(game.ReplicatedStorage.chat.sendMessage)
local sm = sendMessageModule.sendMessage
local channelDefinitions = require(game.ReplicatedStorage.chat.channelDefinitions)
local channel = channelDefinitions.getChannel("All")

local module = {}

module.rotate = function(sign: Part)
	if not sign then
		warn("no sign")
		return
	end
	spawn(function()
		while true do
			for deg = 0, 360 do
				sign.Rotation = Vector3.new(0, -1 * deg, 0)
				wait()
			end
		end
	end)
end

module.rotateMeshpart = function(sign: MeshPart)
	if not sign then
		warn("no sign")
		return
	end
	spawn(function()
		while true do
			for deg = 0, 360 do
				sign.Rotation = Vector3.new(0, -1 * deg, 0)
				wait()
			end
		end
	end)
end

module.riseandspin = function(sign: Part)
	if not sign then
		warn("no sign")
		return
	end
	spawn(function()
		local orig = sign.Position
		local vec = Vector3.new(0, 200, 0)
		sign.Position = Vector3.new(orig.X + vec.X, orig.Y + vec.Y, orig.Z + vec.Z)
		local adjustedOrig = sign.Position
		while true do
			for deg = 0, 360 do
				sign.Rotation = Vector3.new(0, -1 * deg, 0)
				local frac = (deg / 360) * 2 * math.pi
				local val = math.sin(frac)
				sign.Position = adjustedOrig + Vector3.new(val * vec.X, val * vec.Y, val * vec.Z)
				--TODO this should be physics stepped.
				wait(1 / 60)
			end
		end
	end)
end

--following for 007 mystery sign.
module.fadeInSign = function(sign: Part)
	if not sign then
		warn("no sign")
		return
	end
	spawn(function()
		while sign.Transparency > 0 do
			sign.Transparency -= 0.01
			wait(0.03)
		end
	end)
	sign.CanCollide = true
	sign.CanTouch = true
	-- cdholder.Parent = sign
	local sg = sign:FindFirstChildOfClass("SurfaceGui")
	if sg == nil then
		return
	end
	assert(sg)
	sg.Enabled = true
	sm(channel, "007 has appeared")
end

module.fadeOutSign = function(sign: Part?, first: boolean)
	if not sign then
		return
	end
	assert(sign)
	local sg = sign:FindFirstChildOfClass("SurfaceGui")
	if sg == nil then
		return
	end
	assert(sg)
	sg.Enabled = false

	spawn(function()
		while sign.Transparency < 1 do
			sign.Transparency += 0.01
			wait(0.03)
		end
	end)

	sign.CanCollide = false
	sign.CanTouch = false
	if not first then
		sm(channel, "007 has disappeared")
	end
end

return module
