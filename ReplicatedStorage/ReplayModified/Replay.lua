--strict

local MovementLogger = {}
MovementLogger.__index = MovementLogger

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

MovementLogger.Vector3Position = {
	X = 0,
	Y = 0,
	Z = 0,
}

type MovementLogger = typeof(setmetatable(
	{} :: {
		player: Player,
		character: Model,
		humanoidRootPart: any?,
		isLogging: boolean,
		logData: {[number]: {Position: Vector3}},
		previousPosition: Vector3,
		visualFolder: Folder,

		startLogging: (self: MovementLogger) -> (),
		stopLogging: (self: MovementLogger) -> (),
		onUpdate: (self: MovementLogger) -> (),
		createPoint: (self: MovementLogger, position: Vector3) -> (),
		visualizeLog: (self: MovementLogger) -> (),
	},
	
	{} :: {__call: (self: MovementLogger) -> ()}
))

function MovementLogger.Init()
	local self: MovementLogger = setmetatable({}, MovementLogger)
	
	self.player = Players.LocalPlayer
	self.character = self.player.Character or self.player.CharacterAdded:Wait()
	self.humanoidRootPart = self.character:WaitForChild("HumanoidRootPart")
	self.isLogging = false
	self.logData = {}
	self.previousPosition = self.humanoidRootPart.Position
	self.visualFolder = Instance.new("Folder")
	self.visualFolder.Name = "MovementPoints"
	self.visualFolder.Parent = workspace

	local keyBindings = {
		[Enum.KeyCode.F] = function() self:startLogging() end,
		[Enum.KeyCode.G] = function() self:stopLogging() end,
	}

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and keyBindings[input.KeyCode] then keyBindings[input.KeyCode]() end
	end)

	RunService.RenderStepped:Connect(function() self:onUpdate() end)

	return self
end

function MovementLogger:createPoint(position: Vector3)
	local point = Instance.new("Part")
	
	point.Size = Vector3.new(0.3, 0.3, 0.3)
	point.Position = position
	point.Anchored = true
	point.CanCollide = false
	point.Shape = Enum.PartType.Ball
	point.BrickColor = BrickColor.Random()
	point.Material = Enum.Material.Neon
	point.Parent = self.visualFolder
	
	Debris:AddItem(point, 10)
end

function MovementLogger:visualizeLog()
	local pathSize = #self.logData
	
	if pathSize < 2 then warn("Not enough data to visualize.") return end

	for i = 1, pathSize - 1 do
		local pointA = self.logData[i]
		local pointB = self.logData[i + 1]
		
		self:createPoint(pointA.Position)

		local distance = (pointB.Position - pointA.Position).magnitude
		local colorValue = math.clamp(distance / 20, 0, 1)
		local color = Color3.fromRGB(255 * (1 - colorValue), 255 * colorValue, 0)

		local line = Instance.new("LineHandleAdornment")
		
		line.Adornee = workspace
		line.Name = "PathLine" .. i
		line.Length = distance
		line.Thickness = 10
		line.Color3 = color
		line.Transparency = 0.5
		line.AlwaysOnTop = true

		local direction = (pointB.Position - pointA.Position).unit
		line.CFrame = CFrame.new(pointA.Position + direction * (distance / 2), pointB.Position)

		line.Parent = self.visualFolder
		Debris:AddItem(line, 5)
	end

	self:createPoint(self.logData[pathSize].Position)
end

function MovementLogger:onUpdate()
	if self.isLogging then
		local currentPosition = self.humanoidRootPart.Position
		
		if (currentPosition - self.previousPosition).magnitude >= 1 then
			table.insert(self.logData, { Position = currentPosition })
			self.previousPosition = currentPosition
		end
	end
end

function MovementLogger:startLogging()
	self.logData = {}
	self.isLogging = true
	self.previousPosition = self.humanoidRootPart.Position
end

function MovementLogger:stopLogging()
	self.isLogging = false
	self:visualizeLog()
end

return MovementLogger