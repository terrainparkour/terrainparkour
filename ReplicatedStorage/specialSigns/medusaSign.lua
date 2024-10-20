local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local specialSign = {}
local tt = require(game.ReplicatedStorage.types.gametypes)

local Players = game:GetService("Players")
local localPlayer: Player = Players.LocalPlayer
local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait() :: Model
local humanoid: Humanoid = character:WaitForChild("Humanoid") :: Humanoid

----------- GLOBALS -----------
local Moved = false
local Stone = false
-------------- MAIN --------------

specialSign.kill = function()
	if Stone then
		Stone = false
	end
end

specialSign.Init = function()
	_annotate("init")
	if humanoid.Velocity > 0 and Stone then
		Moved = true
		humanoid.Velocity = Vector3.new(0, 0, 0)
		humanoid.PlatformStand = true
		-- change the r15 avatar to stone material or something that looks like medusa's stone
		-- (not sure if platformstand does what I think it does but basically make the player freeze where they were caught moving
		task.wait(3)
		--change back the avatar to be normal again here
		humanoid.PlatformStand = false
	elseif humanoid.Velocity > 0 then
		Moved = true
	end

	-- Create a coroutine to start the movement phase every x amount of seconds
	coroutine.wrap(function()
		while true do
			-- Wait for x amount of seconds (determined by how long you stay in a race)
			task.wait(0.1)

			-- Start the medusa phase
			Stone = true

			-- Wait for y amount of seconds before allowing movement again
			task.wait(2)

			-- End the movement phase
			Stone = false
			humanoid.PlatformStand = false
		end
	end)()
	_annotate("init done")
end

specialSign.InformRetouch = function() end
specialSign.CanRunEnd = function(): tt.runEndExtraDataForRacing
	return {
		canRunEndNow = true,
	}
end

specialSign.GetName = function()
	return "Medusa"
end

local module: tt.SpecialSignInterface = specialSign
local DescriptionUpdateText = function()
	--I ain't doing gui stuff, oh hell nah
end

return module
