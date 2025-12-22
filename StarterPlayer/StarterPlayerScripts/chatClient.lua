--!strict

-- chatClient.lua :: StarterPlayer.StarterPlayerScripts.chatClient
-- CLIENT-ONLY: Initializes the chat system on client startup.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local module = {}

-- Module internals
local ChatModule = require(ReplicatedStorage.ChatSystem.chat)
local incomingHandler = ChatModule:GetIncomingMessageHandler()
local initialized = false

local function logChannelTabs(channelTabsConfig: Instance)
	_annotate("Available TextChat channels:")
	local channelCount = 0
	for _, child in ipairs(channelTabsConfig:GetChildren()) do
		if child:IsA("TextChannel") then
			channelCount = channelCount + 1
			local channelName = child.Name
			_annotate(string.format("  - %s (should appear as tab)", channelName))
		end
	end
	_annotate(string.format("Total channels found: %d (expected: 3 public channels)", channelCount))
	if channelCount < 3 then
		_annotate("WARN: Not all public channels found! Tabs may not appear.")
	end
end

local function watchChannelTabs()
	task.spawn(function()
		_annotate("Waiting for ChannelTabsConfiguration...")
		local channelTabsConfig = TextChatService:WaitForChild("ChannelTabsConfiguration")
		_annotate("ChannelTabsConfiguration located; logging existing tabs")

		-- Wait a bit for channels to be set up on server
		task.wait(1)

		logChannelTabs(channelTabsConfig)

		-- Log again after a delay to see if channels appear
		task.spawn(function()
			task.wait(3)
			_annotate("Re-checking channels after delay...")
			logChannelTabs(channelTabsConfig)
		end)

		channelTabsConfig.ChildAdded:Connect(function(child)
			if child:IsA("TextChannel") then
				_annotate(string.format("Channel tab added: %s", child.Name))
				-- Re-log all channels when a new one is added
				task.wait(0.5)
				logChannelTabs(channelTabsConfig)
			end
		end)
		channelTabsConfig.ChildRemoved:Connect(function(child)
			if child:IsA("TextChannel") then
				_annotate(string.format("Channel tab removed: %s", child.Name))
			end
		end)
	end)
end

local function hookIncomingMessage()
	TextChatService.OnIncomingMessage = function(message: TextChatMessage): TextChatMessageProperties?
		local channelName = message.TextChannel and message.TextChannel.Name or "nil"
		local text = message.Text or ""
		_annotate(string.format("OnIncomingMessage channel=%s text=%s", channelName, text))
		local result = incomingHandler(message)
		if result then
			_annotate(string.format("Message blocked for channel=%s", channelName))
		else
			_annotate(string.format("Message allowed for channel=%s", channelName))
		end
		return result
	end

	-- Set up bubble chat suppression for slash commands
	local function onBubbleDisplayed(message: TextChatMessage, bubble: Instance)
		local messageText = message.Text or ""

		if messageText:sub(1, 1) == "/" then
			-- Suppress bubble chat for commands
			local bubbleProps = message.BubbleChatMessageProperties
			if bubbleProps then
				bubbleProps.Text = ""
				if bubbleProps.PrefixText then
					bubbleProps.PrefixText = ""
				end
			end
			-- Hide the bubble GUI itself
			if bubble:IsA("BillboardGui") then
				(bubble :: BillboardGui).Enabled = false
			elseif bubble:IsA("SurfaceGui") then
				(bubble :: SurfaceGui).Enabled = false
			elseif bubble:IsA("GuiObject") then
				(bubble :: GuiObject).Visible = false
			end
			-- Destroy the bubble
			if bubble.Parent then
				bubble:Destroy()
			end
		end
	end
	(TextChatService.BubbleDisplayed :: any):Connect(onBubbleDisplayed)
end

