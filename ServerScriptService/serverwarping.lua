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

local module = {}

---------- EVENTS ------------
local ServerRequestClientToWarpLockEvent: RemoteEvent = remotes.getRemoteEvent("ServerRequestClientToWarpLockEvent")
local ClientRequestsWarpToRequestFunction = remotes.getRemoteFunction("ClientRequestsWarpToRequestFunction")
----------- LOCAL FUNCTIONS --------------------
local function CreateTemporaryLightPillar(pos: Vector3, desc: string)
	local part = Instance.new("Part")
	part.Position = Vector3.new(pos.X, pos.Y + 320, pos.Z)
	part.Size = Vector3.new(700, 6, 6)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.Anchored = true
	part.CanTouch = false
	part.Massless = true
	part.Name = "LightPillar"
	part.Transparency = 0.6
	part.Orientation = Vector3.new(0, 0, 90)
	part.Shape = Enum.PartType.Cylinder
	part.Parent = game.Workspace
	if desc == "source" then
		part.Color = Color3.fromRGB(255, 160, 160)
	elseif desc == "destination" then
		part.Color = Color3.fromRGB(160, 250, 160)
	else
		_annotate("bad")
	end

	task.spawn(function()
		while true do
			wait(1 / 37)
			part.Transparency = part.Transparency + 0.009
			if part.Transparency >= 1 then
				part:Destroy()
				break
			end
		end
	end)
end

-- this immediately warps them so should only be called via receiving an event which indicates that the client is fully locked.
-- only call this as a response to the client sending in the event that they are fully locked.
local function ServerDoWarpToPosition(player: Player, pos: Vector3, randomize: boolean): boolean
	_annotate(string.format("InnerWarp player=%s pos=%s randomize=%s", player.Name, tostring(pos), tostring(randomize)))
	if randomize then
		pos = pos + Vector3.new(math.random(5), 25 + math.random(10), math.random(5))
	end
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
	local rootPart = character.HumanoidRootPart

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)

	--2024: is this effectively just the server version of resetting movement states?
	rootPart.Velocity = Vector3.new(0, 0, 0)
	rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	while true do
		local state = humanoid:GetState()
		if
			state == Enum.HumanoidStateType.GettingUp
			or state == Enum.HumanoidStateType.Running
			or state == Enum.HumanoidStateType.Freefall
			or state == Enum.HumanoidStateType.Dead
			or state == Enum.HumanoidStateType.Swimming
			or state == Enum.HumanoidStateType.PlatformStanding
		then
			_annotate("state was (finally.) valid inside ServerDoWarpToPosition, state: " .. tostring(state))
			break
		end
		humanoid.PlatformStand = true
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		humanoid.PlatformStand = true
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		humanoid.PlatformStand = true
		task.wait(0.1)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		task.wait(0.1)
		_annotate("while true loop stuck in state: " .. tostring(state))
	end
	CreateTemporaryLightPillar(rootPart.Position, "source")
	--actually move AFTER momentum gone.
	_annotate("Actually changing CFrame")
	rootPart.CFrame = CFrame.new(pos)
	_annotate("Changed CFrame")

	CreateTemporaryLightPillar(pos, "destination")
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
		_annotate("ClientRequestsWarpToRequestFunction.OnServerInvoke")

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
			if not pos then
				_annotate("no POS?" .. tostring(request.signId))
				return false
			end

			local innerWarpRes = ServerDoWarpToPosition(player, pos, true)
			-- _annotate(
			-- 	"Server done with the warp to signId="
			-- 		.. tostring(request.signId)
			-- 		.. " with res: "
			-- 		.. tostring(innerWarpRes)
			-- )
			return innerWarpRes
		elseif request.kind == "position" then
			return ServerDoWarpToPosition(player, request.position, false)
		end
	end
end

_annotate("end")
return module
