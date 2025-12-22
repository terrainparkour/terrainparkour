--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

--[[
	IDENTITY COLORS: Who is this person?
	These colors help users instantly recognize relationships in lists.
	
	Hierarchy (most to least prominent):
	1. meColor - Yellow - YOU, always
	2. friendInServerColor - Cyan/Teal - Friend who is also in this server
	3. friendColor - Light Blue - Roblox friend (any server or offline)
	4. inServerColor - Green - Other player in this server (not friend)
	5. (default grey) - Everyone else
	
	Special case:
	- mePastColor - Orange - Your older run (e.g., you just beat this time)
]]

-- YOU - bright yellow, sacred, always means the current player
module.meColor = Color3.fromRGB(255, 255, 49)

-- YOUR OLDER RUN - orange, for your previous run you just beat or comparing against
module.mePastColor = Color3.fromRGB(255, 180, 100)

-- ROBLOX FRIEND - light blue, any friend regardless of server
module.friendColor = Color3.fromRGB(130, 190, 255)

-- OTHER PLAYER IN SERVER - green, someone playing in this server (not friend)
module.inServerColor = Color3.fromRGB(160, 255, 100)

-- FRIEND + IN SERVER - cyan/teal, friend who is also in this server (blue+green merged)
module.friendInServerColor = Color3.fromRGB(100, 220, 200)

-- Group member color (used in chat only, not for RRG)
module.groupMemberColor = Color3.fromRGB(255, 215, 0) --gold for group members
module.greenGo = Color3.fromRGB(0, 255, 0)
module.warpColor = Color3.fromRGB(173, 213, 230)
module.WRProgressionColor = Color3.fromRGB(255, 200, 150)
module.defaultGrey = Color3.fromRGB(163, 162, 165)
module.blueDone = BrickColor.new("Cyan").Color

module.yellow = Color3.fromRGB(255, 255, 0)
module.white = Color3.fromRGB(255, 255, 255)
module.black = Color3.fromRGB(0, 0, 0)
module.grey = BrickColor.Gray().Color

--used for incomplete contest runs
module.lightGrey = Color3.fromRGB(213, 212, 215)

--movementparticles
module.redSlowDown = Color3.fromRGB(220, 0, 0)

--destinations
module.redStop = Color3.fromRGB(255, 0, 0)
module.blue = Color3.fromRGB(0, 0, 255)

--my textcolor - unused
module.brouText = BrickColor.new("Teal").Color
module.yellowFind = BrickColor.new("New Yeller").Color

--action user just did

--past times

module.lightRed = Color3.fromRGB(255, 120, 130)

module.orangeAccent = Color3.fromRGB(255, 160, 100)
module.lightGreen = Color3.fromRGB(100, 255, 0)
module.darkGreen = Color3.fromRGB(13, 105, 59)
module.lightYellow = Color3.fromRGB(255, 255, 10)

module.signTextColor = Color3.fromRGB(255, 240, 241)
module.signColor = Color3.fromRGB(255, 89, 89)

------- added later, kind of suck.
module.brown = Color3.fromRGB(139, 69, 19)
module.turquoise = Color3.fromRGB(0, 255, 255)
module.magenta = Color3.fromRGB(255, 0, 255)
module.subtlePink = Color3.fromRGB(255, 105, 180)
module.pastel = Color3.fromRGB(255, 200, 150)
module.navyGreen = Color3.fromRGB(0, 100, 100)
module.lightGreenPlush = Color3.fromRGB(100, 255, 100)
module.lightBlueGreen = Color3.fromRGB(100, 255, 255)

------- Variant UI colors (HUD overlays, panels, labels)
-- Backgrounds (dark panels for HUD overlays)
module.panelDark = Color3.fromRGB(18, 18, 22) -- Default variant container
module.panelMedium = Color3.fromRGB(25, 25, 30) -- Slightly lighter panel
module.panelLight = Color3.fromRGB(30, 30, 35) -- Light panel/graph bg
module.panelAccent = Color3.fromRGB(40, 40, 45) -- Empty states, borders

-- Canvas/grid backgrounds
module.canvasDark = Color3.fromRGB(25, 28, 32) -- Vector canvas, map bg
module.gridLine = Color3.fromRGB(50, 50, 55) -- Grid/axis lines
module.gridLineDim = Color3.fromRGB(40, 45, 50) -- Dimmer grid lines

