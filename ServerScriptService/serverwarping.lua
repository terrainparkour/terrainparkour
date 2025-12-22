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
local enums = require(game.ReplicatedStorage.util.enums)

local tpUtil: typeof(require(game.ReplicatedStorage.util.tpUtil)) = require(game.ReplicatedStorage.util.tpUtil)
local remotes = require(game.ReplicatedStorage.util.remotes)
local tt = require(game.ReplicatedStorage.types.gametypes)
local lightPillar = require(game.ServerScriptService.lightPillar)
local settingsServer = require(game.ServerScriptService.settingsServer)
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)

local PlayersService = game:GetService("Players")
local MIN_FINDS_FOR_PLAYER_WARP = 100

local module = {}

---------- EVENTS ------------
local ServerRequestClientToWarpLockEvent: RemoteEvent = remotes.getRemoteEvent("ServerRequestClientToWarpLockEvent")
local ClientRequestsWarpToRequestFunction = remotes.getRemoteFunction("ClientRequestsWarpToRequestFunction")

local _debugVectorsEtc = false
----------- LOCAL FUNCTIONS --------------------

-- modified to not count AIR as terrain.
local function isPositionInTerrain(position: Vector3): { success: boolean, occ: number, mat: Enum.Material }
	local regionSize = Vector3.new(2, 3, 2) -- Adjust this size based on your needs
	local region = Region3.new(position - regionSize / 2, position + regionSize / 2)

	region = region:ExpandToGrid(4)

	-- Read the terrain voxels in the region
	local materials, occupancies = (workspace.Terrain :: any):ReadVoxels(region, 4)

	if not materials or typeof(materials) ~= "table" then
		if materials then
			_annotate("ReadVoxels returned non-table materials: " .. typeof(materials) .. " val=" .. tostring(materials))
		end
		return { success = true, occ = 0, mat = Enum.Material.Air }
	end

	-- Check if any voxel in the region is occupied by non-air, non-water
	local matSize = #materials
	for x = 1, matSize do
		for y = 1, #materials[x] do
			for z = 1, #materials[x][y] do
				local occupancy = occupancies and occupancies[x][y][z] or 0
				local material = materials[x][y][z]
				if occupancy > 0 and material ~= Enum.Material.Air and material ~= Enum.Material.Water then
					return { success = false, occ = occupancy, mat = material }
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

	-- Generate random position in sign's LOCAL space, then transform to world space.
	-- This correctly handles arbitrarily rotated signs (the old AABB approach spawned players
	-- off the sign when it was rotated, since the bounding box expanded beyond the actual footprint).
	local function getRandomPointAboveSign(): Vector3
		-- Random point within 70% of sign's XZ footprint (15% inset from each edge)
		local insetFactor = 0.70
		local localX = (math.random() - 0.5) * size.X * insetFactor
		local localZ = (math.random() - 0.5) * size.Z * insetFactor
		-- 2-16 studs above the sign's top surface
		local localY = halfSize.Y + math.random(2, 16)

		-- Transform from local sign space to world space
		local worldPos = (cf * CFrame.new(localX, localY, localZ)).Position
		return worldPos
	end

	local maxAttempts: number = 45
	local res: Vector3? = nil

	for _ = 1, maxAttempts do
		local position: Vector3 = getRandomPointAboveSign()

		local terrainCheckResult = isPositionInTerrain(position)
		if not terrainCheckResult.success then
			_annotate(string.format("warp destination is in terrain, so skipping. position=%s, occ=%d, mat=%s", tostring(position), terrainCheckResult.occ, tostring(terrainCheckResult.mat)))
		else
			_annotate(string.format("Got a good position to warp at least not in terrain. position=%s", tostring(position)))

			local rayDirections = {
				-- Vector3.new(0, -1, 0), -- Down
				Vector3.new(0, 1, 0), -- Up
				Vector3.new(-1, 0, 0), -- Left
				Vector3.new(1, 0, 0), -- Right
				Vector3.new(0, 0, -1), -- Back
				Vector3.new(0, 0, 1), -- Forward
			}
			local _width = 0.3
			local castOkay = true

			for _, direction: Vector3 in ipairs(rayDirections) do
				for _, rayLength: number in ipairs({ 1, 1.5, 0.5 }) do --4, 5, 6
					local raycastParams = RaycastParams.new()
					raycastParams.FilterType = Enum.RaycastFilterType.Include
					raycastParams.FilterDescendantsInstances = theFilter
					local rayDir: Vector3 = direction * rayLength
					local raycastResult: RaycastResult | nil = workspace:Raycast(position, rayDir, raycastParams) :: RaycastResult | nil

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
		_annotate(string.format("Failed to find a valid warp position after %d attempts, %s", maxAttempts, tostring(res)))
		return nil
	end
