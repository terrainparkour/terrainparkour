--!strict

-- commandUtils.lua :: ReplicatedStorage.ChatSystem.commandUtils
-- SERVER-ONLY: Shared utilities for chat command handlers.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local Players = game:GetService("Players")

local channelManager = require(game.ReplicatedStorage.ChatSystem.channelManager)
local messageFormatter = require(game.ReplicatedStorage.ChatSystem.messageFormatter)
local remotes = require(game.ReplicatedStorage.util.remotes)
local badgeEnums = require(game.ReplicatedStorage.util.badgeEnums)
local grantBadge = require(game.ServerScriptService.grantBadge)
local playerData2 = require(game.ServerScriptService.playerData2)
local tpUtil: typeof(require(game.ReplicatedStorage.util.tpUtil)) = require(game.ReplicatedStorage.util.tpUtil)
local tt = require(game.ReplicatedStorage.types.gametypes)

export type MessageOptions = {
	ChatColor: Color3?,
	channel: string?,
}

type Module = {
	SendMessage: (message: string, player: Player, options: MessageOptions?) -> (),
	GrantCmdlineBadge: (userId: number) -> (),
	GrantUndocumentedCommandBadge: (userId: number) -> (),
	GrantBrightIdeaBadge: (userId: number) -> (),
	GrantFixmeBadge: (userId: number) -> (),
	GrantTrollBadge: (userId: number) -> (),
	ParseRaceFromInput: (message: string, userId: number) -> tt.RaceParseResult,
	FormatLogPreview: (message: string) -> string,
	GetClosestSignToPlayer: (player: Player) -> Instance?,
	RequireArguments: (parts: { string }, minCount: number) -> boolean,
	GetArgumentOrDefault: (parts: { string }, index: number, default: string) -> string,
	SetActiveCommandChannel: (player: Player, channelName: string?) -> (),
	ClearActiveCommandChannel: (player: Player) -> (),
	GetActiveCommandChannel: (player: Player) -> string?,
}

local module: Module = {} :: Module

local logPreviewLimit = 160
local DEFAULT_COMMAND_CHANNEL = "Data"

local activeCommandChannels: { [Player]: string? } = {}

local function resolveTargetChannel(channelOverride: string?): string
	if channelOverride and channelOverride ~= "" then
		local definition = channelManager.GetDefinition(channelOverride)
		if not definition then
			error(string.format("Unknown channel override '%s'. Valid channels: Chat, Data, Joins", channelOverride))
		end
		return channelOverride
	end
	return DEFAULT_COMMAND_CHANNEL
end

Players.PlayerRemoving:Connect(function(player: Player)
	activeCommandChannels[player] = nil
end)

function module.FormatLogPreview(message: string): string
	local preview = message
	if #preview > logPreviewLimit then
		preview = string.format("%s... [len=%d]", preview:sub(1, logPreviewLimit), #message)
	end
	preview = preview:gsub("\r\n", "\\n")
	preview = preview:gsub("\n", "\\n")
	return preview
end

function module.SendMessage(message: string, player: Player, options: MessageOptions?): ()
	local targetChannel = resolveTargetChannel(if options then options.channel else nil)
	local formatted = message
	if options and options.ChatColor then
		formatted = messageFormatter.formatWithColor(message, options.ChatColor)
	end
	_annotate(string.format("sendMessage -> player=%s channel=%s preview=%s", player.Name, targetChannel, module.FormatLogPreview(message)))
	local displayMsgEvent = remotes.getRemoteEvent("DisplaySystemMessageEvent")
	displayMsgEvent:FireClient(player, formatted, targetChannel)
end

function module.GrantCmdlineBadge(userId: number): ()
	grantBadge.GrantBadge(userId, badgeEnums.badges.CmdLine)
end

function module.GrantUndocumentedCommandBadge(userId: number): ()
	grantBadge.GrantBadge(userId, badgeEnums.badges.UndocumentedCommand)
	module.GrantCmdlineBadge(userId)
end

function module.GrantBrightIdeaBadge(userId: number): ()
	grantBadge.GrantBadge(userId, badgeEnums.badges.BrightIdea)
	module.GrantCmdlineBadge(userId)
end

function module.GrantFixmeBadge(userId: number): ()
	grantBadge.GrantBadge(userId, badgeEnums.badges.Fixme)
	module.GrantCmdlineBadge(userId)
end

function module.ParseRaceFromInput(message: string, userId: number): tt.RaceParseResult
	local res = tpUtil.AttemptToParseRaceFromInput(message)
	local TheTrollingError = "Trolling is not allowed."
	if res.error == TheTrollingError then
		grantBadge.GrantBadge(userId, badgeEnums.badges.TheTroll)
	end
	return res
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

function module.SetActiveCommandChannel(player: Player, channelName: string?): ()
	if channelName and channelName ~= "" then
		activeCommandChannels[player] = channelName
	else
		activeCommandChannels[player] = nil
	end
end

function module.ClearActiveCommandChannel(player: Player): ()
	activeCommandChannels[player] = nil
end

function module.GetActiveCommandChannel(player: Player): string?
	return activeCommandChannels[player]
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