-- Text greys (for labels, secondary info)
module.textDim = Color3.fromRGB(100, 100, 100) -- Very dim labels
module.textSubtle = Color3.fromRGB(140, 140, 140) -- Secondary labels
module.textMuted = Color3.fromRGB(160, 160, 160) -- Muted headings
module.textLight = Color3.fromRGB(180, 180, 180) -- Light grey text
module.textSoft = Color3.fromRGB(200, 200, 200) -- Soft white

-- Semantic data colors (speed, altitude, distance, etc.)
module.dataSpeed = Color3.fromRGB(100, 200, 255) -- Speed/velocity (cyan)
module.dataAltitude = Color3.fromRGB(100, 255, 150) -- Altitude/movement (green)
module.dataDistance = Color3.fromRGB(100, 180, 255) -- Distance/trail (blue)
module.dataPositive = Color3.fromRGB(100, 255, 100) -- Gains, positive values
module.dataNegative = Color3.fromRGB(255, 100, 100) -- Losses, negative values
module.dataHighlight = Color3.fromRGB(255, 200, 100) -- Highlights, max values
module.dataDanger = Color3.fromRGB(255, 80, 80) -- Danger/warning states

-- Retro/neon aesthetic
module.neonCyan = Color3.fromRGB(0, 255, 255)
module.neonMagenta = Color3.fromRGB(255, 0, 255)
module.neonYellow = Color3.fromRGB(255, 255, 0)
module.neonGreen = Color3.fromRGB(0, 255, 100) -- ECG green

-- Retro backgrounds
module.retroDark = Color3.fromRGB(10, 10, 20) -- Deep dark (retro)
module.retroGrid = Color3.fromRGB(40, 40, 80) -- Grid overlay
module.ecgDark = Color3.fromRGB(10, 15, 12) -- ECG panel bg
module.ecgGrid = Color3.fromRGB(20, 30, 25) -- ECG grid lines

-- HUD accent
module.hudCyan = Color3.fromRGB(0, 200, 255) -- HUD elements

-- Config/picker UI colors (card-based panels, toggles)
module.pickerCardBg = Color3.fromRGB(38, 40, 45) -- Card background
module.pickerCardBorder = Color3.fromRGB(60, 62, 68) -- Card border/separator
module.pickerButtonUnselected = Color3.fromRGB(70, 72, 78) -- Unselected toggle/button
module.pickerHeaderBg = Color3.fromRGB(180, 60, 70) -- Card header/label area (reddish)
module.pickerSeparator = Color3.fromRGB(80, 80, 80) -- Separator lines
module.pickerResetButton = Color3.fromRGB(100, 100, 100) -- Reset/action button
module.highlightGlow = Color3.fromRGB(255, 200, 0) -- Highlight glow (orange-yellow)

-- Help/info panel UI (keyboard shortcuts, particle explanation)
module.helpPanelBg = Color3.fromRGB(0, 0, 0) -- Panel outer frame
module.helpTitleBg = Color3.fromRGB(168, 208, 230) -- Pale blue title bar
module.helpRowBg = Color3.fromRGB(184, 216, 186) -- Soft green row
module.helpKeyBg = Color3.fromRGB(241, 167, 167) -- Soft red key label
module.helpText = Color3.fromRGB(70, 70, 70) -- Dark gray text

-- Generic button colors
module.buttonNeutral = Color3.fromRGB(200, 200, 200) -- Neutral button bg
module.buttonBorder = Color3.fromRGB(100, 100, 100) -- Button border

-- Close button (shared by standardButton and LLMGeneratedUIFunctions)
module.closeButtonBg = Color3.fromRGB(220, 53, 69) -- Bootstrap-style red
module.closeButtonHoverBg = Color3.fromRGB(200, 35, 51) -- Darker on hover
module.closeButtonBorder = Color3.fromRGB(180, 40, 55)

-- Light pillar indicators
module.pillarSource = Color3.fromRGB(255, 160, 160) -- Source/origin (pink-red)
module.pillarDestination = Color3.fromRGB(160, 250, 160) -- Destination (light green)

_annotate("end")
return module
