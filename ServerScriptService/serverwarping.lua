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

local function isPositionInTerrain(position: Vector3)
	local regionSize = Vector3.new(2, 3, 2) -- Adjust this size based on your needs
	local region = Region3.new(position - regionSize / 2, position + regionSize / 2)

	region = region:ExpandToGrid(4)

	-- Read the terrain voxels in the region
	local material, occupancy = workspace.Terrain:ReadVoxels(region, 4)

	-- Check if any voxel in the region is occupied and not air
	local size = material.Size
	for x = 1, size.X do
		for y = 1, size.Y do
			for z = 1, size.Z do
				if occupancy[x][y][z] > 0 and material[x][y][z] ~= Enum.Material.Air then
					return true
				end
			end
		end
	end
	return false
end

local theFilter = { workspace:FindFirstChild("Signs") }

local findWarpablePositionForSign = function(sign: BasePart)
	local d = game.Workspace:GetDescendants()
	for _, v in pairs(d) do
		if v.Name == "Bad" then
			v:Destroy()
		end
	end
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

	local maxAttempts: number = 10
	local res: Vector3? = nil
	local minY: number = math.floor(sign.Position.Y + 12)
	local maxY: number = math.floor(sign.Position.Y + 16)

	for _ = 1, maxAttempts do
		local position: Vector3 = getRandomPoint(minX, maxX, minZ, maxZ, minY, maxY)

		-- Create a purple sphere at the position
		local sphere
		if debugVectorsEtc then
			sphere = Instance.new("Part")
			sphere.Shape = Enum.PartType.Ball
			sphere.Size = Vector3.new(1, 1, 1)
			sphere.Position = position
			sphere.Anchored = true
			sphere.CanCollide = false
			sphere.Transparency = 0.1
			sphere.Color = Color3.new(0.5, 0, 0.5) -- Purple color
			sphere.Name = "PositionMarker"
			sphere.Parent = workspace
			sphere.Name = "START"
			_annotate(string.format("Created purple sphere at position %s", tostring(position)))
		end

		if isPositionInTerrain(position) then
			_annotate("warp destination is in terrain, so skipping.")
		else
			_annotate("not in terrain at least.")

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
				for _, rayLength: number in ipairs({ 0.2, 1, 9 }) do --4, 5, 6
					local raycastParams = RaycastParams.new()
					raycastParams.FilterType = Enum.RaycastFilterType.Include
					raycastParams.FilterDescendantsInstances = theFilter
					local rayDir: Vector3 = direction * rayLength
					local raycastResult: RaycastResult | nil =
						workspace:Raycast(position, rayDir, raycastParams) :: RaycastResult | nil

					local line, endPoint
					if debugVectorsEtc then
						line = Instance.new("Part")
						line.Anchored = true
						line.CanCollide = false

						line.Size = Vector3.new(
							math.abs(rayDir.X) + width,
							math.abs(rayDir.Y) + width,
							math.abs(rayDir.Z) + width
						)
						local lineVectorToEdge = Vector3.new(
							direction.X * (line.Size.X - width) / 2,
							direction.Y * (line.Size.Y - width) / 2,
							direction.Z * (line.Size.Z - width) / 2
						)
						line.Color = Color3.new(0.8, 0.8, 0.8)
						line.Position = position + lineVectorToEdge
						line.Shape = Enum.PartType.Block
						line.Transparency = 0.5
						line.Parent = sphere
						line.Name = "Line"

						endPoint = Instance.new("Part")
						endPoint.Anchored = true
						endPoint.CanCollide = false
						endPoint.Shape = Enum.PartType.Ball
						endPoint.Size = Vector3.new(0.5, 0.5, 0.5)
						endPoint.Parent = line
						endPoint.Position = position + direction * rayLength
					end

					if raycastResult then
						if debugVectorsEtc then
							endPoint.Color = Color3.new(1, 0, 0)
							endPoint.Name = "Bad"
						end

						-- _annotate(
						-- 	string.format(
						-- 		"bad raycastresult, hit: %d to: %s, rayLength: %d, direction: %s , material: %s, position: %s, instance: %s",
						-- 		position.Y,
						-- 		tostring(endPoint.Position),
						-- 		rayLength,
						-- 		tostring(direction),
						-- 		tostring(raycastResult.Material),
						-- 		tostring(raycastResult.Position),
						-- 		tostring(raycastResult.Instance.Name)
						-- 	)
						-- )
						castOkay = false
						break
					else
						-- _annotate(
						-- 	string.format(
						-- 		"good raycastresult, hit from: %d to: %s, rayLength: %d, direction: %s",
						-- 		position.Y,
						-- 		tostring(endPoint.Position),
						-- 		rayLength,
						-- 		tostring(direction)
						-- 	)
						-- )
						if debugVectorsEtc then
							endPoint.Color = Color3.new(0, 1, 0)
							endPoint.Name = "Good"
						end
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

	if not res then
		_annotate(
			string.format("Failed to find a valid warp position after %d attempts, %s", maxAttempts, tostring(res))
		)
	else
		_annotate(string.format("found a serverwarp destination, did it, returning res=%s", tostring(res)))
	end

	return res
