--!strict

-- ChatService.lua :: ReplicatedStorage.ChatSystem.ChatService
-- SERVER-ONLY: Sets up chat channels for the new TextChatService system.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local channelManager = require(script.Parent.channelManager)
local banning = require(game.ServerScriptService.banning)
local MessageDispatcher = require(script.Parent.messageDispatcher)

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
		_annotate(string.format("Info: TextChannel '%s' already exists", definition.name))
		return existing
	end

	local createdChannel = Instance.new("TextChannel")
	createdChannel.Name = definition.name
	createdChannel.Parent = channelTabsConfig

	-- Set display name for better tab visibility
	-- Note: TextChannel doesn't have DisplayName property, tabs use Name
	-- But we ensure the channel is properly configured for tab display
	_annotate(
		string.format(
			"Created TextChannel '%s' (showInTabs=%s)",
			definition.name,
			tostring(definition.showInChannelTabs)
		)
	)
	return createdChannel
end

module.CreateChannels = function(self: Module, player: Player): {}
	if not player then
		warn("Attempt to create channels for nil player")
		return {}
	end

	_annotate(string.format("Creating channels for player %s (UserId: %d)", player.Name, player.UserId))

	local banLevel = banning.getBanLevel(player.UserId)
	if banLevel and banLevel > 0 then
		_annotate(string.format("Player %s is banned (level %d), skipping chat channel setup", player.Name, banLevel))
		return {}
	end

	_annotate(string.format("Processing %d channel definitions for player %s", #channelDefinitions, player.Name))
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
			_annotate(string.format("Adding player %s to channel %s", player.Name, definition.name))
			local success, err = pcall(function()
				channelInstance:AddUserAsync(player.UserId)
			end)
			if success then
				_annotate(string.format("Info: Player %s joined channel %s", player.Name, definition.name))
				-- Send welcome message only when channel is first created, not when later players join
				if channelWasNewlyCreated and definition.welcomeMessage and definition.welcomeMessage ~= "" then
					if not channelsWithWelcomeSent[definition.name] then
						channelsWithWelcomeSent[definition.name] = true
						task.spawn(function()
							task.wait(0.3) -- Small delay to ensure player is fully joined
							MessageDispatcher.SendSystemMessage(definition.name, definition.welcomeMessage)
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
			_annotate(
				string.format(
					"Channel %s is manual-join; skipping auto-add for player %s",
					definition.name,
					player.Name
				)
			)
		end
	end

	_annotate(string.format("Completed channel setup for player %s", player.Name))
	return {}
end

module.Init = function(self: Module)
	_annotate("Initializing chat channels")

	if TextChatService.CreateDefaultTextChannels ~= false then
		_annotate("Info: Forcing CreateDefaultTextChannels to false")
		TextChatService.CreateDefaultTextChannels = false
	end

	local channelTabsConfig = TextChatService:WaitForChild("ChannelTabsConfiguration") :: Folder
	channelDefinitions = channelManager.GetDefinitions()
	for _, definition in ipairs(channelDefinitions) do
		_annotate(
			string.format(
				"Channel definition -> name=%s autoJoin=%s allowUserMessages=%s showInTabs=%s",
				definition.name,
				tostring(definition.autoJoin),
				tostring(definition.allowUserMessages),
				tostring(definition.showInChannelTabs)
			)
		)
	end

	-- Remove existing channels to ensure correct tab order
	for _, definition in ipairs(channelDefinitions) do
		local existing = channelTabsConfig:FindFirstChild(definition.name)
		if existing and existing:IsA("TextChannel") then
			_annotate(string.format("Removing existing channel '%s' to reorder tabs", definition.name))
			existing:Destroy()
		end
	end

	-- Create channels in the correct order (order determines tab order)
	-- Small delay between each to ensure tabs appear in correct visual order
	for i, definition in ipairs(channelDefinitions) do
		_annotate(string.format("Info: Creating channel '%s' (%d/%d)", definition.name, i, #channelDefinitions))
		local channel = ensureTextChannel(definition, channelTabsConfig)
		channelManager.RegisterChannel(definition.name, channel)
		_annotate(string.format("Info: Channel '%s' created and registered", definition.name))
		-- Send welcome message when channel is first created
		if definition.welcomeMessage and definition.welcomeMessage ~= "" then
			channelsWithWelcomeSent[definition.name] = true
			task.spawn(function()
				task.wait(0.3) -- Small delay to ensure channel is ready
				MessageDispatcher.SendSystemMessage(definition.name, definition.welcomeMessage)
			end)
		end
		if i < #channelDefinitions then
			_annotate("Info: Waiting 10ms before creating next channel")
			task.wait(0.1) -- 10ms delay between channel creations
			_annotate("Info: 10ms delay complete, proceeding to next channel")
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
				_annotate(string.format("Chat input now targets channel '%s'", defaultChannel.Name))
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
		_annotate(string.format("PlayerAdded event -> provisioning channels for %s", player.Name))
		self:CreateChannels(player)
	end)

	_annotate("Chat channels initialized")
end

_annotate("end")
return module
