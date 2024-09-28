--!strict

-- receiveClientEventServer.lua listens for client events and just trusts them.
-- avatar morphs, etc.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local tt = require(game.ReplicatedStorage.types.gametypes)
local remotes = require(game.ReplicatedStorage.util.remotes)

local AvatarManipulationRemoteFunction = remotes.getRemoteFunction("AvatarManipulationRemoteFunction")

--in new trust the client code, just call this directly with the actual details.
--note: it would be nice to retain server-side timing to detect hackers. nearly every one would give themselves away.

local function handleAvatarMorph(player: Player, data: tt.avatarMorphData)
	_annotate("handleAvatarMorph", data)

	local didAnything = false

	if data.transparency then
		_annotate("got request to set character transparency to: " .. tostring(data.transparency))
		local targetCharacter = player.Character
		local targetTransparency = data.transparency
		for i, v: Decal | MeshPart in pairs(targetCharacter:GetDescendants()) do
			-- print(v.Name, v.ClassName)
			if v:IsA("Decal") or v:IsA("MeshPart") then --v:IsA("BasePart")
				if v.Transparency ~= targetTransparency then
					v.Transparency = targetTransparency
					didAnything = true
				end
			end
		end
	end
	if data.scale then
		local targetCharacter = player.Character
		local currentScale = targetCharacter:GetScale()
		if currentScale ~= data.scale then
			_annotate(
				string.format("Rescaling character from currentScale=%f to desiredScale=%f", currentScale, data.scale)
			)
			targetCharacter:ScaleTo(data.scale)
			didAnything = true
		end
	end
	return didAnything
end

module.Init = function()
	_annotate("init")
	AvatarManipulationRemoteFunction.OnServerInvoke = function(player: Player, event: tt.clientToServerRemoteEvent)
		if event.eventKind == "avatarMorph" then
			return handleAvatarMorph(player, event.data)
		end

		return false
	end
end

_annotate("end")
return module
