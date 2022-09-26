--!strict

--2022.04.29 only called by RS.warper which must have been required by various client scripts
--eval 9.25.22

local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local timers = require(game.ServerScriptService.timers)

local rf = require(game.ReplicatedStorage.util.remotes)

local serverWantsWarpFunction = rf.getRemoteFunction("ServerWantsWarpFunction")

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
		print("bad")
	end

	spawn(function()
		while true do
			wait(1 / 37)
			part.Transparency = part.Transparency + 0.015
			if part.Transparency >= 1 then
				part:Destroy()
				break
			end
		end
	end)
end

local function InnerWarp(player: Player, pos: Vector3, randomize: boolean): boolean
	local size = nil
	if randomize then
		if size == nil then
			pos = pos + Vector3.new(math.random(5), 25 + math.random(10), math.random(5))
		else
			print("here")
			pos = pos
				+ Vector3.new(math.random(size.X) - size.X / 2, 25 + math.random(50), math.random(size.Z) - size.Z / 2)
		end
	end
	if not player then
		return false
	end
	if not player.Character then
		return false
	end
	local rootPart = player.Character.HumanoidRootPart

	CreateTemporaryLightPillar(rootPart.Position, "source")

	--TODO this is for cleaning up humanoid states. But it would be nice if it was cleaner
	--i.e. cleaning up swimming state etc.
	player.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	player.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	player.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
	player.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

	player.Character.Humanoid.Sit = false

	rootPart.Velocity = Vector3.new(0, 0, 0)
	rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	player.Character.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	timers.cancelRun(player, "innerWarp.afterVelocityRemoval")

	--actually move AFTER momentum gone.
	rootPart.CFrame = CFrame.new(pos)

	CreateTemporaryLightPillar(pos, "destination")
	return true
end

--note that this does NOT clear client state and therefore is unsafe
--todo: make a new remote warp reservation function
module.WarpToUsername = function(player, username: string)
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

module.WarpToSignName = function(player, signName: string)
	local signId = tpUtil.looseSignName2SignId(signName)
	if signId == nil then
		return false
	end
	serverWantsWarpFunction:InvokeClient(player, signId)
	-- return module.WarpToSignId(player, signId)
end

--make this also warpable to signNumber
module.WarpToSignId = function(player: Player, signId: number, hasLock: boolean): boolean
	local pos = tpUtil.signId2Position(signId)
	-- local signname = tpUtil.signId2signName(signId)
	-- local sign: Part = game.Workspace:FindFirstChild("Signs"):FindFirstChild(signname)
	if not pos then
		return false
	end
	if hasLock then
		return InnerWarp(player, pos, true)
	else
		serverWantsWarpFunction:InvokeClient(player, signId)
	end
end

local warpRequestFunction = rf.getRemoteFunction("WarpRequestFunction")
--when player clicks warp to <sign> they fire this event and go.
warpRequestFunction.OnServerInvoke = function(player: Player, signId: number): any
	-- print("server receive warp.")
	module.WarpToSignId(player, signId, true)
end

return module
