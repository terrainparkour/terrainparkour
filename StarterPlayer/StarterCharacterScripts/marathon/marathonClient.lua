--!strict
--eval 9.25.22
--2022.02.13 split it from main leaderboard code.

local module = {}

local PlayersService = game:GetService("Players")
local localPlayer = PlayersService.LocalPlayer

local enums = require(game.ReplicatedStorage.util.enums)
local colors = require(game.ReplicatedStorage.util.colors)

local marathonstatic = require(game.StarterPlayer.StarterCharacterScripts.marathon["marathon.static"])
local warper = require(game.ReplicatedStorage.warper)
--global storage for user's lbframe
local lbframe: Frame
local lbMarathonRowY = 18
local rf = require(game.ReplicatedStorage.util.remotes)

local mt = require(game.StarterPlayer.StarterCharacterScripts.marathon.marathonTypes)
local joinableMarathonKinds: { mt.marathonDescriptor } = {}

local marathonCompleteEvent = rf.getRemoteEvent("MarathonCompleteEvent")
local ephemeralMarathonCompleteEvent = rf.getRemoteEvent("EphemeralMarathonCompleteEvent")
if marathonCompleteEvent == nil or ephemeralMarathonCompleteEvent == nil then
	warn("FAIL")
end

local doAnnotation = localPlayer.UserId == enums.objects.TerrainParkour and false
local function annotate(s): nil
	if doAnnotation then
		print("marathon.client: " .. string.format("%.0f", tick()) .. " : " .. s)
	end
end

local function startMarathonRunTimer(desc: mt.marathonDescriptor, baseTime: number)
	desc.startTime = baseTime
	if desc.runningTimeTileUpdater then
		-- annotate("runtimer.not start for." .. desc.kind)
		return
	end
	spawn(function()
		-- annotate("runtimer.start for." .. desc.kind)
		desc.runningTimeTileUpdater = true
		while true do
			if desc.killTimerSemaphore then
				-- annotate("runtimer.break for." .. desc.kind)
				desc.killTimerSemaphore = false
				desc.runningTimeTileUpdater = false
				break
			end
			wait(1 / 3.1)
			local gap = tick() - baseTime
			desc.timeTile.Text = string.format("%0.0f", gap)
		end
	end)
end

local function stopTimerForKind(desc: mt.marathonDescriptor): boolean
	-- annotate("stopTimerForKind.start." .. desc.kind)
	if not desc.runningTimeTileUpdater then
		-- annotate("stopTimerForKind.was not running." .. desc.kind)
		return true
	end
	-- annotate("stopTimerForKind.set semaphore." .. desc.kind)
	desc.killTimerSemaphore = true --wait til the timer catches this and dies.
	local ii = 0
	while true do
		ii += 1
		wait(1 / 25.1)
		-- annotate("stopTimerForKind.looping." .. desc.kind)
		if not desc.runningTimeTileUpdater then
			-- annotate("stopTimerForKind.inner break" .. desc.kind)
			return true
		end
		if ii > 20 then --TODO this is a hack.
			-- annotate("stopTimerForKind.assuming timer stopped." .. desc.kind)
			desc.runningTimeTileUpdater = false
			return true
		end
	end
end

local function resetMarathonProgress(desc: mt.marathonDescriptor)
	local stopped = stopTimerForKind(desc)
	module.InitMarathonVisually(desc)
	desc.startTime = nil
	desc.killTimerSemaphore = false
	desc.count = 0
	desc.finds = {}
	desc.addDebounce = {}

	-- annotate("resetMarathon.end." .. desc.kind)
end