end

-- this immediately warps them so should only be called via receiving an event which indicates that the client is fully locked.
-- only call this as a response to the client sending in the event that they are fully locked.
local function ServerDoWarpToPosition(player: Player, pos: Vector3, randomize: boolean, sign: BasePart | nil): tt.warpResult
	_annotate(string.format("Starting: serverDoWarpToPosition player=%s pos=%s randomize=%s sign=%s", player.Name, tostring(pos), tostring(randomize), sign and sign.Name or "nil"))

	if not player then
		_annotate("ServerDoWarpToPosition: player is nil")
		return { didWarp = false, reason = "player nil" }
	end
	if not player.Character then
		_annotate(string.format("ServerDoWarpToPosition: %s has no character (died during warp?)", player.Name))
		return { didWarp = false, reason = "character nil (player may have died)" }
	end
	local character = player.Character
	if not character then
		_annotate(string.format("ServerDoWarpToPosition: %s character became nil", player.Name))
		return { didWarp = false, reason = "character became nil" }
	end

	local rootPartInstance: Instance? = character:FindFirstChild("HumanoidRootPart")
	if not rootPartInstance or not rootPartInstance:IsA("BasePart") then
		_annotate(string.format("ServerDoWarpToPosition: %s missing HumanoidRootPart", player.Name))
		return { didWarp = false, reason = "HumanoidRootPart missing" }
	end
	local rootPart: BasePart = rootPartInstance :: BasePart

	local humanoidInstance: Instance? = character:FindFirstChild("Humanoid")
	if not humanoidInstance or not humanoidInstance:IsA("Humanoid") then
		_annotate(string.format("ServerDoWarpToPosition: %s missing Humanoid", player.Name))
		return { didWarp = false, reason = "Humanoid missing" }
	end
	local humanoid: Humanoid = humanoidInstance :: Humanoid

	--finding a position we are allowed to warp to.
	if randomize then
		if not sign then
			_annotate("ServerDoWarpToPosition: randomize=true but no sign provided")
			return { didWarp = false, reason = "randomize requested but no sign provided" }
		end
		local signPart: BasePart = sign :: BasePart
		local goodPosition = findWarpablePositionForSign(signPart)
		if not goodPosition then
			_annotate(string.format("ServerDoWarpToPosition: no valid position found for sign %s after 45 attempts", signPart.Name))
			return { didWarp = false, reason = string.format("no valid position for sign %s (terrain blocked)", signPart.Name) }
		end
		pos = goodPosition
		_annotate(string.format("ServerDoWarpToPosition: found valid position %s for sign %s", tostring(pos), signPart.Name))
	end

	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	_annotate("humanoid:ChangeState(Enum.HumanoidStateType.Freefall)")
	rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)

	while true do
		local state = humanoid:GetState()
		if state == Enum.HumanoidStateType.PlatformStanding then
			_annotate("Got to PlatformStanding state")
			break
		end
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, false)
		humanoid.PlatformStand = false
		humanoid.PlatformStand = true
		task.wait(0.02)
		_annotate(string.format("waiting for PlatformStanding, currently in state: %s", tostring(state)))
	end
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)

	task.wait(0.02)

	lightPillar.CreateTemporaryLightPillar(rootPart.Position, "source")
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	local oldPos = rootPart.Position
	rootPart.Position = pos
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	_annotate(string.format("Teleported %s from %s to %s", player.Name, tostring(oldPos), tostring(pos)))

	lightPillar.CreateTemporaryLightPillar(pos, "destination")
	_annotate("serverDoWarpToPosition completed successfully")
	return { didWarp = true, reason = "success" }
