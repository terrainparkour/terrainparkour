--!strict

-- chatService.lua :: ReplicatedStorage.ChatSystem.chatService
-- SERVER-ONLY: Sets up chat channels for the new TextChatService system.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local channelManager = require(game.ReplicatedStorage.ChatSystem.channelManager)
local banning = require(game.ServerScriptService.banning)
local messageDispatcher = require(game.ReplicatedStorage.ChatSystem.messageDispatcher)

type Module = {
	CreateChannels: (self: Module, player: Player) -> {},
	Init: (self: Module) -> (),
}

local module: Module = {} :: Module
local channelDefinitions: { channelManager.ChannelDefinition } = {}
local channelsWithWelcomeSent: { [string]: boolean } = {}

local function ensureTextChannel(definition: channelManager.ChannelDefinition, channelTabsConfig: Folder): TextChannel
	local existing = channelTabsConfig:FindFirstChild(definition.name)
	if existing and existing:IsA("TextChannel") then
		return existing
	end

	local createdChannel = Instance.new("TextChannel")
	createdChannel.Name = definition.name
	createdChannel.Parent = channelTabsConfig

	return createdChannel
end

module.CreateChannels = function(self: Module, player: Player): {}
	if not player then
		warn("Attempt to create channels for nil player")
		return {}
	end

	local banLevel = banning.getBanLevel(player.UserId)
	if banLevel and banLevel > 0 then
		return {}
	end

	for _, definition in ipairs(channelDefinitions) do
		local channel = channelManager.GetChannel(definition.name)
		local channelWasNewlyCreated = false
		if not channel then
			local tabsConfig = TextChatService:FindFirstChild("ChannelTabsConfiguration")
			if not tabsConfig or not tabsConfig:IsA("Folder") then
				annotater.Error("ChannelTabsConfiguration missing while adding player", {
					player = player.Name,
				})
				return {}
			end
			local ensured = ensureTextChannel(definition, tabsConfig)
			channelManager.RegisterChannel(definition.name, ensured)
			channel = ensured
			channelWasNewlyCreated = true
		end
		if not channel then
			continue
		end
		local channelInstance = channel :: TextChannel

		if definition.autoJoin then
			local success, err = pcall(function()
				channelInstance:AddUserAsync(player.UserId)
			end)
			if success then
				-- Send welcome message only when channel is first created, not when later players join
				if channelWasNewlyCreated and definition.welcomeMessage and definition.welcomeMessage ~= "" then
					if not channelsWithWelcomeSent[definition.name] then
						channelsWithWelcomeSent[definition.name] = true
						task.spawn(function()
							task.wait(0.3) -- Small delay to ensure player is fully joined
							messageDispatcher.SendSystemMessage(definition.name, definition.welcomeMessage)
						end)
					end
				end
			else
				warn(
					string.format(
						"Error: Failed to add player %s to channel %s: %s",
						player.Name,
						definition.name,
						tostring(err)
					)
				)
			end
		else
			-- Manual-join channels: skip auto-add.
		end
	end

	return {}
end

module.Init = function(self: Module)
	-- Intentionally quiet: init is expected and noisy in logs.
	if TextChatService.CreateDefaultTextChannels ~= false then
		TextChatService.CreateDefaultTextChannels = false
	end

	local channelTabsConfig = TextChatService:WaitForChild("ChannelTabsConfiguration") :: Folder
	channelDefinitions = channelManager.GetDefinitions()

	-- Remove existing channels to ensure correct tab order
	for _, definition in ipairs(channelDefinitions) do
		local existing = channelTabsConfig:FindFirstChild(definition.name)
		if existing and existing:IsA("TextChannel") then
			existing:Destroy()
		end
	end

	-- Create channels in the correct order (order determines tab order)
	-- Small delay between each to ensure tabs appear in correct visual order
	for i, definition in ipairs(channelDefinitions) do
		local channel = ensureTextChannel(definition, channelTabsConfig)
		channelManager.RegisterChannel(definition.name, channel)
		-- Send welcome message when channel is first created
		if definition.welcomeMessage and definition.welcomeMessage ~= "" then
			channelsWithWelcomeSent[definition.name] = true
			task.spawn(function()
				task.wait(0.3) -- Small delay to ensure channel is ready
				messageDispatcher.SendSystemMessage(definition.name, definition.welcomeMessage)
			end)
		end
		if i < #channelDefinitions then
			task.wait(0.1) -- 10ms delay between channel creations
		end
	end

	local chatInputConfig = TextChatService:FindFirstChild("ChatInputBarConfiguration")
	if chatInputConfig then
		local defaultChannel = channelManager.GetChannel(channelManager.GetDefaultChannelName())
		if defaultChannel then
			local ok, err = pcall(function()
				(chatInputConfig :: any).TargetTextChannel = defaultChannel
			end)
			if not ok then
				_annotate(string.format("Warn: Failed to set TargetTextChannel (%s)", tostring(err)))
			else
				-- Successfully assigned input channel.
			end
		else
			_annotate("Warn: Default channel not present when assigning ChatInputBarConfiguration")
		end
	else
		_annotate("ChatInputBarConfiguration not found; leaving default input channel unchanged")
	end

	for _, player in Players:GetPlayers() do
		self:CreateChannels(player)
	end

	Players.PlayerAdded:Connect(function(player)
		self:CreateChannels(player)
	end)
end

_annotate("end")
return module
