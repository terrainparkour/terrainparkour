--!strict

--some work to strip out meshes and other extraneous items from players.
--allowing them makes flinging easier and messes up records.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local function handle(character)
	task.spawn(function()
		local humanoid: Humanoid
		while true do
			humanoid = character:WaitForChild("Humanoid")
			if humanoid ~= nil then
				break
			end
			wait(0.1)
		end

		local desc = humanoid:GetAppliedDescription()
		desc.Head = 0
		desc.Torso = 0
		desc.LeftArm = 0
		desc.RightArm = 0
		desc.LeftLeg = 0
		desc.RightLeg = 0
		desc.BodyTypeScale = 1.0
		wait(0.6)
		humanoid:ApplyDescription(desc)
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

_annotate("end")
return module
