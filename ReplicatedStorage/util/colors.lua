--!strict

--eval 9.21

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
module.lightYellow = Color3.fromRGB(255, 255, 10)

module.signTextColor = Color3.fromRGB(255, 240, 241)
module.signColor = Color3.fromRGB(255, 89, 89)

return module
