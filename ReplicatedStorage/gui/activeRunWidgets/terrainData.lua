--!strict
-- terrainData.lua (ReplicatedStorage/gui/activeRunWidgets/terrainData.lua)
-- Centralized terrain material colors, symbols, and texture information for terrain widgets.
-- Texture tiles extracted from official Roblox terrain documentation and uploaded via Asphalt.

local colors = require(game.ReplicatedStorage.util.colors)

local module = {}

-- Terrain info with emoji symbol for display
export type TerrainInfo = {
	name: string,
	displayName: string,
	color: Color3,
	symbol: string, -- Emoji for display
	textureId: string, -- Roblox image asset ID (empty = use color + symbol)
}

-- Terrain texture asset IDs (uploaded via Asphalt)
-- These are the official Roblox terrain material textures
local TEXTURES = {
	air = "rbxassetid://86803321817964",
	asphalt = "rbxassetid://78614136624014",
	basalt = "rbxassetid://71488841892968",
	brick = "rbxassetid://86199875827473",
	cobblestone = "rbxassetid://138302697949882",
	concrete = "rbxassetid://81313531028668",
	crackedlava = "rbxassetid://115898687343919",
	glacier = "rbxassetid://90944124973144",
	grass = "rbxassetid://99269182833344",
	ground = "rbxassetid://98068530890664",
	ice = "rbxassetid://130640331811455",
	leafygrass = "rbxassetid://132107716629085",
	limestone = "rbxassetid://81415278652229",
	mud = "rbxassetid://76887606792976",
	pavement = "rbxassetid://114087276888883",
	rock = "rbxassetid://92599200690067",
	salt = "rbxassetid://134960396477809",
	sand = "rbxassetid://83926858135627",
	sandstone = "rbxassetid://130446207383659",
	slate = "rbxassetid://106648045724926",
	snow = "rbxassetid://91289820814306",
	water = "rbxassetid://95030501428333",
	woodplanks = "rbxassetid://104230772282297",
}

-- Placeholder for materials without uploaded textures
local NO_TEXTURE = ""

