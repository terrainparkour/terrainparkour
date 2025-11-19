--!strict

-- commandUtils.lua :: ReplicatedStorage.ChatSystem.commandUtils
-- SERVER-ONLY: Shared utilities for chat command handlers.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local badgeEnums = require(game.ReplicatedStorage.util.badgeEnums)
local grantBadge = require(game.ServerScriptService.grantBadge)
local playerData2 = require(game.ServerScriptService.playerData2)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)

type Module = {
	SendMessage: (message: string, player: Player) -> (),
	GrantCmdlineBadge: (userId: number) -> (),
	GrantUndocumentedCommandBadge: (userId: number) -> (),
	FormatLogPreview: (message: string) -> string,
	GetClosestSignToPlayer: (player: Player) -> Instance?,
	RequireArguments: (parts: { string }, minCount: number) -> boolean,
	GetArgumentOrDefault: (parts: { string }, index: number, default: string) -> string,
}

local module: Module = {} :: Module

local logPreviewLimit = 160

function module.FormatLogPreview(message: string): string
	local preview = message
	if #preview > logPreviewLimit then
		preview = string.format("%s... [len=%d]", preview:sub(1, logPreviewLimit), #message)
	end
	preview = preview:gsub("\r\n", "\\n")
	preview = preview:gsub("\n", "\\n")
	return preview
end

function module.SendMessage(message: string, player: Player): ()
	_annotate(string.format("sendMessage -> player=%s channel=Data preview=%s", player.Name, module.FormatLogPreview(message)))
	local remoteEventFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if remoteEventFolder then
		local displayMsg = remoteEventFolder:FindFirstChild("DisplaySystemMessageEvent")
		if displayMsg and displayMsg:IsA("RemoteEvent") then
			displayMsg:FireClient(player, message, "Data")
		else
			_annotate("Error: DisplaySystemMessageEvent RemoteEvent not found")
			warn("DisplaySystemMessageEvent RemoteEvent not found!")
		end
	else
		_annotate("Error: RemoteEvents folder not found when sending message")
		warn("RemoteEvents folder not found!")
	end
end

function module.GrantCmdlineBadge(userId: number): ()
	grantBadge.GrantBadge(userId, badgeEnums.badges.CmdLine)
end

function module.GrantUndocumentedCommandBadge(userId: number): ()
	grantBadge.GrantBadge(userId, badgeEnums.badges.UndocumentedCommand)
	module.GrantCmdlineBadge(userId)
end

function module.RequireArguments(parts: { string }, minCount: number): boolean
	return parts ~= nil and #parts >= minCount
end

function module.GetArgumentOrDefault(parts: { string }, index: number, default: string): string
	if not parts or #parts < index then
		return default
	end
	return parts[index]
end

function module.GetClosestSignToPlayer(player: Player): Instance?
	local character = player.Character
	if not character then
		character = player.CharacterAdded:Wait()
	end

	if not character or not character:IsA("Model") then
		return nil
	end

	local rootCandidate = character:FindFirstChild("HumanoidRootPart")
	local root = (rootCandidate and rootCandidate:IsA("BasePart")) and (rootCandidate :: BasePart) or nil
	if not root then
		return nil
	end

	local signsContainer = workspace:FindFirstChild("Signs")
	if not signsContainer or not signsContainer:IsA("Folder") then
		return nil
	end
	local signsFolder = signsContainer :: Folder

	local playerPos: Vector3 = root.Position
	local bestSign: Instance? = nil
	local bestDist: number? = nil

	for _, sign in ipairs(signsFolder:GetChildren()) do
		local signId = tpUtil.looseSignName2SignId(sign.Name)
		if signId == nil then
			continue
		end

		if not playerData2.HasUserFoundSign(player.UserId, signId) then
			continue
		end

		local signPosition = tpUtil.signId2Position(signId)
		if not signPosition then
			continue
		end

		local dist = tpUtil.getDist(signPosition, playerPos)
		if not bestDist or dist < bestDist then
			bestDist = dist
			bestSign = sign
		end
	end

	return bestSign
end

_annotate("end")
return module

