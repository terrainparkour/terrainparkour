--!strict

--2024.08 simplified everything to use serverwarp.
--also added highlighting.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local remotes = require(game.ReplicatedStorage.util.remotes)
local ShowSignsEvent = remotes.getRemoteEvent("ShowSignsEvent")

local module = {}

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

local function InnerWarp(player: Player, pos: Vector3, randomize: boolean): boolean
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

	CreateTemporaryLightPillar(rootPart.Position, "source")
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)

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
		then
			_annotate("state passed.")
			break
		end

		wait(0.1)
		_annotate("while true loop")
	end
	--actually move AFTER momentum gone.
	_annotate("Actually changing CFrame")
	rootPart.CFrame = CFrame.new(pos)
	_annotate("Changed CFrame")

	CreateTemporaryLightPillar(pos, "destination")
	_annotate("innerWarp done")
	return true
end

--note that this does NOT clear client state and therefore is unsafe
--2024.08 at onset of this version, this is only used by admins.
module.WarpToUsername = function(player, username: string)
	_annotate(string.format("WarpToUsername player=%s username=%s", player.Name, username))
	local targetPlayer = tpUtil.looseGetPlayerFromUsername(username)
	if targetPlayer == nil or targetPlayer.Character == nil then
		return false
	end
	local pos = targetPlayer.Character.PrimaryPart.Position + Vector3.new(10, 20, 10)
	if not pos then
		warn("player not found in workspace")
		return false
	end
	return InnerWarp(player, pos, false)
end

-- this is what's called when a player does "/rr".
module.WarpToSignName = function(player, signName: string, hypotheticalTargetSignId: number?)
	_annotate(
		string.format(
			"WarpToSignName player=%s signName=%s hypotheticalTargetSignId=%s",
			player.Name,
			signName,
			tostring(hypotheticalTargetSignId)
		)
	)
	local signId = tpUtil.looseSignName2SignId(signName)
	if signId == nil then
		return false
	end
	local pos = tpUtil.signId2Position(signId) :: Vector3
	if not pos then
		return false
	end
	local res = InnerWarp(player, pos, true)
	if res then
		ShowSignsEvent:FireClient(player, { hypotheticalTargetSignId })
	end
	return res
end

module.WarpToSignId = function(player: Player, signId: number, hypotheticalTargetSignId: number?)
	_annotate(
		string.format(
			"WarpToSignId player=%s signId=%s, hypotheticalTargetSignId=%s",
			player.Name,
			tostring(signId),
			tostring(hypotheticalTargetSignId)
		)
	)
	if not signId then --do nothing, this was a reflected playerwarp (?)
		warn("no signId.")
		return false
	end
	local pos = tpUtil.signId2Position(signId) :: Vector3
	if not pos then
		_annotate("no POS?" .. tostring(signId))
		return false
	end
	_annotate("starting InnerWarp")
	local innerWarpRes = InnerWarp(player, pos, true)
	if innerWarpRes and hypotheticalTargetSignId then
		_annotate("because we had innerWarpRes and hypothetical, we are: " .. tostring(hypotheticalTargetSignId))

		-- TODO interesting, we could send along this player and everyone's top ten list for this sign target too. But they kind of have that already
		-- after they finish the run.
		ShowSignsEvent:FireClient(player, { hypotheticalTargetSignId })
	end
	_annotate("end WarpToSignId with res: " .. tostring(innerWarpRes))
	return innerWarpRes
end

module.Init = function()
	local WarpRequestFunction = remotes.getRemoteFunction("WarpRequestFunction")
	--when player clicks warp to <sign> they fire this event and go.
	WarpRequestFunction.OnServerInvoke = function(player: Player, signId: number): any
		_annotate("WarpRequestFunction.OnServerInvoke")
		module.WarpToSignId(player, signId)
	end
end

_annotate("end")
return module