end

-- if you are on the server and want to do a warp, then call this to make sure the player is fully locked out first.
module.RequestClientToWarpToWarpRequest = function(player: Player, request: tt.serverWarpRequest)
	_annotate(string.format("server warp command for %s: signId=%s highlightSignId=%s kind=%s position=%s", player.Name, tostring(request.signId), tostring(request.highlightSignId), tostring(request.kind), tostring(request.position)))
	ServerRequestClientToWarpLockEvent:FireClient(player, request)
end

local function CheckWarpingSecurityForPlayerAndSign(player: Player, signId: number?): boolean
	if not signId then
		annotater.Error(string.format("warp security: user %s (userId=%d) had no signId", player.Name, player.UserId), player.UserId)
		return false
	end
	if player.UserId == enums.objects.TerrainParkourUserId then
		--admin can warp to unseen.
	elseif not playerData2.HasUserFoundSign(player.UserId, signId) then
		local signName = tpUtil.signId2signName(signId)
		-- This is suspicious - normal UI shouldn't allow warping to unfound signs
		annotater.Error(string.format("warp security REJECTED: user %s (userId=%d) tried to warp to unfound sign %s (signId=%d)", player.Name, player.UserId, signName, signId), player.UserId)
		return false
	end
	_annotate(string.format("warp security passed for %s to signId=%d", player.Name, signId))
	return true
end

-- Check if requester can warp to target player
local function CheckWarpingSecurityForPlayerToPlayer(requester: Player, targetUserId: number): (boolean, string)
	-- Admin can warp to anyone
	if requester.UserId == enums.objects.TerrainParkourUserId then
		return true, "admin allowed"
	end

	-- Check requester has enough finds
	local requesterStats = playerData2.GetStatsByUserId(requester.UserId, "warp_to_player_check")
	if requesterStats.findCount < MIN_FINDS_FOR_PLAYER_WARP then
		return false, string.format("need %d finds to warp to players", MIN_FINDS_FOR_PLAYER_WARP)
	end

	-- Check target player exists and is in game
	local targetPlayer = PlayersService:GetPlayerByUserId(targetUserId)
	if not targetPlayer then
		return false, "target player not in game"
	end

	-- Check target's warp permission setting
	local targetPermission = settingsServer.GetSettingValueByUserId(targetUserId, settingEnums.settingDefinitions.WARP_TO_PERMISSION.name)
	if not targetPermission or targetPermission == "none" then
		return false, "target does not allow warping"
	end

	if targetPermission == "all" then
		return true, "allowed"
	end

	if targetPermission == "robloxFriends" then
		local success, isFriend = pcall(function()
			return requester:IsFriendsWith(targetUserId)
		end)
		if success and isFriend then
			return true, "allowed (friend)"
		else
			return false, "target only allows friends"
		end
	end

	-- TODO: Add TP friends check when TP friends system is implemented
	-- if targetPermission == "tpFriends" then
	-- 	return tpFriends.IsFriendWith(requester.UserId, targetUserId)
	-- end

	return false, "unknown permission type"
end

