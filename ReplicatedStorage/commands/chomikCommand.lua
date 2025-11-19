--!strict

-- chomikCommand.lua :: ReplicatedStorage.commands.chomikCommand
-- SERVER-ONLY: Finds distance to the Chomik sign.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local commandUtils = require(game.ReplicatedStorage.ChatSystem.commandUtils)

local MessageDispatcher = require(game.ReplicatedStorage.ChatSystem.messageDispatcher)
local commandTypes = require(game.ReplicatedStorage.ChatSystem.commandTypes)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)

local module: commandTypes.CommandModule = {
	Execute = function(_player: Player, _parts: { string }): boolean
		return false
	end,
	Visibility = "public",
	ChannelRestriction = "any",
	AutocompleteVisible = false
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
	local message = string.format("The Chomik is %dd away from %s", dist, player.Name)
	local success = MessageDispatcher.SendSystemMessage("Chat", message)
	if not success then
		_annotate("Warn: Failed to broadcast chomik message to Chat channel")
	end
	commandUtils.GrantCmdlineBadge(player.UserId)
	return true
end

_annotate("end")
return module