--get or create frame; swap out the tiles with new ones.
module.InitMarathonVisually = function(desc: mt.marathonDescriptor)
	-- annotate("initMarathonVisually.start." .. desc.highLevelType .. "_" .. desc.sequenceNumber)

	local frameName = marathonstatic.getMarathonKindFrameName(desc)
	local exi: Frame = lbframe:FindFirstChild(frameName)
	if exi == nil then
		--this happens the first time you start a marathon from client-side.
		exi = Instance.new("Frame")
		exi.BorderMode = Enum.BorderMode.Inset
		exi.BorderSizePixel = 0
		exi.Name = frameName
		exi.Size = UDim2.new(1, 0, 0, lbMarathonRowY)
		exi.Parent = lbframe
	end
	--swap out tiles
	local tiles = marathonstatic.getMarathonInnerTiles(desc, lbframe.AbsoluteSize)
	for _, tile in ipairs(tiles) do
		local exiTile = exi:FindFirstChild(tile.Name)
		if exiTile ~= nil then
			exiTile:Destroy()
		end
		tile.Parent = exi
	end
	local resetTile = marathonstatic.getMarathonResetTile(desc)
	local exiTile = exi:FindFirstChild(resetTile.Name)
	if exiTile ~= nil then
		exiTile:Destroy()
	end
	resetTile.Activated:Connect(function()
		-- annotate("resetTile.clicked.")
		resetMarathonProgress(desc)
		-- annotate("resetTile.done")
	end)
	resetTile.Parent = exi

	exi.Parent = lbframe
end

--handle the juggling of marathonKindFinds keys and stuff.

local function tellDescAboutFind(desc: mt.marathonDescriptor, signName: string): mt.userFoundSignResult
	if desc.addDebounce[signName] then
		return { added = false, marathonDone = false, started = false }
	end
	desc.addDebounce[signName] = true
	--special exclusion case:
	--if the timer is NOT running but we are done.
	if not desc.runningTimeTileUpdater then --not being updated atm.
		if desc.count ~= nil and desc.count > 0 then
			--note that this will spam logs for hitting sign 20 times while first one is being processed
			-- annotate("dofind.skipping find due to marathon being done. kind" .. desc.kind)
			return { added = false, marathonDone = false, started = false }
		end
	end

	if desc.count == nil then
		desc.count = 0
	end

	local ret = desc.EvaluateFind(desc, signName)
	desc.addDebounce[signName] = false
	return ret
end

local function updateTimeTileForKindToCompletion(runMilliseconds: number, timeTile: TextLabel)
	--restrore tile to marathon finish time.
	timeTile.Text = string.format("%0.3f", runMilliseconds / 1000.0)
	timeTile.BackgroundColor3 = colors.blueDone
end

--kill the ongoing update timer.  set  the final time and background blue.
local function finishMarathonVisually(desc: mt.marathonDescriptor, runMilliseconds: number, marathonRow: Frame)
	-- annotate("finishMarathonVisually.start." .. desc.kind)
	stopTimerForKind(desc)
	updateTimeTileForKindToCompletion(runMilliseconds, desc.timeTile)
	-- annotate("finishMarathonVisually.end." .. desc.kind)
end

local function reportEphemeralMarathonResults(desc: mt.marathonDescriptor, runMilliseconds)
	local orderedSignIds = desc.SummarizeResults(desc)
	local joined = table.concat(orderedSignIds, ",")
	local s, e = pcall(function()
		ephemeralMarathonCompleteEvent:FireServer(desc.kind, joined, runMilliseconds)
	end)
	if not s then
		warn(e)
	end
end

--look in the datastores and figure out something to upload to the endpoint.
--can require munging aound
local function reportMarathonResults(desc: mt.marathonDescriptor, runMilliseconds)
	local orderedSignIds = desc.SummarizeResults(desc)
	local joined = table.concat(orderedSignIds, ",")
	local s, e = pcall(function()
		marathonCompleteEvent:FireServer(desc.kind, joined, runMilliseconds)
	end)
	if not s then
		warn(e)
	end
end

