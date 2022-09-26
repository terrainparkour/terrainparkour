--!strict

if false then
	local PlayersService = game:GetService("Players")
	local localplayer = PlayersService.LocalPlayer

	local function calculateHipHeight(character)
		local joints = {
			{
				PartName = "HumanoidRootPart",
				From = nil,
				To = "RootRigAttachment",
			},
			{
				PartName = "LowerTorso",
				From = "RootRigAttachment",
				To = "RightHipRigAttachment",
			},
			{
				PartName = "RightUpperLeg",
				From = "RightHipRigAttachment",
				To = "RightKneeRigAttachment",
			},
			{
				PartName = "RightLowerLeg",
				From = "RightKneeRigAttachment",
				To = "RightAnkleRigAttachment",
			},
			{
				PartName = "RightFoot",
				From = "RightAnkleRigAttachment",
				To = nil,
			},
		}

		local hipHeight = 0
		for _, entry in pairs(joints) do
			local fromPos: Vector3
			if entry.From then
				local pn = character:FindFirstChild(entry.PartName)
				if pn then
					local pnn = pn[entry.From]
					if pnn then
						fromPos = pnn.Position
					end
				end
			end
			if fromPos == nil then
				fromPos = Vector3.new(0, 0, 0)
			end

			-- local toPos = entry.To and character[entry.PartName][entry.To].Position or -character[entry.PartName].Size / 2
			local toPos: Vector3
			if entry.To then
				local pn = character:FindFirstChild(entry.PartName)
				if pn then
					local pnn = pn[entry.To]
					if pnn then
						toPos = pnn.Position
					end
				end
			end
			if toPos == nil then
				local pt = character:FindFirstChild(entry.PartName)
				if pt == nil then
					warn("X")
				else
					toPos = -(pt.Size / 2)
				end
			end

			hipHeight += fromPos.Y - toPos.Y
		end

		hipHeight -= character.PrimaryPart.Size.Y / 2

		return hipHeight
	end

	local done = false
	localplayer.CharacterAppearanceLoaded:Connect(function(character)
		done = true
		local hh = calculateHipHeight(localplayer.Character)
		print("calculaterd hipheight:" .. tostring(hh))
		local hum: Humanoid = localplayer.Character:FindFirstChild("Humanoid")
		hum.HipHeight = hh
	end)

	if not done then
		while true do
			wait(1)
			if localplayer.Character then
				local hh = calculateHipHeight(localplayer.Character)
				print("2 calculaterd hipheight:" .. tostring(hh))
				local hum: Humanoid = localplayer.Character:FindFirstChild("Humanoid")
				hum.HipHeight = hh
				break
			end
		end
	end
end
