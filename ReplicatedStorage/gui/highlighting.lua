--!strict

--2024.08 loaded on client, receives and handles warps which are initiated by the server.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local TweenService = game:GetService("TweenService")

local colors = require(game.ReplicatedStorage.util.colors)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)

local userHasFoundSignCache = {}

local RunService = game:GetService("RunService")

local function createHighlightEffect(highlight)
	local tweenInfo = TweenInfo.new(
		2,
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.InOut,
		-1, -- Repeat infinitely
		false -- Don't reverse the tween
	)

	local function lerpColor(c1, c2, alpha)
		return Color3.new(c1.R + (c2.R - c1.R) * alpha, c1.G + (c2.G - c1.G) * alpha, c1.B + (c2.B - c1.B) * alpha)
	end

	local colorPattern = {
		Color3.fromRGB(255, 0, 0), -- Red
		Color3.fromRGB(255, 165, 0), -- Orange
		Color3.fromRGB(255, 255, 0), -- Yellow
		Color3.fromRGB(0, 255, 0), -- Green
		Color3.fromRGB(0, 0, 255), -- Blue
		Color3.fromRGB(255, 0, 255), -- Purple
	}

	local function updateColor(alpha)
		local index = math.floor(alpha * (#colorPattern - 1)) + 1
		local nextIndex = index % #colorPattern + 1
		local localAlpha = (alpha * (#colorPattern - 1)) % 1
		local color = lerpColor(colorPattern[index], colorPattern[nextIndex], localAlpha)
		-- print("updateColor:" .. tostring(color))
		highlight.OutlineColor = color
	end

	local startTime = tick()
	local connection

	connection = RunService.Heartbeat:Connect(function()
		local elapsed = (tick() - startTime) % tweenInfo.Time
		local alpha = elapsed / tweenInfo.Time
		updateColor(alpha)
	end)

	return connection
end

module.doHighlight = function(signId: number)
	if userHasFoundSignCache[signId] then
	else
		local userHasFoundSign = true
		--actually just make a local cache here. it's a one-way immutable.
		if not userHasFoundSign then
			return
		end
		userHasFoundSignCache[signId] = userHasFoundSign
	end

	local sign = tpUtil.signId2Sign(signId)
	if not sign then
		warn("warping to highlight an unseen sign?")
		return
	end
	--to highlight a sign we have to:
	--verify the signId exists as a sign in this game
	-- local signName = sign.Name
	print("doHighlight:" .. tostring(signId) .. sign.Name)
	local hh: Highlight = Instance.new("Highlight")
	hh.Parent = sign
	hh.Name = "TheHighlightYo"
	hh.FillColor = colors.signColor
	hh.OutlineColor = Color3.new(0, 1, 0)
	hh.OutlineTransparency = 0.0
	hh.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hh.Adornee = sign
	hh.Enabled = true
	hh.FillTransparency = 0.0

	task.spawn(function()
		while true do
			local waitTime = wait(0.1)
			hh.FillTransparency += 0.005 * waitTime / 0.1
			hh.OutlineTransparency += 0.001 * waitTime / 0.1
			if hh.FillTransparency >= 1 then
				hh:Destroy()
				break
			end
		end
	end)

	createHighlightEffect(hh)
end

_annotate("end")
return module