end

-- this immediately warps them so should only be called via receiving an event which indicates that the client is fully locked.
-- only call this as a response to the client sending in the event that they are fully locked.
local function ServerDoWarpToPosition(player: Player, pos: Vector3, randomize: boolean, sign: BasePart | nil): boolean
	_annotate(string.format("InnerWarp player=%s pos=%s randomize=%s", player.Name, tostring(pos), tostring(randomize)))

	if not player then
		_annotate("innerwarp.player nil")
		return false
	end
	if not player.Character then
		_annotate("innerwarp.char nil")
		return false
	end
	local character = player.Character or player.CharacterAdded:Wait()
	if not character.HumanoidRootPart then
		_annotate("innerwarp.HRP nil")
		return false
	end
	local bad = true

	--finding a position we are allowed to warp to.
	if randomize then
		local goodPosition = findWarpablePositionForSign(sign)
		if not goodPosition then
			-- error("no good position found")
			return false
		end
		pos = goodPosition
	end

	local rootPart = character.HumanoidRootPart

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)

	--2024: is this effectively just the server version of resetting movement states?
	rootPart.Velocity = Vector3.new(0, 0, 0)
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
		-- humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		-- humanoid.PlatformStand = true
		task.wait(0.05)
		_annotate("while true loop stuck in state: " .. tostring(state))
	end
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
	-- humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	task.wait(0.05)
	lightPillar.CreateTemporaryLightPillar(rootPart.Position, "source")
	--actually move AFTER momentum gone.
	_annotate("Actually changing CFrame")
	rootPart.CFrame = CFrame.new(pos)
	_annotate("Changed CFrame")

	lightPillar.CreateTemporaryLightPillar(pos, "destination")
	_annotate("innerWarp done")
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

module.Init = function()
	--when player clicks warp to <sign> they fire this event and go.
	ClientRequestsWarpToRequestFunction.OnServerInvoke = function(player: Player, request: tt.serverWarpRequest): any
		_annotate("server received client request to warp.")

		if request.kind == "sign" then
			_annotate(
				string.format(
					"server has been asked by client to to do a warp of player=%s signId=%s, highlight=%s",
					player.Name,
					tostring(request.signId),
					tostring(request.highlightSignId)
				)
			)
			local pos: Vector3 | nil = tpUtil.signId2Position(request.signId)
			local sign: BasePart | nil = tpUtil.signId2Sign(request.signId)
			if not pos then
				_annotate("no POS?" .. tostring(request.signId))
				return false
			end

			local innerWarpRes = ServerDoWarpToPosition(player, pos, true, sign)

			_annotate(
				string.format(
					"Server done with the warp to signId=%s with res: %s",
					tostring(request.signId),
					tostring(innerWarpRes)
				)
			)
			return innerWarpRes
		elseif request.kind == "position" then
			local res = ServerDoWarpToPosition(player, request.position, false)
			_annotate(
				string.format(
					"Server done with the warp to position=%s with res: %s",
					tostring(request.position),
					tostring(res)
				)
			)
			return res
		end
	end
end

_annotate("end")
return module
