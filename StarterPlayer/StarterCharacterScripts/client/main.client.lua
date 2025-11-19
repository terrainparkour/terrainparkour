--!strict

-- client main loader. it loads (by requiring in order) all the client modulescripts in the client folder.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
annotater.Init()

-------- GENERAL CLIENT SETUP -----------
game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
game.Workspace.CurrentCamera.FieldOfView = (70 + (5 * 2))
local localPlayer: Player = game:GetService("Players").LocalPlayer

localPlayer.CameraMaxZoomDistance = 9999

local movement = require(game.StarterPlayer.StarterCharacterScripts.client.movement)
local morphs = require(game.StarterPlayer.StarterCharacterScripts.client.morphs)
local particles = require(game.StarterPlayer.StarterCharacterScripts.client.particles)
local userData = require(game.StarterPlayer.StarterPlayerScripts.userData)
userData.Init()
local notifyClient = require(game.StarterPlayer.StarterCharacterScripts.client.notifyClient)
local serverEvents = require(game.StarterPlayer.StarterCharacterScripts.client.serverEvents)

local MovementLogger = require(game.ReplicatedStorage.ReplayModified.Replay)

local userDataClient = require(game.StarterPlayer.StarterPlayerScripts.userDataClient)
local leaderboard = require(game.StarterPlayer.StarterCharacterScripts.lb.leaderboard)
local marathonClient = require(game.StarterPlayer.StarterCharacterScripts.client.marathonClient)
local avatarEventMonitor = require(game.StarterPlayer.StarterCharacterScripts.client.avatarEventMonitor)
local pickleballSignFade = require(game.StarterPlayer.StarterCharacterScripts.client.pickleballSignFade)
local warper = require(game.StarterPlayer.StarterPlayerScripts.warper)
local clientCommands = require(game.StarterPlayer.StarterCharacterScripts.client.clientCommands)
local textHighlighting = require(game.ReplicatedStorage.gui.textHighlighting)
local settings = require(game.ReplicatedStorage.settings)
local racing = require(game.StarterPlayer.StarterCharacterScripts.client.racing)
local shiftLock = require(game.StarterPlayer.StarterCharacterScripts.client.shiftLock)
-- local character: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait()
-- local humanoid: Humanoid = character:WaitForChild("Humanoid") :: Humanoid
local localSignClickability = require(game.StarterPlayer.StarterPlayerScripts.guis.localSignClickability)
-- local avatarManipulation = require(game.ReplicatedStorage.avatarManipulation)
local keyboard = require(game.StarterPlayer.StarterCharacterScripts.client.keyboard)
-- local aet = require(game.ReplicatedStorage.avatarEventTypes)
local resetCharacterSetup = require(game.StarterPlayer.StarterCharacterScripts.client.resetCharacterSetup)
local drawRunResultsGui = require(game.ReplicatedStorage.gui.runresults.drawRunResultsGui)
local drawWRHistoryProgressionGui = require(game.ReplicatedStorage.gui.menu.drawWRHistoryProgressionGui)
local contestButtonGetter = require(game.StarterPlayer.StarterPlayerScripts.buttons.contestButtonGetter)
-- chatClient is now a LocalScript that runs automatically

