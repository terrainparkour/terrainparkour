--!strict

-- dynamicServer
-- Receives a request from a user to start a dynamic run. Upon receiving it, it periodically sends
-- a list of the nearby signs & best times that the user is near by.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local PlayersService = game:GetService("Players")
local tt = require(game.ReplicatedStorage.types.gametypes)
local rdb = require(game.ServerScriptService.rdb)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local config = require(game.ReplicatedStorage.config)
local serverUtil = require(game.ServerScriptService.serverUtil)

local remotes = require(game.ReplicatedStorage.util.remotes)
local dynamicRunningEvent = remotes.getRemoteEvent("DynamicRunningEvent") :: RemoteEvent
local signs: Folder = game.Workspace:FindFirstChild("Signs")
local dynamicRunningEnums = require(game.ReplicatedStorage.dynamicRunningEnums)

----------- GLOBAL STATE ----------------

--userId => active target
local activeLoopMarkers: { [number]: number } = {}

------------------ FUNCTIONS ------------------

local function getPositionByUserId(userId: number): Vector3?
	local player = PlayersService:GetPlayerByUserId(userId)
	if player == nil then
		return nil
	end

	local character = player.Character or player.CharacterAdded:Wait()
	local rootPart: Part? = character:FindFirstChild("HumanoidRootPart")
	if rootPart == nil then
		return nil
	end
	local characterPosition = rootPart.Position
	return characterPosition
end

local function getNearestSigns(pos: Vector3, userId: number, count: number)
	local dists = {}

	-- yes it's dumb to do this entire thing, no it doesn't actually matter based on measurement
	for _, sign: Part in ipairs(signs:GetChildren()) do
		local dist = tpUtil.getDist(pos, sign.Position)
		local signId = tpUtil.signName2SignId(sign.Name)
		if not serverUtil.UserCanInteractWithSignId(userId, signId) then
			continue
		end

		table.insert(dists, { signName = sign.Name, dist = dist, signId = signId })
	end

	table.sort(dists, function(a, b)
		return a.dist < b.dist
	end)

	local res = {}
	local ii = 0

	while ii < count do
		ii += 1
		if not dists[ii] then
			break
		end
		local signName = dists[ii].signName
		if signName == nil or signName == "" then
			_annotate("signName is nil or empty")
			break
		end
		local signId = dists[ii].signId

		if not rdb.hasUserFoundSign(userId, signId) then
			continue
		end
		table.insert(res, signId)
	end

	return res
end

local function dynamicControlServer(player: Player, input: tt.dynamicRunningControlType)
	local userId = player.UserId

	if input.action == dynamicRunningEnums.ACTIONS.DYNAMIC_START then
		local getSignCount = 20

		if activeLoopMarkers[player.UserId] ~= nil then
			if activeLoopMarkers[player.UserId] == input.fromSignId then
				_annotate("don't restart dynamic for this person?")
				return
			end
		end

		activeLoopMarkers[input.userId] = input.fromSignId

		task.spawn(function()
			local sentSignIds: { [number]: boolean } = {}
			_annotate("starting dynamic run for: " .. tostring(player.Name .. tostring(input.fromSignId)))
			while true do
				_annotate("looping sending")
				if activeLoopMarkers[userId] ~= input.fromSignId then
					_annotate("breaking sending dyanmic info from server.")
					break
				end
				local pos: Vector3?
				local s, e = pcall(function()
					pos = getPositionByUserId(userId)
				end)
				if not s then
					warn("should not happen" .. tostring(e))
					break
				end
				if pos == nil then
					_annotate("player left during dynamic" .. tostring(userId))
					break
				end

				local nearest = getNearestSigns(pos, userId, getSignCount)
				local todoSignIds = {}
				for _, signId in ipairs(nearest) do
					if signId == input.fromSignId then
						continue
					end
					if sentSignIds[signId] then
						_annotate("sign already sent" .. tostring(signId))
						continue
					end
					table.insert(todoSignIds, signId)
					sentSignIds[signId] = true
				end
				if #todoSignIds > 0 then
					local dynamicRunFromDataFrames = rdb.dynamicRunFrom(userId, input.fromSignId, todoSignIds)
					_annotate("sending dynamic frame update.")
					if dynamicRunFromDataFrames == nil then
						warn("Http 'overload'?")
						continue
					end
					--send frames out.
					local player = PlayersService:GetPlayerByUserId(userId)
					local s, e = pcall(function()
						_annotate("fire frames to client.")
						dynamicRunningEvent:FireClient(player, dynamicRunFromDataFrames)
					end)
					if not s then
						_annotate("player left during dynamic sending" .. tostring(userId))
						break
					end
				else
					_annotate("skipping dynamic frames since nothing to do.")
				end

				task.wait(3)
			end
		end)
	elseif input.action == dynamicRunningEnums.ACTIONS.DYNAMIC_STOP then
		_annotate(string.format("stopping dynamic run for: %s", tostring(player.Name)))
		activeLoopMarkers[input.userId] = nil
	else --other actions.
		warn("unhandled action.")
	end
end

module.Init = function()
	dynamicRunningEvent.OnServerEvent:Connect(dynamicControlServer)
end

_annotate("end")
return module
