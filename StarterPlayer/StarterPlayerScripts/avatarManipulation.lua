--!strict

-- avatarManipulation
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local resetMomentumDebounce = false
module.ResetMomentum = function(humanoid: Humanoid, character: Model)
	if resetMomentumDebounce then
		return
	end
	resetMomentumDebounce = true
	_annotate("\t\tresetMomentum")
	local rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart
	if rootPart == nil then
		error("fail")
	end
	-- well, this will certainly remove momentum from the user. But it doesn't feel pleasant.
	rootPart.Anchored = true
	rootPart.Anchored = false

	-- 2024 still unclear what this does, too.
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)

	-- 2024: is this effectively just the server version of resetting movement states?
	rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	while true do
		local state = humanoid:GetState()
		if
			state == Enum.HumanoidStateType.GettingUp
			or state == Enum.HumanoidStateType.Running
			or state == Enum.HumanoidStateType.Freefall
			or state == Enum.HumanoidStateType.Dead
			or state == Enum.HumanoidStateType.Swimming
		then
			_annotate("state passed")
			break
		end

		wait()
		_annotate("waited.in resetMomentum")
	end
	_annotate("movement:\tmomentum has been reset.")
	resetMomentumDebounce = false
end

module.SetCharacterTransparency = function(player: Player, target: number)
	_annotate("Player made transparent: " .. tostring(target))
	local targetCharacter = player.Character
	local any = false
	for i, v: Decal | MeshPart in pairs(targetCharacter:GetDescendants()) do
		if v:IsA("Decal") or v:IsA("MeshPart") then --v:IsA("BasePart")
			if v.Transparency ~= target then
				any = true
				v.Transparency = target
			end
		end
	end
	return any
end

module.ResetPhysicalAvatarMorphs = function(humanoid: Humanoid, character: Model)
	-- i suppose these don't really need to be duplicated into the signs, but that does feel good.
	character:ScaleTo(1)
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown then
		_annotate("reset state yet char is in ragdoll.")
		--this happens because there is some lag in setting state
		--this can happen after warping
		--we should ban runs from this point, but don't currently.
		humanoid:ChangeState(Enum.HumanoidStateType.Running)
	end
end

_annotate("end")
return module
