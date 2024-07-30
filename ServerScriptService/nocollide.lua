--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local PLAYER_GROUP = "Players"

PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
PhysicsService:CollisionGroupSetCollidable(PLAYER_GROUP, PLAYER_GROUP, false)

local function setPlayerCollisionGroup(character)
	for _, part: BasePart in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = PLAYER_GROUP
		end
	end
end

local function onCharacterAdded(character)
	setPlayerCollisionGroup(character)
	character.DescendantAdded:Connect(function(descendant: BasePart)
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = PLAYER_GROUP
		end
	end)
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(onCharacterAdded)
end

Players.PlayerAdded:Connect(onPlayerAdded)

-- Handle existing players
for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then
		onCharacterAdded(player.Character)
	end
end

module.Init = function() end

_annotate("end")
return module