---------- CALL INIT ON ALL THOSE THINGS SINCE THEY'RE STILL LOADED ONLY ONE TIME even if the user resets or dies etc. -----------
local setup = function()
	-- chatClient now runs as a LocalScript automatically

	annotater.Profile("settings.Reset", function()
		settings.Reset()
	end)

	-- character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	-- humanoid = character:WaitForChild("Humanoid") :: Humanoid
	annotater.Profile("userDataClient.Init", function()
		userDataClient.Init()
	end)
	annotater.Profile("movement.Init", function()
		movement.Init()
	end)
	annotater.Profile("morphs.Init", function()
		morphs.Init()
	end)
	annotater.Profile("MovementLogger.Init", function()
		MovementLogger.Init()
	end)

	annotater.Profile("particles.Init", function()
		particles.Init()
	end)
	annotater.Profile("notifyClient.Init", function()
		notifyClient.Init()
	end)
	annotater.Profile("serverEvents.Init", function()
		serverEvents.Init()
	end)
	annotater.Profile("leaderboard.Init", function()
		leaderboard.Init()
	end)
	annotater.Profile("marathonClient.Init", function()
		marathonClient.Init()
	end)
	annotater.Profile("avatarEventMonitor.Init", function()
		avatarEventMonitor.Init()
	end)
	annotater.Profile("pickleballSignFade.Init", function()
		pickleballSignFade.Init()
	end)
	annotater.Profile("warper.Init", function()
		warper.Init()
	end)
	annotater.Profile("clientCommands.Init", function()
		clientCommands.Init()
	end)
	annotater.Profile("textHighlighting.Init", function()
		textHighlighting.Init()
	end)
	annotater.Profile("localSignClickability.Init", function()
		localSignClickability.Init()
	end)
	annotater.Profile("keyboard.Init", function()
		keyboard.Init()
	end)
	annotater.Profile("resetCharacterSetup.Init", function()
		resetCharacterSetup.Init()
	end)
	annotater.Profile("drawRunResultsGui.Init", function()
		drawRunResultsGui.Init()
	end)
	annotater.Profile("drawWRHistoryProgressionGui.Init", function()
		drawWRHistoryProgressionGui.Init()
	end)
	annotater.Profile("contestButtonGetter.Init", function()
		contestButtonGetter.Init()
	end)
	annotater.Profile("shiftLock.Init", function()
		shiftLock.Init()
	end)
	-- you can't race til everything is set up.
	annotater.Profile("racing.Init", function()
		racing.Init()
	end)
	_annotate("client main setup done.")
end

setup()

-- Set Chat tab as active after all initialization is complete
-- Set a few other channels first to wake up the tab system, then set Chat
task.spawn(function()
	local TextChatService = game:GetService("TextChatService")
	local inputBarConfig = TextChatService:FindFirstChild("ChatInputBarConfiguration")
	local tabsConfig = TextChatService:FindFirstChild("ChannelTabsConfiguration")

	if not inputBarConfig or not tabsConfig then
		-- Chat configurations not found after init
		return
	end

	-- Collect all available channels
	local availableChannels: { TextChannel } = {}
	for _, child in ipairs(tabsConfig:GetChildren()) do
		if child:IsA("TextChannel") then
			table.insert(availableChannels, child)
		end
	end

	if #availableChannels == 0 then
		-- No channels found after init
		return
	end

	local inputBarConfigAny = inputBarConfig :: any
	local chatChannel: TextChannel? = nil

	-- Find Chat channel
	for _, channel in ipairs(availableChannels) do
		if channel.Name == "Chat" then
			chatChannel = channel
			break
		end
	end

	if not chatChannel then
		-- Chat channel not found after init
		return
	end

	-- Set 3-4 other channels first, then Chat
	local channelsToSet: { TextChannel } = {}
	for _, channel in ipairs(availableChannels) do
		if channel ~= chatChannel then
			table.insert(channelsToSet, channel)
		end
	end

	-- Set up to 3 other channels first
	local count = math.min(3, #channelsToSet)
	for i = 1, count do
		local channel = channelsToSet[i]
		local ok, err = pcall(function()
			_annotate(string.format("[CHAT TAB] Setting channel %s first (wake up tab system)...", channel.Name))
			inputBarConfigAny.TargetTextChannel = channel
		end)
		if ok then
			_annotate(string.format("[CHAT TAB] Set to %s", channel.Name))
		else
			_annotate(string.format("[CHAT TAB] Failed to set %s: %s", channel.Name, tostring(err)))
		end
		task.wait(0.1)
	end

	-- Finally set Chat channel
	local ok, err = pcall(function()
		_annotate("[CHAT TAB] Setting Chat tab as active after cycling through other channels...")
		inputBarConfigAny.TargetTextChannel = chatChannel
	end)
	if ok then
		_annotate("[CHAT TAB] SUCCESS: Chat tab set as active after init")
	else
		_annotate(string.format("[CHAT TAB] ERROR: Failed to set Chat tab: %s", tostring(err)))
	end
end)

_annotate("end")
