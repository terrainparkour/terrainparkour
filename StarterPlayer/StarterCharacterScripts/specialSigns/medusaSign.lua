local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local Players = game:GetService("Players")
local localPlayer: Player = Players.LocalPlayer
local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid

----------- GLOBALS -----------
local Moved = false
local Stone = false
-------------- MAIN --------------

module.kill = function()
	if Stone then
		Stone = false
	end
	_annotate("killed")
end

module.Init = function()
	if humanoid.velocity > 0 and Stone then
		Moved = true
		humanoid.Velocity = Vector3.new(0, 0, 0)
		humanoid.PlatformStand = true
		-- change the r15 avatar to stone material or something that looks like medusa's stone
		-- (not sure if platformstand does what I think it does but basically make the player freeze where they were caught moving
		task.wait(3)
		--change back the avatar to be normal again here
		humanoid.PlatformStand = false
	elseif humanoid.velocity > 0 then
		Moved = true
	end

	-- Create a coroutine to start the movement phase every x amount of seconds
	coroutine.wrap(function()
		while true do
			-- Wait for x amount of seconds (determined by how long you stay in a race)
			task.wait()

			-- Start the medusa phase
			Stone = true

			-- Wait for y amount of seconds before allowing movement again
			task.wait(2)

			-- End the movement phase
			Stone = false
			humanoid.PlatformStand = false
		end
	end)()
end

local DescriptionUpdateText = function()
	--I ain't doing gui stuff, oh hell nah
end
