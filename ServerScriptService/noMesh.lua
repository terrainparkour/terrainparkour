--!strict

--eval 9.25.22

--some work to strip out meshes and other extraneous items from players.
--allowing them makes flinging easier and messes up records.

local module = {}

local function handle(character)
	spawn(function()
		local hum: Humanoid
		while true do
			hum = character:WaitForChild("Humanoid")
			if hum ~= nil then
				break
			end
			print("W")
			wait(0.1)
		end

		local desc = hum:GetAppliedDescription()
		desc.Head = 0
		desc.Torso = 0
		desc.LeftArm = 0
		desc.RightArm = 0
		desc.LeftLeg = 0
		desc.RightLeg = 0
		desc.BodyTypeScale = 1.0
		wait(0.6)
		hum:ApplyDescription(desc)
		for _, el in ipairs(character:GetChildren()) do
			if el.Name == "CharacterMesh" then
				print("destroy: " .. el.Name)
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
			-- print("char children: " .. el.Name)
		end
	end)
end

module.StandardizeCharacter = function(player: Player)
	player.CharacterAdded:Connect(function(character)
		handle(character)
	end)
	local character = player.Character or player.CharacterAdded:Wait()
	while true do
		if character ~= nil then
			handle(character)
			break
		end
		wait(0.1)
	end
end

return module
