--!strict
--eval 9.25.22

local PlayerService = game:GetService("Players")
--setup sign touch events and also trigger telling user about them.
local tt = require(game.ReplicatedStorage.types.gametypes)
local lbupdater = require(game.ServerScriptService.lbupdater)
local enums = require(game.ReplicatedStorage.util.enums)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local notify = require(game.ReplicatedStorage.notify)
local signInfo = require(game.ReplicatedStorage.signInfo)
local colors = require(game.ReplicatedStorage.util.colors)
local badgeCheckers = require(game.ServerScriptService.badgeCheckersSecret)
local signEnums = require(game.ReplicatedStorage.enums.signEnums)

local banning = require(game.ServerScriptService.banning)
local rdb = require(game.ServerScriptService.rdb)
local timers = require(game.ServerScriptService.timers)

-- from the POV of physical hit monitor, have we already most recently logged the user as touching this sign?
-- if so, don't trigger new race starts from it.
-- TODO 2022-add checking that it always gets fully cleared safely.
local userSignTouchLocks: { [number]: { [number]: boolean } } = {}

local module = {}

--how often is player location modified? every frame I guess?
--this is used to investigate feasibility of using location rather than :touched as a sign touch modifier.
if false then
	local pp = Vector3.new(0, 0, 0)
	spawn(function()
		local t = tick()
		while true do
			local player = PlayerService:GetPlayers()[1]
			wait(1 / 1000.0)

			if player == nil then
				continue
			end
			if player.Character == nil then
				continue
			end
			if player.Character.HumanoidRootPart == nil then
				continue
			end
			local tick = tick()
			local pos = player.Character.HumanoidRootPart.Position
			print(string.format("%0.10f %0.4f-%0.4f-%0.4f", tick - t, pp.X - pos.X, pp.Y - pos.Y, pp.Z - pos.Z))
			pp = pos
			t = tick
		end
	end)
end

--store it in cache, send a remoteevent to persist it, and also tell the user through an event.
--when serverside notices a sign has been touched:

local lastTouchTick = tick()
--for some reason these show up either ~0.11 apart, or 0.0002s apart.

local function touchedSignServer(hit: BasePart, sign: Part)
	--as soon as server receives the hit, note down the hit.

	local theHitTick = tick()
	-- print(string.format("gap between physics touchedSign ticks: %0.10f", theHitTick - lastTouchTick))
	lastTouchTick = theHitTick

	--lots of validation on the touch.
	if not hit:IsA("MeshPart") then
		return false
	end

	local player: Player = tpUtil.getPlayerForUsername(hit.Parent.Name)
	if not player then
		return false
	end

	return module.touchedSign(player, sign, theHitTick)
end

module.touchedSign = function(player: Player, sign: Part, theHitTick: number)
	local userId: number = player.UserId
	if userId == nil then
		return false
	end

	--what is the point of userSignTouchLocks?
	if userSignTouchLocks[userId] == nil then
		userSignTouchLocks[userId] = {}
	end

	local signId: number = enums.name2signId[sign.Name]
	if signId == nil then
		return false
	end

	--exclude dead players from touching a sign.
	local hum: Humanoid = player.Character.Humanoid
	if not hum or hum.Health <= 0 then
		return false
	end

	if banning.getBanLevel(player.UserId) > 0 then
		return false
	end

	--2022.04 this is what prevents you from restarting a race when you are already having touched.
	--this is kind of a debounce.
	if userSignTouchLocks[userId][signId] == true then
		warn("already locked")
		return false
	end

	--validation end, the find is real.

	userSignTouchLocks[userId][signId] = true
	local newFind = not rdb.hasUserFoundSign(userId, signId)

	rdb.ImmediatelySetUserFoundSignInCache(userId, signId)

	--newFind is actually calculated in lua server, not python world.
	if newFind then
		--update players with notes - you found X, other person found X
		spawn(function()
			--handle finding a new sign and also accumulate a bunch of stats on the json response

			local res: tt.pyUserFoundSign = rdb.userFoundSign(userId, signId)
			badgeCheckers.checkBadgeGrantingAfterFind(userId, signId, res)
			--this is kind of weird.  regenerating another partial stat block?
			local options: tt.signFindOptions = {
				kind = "userFoundSign",
				userId = userId,
				lastFinderUserId = res.lastFinderUserId,
				lastFinderUsername = rdb.getUsernameByUserId(res.lastFinderUserId),
				signName = sign.Name,
				totalSignsInGame = signInfo.getSignCountInGameForUserConsumption(),
				userTotalFindCount = res.userTotalFindCount,
				signTotalFinds = res.signTotalFinds,
				findRank = res.findRank,
			}

			notify.notifyPlayerOfSignFind(player, options)

			--update all players leaderboards.
			for _, otherPlayer in ipairs(PlayerService:GetPlayers()) do
				lbupdater.updateLeaderboardForFind(otherPlayer, options)
			end
		end)
	end

	userSignTouchLocks[userId][signId] = false
	--ah, the hits are still being processed when this rolls out!
