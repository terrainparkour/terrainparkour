--!strict
local colors = require(game.ReplicatedStorage.util.colors)

local module = {}

local particleEmitter
module.SetupParticleEmitter = function()
	local pe: ParticleEmitter
	local s, e = pcall(function()
		pe = Instance.new("ParticleEmitter")
		pe.EmissionDirection = Enum.NormalId.Back
		pe.Lifetime = NumberRange.new(1, 1)

		--initially set it to inactive
		pe.Rate = 0
		pe.Size = NumberSequence.new(0.3)
		pe.Name = "PlayerParticleEmitter"
		pe.SpreadAngle = Vector2.new(12, 12)
		pe.Parent = game.Players.LocalPlayer.Character.Humanoid.RootPart
	end)

	if s then
		particleEmitter = pe
	end

	if e then
		error(e)
	end
end

--momentarily set emission to show the thing that just happened to the user.
module.EmitParticle = function(increase: boolean, localPlayer: Player)
	if particleEmitter == nil then
		return
	end
	if localPlayer.Character == nil or localPlayer.Character.Humanoid == nil then
		return
	end
	if particleEmitter.Parent == nil then
		particleEmitter.Parent = localPlayer.Character.Humanoid.RootPart
	end
	local particleColor: ColorSequence = ColorSequence.new(colors.redStop)
	if increase then
		particleColor = ColorSequence.new(colors.greenGo)
	end
	particleEmitter.Color = particleColor
	particleEmitter.Rate = 50

	spawn(function()
		wait(0.7)
		particleEmitter.Rate = 0
	end)
end
return module
