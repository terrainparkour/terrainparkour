--!strict
-- runStats.lua (ReplicatedStorage/gui/activeRunWidgets/runStats.lua)
-- Tracks comprehensive statistics during an active run for visualization.
-- Expanded interface: terrains, jumps, altitude, speed, rotation, distance, and more.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local colors = require(game.ReplicatedStorage.util.colors)

local localPlayer = Players.LocalPlayer

-- Stats storage
export type TerrainTime = {
	name: string,
	totalTime: number,
	color: Color3,
	touchCount: number,
}

-- Typed event marker for chart visualization
export type TypedEventMarker = {
	time: number,
	eventType: string, -- "jump", "terrain", etc.
	color: Color3,
	label: string?,
}

export type RunStatistics = {
	-- Basic
	startTick: number,
	signName: string,

	-- Movement
	jumpCount: number,
	jumpTimestamps: { number }, -- Timestamps when jumps occurred (for chart markers)
	terrainChangeTimestamps: { TypedEventMarker }, -- Timestamps when terrain changed (excludes air)
	avatarEvents: { TypedEventMarker }, -- All avatar events (jumps, swim start/end, speed reasons)
	isSwimming: boolean, -- Current swimming state
	lastNonAirTerrain: string, -- Last terrain that wasn't air (for filtering)
	maxSpeed: number,
	avgSpeed: number,
	totalDistance: number,
	distanceFromStart: number, -- Current distance from starting position

	-- Altitude
	startAltitude: number,
	currentAltitude: number,
	maxAltitude: number,
	minAltitude: number,
	altitudeGained: number,
	altitudeLost: number,
	verticalVelocity: number, -- Current up/down speed

	-- Rotation tracking
	totalRotation: number, -- Total degrees rotated
	clockwiseSpins: number, -- Full 360° clockwise rotations
	counterClockwiseSpins: number, -- Full 360° counter-clockwise
	currentFacing: number, -- Current Y rotation in degrees

	-- Terrain tracking
	terrainTimes: { [string]: TerrainTime },
	currentTerrain: string,
	terrainChangeTime: number,
	uniqueTerrainsVisited: number,
	terrainChanges: number, -- How many times terrain changed

	-- History for charts (full run + recent)
	speedHistory: { number }, -- Full run
	altitudeHistory: { number }, -- Full run
	recentSpeedHistory: { number }, -- Last ~3 seconds
	recentAltitudeHistory: { number }, -- Last ~3 seconds
	historyTimestamps: { number }, -- Timestamps for each sample

	-- Timing
	lastUpdateTick: number,
	speedSampleCount: number,
	speedSum: number,

	-- Direction/velocity
	currentSpeed: number,
	movementDirection: Vector3, -- Normalized movement direction

	-- Acceleration
	lastSpeed: number,
	currentAcceleration: number, -- studs/s²
}

local MAX_HISTORY_SAMPLES = 300 -- ~5 seconds at 60fps sampled every frame
local MAX_RECENT_SAMPLES = 90 -- ~1.5 seconds of recent data
local SAMPLE_INTERVAL = 2 -- Sample every N frames

-- Use terrainData module for colors (lazy-loaded to avoid circular dependencies)
local terrainDataModule: { GetTerrainColor: (string) -> Color3 }? = nil
local function getTerrainDataColor(terrainName: string): Color3
	if not terrainDataModule then
		-- Lazy require to avoid circular dependency
		local success, result = pcall(function()
			return require(game.ReplicatedStorage.gui.activeRunWidgets.terrainData)
		end)
		if success then
			terrainDataModule = result
		end
	end
	if terrainDataModule then
		return terrainDataModule.GetTerrainColor(terrainName)
	end
	-- Fallback default color if module not available
	return Color3.fromRGB(100, 100, 100)
end

-- All possible terrains for "unseen" tracking
local ALL_TERRAINS = {
	"default",
	"ice",
	"lava",
	"water",
	"sand",
	"grass",
	"mud",
	"metal",
	"wood",
	"concrete",
	"plastic",
	"neon",
	"glass",
	"forcefield",
}

local currentStats: RunStatistics? = nil
local updateConnection: RBXScriptConnection? = nil
local wasInAir: boolean = false
local sampleCounter: number = 0
local lastYRotation: number = 0
local rotationAccumulator: number = 0

local module = {}

local function getCharacterPosition(): Vector3?
	local character = localPlayer.Character
	if not character then
		return nil
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp.Position
	end
	return nil
end

local function getCharacterVelocity(): Vector3?
	local character = localPlayer.Character
	if not character then
		return nil
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp.AssemblyLinearVelocity
	end
	return nil
