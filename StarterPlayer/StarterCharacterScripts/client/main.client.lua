--!strict

-- client main loader. it loads (by requiring in order) all the client modulescripts in the client folder.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local annotater = require(ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
annotater.Init()

-------- GENERAL CLIENT SETUP -----------
local StarterGui = game:GetService("StarterGui")
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)

-- Force reset camera to ensure no lingering "Scriptable" state from previous life
local currentCam = game.Workspace.CurrentCamera
currentCam.CameraType = Enum.CameraType.Custom
-- Note: FOV and zoom are managed by cameraControlsButton.ApplySavedSettings()

local localPlayer: Player = game:GetService("Players").LocalPlayer

-- Ensure camera follows the new character
if localPlayer.Character then
	local humanoid = localPlayer.Character:FindFirstChild("Humanoid")
	if humanoid and humanoid:IsA("Humanoid") then
		currentCam.CameraSubject = humanoid
	end
end

local adminHelpTools = require(game.StarterPlayer.StarterCharacterScripts.client.adminHelpTools)
local avatarEventMonitor = require(game.StarterPlayer.StarterCharacterScripts.client.avatarEventMonitor)
local cameraControlsButton = require(game.ReplicatedStorage.gui.menu.cameraControlsButton)
local chatClient = require(game.StarterPlayer.StarterPlayerScripts.chatClient)
local clientCommands = require(game.StarterPlayer.StarterCharacterScripts.client.clientCommands)
local contestButtonGetter = require(game.StarterPlayer.StarterPlayerScripts.buttons.contestButtonGetter)
local drawRunResultGui = require(game.ReplicatedStorage.gui.runresults.drawRunResultGui)
local drawWRHistoryProgressionGui = require(game.ReplicatedStorage.gui.menu.drawWRHistoryProgressionGui)
local dynamicRunning = require(game.StarterPlayer.StarterPlayerScripts.dynamicRunning)
local fps = require(game.StarterPlayer.StarterCharacterScripts.client.fps)
local hamburger = require(game.StarterPlayer.StarterCharacterScripts.hamburger)
local handleClientMessages = require(game.StarterPlayer.StarterCharacterScripts.client.HandleClientMessages)
local keyboard = require(game.StarterPlayer.StarterCharacterScripts.client.keyboard)
local leaderboard = require(game.StarterPlayer.StarterCharacterScripts.lb.leaderboard)
local localCollisions = require(game.StarterPlayer.StarterCharacterScripts.localCollisions)
local localSignClickability = require(game.StarterPlayer.StarterPlayerScripts.guis.localSignClickability)
local marathonClient = require(game.StarterPlayer.StarterCharacterScripts.client.marathonClient)
local morphs = require(game.StarterPlayer.StarterCharacterScripts.client.morphs)
local movement = require(game.StarterPlayer.StarterCharacterScripts.client.movement)
local MovementLogger = require(game.ReplicatedStorage.ReplayModified.Replay)
local notifyClient = require(game.StarterPlayer.StarterCharacterScripts.client.notifyClient)
local particles = require(game.StarterPlayer.StarterCharacterScripts.client.particles)
local pickleballSignFade = require(game.StarterPlayer.StarterCharacterScripts.client.pickleballSignFade)
local racing = require(game.StarterPlayer.StarterCharacterScripts.client.racing)
local resetCharacterSetup = require(game.StarterPlayer.StarterCharacterScripts.client.resetCharacterSetup)
local runWidgetPicker = require(game.ReplicatedStorage.gui.activeRunWidgets.runWidgetPicker)
local serverEvents = require(game.StarterPlayer.StarterCharacterScripts.client.serverEvents)
local settings = require(game.ReplicatedStorage.settings)
local shiftLock = require(game.StarterPlayer.StarterCharacterScripts.client.shiftLock)
local signProfileDisplayer = require(game.StarterPlayer.StarterPlayerScripts.guis.signProfileDisplayer)
local signProfileSguiCreator = require(game.ReplicatedStorage.gui.signProfile.signProfileSguiCreator)
local textHighlighting = require(game.ReplicatedStorage.gui.textHighlighting)
local userData = require(game.StarterPlayer.StarterPlayerScripts.userData)
local userDataClient = require(game.StarterPlayer.StarterPlayerScripts.userDataClient)
local usersettings = require(game.StarterPlayer.StarterPlayerScripts.guis.usersettings)
local warper = require(game.StarterPlayer.StarterCharacterScripts.client.warper)
local widgetComposer = require(game.ReplicatedStorage.gui.activeRunWidgets.widgetComposer)

