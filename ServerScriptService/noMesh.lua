--!strict

--some work to strip out meshes and other extraneous items from players.
--allowing them makes flinging easier and messes up records.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local function handle(character: Model)
	task.spawn(function()
		local humanoid: Humanoid?
		while true do
			local humanoidInstance: Instance? = character:WaitForChild("Humanoid")
			if humanoidInstance and humanoidInstance:IsA("Humanoid") then
				humanoid = humanoidInstance :: Humanoid
				break
			end
			wait(0.1)
		end
		if not humanoid then
			warn("noMesh.handle: Failed to get Humanoid")
			return
		end

		local desc = humanoid:GetAppliedDescription()
		desc.Head = 0
		desc.Torso = 0
		desc.LeftArm = 0
		desc.RightArm = 0
		desc.LeftLeg = 0
		desc.RightLeg = 0
		desc.BodyTypeScale = 1.0
		wait(0.1)
		humanoid:ApplyDescription(desc)
		for _, el in ipairs(character:GetChildren()) do
			if el.Name == "CharacterMesh" then
				_annotate("destroy: " .. el.Name)
				el:Destroy()
			else
				if el.ClassName == "MeshPart" then
					continue
				end
				if el.ClassName == "Accessory" then
					local el2: Accessory = el :: Accessory
					if
						el2.AccessoryType == Enum.AccessoryType.LeftShoe
						or el2.AccessoryType == Enum.AccessoryType.RightShoe
						or el2.AccessoryType == Enum.AccessoryType.Unknown
					then
						el:Destroy()
					end
				end
			end
			-- _annotate("char children: " .. el.Name)
		end
	end)
end

module.StandardizeCharacter = function(player: Player)
	local start = tick()
	player.CharacterAdded:Connect(function(character)
		handle(character)
	end)
	local character: Model? = player.Character or player.CharacterAdded:Wait()
	while true do
		if character then
			handle(character :: Model)
			break
		end
		wait(0.1)
	end
	_annotate(string.format("StandardizeCharacter DONE for %s (%.3fs, mesh work spawned)", player.Name, tick() - start))
end

_annotate("end")
return module
