local module = {}

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

module.SetCharacterTransparency = function(player: Player, target: number)
	local character = player.Character
	--if you include basepart you get the weird humanoidRootPart!
	--not sure how much of this matters
	--or, if i were to allow users to wear accessories again, it would matter
	--that i don't revert them to their original transparency but rather set to 0
	local any = false
	for i, v in pairs(character:GetDescendants()) do
		if v:IsA("Decal") or v:IsA("MeshPart") then --v:IsA("BasePart")
			if v.Transparency ~= target then
				any = true
				v.Transparency = target
			end
		end
	end
	return any
end

_annotate("end")
return module
