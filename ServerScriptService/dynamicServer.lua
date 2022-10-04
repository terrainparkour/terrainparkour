--!strict
--eval 9.24.22

local PlayersService = game:GetService("Players")
local tt = require(game.ReplicatedStorage.types.gametypes)
local rdb = require(game.ServerScriptService.rdb)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)

local module = {}

local rf = require(game.ReplicatedStorage.util.remotes)

local dynamicRunningFunction = rf.getRemoteFunction("DynamicRunningFunction") :: RemoteFunction
local dynamicRunningEvent = rf.getRemoteEvent("DynamicRunningEvent") :: RemoteEvent
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

local signs: Folder = game.Workspace:FindFirstChild("Signs")
--hmm i should do this based on game.workspace actually
local function getNearestSigns(pos: Vector3, userId: number, includeUnfound: boolean, count: number)
	local dists = {}
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
		if not includeUnfound then
			if not rdb.hasUserFoundSign(userId, signId) then
				continue
			end
		end
		table.insert(res, signId)
	end

	return res
end

local function dynamicControlServer(userId: number, input: tt.dynamicRunningControlType)
	if input.action == "start" then
		local thisLoopMonitor = { active = true }

		spawn(function()
			local sentSignIds: { [number]: boolean } = {}

			while true do
				local pos = getPositionByUserId(userId)
				if pos == nil then
					continue
				end
				assert(pos)
				local nearest = getNearestSigns(pos, userId, false, 50)
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
						print("http overload.")
						continue
					end
					--send frames out.
					local player = PlayersService:GetPlayerByUserId(userId)
					dynamicRunningEvent:FireClient(player, frames)
				end
				if not thisLoopMonitor.active then
					break
				end
				wait(5)
			end
		end)
	end
end

module.init = function()
	dynamicRunningFunction.OnServerInvoke = function(player: Player, data: tt.dynamicRunningControlType)
		return dynamicControlServer(player.UserId, data)
	end
end

return module