end

local function getCharacterYRotation(): number
	local character = localPlayer.Character
	if not character then
		return 0
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		local _, y, _ = hrp.CFrame:ToEulerAnglesYXZ()
		return math.deg(y)
	end
	return 0
end

local function isCharacterJumping(): boolean
	local character = localPlayer.Character
	if not character then
		return false
	end
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid and humanoid:IsA("Humanoid") then
		return humanoid.FloorMaterial == Enum.Material.Air
	end
	return false
end

local function normalizeAngle(angle: number): number
	while angle > 180 do
		angle = angle - 360
	end
	while angle < -180 do
		angle = angle + 360
	end
	return angle
end

function module.StartTracking(signName: string, startTick: number, startPosition: Vector3?)
	local pos = getCharacterPosition()
	local startAlt = if pos then pos.Y else 0
	local startPos = startPosition or pos or Vector3.new(0, 0, 0)

	lastYRotation = getCharacterYRotation()
	rotationAccumulator = 0

	currentStats = {
		startTick = startTick,
		signName = signName,

		jumpCount = 0,
		jumpTimestamps = {},
		terrainChangeTimestamps = {},
		avatarEvents = {},
		isSwimming = false,
		lastNonAirTerrain = "",
		maxSpeed = 0,
		avgSpeed = 0,
		totalDistance = 0,
		distanceFromStart = 0,

		startAltitude = startAlt,
		currentAltitude = startAlt,
		maxAltitude = startAlt,
		minAltitude = startAlt,
		altitudeGained = 0,
		altitudeLost = 0,
		verticalVelocity = 0,

		totalRotation = 0,
		clockwiseSpins = 0,
		counterClockwiseSpins = 0,
		currentFacing = lastYRotation,

		terrainTimes = {},
		currentTerrain = "default",
		terrainChangeTime = startTick,
		uniqueTerrainsVisited = 0,
		terrainChanges = 0,

		speedHistory = {},
		altitudeHistory = {},
		recentSpeedHistory = {},
		recentAltitudeHistory = {},
		historyTimestamps = {},

		lastUpdateTick = startTick,
		speedSampleCount = 0,
		speedSum = 0,

		currentSpeed = 0,
		movementDirection = Vector3.new(0, 0, 0),

		lastSpeed = 0,
		currentAcceleration = 0,
	}

	wasInAir = false
	sampleCounter = 0
	lastYRotation = getCharacterYRotation() -- Reset to current rotation
	rotationAccumulator = 0 -- Reset spin accumulator

	if updateConnection then
		updateConnection:Disconnect()
	end

	local lastPosition = pos
	local runStartPosition = startPos

	updateConnection = RunService.Heartbeat:Connect(function(deltaTime)
		local stats = currentStats
		if not stats then
			return
		end

		local now = tick()
		stats.lastUpdateTick = now

		local position = getCharacterPosition()
		local velocity = getCharacterVelocity()

		if not position or not velocity then
			return
		end

		-- Speed tracking
		local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
		local speed = horizontalVelocity.Magnitude

		stats.currentSpeed = speed
		stats.speedSum = stats.speedSum + speed
		stats.speedSampleCount = stats.speedSampleCount + 1
		stats.avgSpeed = stats.speedSum / stats.speedSampleCount

		if speed > stats.maxSpeed then
			stats.maxSpeed = speed
		end

		-- Acceleration
		stats.currentAcceleration = (speed - stats.lastSpeed) / deltaTime
		stats.lastSpeed = speed

		-- Vertical velocity
		stats.verticalVelocity = velocity.Y

		-- Movement direction
		if horizontalVelocity.Magnitude > 0.1 then
			stats.movementDirection = horizontalVelocity.Unit
		end

		-- Distance tracking
		if lastPosition then
			local dist = (position - lastPosition).Magnitude
			stats.totalDistance = stats.totalDistance + dist
		end
		lastPosition = position

		-- Distance from start
		stats.distanceFromStart = (Vector3.new(position.X, 0, position.Z) - Vector3.new(runStartPosition.X, 0, runStartPosition.Z)).Magnitude

		-- Altitude tracking
		local alt = position.Y
		local prevAlt = stats.currentAltitude
		stats.currentAltitude = alt

		if alt > prevAlt then
			stats.altitudeGained = stats.altitudeGained + (alt - prevAlt)
		elseif alt < prevAlt then
			stats.altitudeLost = stats.altitudeLost + (prevAlt - alt)
		end

		if alt > stats.maxAltitude then
			stats.maxAltitude = alt
		end
		if alt < stats.minAltitude then
			stats.minAltitude = alt
		end

		-- Jump detection
		local inAir = isCharacterJumping()
		if inAir and not wasInAir then
			stats.jumpCount = stats.jumpCount + 1
			local jumpTime = tick()
			table.insert(stats.jumpTimestamps, jumpTime)
			-- Add to avatar events for chart markers
			table.insert(stats.avatarEvents, {
				time = jumpTime,
				eventType = "avatar",
				color = colors.yellow,
				label = "Jump",
			})
		end
		wasInAir = inAir

		-- Rotation tracking
		local currentYRot = getCharacterYRotation()
		local rotDelta = normalizeAngle(currentYRot - lastYRotation)
		rotationAccumulator = rotationAccumulator + rotDelta
		stats.totalRotation = stats.totalRotation + math.abs(rotDelta)
		stats.currentFacing = currentYRot

		-- Count full spins
		-- Positive Y rotation = counterclockwise when viewed from above
		-- Negative Y rotation = clockwise when viewed from above
		while rotationAccumulator >= 360 do
			stats.counterClockwiseSpins = stats.counterClockwiseSpins + 1
			rotationAccumulator = rotationAccumulator - 360
		end
		while rotationAccumulator <= -360 do
			stats.clockwiseSpins = stats.clockwiseSpins + 1
			rotationAccumulator = rotationAccumulator + 360
		end

		lastYRotation = currentYRot

		-- Sample history
		sampleCounter = sampleCounter + 1
		if sampleCounter % SAMPLE_INTERVAL == 0 then
			-- Full history
			table.insert(stats.speedHistory, speed)
			table.insert(stats.altitudeHistory, alt)
			table.insert(stats.historyTimestamps, now)

			-- Keep full history bounded
			if #stats.speedHistory > MAX_HISTORY_SAMPLES then
				table.remove(stats.speedHistory, 1)
				table.remove(stats.altitudeHistory, 1)
				table.remove(stats.historyTimestamps, 1)
			end

			-- Recent history (more samples for smooth zoomed view)
			table.insert(stats.recentSpeedHistory, speed)
			table.insert(stats.recentAltitudeHistory, alt)

			if #stats.recentSpeedHistory > MAX_RECENT_SAMPLES then
				table.remove(stats.recentSpeedHistory, 1)
				table.remove(stats.recentAltitudeHistory, 1)
			end
		end
	end)

	_annotate("Started tracking run stats")