-- Complete terrain material mappings matching Roblox Enum.Material values
-- Colors approximate the actual Roblox terrain colors
local TERRAIN_DATA: { [string]: TerrainInfo } = {
	-- Natural Ground
	grass = {
		name = "grass",
		displayName = "Grass",
		color = Color3.fromRGB(75, 151, 75),
		symbol = "🌿",
		textureId = TEXTURES.grass,
	},
	leafygrass = {
		name = "leafygrass",
		displayName = "Leafy Grass",
		color = Color3.fromRGB(60, 140, 60),
		symbol = "🍃",
		textureId = TEXTURES.leafygrass,
	},
	ground = {
		name = "ground",
		displayName = "Ground",
		color = Color3.fromRGB(102, 92, 59),
		symbol = "🟤",
		textureId = TEXTURES.ground,
	},
	mud = {
		name = "mud",
		displayName = "Mud",
		color = Color3.fromRGB(90, 70, 45),
		symbol = "🫘",
		textureId = TEXTURES.mud,
	},
	sand = {
		name = "sand",
		displayName = "Sand",
		color = Color3.fromRGB(220, 200, 140),
		symbol = "🏖️",
		textureId = TEXTURES.sand,
	},
	snow = {
		name = "snow",
		displayName = "Snow",
		color = Color3.fromRGB(240, 245, 255),
		symbol = "❄️",
		textureId = TEXTURES.snow,
	},
	salt = {
		name = "salt",
		displayName = "Salt",
		color = Color3.fromRGB(235, 235, 245),
		symbol = "🧂",
		textureId = TEXTURES.salt,
	},

	-- Stone/Rock
	rock = {
		name = "rock",
		displayName = "Rock",
		color = Color3.fromRGB(128, 128, 128),
		symbol = "🪨",
		textureId = TEXTURES.rock,
	},
	slate = {
		name = "slate",
		displayName = "Slate",
		color = Color3.fromRGB(100, 105, 110),
		symbol = "🔳",
		textureId = TEXTURES.slate,
	},
	basalt = {
		name = "basalt",
		displayName = "Basalt",
		color = Color3.fromRGB(45, 45, 50),
		symbol = "⬛",
		textureId = TEXTURES.basalt,
	},
	limestone = {
		name = "limestone",
		displayName = "Limestone",
		color = Color3.fromRGB(200, 195, 180),
		symbol = "🔲",
		textureId = TEXTURES.limestone,
	},
	sandstone = {
		name = "sandstone",
		displayName = "Sandstone",
		color = Color3.fromRGB(180, 140, 100),
		symbol = "🟧",
		textureId = TEXTURES.sandstone,
	},

	-- Paved/Built
	concrete = {
		name = "concrete",
		displayName = "Concrete",
		color = Color3.fromRGB(160, 160, 160),
		symbol = "⬜",
		textureId = TEXTURES.concrete,
	},
	brick = {
		name = "brick",
		displayName = "Brick",
		color = Color3.fromRGB(140, 80, 60),
		symbol = "🧱",
		textureId = TEXTURES.brick,
	},
	cobblestone = {
		name = "cobblestone",
		displayName = "Cobblestone",
		color = Color3.fromRGB(130, 130, 130),
		symbol = "🔘",
		textureId = TEXTURES.cobblestone,
	},
	pavement = {
		name = "pavement",
		displayName = "Pavement",
		color = Color3.fromRGB(140, 140, 145),
		symbol = "🛤️",
		textureId = TEXTURES.pavement,
	},
	asphalt = {
		name = "asphalt",
		displayName = "Asphalt",
		color = Color3.fromRGB(60, 60, 65),
		symbol = "🛣️",
		textureId = TEXTURES.asphalt,
	},

	-- Cold
	ice = {
		name = "ice",
		displayName = "Ice",
		color = Color3.fromRGB(180, 210, 230),
		symbol = "🧊",
		textureId = TEXTURES.ice,
	},
	glacier = {
		name = "glacier",
		displayName = "Glacier",
		color = Color3.fromRGB(150, 190, 220),
		symbol = "🏔️",
		textureId = TEXTURES.glacier,
	},

	-- Hot
	crackedlava = {
		name = "crackedlava",
		displayName = "Cracked Lava",
		color = Color3.fromRGB(40, 30, 30),
		symbol = "🌋",
		textureId = TEXTURES.crackedlava,
	},

	-- Water
	water = {
		name = "water",
		displayName = "Water",
		color = Color3.fromRGB(60, 120, 180),
		symbol = "💧",
		textureId = TEXTURES.water,
	},

	-- Wood
	woodplanks = {
		name = "woodplanks",
		displayName = "Wood Planks",
		color = Color3.fromRGB(140, 100, 60),
		symbol = "🪵",
		textureId = TEXTURES.woodplanks,
	},

	-- Metal (no uploaded textures yet)
	corrodedmetal = {
		name = "corrodedmetal",
		displayName = "Corroded Metal",
		color = Color3.fromRGB(120, 90, 70),
		symbol = "🔩",
		textureId = NO_TEXTURE,
	},
	diamondplate = {
		name = "diamondplate",
		displayName = "Diamond Plate",
		color = Color3.fromRGB(150, 150, 155),
		symbol = "🔷",
		textureId = NO_TEXTURE,
	},

	-- Special
	air = {
		name = "air",
		displayName = "Air",
		color = Color3.fromRGB(200, 220, 255),
		symbol = "💨",
		textureId = TEXTURES.air,
	},
}

-- Default fallback for unknown terrain
local DEFAULT_INFO: TerrainInfo = {
	name = "unknown",
	displayName = "Unknown",
	color = Color3.fromRGB(128, 128, 128),
	symbol = "❓",
	textureId = NO_TEXTURE,
}

-- Get terrain info by name (case-insensitive)
function module.GetTerrainInfo(terrainName: string): TerrainInfo
	local key = string.lower(terrainName)
	return TERRAIN_DATA[key] or DEFAULT_INFO
end

-- Get just the color for a terrain
function module.GetTerrainColor(terrainName: string): Color3
	return module.GetTerrainInfo(terrainName).color
