--!strict
--eval 9.24.22

local PlayersService = game:GetService("Players")
local tt = require(game.ReplicatedStorage.types.gametypes)
local rdb = require(game.ServerScriptService.rdb)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)

local remotes = require(game.ReplicatedStorage.util.remotes)
local dynamicRunningEvent = remotes.getRemoteEvent("DynamicRunningEvent") :: RemoteEvent
local signs: Folder = game.Workspace:FindFirstChild("Signs")
local dynamicRunningEnums = require(game.ReplicatedStorage.dynamicRunningEnums)

local module = {}

local doAnnotation = false
-- doAnnotation = true
local annotationStart = tick()
local function annotate(s: string)
	if doAnnotation then
		if typeof(s) == "string" then
			print("dynamicRunning.Client: " .. string.format("%.0f", tick() - annotationStart) .. " : " .. s)
		else
			print("dynamicRunning.Client.object: " .. string.format("%.0f", tick() - annotationStart) .. " : ")
			print(s)
		end
	end
end

local function getPositionByUserId(userId: number): Vector3?
	local player = PlayersService:GetPlayerByUserId(userId)
	if player == nil then
		return nil
	end

	local char = player.Character
	if char == nil then
		return nil
	end
	local hum: Humanoid? = char:FindFirstChild("Humanoid")
	if hum == nil then
		return nil
	end
	local rootPart: Part? = char:FindFirstChild("HumanoidRootPart")
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
	activeLoopMarkers[input.userId] = input.fromSignId
	if input.action == dynamicRunningEnums.ACTIONS.DYNAMIC_START then
		spawn(function()
			local sentSignIds: { [number]: boolean } = {}
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
					annotate("player left." .. tostring(userId))
					break
				end
				assert(pos)
				local nearest = getNearestSigns(pos, userId, true, 50)
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
						annotate("fire frames to client.")
						dynamicRunningEvent:FireClient(player, frames)
					end)
					if not s then
						--player has left.
						break
					end
				end
				wait(5)
			end
		end)
	elseif input.action == dynamicRunningEnums.ACTIONS.DYNAMIC_STOP then
		activeLoopMarkers[input.userId] = 0
	else --other actions.
		warn("unhandled action.")
	end
end

module.init = function()
	dynamicRunningEvent.OnServerEvent:Connect(dynamicControlServer)
end

return module
