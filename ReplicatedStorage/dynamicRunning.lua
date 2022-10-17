--!strict

-- 9.05.22 start
-- draw a ui which appends uis on nearby found sign statuses

--used on client to kick off sending loops
--eval 9.24.22
--10.09 bugfixing why this breaks servers
local textUtil = require(game.ReplicatedStorage.util.textUtil)
local colors = require(game.ReplicatedStorage.util.colors)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local tt = require(game.ReplicatedStorage.types.gametypes)
local dynamicRunningEnums = require(game.ReplicatedStorage.dynamicRunningEnums)

local PlayersService = game:GetService("Players")
local RunService = game:GetService("RunService")
local localPlayer: Player = PlayersService.LocalPlayer

local remotes = require(game.ReplicatedStorage.util.remotes)
local dynamicRunningEvent = remotes.getRemoteEvent("DynamicRunningEvent") :: RemoteEvent
local renderStepped

--control settings, default start. modifiable by a setting.
local dynamicRunningEnabled = false

--global for tracking
local dynamicStartTick: number = 0

--max visualization (CAMERA, not PLAYER) range.
local bbguiMaxDist = 250

local debounce = false
local dynamicRunFrames: { tt.DynamicRunFrame } = {}
--target sign name => TL;
local tls: { [string]: TextLabel } = {}

---------ANNOTATION----------------
local doAnnotation = false
-- doAnnotation = true
local annotationStart = tick()
local function annotate(s: string)
	if doAnnotation then
		if typeof(s) == "string" then
			print(
				"dynamicRunning.Server: "
					.. string.format("%.2f", tick() - annotationStart)
					.. ": "
					.. s
					.. " frames:"
					.. #dynamicRunFrames
			)
		else
			print("dynamicRunning.Server.bject: " .. string.format("%.0f", tick() - annotationStart) .. " : ")
			print(s)
		end
	end
end

local module = {}

--signName => ui outer frame
local targetSignUis: { [string]: TextLabel } = {}

local startDynamicDebounce = false
--destroy all UIs and nuke the pointer dict to them
module.endDynamic = function(force: boolean?)
	annotate("endDynamic, force:" .. tostring(force))
	if not (force or dynamicRunningEnabled) then
		return
	end

	annotate("endDynamic, real")
	startDynamicDebounce = true

	for k, v in pairs(targetSignUis) do
		local par = v.Parent
		assert(par)
		par = par.Parent
		assert(par)
		par:Destroy()
	end
	targetSignUis = {}
	dynamicStartTick = 0
	local data: tt.dynamicRunningControlType = {
		action = dynamicRunningEnums.ACTIONS.DYNAMIC_STOP,
		fromSignId = 0,
		userId = localPlayer.UserId,
	}
	dynamicRunningEvent:FireServer(data)
	startDynamicDebounce = false
end

--called when a player re-touches a sign to reser timer
module.resetDynamicTiming = function(startTick: number)
	if not dynamicRunningEnabled then
		return
	end
	dynamicStartTick = startTick
end

--do everything on the server and just monitor it on the client
module.startDynamic = function(player: Player, signName: string, startTick: number)
	if not dynamicRunningEnabled then
		return
	end

	spawn(function()
		while startDynamicDebounce do
			wait(0.1)
			annotate("waited for dynamic start debounce")
		end
		startDynamicDebounce = true
		dynamicStartTick = startTick
		local signId = tpUtil.signName2SignId(signName)
		local data: tt.dynamicRunningControlType = {
			action = dynamicRunningEnums.ACTIONS.DYNAMIC_START,
			fromSignId = signId,
			userId = player.UserId,
		}
		dynamicRunningEvent:FireServer(data)
		startDynamicDebounce = false
	end)
end

local function makeDynamicSignMouseoverUI(from: string, to: string): TextLabel
	local bbgui = Instance.new("BillboardGui")
	bbgui.Size = UDim2.new(0, 200, 0, 100)
	bbgui.StudsOffset = Vector3.new(0, 5, 0)
	bbgui.MaxDistance = bbguiMaxDist
	bbgui.AlwaysOnTop = false
	bbgui.Name = "For_" .. from .. "_to_" .. to
	local frame: Frame = Instance.new("Frame")
	frame.Parent = bbgui
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundTransparency = 1
	local tl: TextLabel = Instance.new("TextLabel")
	tl.Parent = frame
	tl.Font = Enum.Font.GothamBold
	tl.TextXAlignment = Enum.TextXAlignment.Center
	tl.Size = UDim2.new(1, 0, 1, 0)
	tl.Text = ""
	tl.TextTransparency = 0.1
	tl.BackgroundTransparency = 1
	tl.TextColor3 = Color3.new(155, 100, 120)
	tl.Size = UDim2.new(1, 0, 1, 0)
	tl.FontSize = Enum.FontSize.Size24
	tl.TextScaled = false
	local signs = game.Workspace:FindFirstChild("Signs")
	local sign = signs:FindFirstChild(to)
	if sign == nil then
		error("bad:" .. from .. "-" .. to)
	end
	bbgui.Parent = sign
	return tl