end

-- Get the symbol for a terrain
function module.GetTerrainSymbol(terrainName: string): string
	return module.GetTerrainInfo(terrainName).symbol
end

-- Get the texture ID for a terrain (empty string if no texture)
function module.GetTerrainTexture(terrainName: string): string
	return module.GetTerrainInfo(terrainName).textureId
end

-- Check if terrain has a texture image available
function module.HasTexture(terrainName: string): boolean
	local textureId = module.GetTerrainTexture(terrainName)
	return textureId ~= ""
end

-- Create a terrain indicator frame - uses texture image if available, otherwise color + symbol
function module.CreateTerrainIndicator(terrainName: string, size: number): Frame
	local info = module.GetTerrainInfo(terrainName)

	local frame = Instance.new("Frame")
	frame.Name = "TerrainIndicator_" .. info.name
	frame.Size = UDim2.fromOffset(size, size)
	frame.BackgroundColor3 = info.color
	frame.BorderSizePixel = 1
	frame.BorderColor3 = Color3.fromRGB(60, 60, 60)

	-- If texture image is available, use it
	if info.textureId ~= "" then
		local imageLabel = Instance.new("ImageLabel")
		imageLabel.Name = "TextureImage"
		imageLabel.Size = UDim2.fromScale(1, 1)
		imageLabel.BackgroundTransparency = 1
		imageLabel.Image = info.textureId
		imageLabel.ScaleType = Enum.ScaleType.Crop
		imageLabel.Parent = frame
	else
		-- Use emoji symbol
		local symbolLabel = Instance.new("TextLabel")
		symbolLabel.Name = "Symbol"
		symbolLabel.Size = UDim2.fromScale(1, 1)
		symbolLabel.BackgroundTransparency = 1
		symbolLabel.Text = info.symbol
		symbolLabel.TextScaled = true
		symbolLabel.Parent = frame
	end

	frame.ClipsDescendants = true
	return frame
end

-- Create a terrain legend row with indicator, name, and stats
function module.CreateTerrainLegendRow(
	terrainName: string,
	time: number,
	percent: number,
	touchCount: number,
	fonts: { GetFont: (boolean, boolean) -> Font }
): Frame
	local info = module.GetTerrainInfo(terrainName)

	local row = Instance.new("Frame")
	row.Name = "TerrainRow_" .. info.name
	row.Size = UDim2.new(1, 0, 0, 24)
	row.BackgroundTransparency = 1

	-- Terrain indicator with color (14x14)
	local indicator = module.CreateTerrainIndicator(terrainName, 14)
	indicator.Position = UDim2.fromOffset(2, 5)
	indicator.Parent = row

	-- Symbol
	local symbol = Instance.new("TextLabel")
	symbol.Size = UDim2.fromOffset(18, 24)
	symbol.Position = UDim2.fromOffset(18, 0)
	symbol.BackgroundTransparency = 1
	symbol.Text = info.symbol
	symbol.TextSize = 14
	symbol.Parent = row

	-- Name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.fromOffset(50, 24)
	nameLabel.Position = UDim2.fromOffset(38, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = info.color
	nameLabel.FontFace = fonts.GetFont(false, true)
	nameLabel.TextSize = 11
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Text = info.displayName
	nameLabel.Parent = row

	-- Stats (time, percent, touches)
	local statsLabel = Instance.new("TextLabel")
	statsLabel.Size = UDim2.fromOffset(55, 24)
	statsLabel.Position = UDim2.new(1, -57, 0, 0)
	statsLabel.BackgroundTransparency = 1
	statsLabel.TextColor3 = colors.defaultGrey
	statsLabel.FontFace = fonts.GetFont(false, false)
	statsLabel.TextSize = 10
	statsLabel.TextXAlignment = Enum.TextXAlignment.Right
	statsLabel.Text = string.format("%.1fs %d%%", time, math.floor(percent))
	statsLabel.Parent = row

	return row
end

-- Get all terrain names (for iteration)
function module.GetAllTerrainNames(): { string }
	local names = {}
	for name, _ in pairs(TERRAIN_DATA) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

return module