end

local useLeftFaceSignNames = { ["cOld mOld on a sLate pLate"] = 1, ["Tetromino"] = 2 }
local unanchoredSignNames = { ["Freedom"] = 1 }

local function SetupSignVisually(part: Part)
	if part.Name == signEnums.signs.COLD_MOLD then
		part.Material = Enum.Material.Slate
	else
		part.Material = Enum.Material.Granite
	end
	if unanchoredSignNames[part.Name] then
		part.Anchored = false
	else
		part.Anchored = true
	end

	part.Color = Color3.fromRGB(255, 89, 89)

	local childs = part:GetChildren()
	for _, child in ipairs(childs) do
		child:Destroy()
	end

	local sguiName = "SignGui_" .. part.Name
	local sGui = Instance.new("SurfaceGui")
	sGui.Name = sguiName
	sGui.Parent = part

	local canvasSize: Vector2

	if useLeftFaceSignNames[part.Name] then
		canvasSize = Vector2.new(part.Size.Y * 30, part.Size.X * 30)
		sGui.Face = Enum.NormalId.Left
	else
		canvasSize = Vector2.new(part.Size.Z * 30, part.Size.X * 30)
		sGui.Face = Enum.NormalId.Top
	end
	sGui.CanvasSize = canvasSize
	sGui.Brightness = 1.5

	sGui.Parent.TopSurface = Enum.SurfaceType.Smooth
	sGui.Parent.BottomSurface = Enum.SurfaceType.Smooth
	sGui.Parent.LeftSurface = Enum.SurfaceType.Smooth
	sGui.Parent.RightSurface = Enum.SurfaceType.Smooth
	sGui.Parent.FrontSurface = Enum.SurfaceType.Smooth
	sGui.Parent.BackSurface = Enum.SurfaceType.Smooth

	local children = sGui:GetChildren()
	for _, c in ipairs(children) do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end

	local textLabel = Instance.new("TextLabel")
	textLabel.Parent = sGui
	textLabel.AutoLocalize = true
	textLabel.Text = part.Name
	textLabel.Font = Enum.Font.Gotham
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.TextScaled = true
	textLabel.RichText = true
	textLabel.TextColor3 = colors.signTextColor

	--I shold add a touch sound TODO
	--i should add a touch visual
end

local setupSignMovement = {}

--setupSigns
module.init = function()
	for _, sign: Part in ipairs(game.Workspace:WaitForChild("Signs"):GetChildren()) do
		SetupSignVisually(sign)
		local signId = enums.name2signId[sign.Name]
		if signId == nil then
			warn("bad" .. tostring(sign.Name))
			continue
		end
		signInfo.storeSignPositionInMemory(signId, sign.Position)

		if true then
			--this is necessary for tracking finds.
			sign.Touched:Connect(function(hit)
				touchedSignServer(hit, sign)
			end)
		end
	end

	spawn(function()
		--rotate the meme sign.
		local meme: Part = game.Workspace:WaitForChild("Signs"):WaitForChild("Meme", 2)

		if meme then
			if setupSignMovement[meme.Name] == nil then
				local r = require(game.ReplicatedStorage.util.signMovement)
				r.rotate(meme)
				setupSignMovement[meme.Name] = true
			end
		end

		local osign: MeshPart = game.Workspace:WaitForChild("Signs"):WaitForChild("O", 2)
		if osign then
			if setupSignMovement[osign.Name] == nil then
				local r = require(game.ReplicatedStorage.util.signMovement)
				r.rotateMeshpart(osign)
				setupSignMovement[osign.Name] = true
			end
		end

		local chiralitySign: Part = game.Workspace:WaitForChild("Signs"):WaitForChild("Chirality", 2)
		if chiralitySign then
			if setupSignMovement[chiralitySign.Name] == nil then
				local r = require(game.ReplicatedStorage.util.signMovement)
				r.riseandspin(chiralitySign)
				setupSignMovement[chiralitySign.Name] = true
			end
		end

		spawn(function()
			local doubleO7Sign = game.Workspace:WaitForChild("Signs"):WaitForChild("007", 2)
			local r = require(game.ReplicatedStorage.util.signMovement)
			r.fadeOutSign(doubleO7Sign, true)
			local signVisible = false
			while true do
				local minute = os.date("%M", tick())
				local minnum = tonumber(minute)
				if minnum == 7 then
					if not signVisible then
						signVisible = true
						r.fadeInSign(doubleO7Sign)
					end
				else
					if signVisible then
						r.fadeOutSign(doubleO7Sign, false)
						signVisible = false
					end
				end

				wait(1)
			end
		end)
	end)
end

return module