local function hookOutgoingMessage()
	-- Connect with highest priority to intercept commands before they're sent
	TextChatService.SendingMessage:Connect(function(message: TextChatMessage)
		local text = message.Text or ""

		if text == "" then
			return
		end

		-- Check if this is a command (starts with "/")
		if text:sub(1, 1) ~= "/" then
			return
		end

		-- CRITICAL: Clear message properties SYNCHRONOUSLY before message is sent
		-- This must happen immediately to prevent the message from appearing in chat or bubbles
		message.Text = ""

		-- Clear bubble chat properties to prevent bubble from appearing
		local bubbleProps = message.BubbleChatMessageProperties
		if bubbleProps then
			bubbleProps.Text = ""
			if bubbleProps.PrefixText then
				bubbleProps.PrefixText = ""
			end
		end

		-- Clear chat window properties to prevent message from appearing in chat window
		local windowProps = message.ChatWindowMessageProperties
		if windowProps then
			windowProps.Text = ""
			if windowProps.PrefixText then
				windowProps.PrefixText = ""
			end
		end

		-- Also clear PrefixText on the message itself if it exists
		if message.PrefixText then
			message.PrefixText = ""
		end

		-- Process the command asynchronously after clearing the message
		task.spawn(function()
			ChatModule:ProcessSlashCommand(text, message.TextChannel and message.TextChannel.Name or "RBXGeneral")
		end)
	end)
end

