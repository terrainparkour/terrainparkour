--!strict

-- setupPlayerNames.lua :: ServerScriptService.setupPlayerNames
-- Forces overhead nameplates to display username instead of displayname for consistency.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

-- Module internals

local function setNameplateToUsername(character: Model, player: Player)
	task.spawn(function()
		local humanoid: Humanoid?
		local attempts = 0
		while attempts < 50 do
			local humanoidInstance: Instance? = character:FindFirstChild("Humanoid")
			if humanoidInstance and humanoidInstance:IsA("Humanoid") then
				humanoid = humanoidInstance :: Humanoid
				break
			end
			attempts += 1
			task.wait(0.1)
		end

		if not humanoid then
			annotater.Error("setupPlayerNames: Failed to get Humanoid after 5 seconds", {
				playerName = player.Name,
				userId = player.UserId,
			})
			return
		end

		-- Set DisplayName to username for consistency throughout game
		humanoid.DisplayName = player.Name
		_annotate(string.format("Set nameplate to username for %s", player.Name))
	end)
end

module.SetupPlayerNameplates = function(player: Player)
	local start = tick()
	
	-- Handle all future character spawns
	player.CharacterAdded:Connect(function(character)
		setNameplateToUsername(character, player)
	end)
	
	-- Handle current character if it exists
	local character: Model? = player.Character
	if character then
		setNameplateToUsername(character, player)
	end
	
	_annotate(string.format("SetupPlayerNameplates registered for %s (%.3fs)", player.Name, tick() - start))
end

_annotate("end")
return module

