--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local remotes = require(game.ReplicatedStorage.util.remotes)
local tt = require(game.ReplicatedStorage.types.gametypes)

local module = {}

----------- LOCAL FUNCTIONS --------------------
module.CreateTemporaryLightPillar = function(pos: Vector3, desc: string)
	local part = Instance.new("Part")
	part.Position = Vector3.new(pos.X, pos.Y + 320, pos.Z)
	part.Size = Vector3.new(700, 6, 6)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.Anchored = true
	part.CanTouch = false
	part.Massless = true
	part.Name = "LightPillar"
	part.Transparency = 0.6
	part.Orientation = Vector3.new(0, 0, 90)
	part.Shape = Enum.PartType.Cylinder
	part.Parent = game.Workspace
	if desc == "source" then
		part.Color = Color3.fromRGB(255, 160, 160)
	elseif desc == "destination" then
		part.Color = Color3.fromRGB(160, 250, 160)
	else
		_annotate("bad")
	end

	task.spawn(function()
		while true do
			wait(1 / 37)
			part.Transparency = part.Transparency + 0.009
			if part.Transparency >= 1 then
				part:Destroy()
				break
			end
		end
	end)
end

_annotate("end")
return module