end

function module.StopTracking(): RunStatistics?
	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
	end

	local stats = currentStats
	currentStats = nil

	_annotate("Stopped tracking run stats")
	return stats
end

function module.GetCurrentStats(): RunStatistics?
	return currentStats
end

function module.UpdateTerrain(terrainName: string)
	local stats = currentStats
	if not stats then
		return
	end

	if terrainName == stats.currentTerrain then
		return -- No change
	end

	local now = tick()
	local terrainLower = string.lower(terrainName)
	local isAir = (terrainLower == "air")

	-- Detect swim start/end (Water terrain)
	local nowSwimming = (terrainName == "Water")
	if nowSwimming and not stats.isSwimming then
		-- Started swimming
		table.insert(stats.avatarEvents, {
			time = now,
			eventType = "avatar",
			color = colors.hudCyan,
			label = "Swim",
		})
	end
	stats.isSwimming = nowSwimming

	-- Update time on previous terrain
	if stats.currentTerrain ~= "" then
		local prevTerrain = stats.terrainTimes[stats.currentTerrain]
		if prevTerrain then
			prevTerrain.totalTime = prevTerrain.totalTime + (now - stats.terrainChangeTime)
		else
			local color = getTerrainDataColor(stats.currentTerrain)
			stats.terrainTimes[stats.currentTerrain] = {
				name = stats.currentTerrain,
				totalTime = now - stats.terrainChangeTime,
				color = color,
				touchCount = 1,
			}
			stats.uniqueTerrainsVisited = stats.uniqueTerrainsVisited + 1
		end
	end

	-- Switch to new terrain
	stats.currentTerrain = terrainName
	stats.terrainChangeTime = now
	stats.terrainChanges = stats.terrainChanges + 1

	-- Record terrain change timestamp ONLY for non-air terrains that differ from last non-air terrain
	-- This prevents "air" from cluttering the terrain change history
	if not isAir then
		local terrainColor = getTerrainDataColor(terrainName)
		if terrainName ~= stats.lastNonAirTerrain and stats.lastNonAirTerrain ~= "" then
			table.insert(stats.terrainChangeTimestamps, {
				time = now,
				eventType = "terrain",
				color = terrainColor,
				label = terrainName,
			})
		end
		stats.lastNonAirTerrain = terrainName

		-- Initialize new terrain entry if needed
		if not stats.terrainTimes[terrainName] then
			stats.terrainTimes[terrainName] = {
				name = terrainName,
				totalTime = 0,
				color = terrainColor,
				touchCount = 1,
			}
			stats.uniqueTerrainsVisited = stats.uniqueTerrainsVisited + 1
		else
			stats.terrainTimes[terrainName].touchCount = stats.terrainTimes[terrainName].touchCount + 1
		end
	end
