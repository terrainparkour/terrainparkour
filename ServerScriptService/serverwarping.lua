--!strict

--2022.04.29 only called by RS.warper which must have been required by various client scripts
--eval 9.25.22

--2024.08 simplified everything to use serverwarp.
--also added highlighting.
local annotationStart = tick()
local doAnnotation = true

local function annotate(s: string)
	if doAnnotation then
		if typeof(s) == "string" then
			print("serverWarping: " .. string.format("%.1fs ", tick() - annotationStart) .. "text:" .. s)
		else
			print("serverWarping: " .. string.format("%.1fs ", tick() - annotationStart) .. " : " .. tostring(s))
			print(s)
		end
	end
end

local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local remotes = require(game.ReplicatedStorage.util.remotes)

local serverWantsWarpFunction = remotes.getRemoteFunction("serverWantsWarpFunction")

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
		annotate("bad")
	end

	spawn(function()
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

--what in the world is size here?
local function InnerWarp(player: Player, pos: Vector3, randomize: boolean): boolean
	annotate("innerwarp.")
	annotate("invoke Client:serverWantsWarpFunction .")
	serverWantsWarpFunction:InvokeClient(player, 0)
	if randomize then
		pos = pos + Vector3.new(math.random(5), 25 + math.random(10), math.random(5))
	end
	if not player then
		annotate("innerwarp.player nil")
		return false
	end
	if not player.Character then
		annotate("innerwarp.char nil")
		return false
	end
	local character = player.Character or player.CharacterAdded:Wait()
	if not character.HumanoidRootPart then
		annotate("innerwarp.HRP nil")
		return false
	end
	local rootPart = character.HumanoidRootPart

	CreateTemporaryLightPillar(rootPart.Position, "source")

	--TODO this is for cleaning up humanoid states. But it would be nice if it was cleaner
	--i.e. cleaning up swimming state etc.

	local hum = character:WaitForChild("Humanoid") :: Humanoid
	hum:ChangeState(Enum.HumanoidStateType.GettingUp)

	--2024: is this effectively just the server version of resetting movement states?
	rootPart.Velocity = Vector3.new(0, 0, 0)
	rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	while true do
		local state = hum:GetState()
		if
			state == Enum.HumanoidStateType.GettingUp
			or state == Enum.HumanoidStateType.Running
			or state == Enum.HumanoidStateType.Freefall
			or state == Enum.HumanoidStateType.Dead
			or state == Enum.HumanoidStateType.Swimming
		then
			annotate("state passed.")
			break
		end

		wait(0.1)
		annotate("while true loop")
	end
	--actually move AFTER momentum gone.
	annotate("Actually changing CFrame")
	rootPart.CFrame = CFrame.new(pos)
	annotate("Changed CFrame")

	CreateTemporaryLightPillar(pos, "destination")
	annotate("innerWarp done")
	return true
end

--note that this does NOT clear client state and therefore is unsafe
--2024.08 at onset of this version, this is only used by admins.
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

--this is the one players can use.
module.WarpToSignName = function(player, signName: string)
	local signId = tpUtil.looseSignName2SignId(signName)
	if signId == nil then
		return false
	end
	local pos = tpUtil.signId2Position(signId) :: Vector3
	if not pos then
		return false
	end
	return InnerWarp(player, pos, true)
end

--make this also warpable to signNumber
module.WarpToSignId = function(player: Player, signId: number): boolean
	annotate("start warpToSignId.")
	if not signId then --do nothing, this was a reflected playerwarp (?)
		annotate("no signId.")
		return false
	end
	local pos = tpUtil.signId2Position(signId) :: Vector3
	if not pos then
		annotate("no POS?")
		return false
	end
	annotate("starting InnerWarp")
	local innerWarpRes = InnerWarp(player, pos, true)
	annotate("end WarpToSignId with res: " .. tostring(innerWarpRes))
	return innerWarpRes
end

module.init = function()
	local warpRequestFunction = remotes.getRemoteFunction("warpRequestFunction")
	--when player clicks warp to <sign> they fire this event and go.
	warpRequestFunction.OnServerInvoke = function(player: Player, signId: number): any
		annotate("warpRequestFunction.OnServerInvoke")
		module.WarpToSignId(player, signId)
	end
end

return module
