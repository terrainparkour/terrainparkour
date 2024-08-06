--!strict

-- settingSort.lua
-- a function to sort user settings by domain and then name.
-- local settingSort = require(game.ReplicatedStorage.settingSort)

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local tt = require(game.ReplicatedStorage.types.gametypes)
local module = {}

module.SettingSort = function(a: tt.userSettingValue, b: tt.userSettingValue): boolean
	if a.domain ~= b.domain then
		return a.domain < b.domain
	end
	return a.name < b.name
end

_annotate("end")
return module
