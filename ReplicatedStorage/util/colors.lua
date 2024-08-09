--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

module.yellow = Color3.fromRGB(255, 255, 0)
module.white = Color3.fromRGB(255, 255, 255)
module.black = Color3.fromRGB(0, 0, 0)
module.grey = BrickColor.Gray().Color
module.defaultGrey = Color3.fromRGB(163, 162, 165)

--used for incomplete contest runs
module.lightGrey = Color3.fromRGB(213, 212, 215)

module.greenGo = Color3.fromRGB(0, 255, 0)
module.lightBlue = Color3.fromRGB(173, 213, 230)

--movementparticles
module.redSlowDown = Color3.fromRGB(220, 0, 0)

--destinations
module.redStop = Color3.fromRGB(255, 0, 0)
module.blue = Color3.fromRGB(0, 0, 255)

--warps;
module.blueDone = BrickColor.new("Cyan").Color

--my textcolor - unused
module.brouText = BrickColor.new("Teal").Color
module.yellowFind = BrickColor.new("New Yeller").Color

--action user just did
module.meColor = Color3.fromRGB(255, 255, 49)

--past times
module.mePastColor = Color3.fromRGB(112, 136, 255)
module.lightRed = Color3.fromRGB(255, 120, 130)
module.lightOrange = Color3.fromRGB(255, 160, 100)
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

_annotate("end")
return module