-- Get warpable position near target player with terrain checking
local function GetWarpPositionForPlayer(targetPlayer: Player): Vector3?
	local character = targetPlayer.Character
	if not character then
		_annotate("GetWarpPositionForPlayer: target has no character")
		return nil
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		_annotate("GetWarpPositionForPlayer: target has no HumanoidRootPart")
		return nil
	end

	local targetPos = hrp.Position
	local maxAttempts = 30
	local MIN_Y_OFFSET = 10 -- Never warp below or at same level; always above

	-- Try various offsets around the target player
	-- All offsets MUST have Y >= MIN_Y_OFFSET (never below or to the side without being above)
	local offsets = {
		Vector3.new(0, 12, 0), -- Directly above first
		Vector3.new(0, 15, 0),
		Vector3.new(0, 20, 0),
		Vector3.new(5, 12, 5), -- Above and offset
		Vector3.new(-5, 12, 5),
		Vector3.new(5, 12, -5),
		Vector3.new(-5, 12, -5),
		Vector3.new(6, 10, 0), -- Minimal horizontal with minimum vertical
		Vector3.new(-6, 10, 0),
		Vector3.new(0, 10, 6),
		Vector3.new(0, 10, -6),
	}

	-- First try the predefined offsets
	for _, offset in ipairs(offsets) do
		local candidatePos = targetPos + offset
		local terrainCheck = isPositionInTerrain(candidatePos)
		if terrainCheck.success then
			-- Also do raycast checks like we do for sign warps
			local castOkay = true
			local rayDirections = {
				Vector3.new(0, 1, 0), -- Up
				Vector3.new(-1, 0, 0), -- Left
				Vector3.new(1, 0, 0), -- Right
				Vector3.new(0, 0, -1), -- Back
				Vector3.new(0, 0, 1), -- Forward
			}

			for _, direction in ipairs(rayDirections) do
				for _, rayLength in ipairs({ 1, 1.5 }) do
					local raycastParams = RaycastParams.new()
					raycastParams.FilterType = Enum.RaycastFilterType.Include
					raycastParams.FilterDescendantsInstances = theFilter
					local rayDir = direction * rayLength
					local raycastResult = workspace:Raycast(candidatePos, rayDir, raycastParams)

					if raycastResult then
						_annotate(string.format("GetWarpPositionForPlayer: raycast hit at offset %s, direction %s", tostring(offset), tostring(direction)))
						castOkay = false
						break
					end
				end
				if not castOkay then
					break
				end
			end

			if castOkay then
				_annotate(string.format("GetWarpPositionForPlayer: found valid position at offset %s", tostring(offset)))
				return candidatePos
			end
		else
			_annotate(string.format("GetWarpPositionForPlayer: terrain blocked at offset %s, mat=%s", tostring(offset), tostring(terrainCheck.mat)))
		end
	end

	-- If predefined offsets failed, try random positions above the target
	for attempt = 1, maxAttempts do
		-- Random horizontal offset 0-8 studs, always above by MIN_Y_OFFSET to 25 studs
		local angle = math.random() * math.pi * 2
		local horizontalDistance = math.random() * 8 -- 0-8 studs horizontal
		local yOffset = MIN_Y_OFFSET + math.random() * 15 -- 10-25 studs above

		local offset = Vector3.new(math.cos(angle) * horizontalDistance, yOffset, math.sin(angle) * horizontalDistance)

		local candidatePos = targetPos + offset
		local terrainCheck = isPositionInTerrain(candidatePos)

		if terrainCheck.success then
			local castOkay = true
			local rayDirections = {
				Vector3.new(0, 1, 0),
				Vector3.new(-1, 0, 0),
				Vector3.new(1, 0, 0),
				Vector3.new(0, 0, -1),
				Vector3.new(0, 0, 1),
			}

			for _, direction in ipairs(rayDirections) do
				local raycastParams = RaycastParams.new()
				raycastParams.FilterType = Enum.RaycastFilterType.Include
				raycastParams.FilterDescendantsInstances = theFilter
				local raycastResult = workspace:Raycast(candidatePos, direction * 1.5, raycastParams)
				if raycastResult then
					castOkay = false
					break
				end
			end

			if castOkay then
				_annotate(string.format("GetWarpPositionForPlayer: found valid position on attempt %d at %s", attempt, tostring(candidatePos)))
				return candidatePos
			end
		end
	end

	_annotate(string.format("GetWarpPositionForPlayer: failed to find valid position after %d attempts for target %s", maxAttempts + #offsets, targetPlayer.Name))
	return nil
end

module.Init = function()
	_annotate("init")
	--when player clicks warp to <sign> they fire this event and go.
	ClientRequestsWarpToRequestFunction.OnServerInvoke = function(player: Player, request: tt.serverWarpRequest): tt.warpResult
		_annotate("server received client request to warp.")

		if request.kind == "sign" then
			local signId = request.signId
			if not signId then
				return { didWarp = false, reason = "no signId" }
			end
			local validSignId: number = signId :: number

			_annotate(string.format("server has been asked by client to to do a warp of player=%s signId=%s, highlight=%s", player.Name, tostring(validSignId), tostring(request.highlightSignId)))
			local pos: Vector3 | nil = tpUtil.signId2Position(validSignId)
			if not pos then
				local signName = enums.signId2name[validSignId] or "UNKNOWN"
				_annotate(string.format("no POS for signId=%d name=%s", validSignId, signName))
				return { didWarp = false, reason = "no POS" }
			end
			local validPos: Vector3 = pos :: Vector3

			local sign: BasePart | nil = tpUtil.signId2Sign(validSignId)
			if not sign then
				_annotate("no SIGN?" .. tostring(validSignId))
				return { didWarp = false, reason = "no SIGN" }
			end

			local securityPass = CheckWarpingSecurityForPlayerAndSign(player, validSignId)
			if not securityPass then
				-- Error already logged by CheckWarpingSecurityForPlayerAndSign with full details
				return { didWarp = false, reason = "security pass failed - user has not found this sign" }
			end

			local innerWarpRes = ServerDoWarpToPosition(player, validPos, true, sign)
			if not innerWarpRes.didWarp then
				_annotate(string.format("inner warp failed for %s to sign %d: %s", player.Name, validSignId, innerWarpRes.reason))
				return innerWarpRes
			end

			_annotate(string.format("Server done with warp of %s to signId=%d", player.Name, validSignId))
			return innerWarpRes
		elseif request.kind == "position" then
			-- Position warps are only allowed from server-initiated requests (admin commands)
			-- Client-initiated position warps are rejected for security
			annotater.Error(string.format("user %s attempted client-initiated position warp (rejected)", player.Name), player.UserId)
			return { didWarp = false, reason = "position warps not allowed from client" }
		elseif request.kind == "player" then
			local targetUserId = request.targetUserId
			if not targetUserId then
				return { didWarp = false, reason = "no targetUserId provided" }
			end

			_annotate(string.format("server has been asked to warp %s to player %d", player.Name, targetUserId))

			local allowed, reason = CheckWarpingSecurityForPlayerToPlayer(player, targetUserId)
			if not allowed then
				_annotate(string.format("warp to player rejected: %s", reason))
				return { didWarp = false, reason = reason }
			end

			local targetPlayer = PlayersService:GetPlayerByUserId(targetUserId)
			if not targetPlayer then
				return { didWarp = false, reason = "target player left" }
			end

			local warpPos = GetWarpPositionForPlayer(targetPlayer)
			if not warpPos then
				return { didWarp = false, reason = "could not find safe position near target (terrain blocked)" }
			end

			local innerWarpRes = ServerDoWarpToPosition(player, warpPos, false)
			if not innerWarpRes.didWarp then
				_annotate(string.format("inner warp failed for %s to player %d: %s", player.Name, targetUserId, innerWarpRes.reason))
				return innerWarpRes
			end

			_annotate(string.format("Server done with warp of %s to player %d", player.Name, targetUserId))
			return innerWarpRes
		else
			warn("unknown kind of warp request: " .. tostring(request.kind))
			return { didWarp = false, reason = "unknown kind of warp request" }
		end
	end
	_annotate("init done")
end

_annotate("end")
return module
