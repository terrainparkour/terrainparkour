--!strict

-- 2024.08 simplified everything to use serverwarp.
-- also added highlighting.
-- there are two main kinds of warping.
-- 1. client initated.  the client sends a local bindable avatar monitoring event getw_ready_for_warp.
-- all listeners (all who must listen) get into a legal warping state and stay that way.
-- nothing can happen to them until they are told wapr is done.
-- when they're all ready, client warper tells the server to do the warp.
-- server does it and then replies.
-- then the client sends another event saying warp is done.
-- 2. server initated.
-- user does a command like /rr (or admin does /warp) which entails warping.
-- server sends the client a message to get ready for warp.
-- client then does the above process, involving sending back to the client that it should warp.
-- when the client is done getting ready the server does the work, then the client is done.

local playerData2 = require(script.Parent.playerData2)
local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local remotes = require(game.ReplicatedStorage.util.remotes)
local tt = require(game.ReplicatedStorage.types.gametypes)
local lightPillar = require(game.ServerScriptService.lightPillar)

local module = {}

---------- EVENTS ------------
local ServerRequestClientToWarpLockEvent: RemoteEvent = remotes.getRemoteEvent("ServerRequestClientToWarpLockEvent")
local ClientRequestsWarpToRequestFunction = remotes.getRemoteFunction("ClientRequestsWarpToRequestFunction")

local debugVectorsEtc = false
----------- LOCAL FUNCTIONS --------------------

-- modified to not count AIR as terrain.
local function isPositionInTerrain(position: Vector3): { success: boolean, occ: number, mat: Enum.Material }
	local regionSize = Vector3.new(2, 3, 2) -- Adjust this size based on your needs
	local region = Region3.new(position - regionSize / 2, position + regionSize / 2)

	region = region:ExpandToGrid(4)

	-- Read the terrain voxels in the region
	local material, occupancy = workspace.Terrain:ReadVoxels(region, 4)
	if not material then
		return { success = true, occ = 0, mat = Enum.Material.Air }
	end

	-- Check if any voxel in the region is occupied by non-air, non-water
	local size = material.Size
	for x = 1, size.X do
		for y = 1, size.Y do
			for z = 1, size.Z do
				if
					occupancy[x][y][z] > 0
					and material[x][y][z] ~= Enum.Material.Air
					and material[x][y][z] ~= Enum.Material.Water
				then
					return { success = false, occ = occupancy[x][y][z], mat = material[x][y][z] }
				end
			end
		end
	end
	return { success = true, occ = 0, mat = Enum.Material.Air }
end

local signsFolderInstance: Instance? = workspace:FindFirstChild("Signs")
local theFilter: { Instance } = if signsFolderInstance then { signsFolderInstance } else {}

