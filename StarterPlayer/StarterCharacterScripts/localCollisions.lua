--!strict

-- localCollisions.lua :: StarterPlayer.StarterCharacterScripts.localCollisions
-- Constantly sets collidability of player torso.
-- Removing this spams server with fewer update hits - which makes run timing less accurate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PlayersService = game:GetService("Players")

local annotater = require(ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

type Module = {
	Init: () -> (),
	Reset: () -> (),
}

local module: Module = {} :: Module

local steppedConnection: RBXScriptConnection? = nil

local function setupCollisions()
	-- Disconnect old connection if exists
	if steppedConnection then
		steppedConnection:Disconnect()
		steppedConnection = nil
	end

	local char = PlayersService.LocalPlayer.Character
	if not char then
		_annotate("no character, skipping collision setup")
		return
	end
	local character: Model = char

	steppedConnection = RunService.Stepped:Connect(function(_time, _step)
		local ltInstance = character:FindFirstChild("LowerTorso")
		if ltInstance and ltInstance:IsA("Part") then
			local lt: Part = ltInstance :: Part
			lt.CanCollide = true
		end

		local utInstance = character:FindFirstChild("UpperTorso")
		if utInstance and utInstance:IsA("Part") then
			local ut: Part = utInstance :: Part
			ut.CanCollide = true
		end
	end)

	_annotate("collision handler connected")
end

function module.Init()
	setupCollisions()
end

function module.Reset()
	setupCollisions()
end

_annotate("end")
return module