userData.Init()

local function runInitStep(label: string, initFn: () -> ())
	local startTime = os.clock()
	_annotate(string.format("init.%s.start", label))
	annotater.Profile(label, initFn)
	local duration = os.clock() - startTime
	_annotate(string.format("init.%s.done took %.4fs", label, duration))
end

---------- CALL INIT ON ALL THOSE THINGS SINCE THEY'RE STILL LOADED ONLY ONE TIME even if the user resets or dies etc. -----------
local setup = function()
	local totalStart = os.clock()
	_annotate("setup.start")

	local initSteps = {
		-- Session-level modules (init once, idempotent)
		{
			label = "chatClient.Init",
			run = function()
				chatClient.Init()
			end,
		},
		{
			label = "usersettings.Init",
			run = function()
				usersettings.Init()
			end,
		},
		{
			label = "signProfileDisplayer.Init",
			run = function()
				signProfileDisplayer.Init()
			end,
		},
		{
			label = "hamburger.Init",
			run = function()
				hamburger.Init()
			end,
		},
		{
			label = "handleClientMessages.Init",
			run = function()
				handleClientMessages.Init()
			end,
		},
		-- Character-level modules (reset on respawn)
		{
			label = "localCollisions.Reset",
			run = function()
				localCollisions.Reset()
			end,
		},
		{
			label = "settings.Reset",
			run = function()
				settings.Reset()
			end,
		},
		{
			label = "cameraControlsButton.ApplySavedSettings",
			run = function()
				cameraControlsButton.ApplySavedSettings()
			end,
		},
		{
			label = "fps.Init",
			run = function()
				fps.Init()
			end,
		},
		{
			label = "userDataClient.Init",
			run = function()
				userDataClient.Init()
			end,
		},
		{
			label = "movement.Init",
			run = function()
				movement.Init()
			end,
		},
		{
			label = "morphs.Init",
			run = function()
				morphs.Init()
			end,
		},
		{
			label = "MovementLogger.Init",
			run = function()
				MovementLogger.Init()
			end,
		},
		{
			label = "particles.Init",
			run = function()
				particles.Init()
			end,
		},
		{
			label = "notifyClient.Init",
			run = function()
				notifyClient.Init()
			end,
		},
		{
			label = "serverEvents.Init",
			run = function()
				serverEvents.Init()
			end,
		},
		{
			label = "leaderboard.Init",
			run = function()
				leaderboard.Init()
			end,
		},
		{
			label = "marathonClient.Init",
			run = function()
				marathonClient.Init()
			end,
		},
		{
			label = "avatarEventMonitor.Init",
			run = function()
				avatarEventMonitor.Init()
			end,
		},
		{
			label = "pickleballSignFade.Init",
			run = function()
				pickleballSignFade.Init()
			end,
		},
		{
			label = "warper.Init",
			run = function()
				warper.Init()
			end,
		},
		{
			label = "clientCommands.Init",
			run = function()
				clientCommands.Init()
			end,
		},
		{
			label = "textHighlighting.Init",
			run = function()
				textHighlighting.Init()
			end,
		},
		{
			label = "localSignClickability.Init",
			run = function()
				localSignClickability.Init()
			end,
		},
		{
			label = "keyboard.Init",
			run = function()
				keyboard.Init()
			end,
		},
		{
			label = "resetCharacterSetup.Init",
			run = function()
				resetCharacterSetup.Init()
			end,
		},
		{
			label = "drawRunResultGui.Init",
			run = function()
				drawRunResultGui.Init()
			end,
		},
		{
			label = "drawWRHistoryProgressionGui.Init",
			run = function()
				drawWRHistoryProgressionGui.Init()
			end,
		},
		{
			label = "contestButtonGetter.Init",
			run = function()
				contestButtonGetter.Init()
			end,
		},
		{
			label = "shiftLock.Init",
			run = function()
				shiftLock.Init()
			end,
		},
		{
			label = "racing.Init",
			run = function()
				racing.Init()
			end,
		},
		{
			label = "dynamicRunning.Init",
			run = function()
				dynamicRunning.Init()
			end,
		},
		{
			label = "signProfileSguiCreator.Reset",
			run = function()
				signProfileSguiCreator.Reset()
			end,
		},
		{
			label = "adminHelpTools.Init",
			run = function()
				adminHelpTools.Init()
			end,
		},
	}

	for _, step in ipairs(initSteps) do
		runInitStep(step.label, step.run)
	end

	_annotate(string.format("setup.end took %.4fs", os.clock() - totalStart))
	_annotate("client main setup done.")