local findWarpablePositionForSign = function(sign: BasePart): Vector3?
	local size = sign.Size
	local cf = sign.CFrame
	local halfSize = size * 0.5

	local corners = {
		cf * CFrame.new(halfSize.X, halfSize.Y, halfSize.Z),
		cf * CFrame.new(-halfSize.X, halfSize.Y, halfSize.Z),
		cf * CFrame.new(halfSize.X, halfSize.Y, -halfSize.Z),
		cf * CFrame.new(-halfSize.X, halfSize.Y, -halfSize.Z),
	}

	local minX, maxX = math.huge, -math.huge
	local minZ, maxZ = math.huge, -math.huge

	for _, corner in ipairs(corners) do
		local x, _, z = corner.Position.X, corner.Position.Y, corner.Position.Z
		minX, maxX = math.min(minX, x), math.max(maxX, x)
		minZ, maxZ = math.min(minZ, z), math.max(maxZ, z)
	end

	-- Iterate over every point above the sign in the Y direction, from 10 to 20 studs above
	local function getRandomPoint(
		minX: number,
		maxX: number,
		minZ: number,
		maxZ: number,
		minY: number,
		maxY: number
	): Vector3
		return Vector3.new(math.random(minX, maxX), math.random(minY, maxY), math.random(minZ, maxZ))
	end

	--don't warp right to the edge of a sign - it's messed up for mesh thingies.
	minX = minX + 0.15 * (maxX - minX)
	minZ = minZ + 0.15 * (maxZ - minZ)

	maxX = maxX - 0.15 * (maxX - minX)
	maxZ = maxZ - 0.15 * (maxZ - minZ)

	local maxAttempts: number = 45
	local res: Vector3? = nil
	local signTop = sign.Position.Y + sign.Size.Y / 2
	local minY: number = math.floor(signTop + 2)
	local maxY: number = math.floor(signTop + 16)

	for _ = 1, maxAttempts do
		local position: Vector3 = getRandomPoint(minX, maxX, minZ, maxZ, minY, maxY)

		local terrainCheckResult = isPositionInTerrain(position)
		if not terrainCheckResult.success then
			_annotate(
				string.format(
					"warp destination is in terrain, so skipping. position=%s, occ=%d, mat=%s",
					tostring(position),
					terrainCheckResult.occ,
					tostring(terrainCheckResult.mat)
				)
			)
		else
			_annotate(
				string.format("Got a good position to warp at least not in terrain. position=%s", tostring(position))
			)

			local rayDirections = {
				-- Vector3.new(0, -1, 0), -- Down
				Vector3.new(0, 1, 0), -- Up
				Vector3.new(-1, 0, 0), -- Left
				Vector3.new(1, 0, 0), -- Right
				Vector3.new(0, 0, -1), -- Back
				Vector3.new(0, 0, 1), -- Forward
			}
			local width = 0.3
			local castOkay = true

			for _, direction: Vector3 in ipairs(rayDirections) do
				for _, rayLength: number in ipairs({ 1, 1.5, 0.5 }) do --4, 5, 6
					local raycastParams = RaycastParams.new()
					raycastParams.FilterType = Enum.RaycastFilterType.Include
					raycastParams.FilterDescendantsInstances = theFilter
					local rayDir: Vector3 = direction * rayLength
					local raycastResult: RaycastResult | nil =
						workspace:Raycast(position, rayDir, raycastParams) :: RaycastResult | nil

					if raycastResult then
						_annotate(string.format(
							"bad raycastresult, hit: %d rayLength: %d, direction: %s , material: %s, position: %s, instance: %s",
							position.Y,
							-- tostring(endPoint.Position),
							rayLength,
							tostring(direction),
							tostring(raycastResult.Material),
							tostring(raycastResult.Position),
							tostring(raycastResult.Instance.Name)
						))
						castOkay = false
						break
					end
				end
				if not castOkay then
					break
				end
			end
			if castOkay then
				res = position
				break
			end
		end
	end

	if res then
		_annotate(string.format("found a serverwarp destination, did it, returning res=%s", tostring(res)))
		return res
	else
		_annotate(
			string.format("Failed to find a valid warp position after %d attempts, %s", maxAttempts, tostring(res))
		)
		return nil
	end
end

-- this immediately warps them so should only be called via receiving an event which indicates that the client is fully locked.
-- only call this as a response to the client sending in the event that they are fully locked.
local function ServerDoWarpToPosition(player: Player, pos: Vector3, randomize: boolean, sign: BasePart | nil): boolean
	_annotate(
		string.format(
			"Starting: serverDoWarpToPosition player=%s pos=%s randomize=%s",
			player.Name,
			tostring(pos),
			tostring(randomize)
		)
	)

	if not player then
		_annotate("ServerDoWarpToPosition.player nil")
		return false
	end
	if not player.Character then
		_annotate("ServerDoWarpToPosition.char nil")
		return false
	end
	local character = player.Character or player.CharacterAdded:Wait()
	if not character then
		_annotate("ServerDoWarpToPosition.char nil")
		return false
	end

	local rootPartInstance: Instance? = character:FindFirstChild("HumanoidRootPart")
	if not rootPartInstance or not rootPartInstance:IsA("BasePart") then
		_annotate("ServerDoWarpToPosition.HRP nil")
		return false
	end
	local rootPart: BasePart = rootPartInstance :: BasePart
	local humanoidInstance: Instance? = character:WaitForChild("Humanoid")
	if not humanoidInstance or not humanoidInstance:IsA("Humanoid") then
		_annotate("ServerDoWarpToPosition.Humanoid nil")
		return false
	end
	local humanoid: Humanoid = humanoidInstance :: Humanoid

	--finding a position we are allowed to warp to.
	if randomize then
		if not sign then
			annotater.Error("randomize was true but no sign provided")
			return false
		end
		local goodPosition = findWarpablePositionForSign(sign)
		if not goodPosition then
			annotater.Error(string.format("no good position found for: %s", tostring(sign.Name)))
			return false
		end
		pos = goodPosition
	end

	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	_annotate("humanoid:ChangeState(Enum.HumanoidStateType.Freefall)")
	--2024: is this effectively just the server version of resetting movement states?
	rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	while true do
		local state = humanoid:GetState()
		if state == Enum.HumanoidStateType.PlatformStanding then
			_annotate(
				"We got to a good state while preparing warp in ServerDoWarpToPosition, state: " .. tostring(state)
			)
			break
		end
		-- humanoid.PlatformStand = true
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, false)
		humanoid.PlatformStand = false
		humanoid.PlatformStand = true
		task.wait(0.02)
		_annotate("while true loop stuck in state: " .. tostring(state))
	end
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)

	task.wait(0.02)

	lightPillar.CreateTemporaryLightPillar(rootPart.Position, "source")
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	rootPart.Position = pos
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	_annotate(string.format("Changed Position to %s", tostring(pos)))

	lightPillar.CreateTemporaryLightPillar(pos, "destination")
	_annotate("serverDoWarpToPosition done")
	return true
