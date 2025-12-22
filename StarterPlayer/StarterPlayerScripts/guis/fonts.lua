--!strict
-- fonts.lua (StarterPlayer/StarterPlayerScripts/guis/fonts.lua)
-- Cached font faces to avoid per-call allocation.

-- Pre-cache all four font variants at module load
local monoRegular = Font.new("rbxasset://fonts/families/Inconsolata.json")
local monoBold = Font.new("rbxasset://fonts/families/Inconsolata.json")
monoBold.Weight = Enum.FontWeight.Bold

local serifRegular = Font.new("rbxasset://fonts/families/Merriweather.json")
local serifBold = Font.new("rbxasset://fonts/families/Merriweather.json")
serifBold.Weight = Enum.FontWeight.Bold

local module = {}

function module.GetFont(isMonospaced: boolean?, bold: boolean?): Font
	if isMonospaced then
		return if bold then monoBold else monoRegular
	else
		return if bold then serifBold else serifRegular
	end
end

return module
