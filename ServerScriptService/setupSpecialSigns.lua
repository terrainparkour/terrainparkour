--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local sound = require(game.ServerScriptService.sounds)

local module = {}

--just in case of parallelization?
local isWeirdSignSetupYet = {}

--loop repeatedly, enabling new day of week signs when they come online.
local function setupDayOfWeekSigns()
	local daySigns = { "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" }
	task.spawn(function()
		local outerDayOfWeek
		local n = 600
		while true do
			local theTick = tick()
			local dayOfWeek = os.date("%A", theTick)
			if dayOfWeek == outerDayOfWeek and outerDayOfWeek ~= nil then
				wait(n)
				continue
			end
			for _, signName in pairs(daySigns) do
				local sign = tpUtil.looseSignName2Sign(signName) :: Part
				if not sign then
					continue
				end
				if signName == dayOfWeek then
					sign.Transparency = 0
					sign.CanCollide = true
					sign.CanTouch = true
					local surfaceGui = sign:FindFirstChildOfClass("SurfaceGui")
					if surfaceGui then
						surfaceGui.Enabled = true
					end
				else
					sign.Transparency = 1
					sign.CanCollide = false
					sign.CanTouch = false
					local surfaceGui = sign:FindFirstChildOfClass("SurfaceGui")
					if surfaceGui then
						surfaceGui.Enabled = false
					end
				end
			end
			--passed update time.
			outerDayOfWeek = dayOfWeek

			wait(n)
		end
	end)
end

module.init = function()
	task.spawn(function()
		local signFolder = game.Workspace:WaitForChild("Signs")
		local cold_mold: Part = signFolder:WaitForChild("cOld mOld on a sLate pLate", 2)
		if cold_mold then
			cold_mold.Material = Enum.Material.Slate
		end

		local ghost: Part = signFolder:WaitForChild("👻", 2)
		if ghost then
			local ghostTextTransparency = 0.7
			ghost.Color = Color3.fromRGB(255, 255, 255)
			ghost.Transparency = 1
			local label = ghost:FindFirstChild("TextLabel") :: TextLabel
			if label then
				label.TextTransparency = ghostTextTransparency
			end
		end

		setupDayOfWeekSigns()

		--rotate the meme sign.
		local meme: Part = signFolder:WaitForChild("Meme", 2)

		if meme then
			if isWeirdSignSetupYet[meme.Name] == nil then
				local r = require(game.ReplicatedStorage.util.signMovement)
				r.rotate(meme)
				isWeirdSignSetupYet[meme.Name] = true
			end
		end

		local osign: MeshPart = signFolder:WaitForChild("O", 2)
		if osign then
			if isWeirdSignSetupYet[osign.Name] == nil then
				local r = require(game.ReplicatedStorage.util.signMovement)
				r.rotateMeshpart(osign)
				isWeirdSignSetupYet[osign.Name] = true
			end
		end

		local big: Part = signFolder:WaitForChild("Big", 2)
		if big then
		end
		local small: Part = signFolder:WaitForChild("Small", 2)
		if small then
		end

		local chiralitySign: Part = signFolder:WaitForChild("Chirality", 2)
		if chiralitySign then
			if isWeirdSignSetupYet[chiralitySign.Name] == nil then
				local r = require(game.ReplicatedStorage.util.signMovement)
				r.riseandspin(chiralitySign)
				isWeirdSignSetupYet[chiralitySign.Name] = true
			end
		end

		-- set up 007 sign.
		task.spawn(function()
			local doubleO7Sign = signFolder:WaitForChild("007", 2)
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

_annotate("end")
return module