end

-- Utility functions for variants

function module.GetSpeedHistoryNormalized(useRecent: boolean?): { number }
	local stats = currentStats
	if not stats then
		return {}
	end

	local history = if useRecent then stats.recentSpeedHistory else stats.speedHistory
	if #history == 0 then
		return {}
	end

	local maxSpeed: number = stats.maxSpeed
	if maxSpeed <= 0 then
		maxSpeed = 1
	end

	local normalized = {}
	for _, speed: number in ipairs(history) do
		table.insert(normalized, math.min(speed / maxSpeed, 1))
	end
	return normalized
end

function module.GetAltitudeHistoryNormalized(useRecent: boolean?): { number }
	local stats = currentStats
	if not stats then
		return {}
	end

	local history = if useRecent then stats.recentAltitudeHistory else stats.altitudeHistory
	if #history == 0 then
		return {}
	end

	local range: number = stats.maxAltitude - stats.minAltitude
	if range <= 0 then
		range = 1
	end

	local normalized = {}
	for _, alt: number in ipairs(history) do
		local norm = (alt - stats.minAltitude) / range
		table.insert(normalized, math.clamp(norm, 0, 1))
	end
	return normalized
end

function module.GetTerrainBreakdown(): { { name: string, time: number, percent: number, color: Color3, touchCount: number } }
	local stats = currentStats
	if not stats then
		return {}
	end

	local totalTime = 0
	for _, terrain in pairs(stats.terrainTimes) do
		totalTime = totalTime + terrain.totalTime
	end

	-- Add current terrain's ongoing time
	local currentTerrainTime = tick() - stats.terrainChangeTime
	totalTime = totalTime + currentTerrainTime

	if totalTime <= 0 then
		return {}
	end

	local breakdown = {}
	for name, terrain in pairs(stats.terrainTimes) do
		local time = terrain.totalTime
		if name == stats.currentTerrain then
			time = time + currentTerrainTime
		end
		table.insert(breakdown, {
			name = name,
			time = time,
			percent = (time / totalTime) * 100,
			color = terrain.color,
			touchCount = terrain.touchCount,
		})
	end

	-- Sort by time descending
	table.sort(breakdown, function(a, b)
		return a.time > b.time
	end)

	return breakdown
end

function module.GetUnseenTerrains(): { string }
	local stats = currentStats
	if not stats then
		return ALL_TERRAINS
	end

	local unseen = {}
	for _, terrain in ipairs(ALL_TERRAINS) do
		if not stats.terrainTimes[terrain] then
			table.insert(unseen, terrain)
		end
	end
	return unseen
end

function module.GetTerrainColor(terrainName: string): Color3
	return getTerrainDataColor(terrainName)
end

-- Get avatar events since a given index (for incremental processing)
-- Returns the new events and the new index to use next time
function module.GetAvatarEventsSince(startIndex: number): ({ TypedEventMarker }, number)
	local stats = currentStats
	if not stats then
		return {}, startIndex
	end
	local events = stats.avatarEvents
	local newEvents: { TypedEventMarker } = {}
	for i = startIndex + 1, #events do
		table.insert(newEvents, events[i])
	end
	return newEvents, #events
end

-- Get terrain change events since a given index (for incremental processing)
function module.GetTerrainEventsSince(startIndex: number): ({ TypedEventMarker }, number)
	local stats = currentStats
	if not stats then
		return {}, startIndex
	end
	local events = stats.terrainChangeTimestamps
	local newEvents: { TypedEventMarker } = {}
	for i = startIndex + 1, #events do
		table.insert(newEvents, events[i])
	end
	return newEvents, #events
end

-- Add a speed reason event (called from widgetComposer when speed reason changes)
-- This centralizes the speed reason -> event conversion
function module.AddSpeedReasonEvent(reason: string, reasonColor: Color3)
	local stats = currentStats
	if not stats then
		return
	end
	local now = tick()
	table.insert(stats.avatarEvents, {
		time = now,
		eventType = "avatar",
		color = reasonColor,
		label = reason,
	})
end

_annotate("end")
return module