end

-- if you are on the server and want to do a warp, then call this to make sure the player is fully locked out first.
module.RequestClientToWarpToWarpRequest = function(player: Player, request: tt.serverWarpRequest)
	_annotate(
		string.format(
			"server warp command for %s: signId=%s highlightSignId=%s kind=%s position=%s",
			player.Name,
			tostring(request.signId),
			tostring(request.highlightSignId),
			tostring(request.kind),
			tostring(request.position)
		)
	)
	ServerRequestClientToWarpLockEvent:FireClient(player, request)
end

local function CheckWarpingSecurityForPlayerAndSign(player: Player, signId: number?): boolean
	if not signId then
		annotater.Error(string.format("user %s had no signId", player.Name), player.UserId)
		return false
	end
	if not playerData2.HasUserFoundSign(player.UserId, signId) then
		local signName = tpUtil.signId2signName(signId)
		annotater.Error(
			string.format("user %s had not found sign, so was rejected from warping to: %s", player.Name, signName),
			player.UserId
		)
		return false
	end

	return true
end

module.Init = function()
	_annotate("init")
	--when player clicks warp to <sign> they fire this event and go.
	ClientRequestsWarpToRequestFunction.OnServerInvoke = function(
		player: Player,
		request: tt.serverWarpRequest
	): tt.warpResult
		_annotate("server received client request to warp.")

		if request.kind == "sign" then
			local signId = request.signId
			if not signId then
				return { didWarp = false, reason = "no signId" }
			end

			_annotate(
				string.format(
					"server has been asked by client to to do a warp of player=%s signId=%s, highlight=%s",
					player.Name,
					tostring(signId),
					tostring(request.highlightSignId)
				)
			)
			local pos: Vector3 | nil = tpUtil.signId2Position(signId)
			if not pos then
				_annotate("no POS?" .. tostring(signId))
				return { didWarp = false, reason = "no POS" }
			end

			local sign: BasePart | nil = tpUtil.signId2Sign(signId)
			if not sign then
				_annotate("no SIGN?" .. tostring(signId))
				return { didWarp = false, reason = "no SIGN" }
			end

			local securityPass = CheckWarpingSecurityForPlayerAndSign(player, signId)
			if not securityPass then
				annotater.Error(string.format("security pass failed %s %d", tostring(player.Name), signId))
				return { didWarp = false, reason = "security pass failed" }
			end

			local innerWarpRes = ServerDoWarpToPosition(player, pos, true, sign)
			if not innerWarpRes then
				return { didWarp = false, reason = "inner warp failed" }
			end

			_annotate(
				string.format(
					"Server done with the warp to signId=%s with res: %s",
					tostring(signId),
					tostring(innerWarpRes)
				)
			)
			return { didWarp = true, reason = "all seems okay" }
		elseif request.kind == "position" then
			local res = ServerDoWarpToPosition(player, request.position, false)
			_annotate(
				string.format(
					"Server done with the warp to position=%s with res: %s",
					tostring(request.position),
					tostring(res)
				)
			)
			return { didWarp = res, reason = "returning serverWarp results" }
		else
			warn("unknown kind of warp request: " .. tostring(request.kind))
			return { didWarp = false, reason = "unknown kind of warp request" }
		end
	end
	_annotate("init done")
end

_annotate("end")
return module
