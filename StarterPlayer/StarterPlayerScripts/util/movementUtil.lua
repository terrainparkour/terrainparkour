local module = {}

module.SetCharacterTransparency = function(player: Player, target: number)
	local character = player.Character
	--if you include basepart you get the weird humanoidRootPart!
	--not sure how much of this matters
	--or, if i were to allow users to wear accessories again, it would matter
	--that i don't revert them to their original transparency but rather set to 0
	for i, v in pairs(character:GetDescendants()) do
		if v:IsA("Decal") or v:IsA("MeshPart") then --v:IsA("BasePart")
			v.Transparency = target
		end
	end
end

return module