end

--get or create bbgui above sign
local function getOrCreateUI(from: string, to: string): TextLabel
	if not targetSignUis[to] then
		local ui = makeDynamicSignMouseoverUI(from, to)
		targetSignUis[to] = ui
	end
	return targetSignUis[to]
end

local function calculateText(frame: tt.DynamicRunFrame): (string, Color3)
	local currentRunElapsedMs = (tick() - dynamicStartTick) * 1000

	--cutout early if its a new run entirely or you haven't found it.
	if #frame.places == 0 then
		if not frame.myfound then
			return "New Race\nNew Find for you", colors.lightGreen
		end
		return "New Race", colors.lightGreen
	end

	--interleave user's time, AND don't forget to include find status

	local comparatorPlace = 0
	local comparatorTimeImprovement = 0

	--or if you're worse than the last recorded, you get this.
	--and if this is 11th, you don't place at all
	local newNth = 0
	local lastSeenPlace = 0

	--you can't compare to a run after your own place
	--determine comparator, that's why this makes sense.
	for _, exipl in ipairs(frame.places) do
		lastSeenPlace = exipl.place
		if currentRunElapsedMs < exipl.timeMs then
			comparatorPlace = exipl.place
			comparatorTimeImprovement = (exipl.timeMs - currentRunElapsedMs) / 1000
			break
		end
		if frame.myplace and frame.myplace.place and frame.myplace.place <= exipl.place then
			break
		end
	end
	if comparatorPlace == 0 then
		newNth = lastSeenPlace + 1
	end

	------------Determine hover color--------------
	local useColor = colors.defaultGrey
	if comparatorPlace == 1 then
		if frame.myplace and frame.myplace.place == 1 then
			useColor = colors.lightBlue --just improve your 1st place.
		else
			useColor = colors.greenGo
		end
	else
		if frame.myplace and frame.myplace.place == comparatorPlace then
			useColor = colors.lightOrange
		else
			useColor = colors.lightBlue
		end
	end

	-----------the actual text.----------------
	local text = ""
	if comparatorPlace > 0 then
		if frame.myplace and comparatorPlace == frame.myplace.place then
			text = string.format(
				"improve your %s by %0.1fs",
				tpUtil.getCardinal(comparatorPlace),
				comparatorTimeImprovement
			)
		else
			text = string.format(
				"on track for %s by %0.1fs",
				tpUtil.getCardinal(comparatorPlace),
				comparatorTimeImprovement
			)
		end
	else
		if frame.myplace then
			text = string.format("no improvement by %0.1fs", (currentRunElapsedMs - frame.myplace.timeMs) / 1000)
			useColor = colors.lightRed
		else
			if newNth <= 10 then
				text = "Would get new " .. tpUtil.getCardinal(newNth)
			else
				text = "Would not place"
				useColor = colors.lightRed
			end
		end
	end

	local yourlast = ""
	if frame.myplace and frame.myplace.place then
		if frame.myplace.place <= 10 then
			yourlast = "(prev " .. tpUtil.getCardinal(frame.myplace.place) .. ")"
		else
			yourlast = ""
		end
	else
		yourlast = "new run for you"
	end

	return text .. "\n" .. yourlast, useColor
end

--called once per active run + target; after setup, self-runs.
--(also, self-destroys when you leave the area?)
--also, needs dynamic runtime.

local function lock(src: string?)
	if not src then
		src = ""
	end
	while debounce do
		annotate("debounce " .. src)
		wait(0.01)
	end
	debounce = true
end

local function unlock()
	debounce = false
end

local function add(dynamicRunFrame: tt.DynamicRunFrame, from)
	lock()
	table.insert(dynamicRunFrames, dynamicRunFrame)
	local tl = getOrCreateUI(from, dynamicRunFrame.targetSignName)
	tls[dynamicRunFrame.targetSignName] = tl
	annotate("added " .. dynamicRunFrame.targetSignName)
	unlock()
end

