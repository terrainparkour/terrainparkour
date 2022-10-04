--!strict

-- 4.29.2022 redo to trust client
--eval 9.25.22
-- completely locally track times and then just hit the endpoint with what they are
-- What is this: the guy who does local tracking of the time for a run.

local enums = require(game.ReplicatedStorage.util.enums)
local colors = require(game.ReplicatedStorage.util.colors)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local remotes = require(game.ReplicatedStorage.util.remotes)
local marathonClient = require(game.StarterPlayer.StarterCharacterScripts.marathon.marathonClient)
local movementEnums = require(game.StarterPlayer.StarterCharacterScripts.movementEnums)
local speedEvents = require(game.StarterPlayer.StarterCharacterScripts.speedEvents)
local dynamicRunning = require(game.ReplicatedStorage.dynamicRunning)

local PlayersService = game:GetService("Players")
local localPlayer: Player = PlayersService.LocalPlayer

local playerGui = localPlayer:WaitForChild("PlayerGui")
local warper = require(game.ReplicatedStorage.warper)

--script globals - directly set with updated info when messages come over the wire.
local currentRunStartTick: number = 0
local currentRunSignName: string = ""

local clientTouchDebounce: { [string]: boolean } = {}
local lastRunCompleteTime = 0

--can user touch signs at all (or are they in the middle of a warp)
local canDoAnything = true

--the start position of the initial sign in a race.
local currentRunStartPosition = nil

--some kinda debouncer
local runShouldEndSemaphore = false

local cancelRunRemoteFunction = remotes.getRemoteFunction("CancelRunRemoteFunction")
local clientControlledRunEndEvent = remotes.getRemoteEvent("ClientControlledRunEndEvent")

---------ANNOTATION----------------
local doAnnotation = false
	or localPlayer.Name == "TerrainParkour"
	or localPlayer.Name == "Player2"
	or localPlayer.Name == "Player1"
doAnnotation = false
local annotationStart = tick()
local function annotate(s: string)
	if doAnnotation then
		print("client2." .. string.format("%.7f", tick() - annotationStart) .. " : " .. s)
	end
end

local function killClientRun(context: string)
	annotate("kill.run from " .. currentRunSignName .. " cause: " .. context)
	currentRunStartTick = 0
	currentRunSignName = ""
	cancelRunRemoteFunction:InvokeServer()
	local sgui = playerGui:FindFirstChild("RunningRunSgui")
	if sgui ~= nil then
		sgui:Destroy()
	end
	dynamicRunning.endDynamic()
end

--the one in the lower left, where you can cancel out of a race.
local debounceCreateRunProgressSgui = false
local function createRunProgressSgui()
	if debounceCreateRunProgressSgui then
		return
	end
	debounceCreateRunProgressSgui = true
	local sgui: ScreenGui = playerGui:FindFirstChild("RunningRunSgui") :: ScreenGui
	if not sgui then
		sgui = Instance.new("ScreenGui")
		sgui.Parent = playerGui
		sgui.Name = "RunningRunSgui"
		sgui.Enabled = true
	end

	local tb = Instance.new("TextButton")
	tb.Parent = sgui
	tb.Name = "RaceRunningButton"
	tb.Size = UDim2.new(0.57, 0, 0.1, 0)
	tb.Position = UDim2.new(0.0, 0, 0.9, 0)
	tb.TextTransparency = 0
	tb.BackgroundTransparency = 1
	tb.TextScaled = true
	tb.TextColor3 = colors.yellow
	tb.TextXAlignment = Enum.TextXAlignment.Left
	tb.Text = ""
	tb.Font = Enum.Font.GothamBlack
	tb.TextTransparency = 0
	tb.Activated:Connect(function()
		killClientRun("unclick progress")
	end)
	debounceCreateRunProgressSgui = false
end

--what to display on the 'race active' label in LL
local function getRacingText()
	local use = 0
	if currentRunStartTick == 0 then
		return ""
	end
	if currentRunStartTick ~= 0 then
		use = tick() - currentRunStartTick
	end
	if currentRunSignName == "" then
		return ""
	end
	if
		localPlayer == nil
		or localPlayer.Character == nil
		or localPlayer.Character.PrimaryPart == nil
		or currentRunSignName == ""
	then
		return ""
	end

	local pos = localPlayer.Character.PrimaryPart.Position
	local distance = tpUtil.getDist(pos, currentRunStartPosition)
	local text = string.format("%.1f\nRacing From: %s (%.1fd)", use, currentRunSignName, distance)
	return text
end