local function innerReceiveHit(desc: mt.marathonDescriptor, signName: string)
	local res = tellDescAboutFind(desc, signName)
	if res == nil then
		warn("NIL")
		return
	end
	if not res.added then
		return
	end
	-- annotate("innerReceiveHit.signName=" .. signName .. " kind=" .. desc.kind)
	-- annotate("innerReceiveHit.added?" .. tostring(res.added))
	-- annotate("innerReceiveHit.marathonDone?" .. tostring(res.marathonDone))
	-- annotate("innerReceiveHit.started?" .. tostring(res.started))

	local frameName = marathonstatic.getMarathonKindFrameName(desc)
	local marathonRow: Frame = lbframe:FindFirstChild(frameName)

	--NOTE: Why do this here, separated, not above in evaluateFind?
	desc.UpdateRow(desc, marathonRow, signName)
	--previously this also initialized them visually.

	if res.started then
		-- annotate("innerReceiveHit.res-started.start")
		startMarathonRunTimer(desc, tick())
		-- annotate("innerReceiveHit.res-started.end")
	end

	if res.marathonDone then
		-- annotate("innerReceiveHit.marathonDone.start")
		local completionTime = tick() - desc.startTime
		local runMilliseconds = math.round(completionTime * 1000)
		finishMarathonVisually(desc, runMilliseconds, marathonRow)
		if desc.highLevelType == "randomrace" then
			reportEphemeralMarathonResults(desc, runMilliseconds)
		else
			reportMarathonResults(desc, runMilliseconds)
		end
		-- annotate("innerReceiveHit.marathonDone.end")
	end
	-- annotate("innerReceiveHit.end")
end

--blocker to confirm the user has completed warp
local canDoAnything = true

module.receiveHit = function(signName: string, _: number)
	-- annotate("marathon receive hit ." .. signName)
	if not canDoAnything then
		-- annotate("can't do anything while warping so skipping.")
		return
	end
	-- annotate("received hit in marathon.")
	for _, desc: mt.marathonDescriptor in ipairs(joinableMarathonKinds) do
		if warper.isWarping() then
			break
		end
		-- annotate("receiveHit " .. desc.kind .. signName)
		innerReceiveHit(desc, signName)
	end
end

local function onWarpStart()
	canDoAnything = false
	-- annotate("init.callback.warped.start")
	-- annotate("reset all marathon.")
	for _, desc: mt.marathonDescriptor in ipairs(joinableMarathonKinds) do
		spawn(function()
			resetMarathonProgress(desc)
		end)
	end
	-- annotate("init.callback.warped.end")
end

local function onWarpEnd()
	canDoAnything = true
end

-- when user warps, kill outstanding marathons.
module.Init = function(lbframeInput: Frame): nil
	if lbframeInput == nil then
		warn("nil lbframe ")
		return
	end
	lbframe = lbframeInput
	-- local warpedEvent: RemoteEvent = game.ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("WarpedEvent")
	warper.addCallbackToWarpStart(onWarpStart)
	warper.addCallbackToWarpEnd(onWarpEnd)
	-- warpedEvent.OnClientEvent:Connect(onWarp)
end

module.InitMarathon = function(desc: mt.marathonDescriptor, forceDisplay: boolean)
	local intable = false
	for ii, joinable in ipairs(joinableMarathonKinds) do
		if joinable.humanName == desc.humanName then
			intable = true
			break
		end
	end
	-- annotate("marathon.init.start")
	resetMarathonProgress(desc)
	if not intable then
		table.insert(joinableMarathonKinds, desc)
	end
	-- annotate("marathon.init.end" .. desc.kind)
	if forceDisplay then
		module.InitMarathonVisually(desc)
	end
end

module.DisableMarathon = function(desc: mt.marathonDescriptor)
	local target = 0
	for ii, d in pairs(joinableMarathonKinds) do
		if d.humanName == desc.humanName then
			target = ii
			break
		end
	end
	if target == 0 then
		-- warn("could not find marathon to remove.")
		return
	end
	resetMarathonProgress(desc)
	local frameName = marathonstatic.getMarathonKindFrameName(desc)
	local exi: Frame = lbframe:FindFirstChild(frameName)
	if exi ~= nil then
		exi:Destroy()
	end

	table.remove(joinableMarathonKinds, target)
end

return module
