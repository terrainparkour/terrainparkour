--!strict
local colors = require(game.ReplicatedStorage.util.colors)

local module = {}

local particleEmitter

module.SetupParticleEmitter = function(player: Player)
	player.CharacterAdded:Connect(function()
		local character = player.Character or player.CharacterAdded:Wait()

		particleEmitter = Instance.new("ParticleEmitter")
		particleEmitter.EmissionDirection = Enum.NormalId.Back
		particleEmitter.Lifetime = NumberRange.new(1, 1)

		--initially set it to inactive
		particleEmitter.Rate = 0
		particleEmitter.Size = NumberSequence.new(0.3)
		particleEmitter.Name = "PlayerParticleEmitter"
		particleEmitter.SpreadAngle = Vector2.new(12, 12)

		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		particleEmitter.Parent = humanoid.RootPart
	end)
end

--momentarily set emission to show the thing that just happened to the user.
module.EmitParticle = function(increase: boolean)
	if particleEmitter == nil then
		warn("never hsould happne, if not delete.")
		return
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
