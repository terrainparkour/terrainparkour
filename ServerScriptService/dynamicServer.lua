--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local PlayersService = game:GetService("Players")
local tt = require(game.ReplicatedStorage.types.gametypes)
local rdb = require(game.ServerScriptService.rdb)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local config = require(game.ReplicatedStorage.config)

local remotes = require(game.ReplicatedStorage.util.remotes)
local dynamicRunningEvent = remotes.getRemoteEvent("DynamicRunningEvent") :: RemoteEvent
local signs: Folder = game.Workspace:FindFirstChild("Signs")
local dynamicRunningEnums = require(game.ReplicatedStorage.dynamicRunningEnums)

local module = {}

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
	assert(rootPart)
	local characterPosition = rootPart.Position
	return characterPosition
end

local function getNearestSigns(pos: Vector3, userId: number, includeFoundOnly: boolean, count: number)
	local dists = {}

	--yes it's dumb to do this entire thing, no it doesn't actually matter based on measurement
	for _, sign: Part in ipairs(signs:GetChildren()) do
		local dist = tpUtil.getDist(pos, sign.Position)
		table.insert(dists, { signName = sign.Name, dist = dist })
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
			break
		end
		local signId = tpUtil.signName2SignId(signName)
		if includeFoundOnly then
			if not rdb.hasUserFoundSign(userId, signId) then
				continue
			end
		end
		table.insert(res, signId)
	end

	return res
end

--userId => active target
local activeLoopMarkers: { [number]: number } = {}

local function dynamicControlServer(player: Player, input: tt.dynamicRunningControlType)
	local userId = player.UserId

	if input.action == dynamicRunningEnums.ACTIONS.DYNAMIC_START then
		local getSignCount = 20
		if config.isInStudio() then
			getSignCount = 20
		end

		if activeLoopMarkers[player.UserId] ~= nil then
			if activeLoopMarkers[player.UserId] == input.fromSignId then
				-- print("don't restart dynamic for this person.")
				return
			end
		end

		activeLoopMarkers[input.userId] = input.fromSignId

		task.spawn(function()
			local sentSignIds: { [number]: boolean } = {}
			-- print("starting dynamic run for: " .. tostring(player.Name .. tostring(input.fromSignId)))
			while true do
				if activeLoopMarkers[userId] ~= input.fromSignId then
					break
				end
				local pos: Vector3?
				local s, e = pcall(function()
					pos = getPositionByUserId(userId)
				end)
				if not s then
					warn("should not happen")
					break
				end
				if pos == nil then
					--_annotate("player left." .. tostring(userId))
					break
				end
				assert(pos)
				local nearest = getNearestSigns(pos, userId, true, getSignCount)
				local todoSignIds = {}
				for _, signId in ipairs(nearest) do
					if signId == input.fromSignId then
						continue
					end
					if sentSignIds[signId] then
						continue
					end
					table.insert(todoSignIds, signId)
					sentSignIds[signId] = true
				end
				if #todoSignIds > 0 then
					local frames = rdb.dynamicRunFrom(userId, input.fromSignId, todoSignIds)
					if frames == nil then
						warn("Http 'overload'?")
						continue
					end
					--send frames out.
					local player = PlayersService:GetPlayerByUserId(userId)
					local s, e = pcall(function()
						--_annotate("fire frames to client.")
						dynamicRunningEvent:FireClient(player, frames)
					end)
					if not s then
						--player has left.
						break
					end
				end
				wait(3)
			end
		end)
	elseif input.action == dynamicRunningEnums.ACTIONS.DYNAMIC_STOP then
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