local function configureChatWindow()
	local chatWindowConfig = TextChatService:FindFirstChild("ChatWindowConfiguration")
	if chatWindowConfig then
		-- First, inspect all available properties on ChatWindowConfiguration
		_annotate("=== CHAT WINDOW CONFIGURATION INSPECTION ===")
		local config = chatWindowConfig :: any
		-- Inspect properties on ChatWindowConfiguration
		-- According to official docs: Position, Size (UDim2), BackgroundColor3, BackgroundTransparency,
		-- TextColor3, TextSize, Font/FontFace, TextStrokeTransparency
		local configProps = {
			"Enabled",
			"Position",
			"Size",
			"BackgroundColor3",
			"BackgroundTransparency",
			"TextColor3",
			"TextSize",
			"Font",
			"FontFace",
			"TextStrokeTransparency",
			"TargetTextChannel",
		}
		for _, propName in ipairs(configProps) do
			local success, value = pcall(function()
				return config[propName]
			end)
			if success then
				_annotate(string.format("ChatWindowConfiguration.%s = %s", propName, tostring(value)))
			else
				_annotate(string.format("ChatWindowConfiguration.%s = (not accessible)", propName))
			end
		end
		_annotate("=== END CONFIGURATION INSPECTION ===")

		local ok, err = pcall(function()
			config.Enabled = true

			-- Set position: 10% from left, 10% from top (per official docs example)
			if config.Position ~= nil then
				config.Position = UDim2.new(0.1, 0, 0.1, 0)
			end

			-- Set size: 50% width, 50% height (programmatic only, users cannot resize)
			if config.Size ~= nil then
				config.Size = UDim2.new(0.5, 0, 0.5, 0)
			end

			-- Set background color and transparency
			if config.BackgroundColor3 ~= nil then
				config.BackgroundColor3 = Color3.fromRGB(30, 30, 30) -- Lighter gray than default black
			end
			config.BackgroundTransparency = 0 -- No transparency (0 = fully opaque)

			-- Verify the values were set
			_annotate(
				string.format(
					"After setting: Position=%s, Size=%s, BackgroundTransparency=%s",
					tostring(config.Position),
					tostring(config.Size),
					tostring(config.BackgroundTransparency)
				)
			)
			_annotate("Info: Chat window configured per official docs (Position/Size via UDim2, lighter background, no transparency)")

			-- Re-inspect configuration after a moment to see if values stuck
			task.spawn(function()
				task.wait(0.5)
				_annotate("=== RE-INSPECTING CONFIGURATION AFTER SETTING VALUES ===")
				if config.Position ~= nil then
					_annotate(string.format("Position now: %s", tostring(config.Position)))
				end
				if config.Size ~= nil then
					_annotate(string.format("Size now: %s", tostring(config.Size)))
				end
				_annotate(string.format("BackgroundTransparency now: %s", tostring(config.BackgroundTransparency)))
				_annotate("=== END RE-INSPECTION ===")
			end)

			-- Inspect the chat GUI structure to understand what we're working with
			task.spawn(function()
				-- Wait for chat UI to be created - try multiple times with increasing delays
				local localPlayer = Players.LocalPlayer
				if localPlayer then
					local playerGui = localPlayer:WaitForChild("PlayerGui")

					-- Try to find Chat GUI multiple times
					-- In TextChatService, the GUI might be named differently or nested
					local chatGui: Instance? = nil
					for attempt = 1, 10 do
						task.wait(0.5)

						-- Try different possible names/locations
						chatGui = playerGui:FindFirstChild("Chat")
						if not chatGui then
							chatGui = playerGui:FindFirstChild("ChatWindow")
						end
						if not chatGui then
							chatGui = playerGui:FindFirstChild("TextChatService")
						end

						-- Also search in descendants
						if not chatGui then
							for _, child in ipairs(playerGui:GetDescendants()) do
								local name = string.lower(child.Name)
								if string.find(name, "chat") and (child:IsA("ScreenGui") or child:IsA("Frame")) then
									chatGui = child
									_annotate(string.format("Found chat-related GUI: %s", child:GetFullName()))
									break
								end
							end
						end

						if chatGui then
							_annotate(string.format("Chat GUI found on attempt %d: %s", attempt, chatGui:GetFullName()))
							break
						end
						if attempt <= 3 then
							_annotate(string.format("Attempt %d: Chat GUI not found yet, waiting...", attempt))
						end
					end

					if chatGui then
						_annotate("=== CHAT GUI INSPECTION ===")
						_annotate(string.format("Chat GUI found: %s", chatGui:GetFullName()))
						_annotate(string.format("Chat GUI ClassName: %s", chatGui.ClassName))

						-- Recursively inspect the GUI tree
						local function inspectGUI(parent: Instance, depth: number)
							local indent = string.rep("  ", depth)
							local prefix = indent .. "├─ "

							-- Log this instance's key properties
							if parent:IsA("Frame") or parent:IsA("ScrollingFrame") then
								local frame = parent :: Frame
								_annotate(string.format("%s%s (%s)", prefix, parent.Name, parent.ClassName))
								_annotate(string.format("%s  Size: %s", indent, tostring(frame.Size)))
								_annotate(string.format("%s  Position: %s", indent, tostring(frame.Position)))
								_annotate(string.format("%s  AbsoluteSize: %s", indent, tostring(frame.AbsoluteSize)))
								_annotate(string.format("%s  AbsolutePosition: %s", indent, tostring(frame.AbsolutePosition)))
								_annotate(string.format("%s  BackgroundColor3: %s", indent, tostring(frame.BackgroundColor3)))
								_annotate(string.format("%s  BackgroundTransparency: %s", indent, tostring(frame.BackgroundTransparency)))
								_annotate(string.format("%s  BorderSizePixel: %s", indent, tostring(frame.BorderSizePixel)))
								if frame:IsA("ScrollingFrame") then
									local scroll = frame :: ScrollingFrame
									_annotate(string.format("%s  CanvasSize: %s", indent, tostring(scroll.CanvasSize)))
									_annotate(string.format("%s  ScrollBarThickness: %s", indent, tostring(scroll.ScrollBarThickness)))
								end
							elseif parent:IsA("TextLabel") or parent:IsA("TextButton") or parent:IsA("TextBox") then
								local text = parent :: TextLabel | TextButton | TextBox
								_annotate(string.format("%s%s (%s)", prefix, parent.Name, parent.ClassName))
								_annotate(string.format("%s  Size: %s", indent, tostring(text.Size)))
								_annotate(string.format("%s  Position: %s", indent, tostring(text.Position)))
								_annotate(string.format("%s  Text: %s", indent, string.sub(tostring(text.Text), 1, 50)))
								_annotate(string.format("%s  TextColor3: %s", indent, tostring(text.TextColor3)))
								_annotate(string.format("%s  TextSize: %s", indent, tostring(text.TextSize)))
							elseif parent:IsA("ImageButton") or parent:IsA("ImageLabel") then
								local image = parent :: ImageButton | ImageLabel
								_annotate(string.format("%s%s (%s)", prefix, parent.Name, parent.ClassName))
								_annotate(string.format("%s  Size: %s", indent, tostring(image.Size)))
								_annotate(string.format("%s  Position: %s", indent, tostring(image.Position)))
								_annotate(string.format("%s  Image: %s", indent, string.sub(tostring(image.Image), 1, 50)))
							else
								_annotate(string.format("%s%s (%s)", prefix, parent.Name, parent.ClassName))
							end

							-- Inspect children (limit depth to avoid spam)
							if depth < 5 then
								for _, child in ipairs(parent:GetChildren()) do
									inspectGUI(child, depth + 1)
								end
							elseif #parent:GetChildren() > 0 then
								_annotate(string.format("%s  ... (%d more children)", indent, #parent:GetChildren()))
							end
						end

						-- Start inspection from the Chat GUI root
						inspectGUI(chatGui, 0)
						_annotate("=== END CHAT GUI INSPECTION ===")
					else
						_annotate("Warn: Chat GUI not found in PlayerGui")
					end
				end
			end)
		end)
		if not ok then
			_annotate(string.format("Warn: Failed to configure ChatWindowConfiguration (%s)", tostring(err)))
		else
			_annotate("Info: Chat window enabled and customized")
		end
	else
		_annotate("Warn: ChatWindowConfiguration not found")
	end

	-- Configure ChatInputBarConfiguration
	local chatInputBarConfig = TextChatService:FindFirstChild("ChatInputBarConfiguration")
	if chatInputBarConfig then
		local ok, err = pcall(function()
			local config = chatInputBarConfig :: any

			-- Change placeholder text via TextBox property
			-- The placeholder text is on the TextBox, not directly on ChatInputBarConfiguration
			if config.TextBox then
				local textBox = config.TextBox :: TextBox
				textBox.PlaceholderText = "Type to chat..." -- Custom placeholder text
				_annotate("Info: Chat input placeholder text set")
			end

			-- Ensure input bar targets Chat channel (server sets this too, but ensure it on client)
			task.spawn(function()
				task.wait(0.5) -- Wait for channels to be created by server
				local channelTabsConfig = TextChatService:FindFirstChild("ChannelTabsConfiguration")
				if channelTabsConfig then
					local chatChannel = channelTabsConfig:FindFirstChild("Chat")
					if chatChannel and chatChannel:IsA("TextChannel") then
						local ok2, err2 = pcall(function()
							config.TargetTextChannel = chatChannel
						end)
						if ok2 then
							_annotate("Info: Chat input bar now targets Chat channel")
						else
							_annotate(string.format("Warn: Failed to set ChatInputBarConfiguration.TargetTextChannel (%s)", tostring(err2)))
						end
					end
				end
			end)

			-- Try to customize the send button
			task.spawn(function()
				task.wait(1) -- Wait for chat UI to initialize
				local localPlayer = Players.LocalPlayer
				if localPlayer then
					local playerGui = localPlayer:WaitForChild("PlayerGui")
					local chatGui = playerGui:FindFirstChild("Chat")
					if chatGui then
						-- Look for the send button (it's usually an ImageButton or TextButton)
						local function hideSendButton(parent: Instance)
							local descendants = parent:GetDescendants()
							for i = 1, #descendants do
								local child: Instance = descendants[i]
								if child:IsA("ImageButton") then
									local name = string.lower(child.Name)
									if string.find(name, "send") or string.find(name, "arrow") or string.find(name, "submit") then
										(child :: ImageButton).Visible = false
										_annotate(string.format("Info: Hidden send button: %s", child:GetFullName()))
									end
								elseif child:IsA("TextButton") then
									local name = string.lower(child.Name)
									if string.find(name, "send") or string.find(name, "arrow") or string.find(name, "submit") then
										(child :: TextButton).Visible = false
										_annotate(string.format("Info: Hidden send button: %s", child:GetFullName()))
									end
								end
							end
						end
						hideSendButton(chatGui)
					end
				end
			end)

			_annotate("Info: Chat input bar configured")
		end)
		if not ok then
			_annotate(string.format("Warn: Failed to configure ChatInputBarConfiguration (%s)", tostring(err)))
		end
	else
		_annotate("Warn: ChatInputBarConfiguration not found")
	end

	-- Ensure ChannelTabsConfiguration is enabled
	local channelTabsConfig = TextChatService:FindFirstChild("ChannelTabsConfiguration")
	if channelTabsConfig then
		local ok, err = pcall(function()
			(channelTabsConfig :: any).Enabled = true
		end)
		if not ok then
			_annotate(string.format("Warn: Failed to set ChannelTabsConfiguration.Enabled (%s)", tostring(err)))
		else
			_annotate("Info: Channel tabs configuration enabled")
		end
	end

	-- Set Chat channel as active tab on startup
	task.spawn(function()
		local inputBarConfig = TextChatService:FindFirstChild("ChatInputBarConfiguration")
		local tabsConfig = TextChatService:FindFirstChild("ChannelTabsConfiguration")

		if not inputBarConfig then
			return
		end

		if not tabsConfig then
			return
		end

		-- Wait for Chat channel to be created by server
		local chatChannel = tabsConfig:WaitForChild("Chat", 10)

		if not chatChannel or not chatChannel:IsA("TextChannel") then
			return
		end

		-- Wait for chat UI to be visible before setting target
		local windowConfig = TextChatService:FindFirstChild("ChatWindowConfiguration")
		if windowConfig then
			local windowConfigAny = windowConfig :: any

			-- Wait for window to be enabled, with timeout
			local startTime = tick()
			local timeout = 5

			while (tick() - startTime) < timeout do
				local ok, enabled = pcall(function()
					return windowConfigAny.Enabled
				end)
				if ok and enabled then
					break
				end
				task.wait(0.1)
			end
		end

		-- Set Chat channel as the target to make it the active tab
		local inputBarConfigAny = inputBarConfig :: any

		pcall(function()
			inputBarConfigAny.TargetTextChannel = chatChannel
		end)
	end)

	-- Disable bubble chat
	local bubbleConfig = TextChatService:FindFirstChild("BubbleChatConfiguration")
	if bubbleConfig then
		local ok, err = pcall(function()
			(bubbleConfig :: any).Enabled = false
		end)
		if not ok then
			_annotate(string.format("Warn: Failed to disable BubbleChatConfiguration (%s)", tostring(err)))
		else
			_annotate("Info: Bubble chat disabled")
		end
	end
end

function module.Init()
	-- Guard against double-init (idempotent)
	if initialized then
		_annotate("already initialized, skipping")
		return
	end
	initialized = true

	_annotate("Client chat bootstrap starting")

	_annotate(string.format("TextChatService.ChatVersion: %s", tostring(TextChatService.ChatVersion)))
	_annotate(string.format("TextChatService.CreateDefaultTextChannels: %s", tostring(TextChatService.CreateDefaultTextChannels)))

	-- CRITICAL: Set up message hooks FIRST to intercept commands before they're sent
	hookOutgoingMessage()
	hookIncomingMessage()

	watchChannelTabs()
	configureChatWindow()

	_annotate("Client chat bootstrap complete")
end

_annotate("end")
return module

