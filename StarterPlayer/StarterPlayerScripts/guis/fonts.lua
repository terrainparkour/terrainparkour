local module = {}

module.GetFont = function(isMonospaced: boolean?, bold: boolean?): Font
	if isMonospaced then
		if bold then
			local font1 = Font.new("rbxasset://fonts/families/Inconsolata.json")
			font1.Weight = Enum.FontWeight.Bold
			return font1
		else
			local font2 = Font.new("rbxasset://fonts/families/Inconsolata.json")
			return font2
		end
	else
		if bold then
			local font3 = Font.new("rbxasset://fonts/families/Merriweather.json")
			font3.Weight = Enum.FontWeight.Bold
			return font3
		else
			local font4 = Font.new("rbxasset://fonts/families/Merriweather.json")
			return font4
		end
	end
end

return module
