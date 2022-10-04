--!strict

-- 9.05.22 start
-- draw a ui which appends uis on nearby found sign statuses

--used on client to kick off sending loops
--eval 9.24.22

local colors = require(game.ReplicatedStorage.util.colors)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local RunService = game:GetService("RunService")

local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local tt = require(game.ReplicatedStorage.types.gametypes)

local PlayersService = game:GetService("Players")
local localPlayer: Player = PlayersService.LocalPlayer

--control settings, default start. modifiable by a setting.
local dynamicRunningEnabled = false

local rf = require(game.ReplicatedStorage.util.remotes)
local dynamicRunningFunction = rf.getRemoteFunction("DynamicRunningFunction") :: RemoteFunction
local dynamicRunningEvent = rf.getRemoteEvent("DynamicRunningEvent") :: RemoteEvent

local dynamicStartTick: number = 0

local bbguiMaxDist = 190

local module = {}

--signName => ui outer frame
local targetSignUis: { [string]: TextLabel } = {}

local startDynamicDebounce = false
--destroy all UIs and nuke the pointer dict to them
module.endDynamic = function(force: boolean?)
	if not (force or dynamicRunningEnabled) then
		return
	end
	startDynamicDebounce = true
	local data: tt.dynamicRunningControlType = { action = "stop", fromSignId = 0, userId = localPlayer.UserId }
	for k, v in pairs(targetSignUis) do
		local par = v.Parent
		assert(par)
		par = par.Parent
		assert(par)
		par:Destroy()
	end
	targetSignUis = {}
	dynamicStartTick = 0
	dynamicRunningFunction:InvokeServer(data)
	startDynamicDebounce = false
end

module.resetDynamicTiming = function(player: Player, signName: string, startTick: number)
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
	module.endDynamic()
	spawn(function()
		local waited = 0
		while startDynamicDebounce do
			wait(0.1)
			waited += 1
		end
		if waited > 0 then
			print("waited", waited)
		end
		startDynamicDebounce = true
		dynamicStartTick = startTick
		-- print("start dynamic from: " .. signName)
		local signId = tpUtil.signName2SignId(signName)
		--find nearest 3 signs which I have found
		--and which are not in lookedup
		local data: tt.dynamicRunningControlType = { action = "start", fromSignId = signId, userId = player.UserId }
		dynamicRunningFunction:InvokeServer(data)
		startDynamicDebounce = false
	end)
end

local function makeDynamicUI(from: string, to: string): TextLabel
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
	tl.TextXAlignment = Enum.TextXAlignment.Left
	tl.Size = UDim2.new(1, 0, 1, 0)
	tl.Text = ""
	tl.TextTransparency = 0.1
	tl.BackgroundTransparency = 1
	-- tl.BackgroundColor3=Color3.new(0,0,0)
	tl.TextColor3 = Color3.new(155, 100, 120)
	tl.Size = UDim2.new(1, 0, 1, 0)
	tl.FontSize = Enum.FontSize.Size24
	tl.TextScaled = false
	-- local sign=tpUtil.signName2SignId(from)
	local signs = game.Workspace:FindFirstChild("Signs")
	local sign = signs:FindFirstChild(to)
	if sign == nil then
		error("bad")
	end
	bbgui.Parent = sign
	return tl
end

local function getOrCreateUI(from: string, to: string): TextLabel
	if not targetSignUis[to] then
		local ui = makeDynamicUI(from, to)
		targetSignUis[to] = ui
	end
	return targetSignUis[to]
end

local function calculateText(frame: tt.DynamicRunFrame): (string, Color3)
	--flag for destruction having happened.
	if dynamicStartTick == 0 then
		return "", colors.black
	end
	local currentRunElapsedMs = (tick() - dynamicStartTick) * 1000
	if #frame.places > 0 then
		--interleave user's time, AND don't forget to include find status

		local comparatorPlace = 0
		local comparatorTimeImprovement = 0

		--or if you're worse than the last recorded, you get this.
		--and if this is 11th, you don't place at all
		local newNth = 0
		local lastSeenPlace = 0

		--you can't compare to a run after your own place
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
		local text = ""
		if comparatorPlace > 0 then
			if frame.myplace and comparatorPlace == frame.myplace.place then
				text = string.format(
					"improve your %s by %0.1f",
					tpUtil.getCardinal(comparatorPlace),
					comparatorTimeImprovement
				)
			else
				text = string.format(
					"on track for %s by %0.1f",
					tpUtil.getCardinal(comparatorPlace),
					comparatorTimeImprovement
				)
			end
		else
			if frame.myplace then
				text = string.format("no improvement by %0.1f", (currentRunElapsedMs - frame.myplace.timeMs) / 1000)
			else
				if newNth <= 10 then
					text = "Would get new " .. tpUtil.getCardinal(newNth)
				else
					text = "Would not place"
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
		return text .. "\n" .. yourlast, useColor
	else
		if not frame.myfound then
			return "New Race\nNew Find for you", colors.lightGreen
		end
		return "New Race", colors.lightGreen
	end
end

--called once per active run + target; after setup, self-runs.
--(also, self-destroys when you leave the area?)
--also, needs dynamic runtime.
local function setupDynamicVisualization(from: string, frame: tt.DynamicRunFrame)
	local tl = getOrCreateUI(from, frame.targetSignName)
	local bbgui = tl.Parent.Parent :: BillboardGui
	--based on the frame, calculate the user's position in the list.

	--spin up monitor.
	--TODO optimize - don't run this all the time if the user is outside distance.
	--but probably no matter.
	local signs = game.Workspace:FindFirstChild("Signs")
	local sign: Part = signs:FindFirstChild(frame.targetSignName)
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local pos = localPlayer.Character.HumanoidRootPart.Position
		local dist = tpUtil.getDist(sign.Position, pos)
		if dist > bbguiMaxDist then
			if bbgui.Enabled then
				bbgui.Enabled = false
			end
		end
		if not bbgui.Enabled then
			bbgui.Enabled = true
		end
		local text, color = calculateText(frame)

		if text == "" then
			conn:Disconnect()
		end
		if tl.Text ~= text then
			tl.Text = text
			tl.TextColor3 = color
			-- if frame.targetSignName == "Atocha" then
			-- 	print("\n" .. text)
			-- 	print(frame)
			-- end
		end
	end)
end

local function handleNewDynamicFrames(updates: tt.dynamicRunFromData)
	if not dynamicRunningEnabled then
		return
	end
	for _, frame in ipairs(updates.frames) do
		-- singleTextUpdate(updates.fromSignName, frame)
		-- print("setup dynamic " .. updates.fromSignName .. frame.targetSignName)
		setupDynamicVisualization(updates.fromSignName, frame)
	end
end

local function handleUserSettingChanged(setting: tt.userSettingValue)
	if setting.name == settingEnums.settingNames.ENABLE_DYNAMIC_RUNNING then
		if setting.value then
			if not dynamicRunningEnabled then
				dynamicRunningEnabled = true
				print("enabled dynamic running.")
			end
		elseif setting.value == false then
			if dynamicRunningEnabled then
				--also destroy them all.
				dynamicRunningEnabled = false
				module.endDynamic(true)
				print("disabled dynamic running.")
			end
		end
	end
end

local init = function()
	dynamicRunningEvent.OnClientEvent:Connect(function(updates: tt.dynamicRunFromData)
		--frames are showing up in A!
		handleNewDynamicFrames(updates)
	end)
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
