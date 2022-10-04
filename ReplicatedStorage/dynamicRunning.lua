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
	bbgui.StudsOffset = Vector3.new(0, 10, 0)
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
	tl.FontSize = Enum.FontSize.Size36
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
		--interpose user's time, AND don't forget to include find status

		--for this case display time behind, and new rank, if complete.
		if frame.myplace and frame.myplace.place and frame.myplace.place <= 10 then
			local thisRunImprovementVsMyLastRunMs = currentRunElapsedMs - frame.myplace.timeMs

			--now determine my effective rank
			local myProvisionalPlaceText = "not top10"
			local myProvisionalPlace: number = 12
			local pasttext = tpUtil.getCardinal(frame.myplace.place)
			if thisRunImprovementVsMyLastRunMs >= 0 then
				myProvisionalPlaceText = "no improvement"
			elseif thisRunImprovementVsMyLastRunMs < 0 then
				for _, pl in ipairs(frame.places) do
					if currentRunElapsedMs < pl.timeMs then
						myProvisionalPlaceText = tpUtil.getCardinal(pl.place)
						myProvisionalPlace = pl.place
						break
					end
				end
			end

			local color = colors.lightGreen
			local sign = ""
			if thisRunImprovementVsMyLastRunMs >= 0 then
				color = colors.lightRed
				sign = "+"
			end
			local text = string.format(
				"%s (prev %s)\n%s%0.3f",
				myProvisionalPlaceText,
				pasttext,
				sign,
				thisRunImprovementVsMyLastRunMs / 1000
			)
			if frame.myplace and frame.myplace.place == myProvisionalPlace then
				color = colors.lightOrange
			end
			return text, color
		else
			local myProvisionalPlaceText: string
			local seenLastPlace = 0
			for _, pl in ipairs(frame.places) do
				if currentRunElapsedMs < pl.timeMs then
					myProvisionalPlaceText = string.format(
						"-%0.3f %s",
						(pl.timeMs - currentRunElapsedMs) / 1000,
						tpUtil.getCardinal(pl.place)
					)
					return myProvisionalPlaceText, colors.lightGreen
				end
				seenLastPlace = pl.place
			end
			if seenLastPlace < 10 then
				return string.format("new %s", tpUtil.getCardinal(seenLastPlace + 1)), colors.lightOrange
			end
			local extra = ""
			if not frame.myfound then
				extra = "\nnew find"
			end
			return "would not place" .. extra, colors.redStop
		end
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
		tl.Text = text
		tl.TextColor3 = color
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