local doNotCheckInGameIdentifier = require(game.ReplicatedStorage:FindFirstChild("doNotCheckInGameIdentifier"))
local newMovement = doNotCheckInGameIdentifier.useNewMovement()
--send "run ended" to server.  server still handles FINDs
--somehow when player1 hits this, player2 is triggered.
local function clientTouchedSign(humanoid: Humanoid, sign: BasePart, signId: number)
	if not canDoAnything then
		annotate("blocked til warp done.")
		return
	end
	annotate("hit")
	if newMovement then
		speedEvents.addEvent({ timems = tick(), type = movementEnums.SpeedEventName2Id.TOUCHSIGN })
	end
	local par = humanoid.Parent :: Instance
	local pn = par.Name
	if clientTouchDebounce[pn] then
		return
	end
	clientTouchDebounce[pn] = true
	local touchTimeTick = tick()
	local gapSinceLastRun = touchTimeTick - lastRunCompleteTime
	if gapSinceLastRun < 0.8 then
		clientTouchDebounce[pn] = false
		return false
	end

	if pn ~= localPlayer.Name then
		--i set up global hit monitoring for all signs by anyone, and other players are in my local DM, so of course when they hit, I notice
		annotate("somehow got a note for other players hit.")
		return
	end
	--hit is valid.

	--notify marathon ui
	marathonClient.receiveHit(sign.Name, touchTimeTick)

	----NEW HIT AREA START, RETURNED--------
	if currentRunSignName == "" then
		if warper.isWarping() then
			clientTouchDebounce[pn] = false
			annotate("blocked due to iswarping.")
			return false
		end
		currentRunSignName = sign.Name
		annotate("starting.run from " .. currentRunSignName)
		currentRunStartTick = touchTimeTick
		currentRunStartPosition = sign.Position
		createRunProgressSgui()

		--spin up something monitoring progress
		spawn(function()
			while true do
				if runShouldEndSemaphore then
					killClientRun("semaphore1")
					runShouldEndSemaphore = false
					break
				end
				wait(1 / 60)
				if runShouldEndSemaphore then
					killClientRun("semaphore2")
					runShouldEndSemaphore = false
					break
				end
				local sgui = playerGui:FindFirstChild("RunningRunSgui") :: ScreenGui?
				if sgui == nil then
					killClientRun("nil label")
					break
				end
				local nnsgui = sgui :: ScreenGui
				local racingText = getRacingText()
				if racingText == "" then
					killClientRun("notext")
					break
				end

				local tl = nnsgui:FindFirstChild("RaceRunningButton") :: TextLabel
				tl.Text = racingText
				-- annotate("roll through checking loop")
			end
		end)
		annotate("started.run from " .. currentRunSignName)
		clientTouchDebounce[pn] = false
		dynamicRunning.startDynamic(localPlayer, sign.Name, touchTimeTick)
		return
	end
	if sign.Name == currentRunSignName then
		annotate(string.format("reset time by %0.4f", touchTimeTick - currentRunStartTick))
		currentRunStartTick = touchTimeTick
		clientTouchDebounce[pn] = false
		dynamicRunning.resetDynamicTiming(localPlayer, sign.Name, touchTimeTick)
		return
	end

	----NEW HIT AREA END, RETURNED--------

	--hit is valid and ends run.
	local gapTick = touchTimeTick - currentRunStartTick
	annotate(string.format("telling server user finished %s %s in %0.3f", currentRunSignName, sign.Name, gapTick))
	dynamicRunning.endDynamic()
	clientControlledRunEndEvent:FireServer(currentRunSignName, sign.Name, math.floor(gapTick * 1000))
	currentRunSignName = ""
	currentRunStartTick = 0
	runShouldEndSemaphore = true
	--set this to debounce new run starts immediately.
	lastRunCompleteTime = tick()
	clientTouchDebounce[pn] = false
end

local function setupCharacter()
	annotate("localtimer init start CA")
	canDoAnything = true

	local char: Model = localPlayer.Character
	local hum: Humanoid = char:WaitForChild("Humanoid", 5) :: Humanoid

	hum.Died:Connect(function()
		warper.blockWarping("died")
	end)

	hum.Touched:Connect(function(hit)
		annotate("hit ")
		if hit.ClassName == "Terrain" then
			return
		end
		if hit.ClassName == "SpawnLocation" then
			return
		end
		if hit.ClassName == "Part" or hit.ClassName == "MeshPart" then
			local signId = enums.name2signId[hit.Name]
			if signId == nil then
				return
			end
			clientTouchedSign(hum, hit, signId)
		end
	end)
	warper.unblockWarping("new char unblock")
end

local function init()
	--client-side setup touch listening for this player.
	--assume this sees all signs.
	annotate("localtimer init start")
	local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	setupCharacter()
	localPlayer.CharacterAdded:Connect(setupCharacter)
	localPlayer.CharacterRemoving:Connect(function(character)
		warper.blockWarping("char removing")
	end)

	--when the user warps, kill active runs
	warper.addCallbackToWarpStart(function()
		-- annotate("locked run due to warping")
		canDoAnything = false
		killClientRun("warping event received.")
	end)

	warper.addCallbackToWarpEnd(function()
		-- annotate("unlocked")
		-- print("warp end callback re-enabling doing anything.")
		canDoAnything = true
	end)

	local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	if character == nil then
		killClientRun("no char")
		error("no char")
	end
	local hum: Humanoid = character:WaitForChild("Humanoid")
	if hum == nil then
		killClientRun("no hum")
		error("no hum")
	end
	hum.Died:Connect(function()
		canDoAnything = false
		killClientRun("Died")
	end)
end

init()