local function handleOne(dynamicRunFrame: tt.DynamicRunFrame)
	if dynamicStartTick == 0 then
		return
	end
	-- local st = tick()
	local tl: TextLabel = tls[dynamicRunFrame.targetSignName]
	local bbgui: BillboardGui = tl.Parent.Parent
	local pos = localPlayer.Character.HumanoidRootPart.Position
	local dist = tpUtil.getDist(bbgui.Parent.Position, pos)

	if dist > bbguiMaxDist then --far away
		if bbgui.Enabled then
			bbgui.Enabled = false
			-- annotate("\tturned off: too far:" .. dynamicRunFrame.targetSignName)
			return
		end
		-- annotate("\tstayed off: too far:" .. dynamicRunFrame.targetSignName)
		return
	else --within region
		if not bbgui.Enabled then
			bbgui.Enabled = true
		end
	end

	local text, color = calculateText(dynamicRunFrame)
	local changed = false
	if tl.Text ~= text then
		tl.Text = text
		changed = true
		tl.TextColor3 = color
	end
	-- if changed then
	-- 	annotate(
	-- 		string.format(
	-- 			"\tupdate (changed:%s) of %s took %0.7f",
	-- 			tostring(changed),
	-- 			dynamicRunFrame.targetSignName,
	-- 			tick() - st
	-- 		)
	-- 	)
	-- end
end

local function fullReset()
	annotate("full reset")
	lock()
	for _, item in ipairs(tls) do
		item.Parent.Parent:Destroy()
	end
	tls = {}
	dynamicRunFrames = {}
	unlock()
end

local function receiveDynamicRunData(updates: tt.dynamicRunFromData)
	annotate("Receive " .. tostring(#updates.frames))
	if not dynamicRunningEnabled then
		return
	end
	annotate("add Receive " .. tostring(#updates.frames))

	for _, dynamicRunFrame: tt.DynamicRunFrame in ipairs(updates.frames) do
		add(dynamicRunFrame, updates.fromSignName)
	end
end

local lastupdates = {}
local hasReset = false
local function setupRenderStepped()
	annotate("strating render stepped")

	renderStepped = RunService.RenderStepped:Connect(function()
		local st = tick()
		if dynamicStartTick == 0 then
			if not hasReset then
				fullReset()
				hasReset = true
			end
			return
		end
		hasReset = false
		if #dynamicRunFrames == 0 then
			return
		end

		-- local didframe = {}
		for ii, item in ipairs(dynamicRunFrames) do
			if not lastupdates[item.targetSignName] then
				lastupdates[item.targetSignName] = tick()
			end
			if tick() - lastupdates[item.targetSignName] >= 0.1 then
				handleOne(item)
				-- table.insert(didframe,tostring(ii))

				-- annotate(
				-- 	string.format(
				-- 		"\t %d updating cause gap: %0.5f %s",
				-- 		ii,
				-- 		st - lastupdates[item.targetSignName],
				-- 		item.targetSignName
				-- 	)
				-- )

				lastupdates[item.targetSignName] = tick()
				if tick()-st>0.001 then break end
			else
				-- annotate(string.format("\t %d skipping %s", ii, item.targetSignName))
			end
		end

		-- if didframe == 0 then
		-- 	annotate(string.format("all frames arleady updated. in %0.5f.", tick() - st))
		-- else
		-- 	annotate(string.format("successfully updated frames %s in %0.5f.", textUtil.stringJoin(',',didframe), tick() - st))
		-- end
	end)
end

local function handleUserSettingChanged(setting: tt.userSettingValue)
	if setting.name == settingEnums.settingNames.ENABLE_DYNAMIC_RUNNING then
		if setting.value then
			if not dynamicRunningEnabled then
				dynamicRunningEnabled = true
				setupRenderStepped()
			end
		elseif setting.value == false then
			if dynamicRunningEnabled then
				--also destroy them all.
				dynamicRunningEnabled = false
				renderStepped:Disconnect()
				annotate("kill renderstepped")
				module.endDynamic(true)
			end
		end
	end
end

local init = function()
	dynamicRunningEvent.OnClientEvent:Connect(receiveDynamicRunData)
	local localFunctions = require(game.ReplicatedStorage.localFunctions)

	--in addition to this, needs to get the original setting to set it locally too.
	localFunctions.registerLocalSettingChangeReceiver(function(item)
		return handleUserSettingChanged(item)
	end, settingEnums.settingNames.ENABLE_DYNAMIC_RUNNING)

	local dynset = localFunctions.getSettingByName(settingEnums.settingNames.ENABLE_DYNAMIC_RUNNING)
	handleUserSettingChanged(dynset)
end

init()

return module
