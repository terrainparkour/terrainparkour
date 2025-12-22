--!strict

-- chomikCommand.lua :: ReplicatedStorage.commands.chomikCommand
-- SERVER-ONLY: Finds distance to the Chomik sign.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)

local messageDispatcher = require(game.ReplicatedStorage.ChatSystem.messageDispatcher)
local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local tpUtil: typeof(require(game.ReplicatedStorage.util.tpUtil)) = require(game.ReplicatedStorage.util.tpUtil)

-- Distance-based color gradient: dull brown (far) → rich green (close)
-- Stops: brown → red → orange → yellow → blue → light green → rich green
local colorStops: { { dist: number, color: Color3 } } = {
	{ dist = 4000, color = Color3.fromRGB(100, 60, 30) }, -- dull brown (far)
	{ dist = 3000, color = Color3.fromRGB(180, 50, 50) }, -- dull red
	{ dist = 2000, color = Color3.fromRGB(200, 120, 50) }, -- orange
	{ dist = 1200, color = Color3.fromRGB(220, 200, 60) }, -- yellow
	{ dist = 600, color = Color3.fromRGB(80, 140, 220) }, -- blue
	{ dist = 300, color = Color3.fromRGB(120, 220, 120) }, -- light green
	{ dist = 100, color = Color3.fromRGB(30, 180, 60) }, -- rich green (close)
}

local function getChomikColor(dist: number): Color3
	-- Clamp to range
	if dist >= colorStops[1].dist then
		return colorStops[1].color
	end
	if dist <= colorStops[#colorStops].dist then
		return colorStops[#colorStops].color
	end

	-- Find which two stops we're between
	for i = 1, #colorStops - 1 do
		local farStop = colorStops[i]
		local nearStop = colorStops[i + 1]
		if dist <= farStop.dist and dist >= nearStop.dist then
			-- Interpolate between the two stops
			local t = (farStop.dist - dist) / (farStop.dist - nearStop.dist)
			return farStop.color:Lerp(nearStop.color, t)
		end
	end

	return colorStops[1].color
end

-- Track users who have already received the "has moved" message this session
local usersWhoHaveSeenMovedMessage: { [number]: boolean } = {}

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "any",
	AutocompleteVisible = false,
}

function module.Execute(player: Player, _parts: { string }): boolean
	local character = player.Character or player.CharacterAdded:Wait()
	if not character then
		annotater.Error("no character.")
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		annotater.Error("no root")
		return false
	end
	local signs = game.Workspace:FindFirstChild("Signs")
	if not signs then
		annotater.Error("Signs folder not found")
		return true
	end
	local chomik = signs:FindFirstChild("Chomik")
	if not chomik or not chomik:IsA("BasePart") then
		annotater.Error("Chomik not found")
		return true
	end
	local dist = tpUtil.getDist(root.Position, chomik.Position)
	local isFirstUse = not usersWhoHaveSeenMovedMessage[player.UserId]
	if isFirstUse then
		usersWhoHaveSeenMovedMessage[player.UserId] = true
	end
	local prefix = isFirstUse and "The Chomik has moved! " or ""
	local message = string.format("%sThe Chomik is %dd away from %s", prefix, dist, player.Name)
	local options = { ChatColor = getChomikColor(dist) }
	messageDispatcher.SendSystemMessage("Chat", message, options)
	commandUtils.GrantCmdlineBadge(player.UserId)
	return true
end

_annotate("end")
return module