end

setup()

-- Show version label in lower-left corner when in Studio
local config = require(ReplicatedStorage.config)
if config.IsInStudio() then
	local enums = require(ReplicatedStorage.util.enums)
	local fonts = require(game.StarterPlayer.StarterPlayerScripts.guis.fonts)

	local versionGui = Instance.new("ScreenGui")
	versionGui.Name = "StudioVersionGui"
	versionGui.IgnoreGuiInset = true
	versionGui.DisplayOrder = 999
	versionGui.Parent = localPlayer:WaitForChild("PlayerGui")

	local versionLabel = Instance.new("TextLabel")
	versionLabel.Name = "VersionLabel"
	versionLabel.Size = UDim2.new(0, 300, 0, 30)
	versionLabel.Position = UDim2.new(0, 10, 1, -40)
	versionLabel.AnchorPoint = Vector2.new(0, 0)
	versionLabel.BackgroundTransparency = 1
	versionLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
	versionLabel.FontFace = fonts.GetFont(true, true)
	versionLabel.TextSize = 18
	versionLabel.TextXAlignment = Enum.TextXAlignment.Left
	versionLabel.Parent = versionGui

	local function formatElapsed(seconds: number): string
		if seconds < 60 then
			return string.format("%ds", seconds)
		elseif seconds < 3600 then
			return string.format("%dm", math.floor(seconds / 60))
		else
			return string.format("%dh", math.floor(seconds / 3600))
		end
	end

	local function updateVersionText()
		local elapsed = os.time() - enums.syncTimestamp
		versionLabel.Text = string.format("%s (synced %s ago)", enums.gameVersion, formatElapsed(elapsed))
		-- Turn red if sync is stale (> 5 minutes)
		if elapsed > 300 then
			versionLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
		else
			versionLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
		end
	end

	updateVersionText()
	task.spawn(function()
		while versionLabel and versionLabel.Parent do
			task.wait(5)
			updateVersionText()
		end
	end)
end

-- Auto-open the run widget picker on game start (dev toggle in config.lua)
if config.AUTO_OPEN_WIDGET_PICKER then
	widgetComposer.Init()
	runWidgetPicker.Toggle()
end

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
		local _ok, _err = pcall(function()
			-- _annotate(string.format("Setting channel %s first (wake up tab system)...", channel.Name))
			inputBarConfigAny.TargetTextChannel = channel
		end)
		-- if ok then
		-- 	_annotate(string.format("Set to %s", channel.Name))
		-- else
		-- 	_annotate(string.format("Failed to set %s: %s", channel.Name, tostring(err)))
		-- end
		task.wait(0.1)
	end

	-- Finally set Chat channel
	local _ok, _err = pcall(function()
		-- _annotate("Setting Chat tab as active after cycling through other channels...")
		inputBarConfigAny.TargetTextChannel = chatChannel
	end)
	-- if ok then
	-- _annotate("SUCCESS: Chat tab set as active after init")
	-- else
	-- 	_annotate(string.format("ERROR: Failed to set Chat tab: %s", tostring(err)))
	-- end
end)

_annotate("end")
