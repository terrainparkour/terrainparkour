--!strict

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local tt = require(game.ReplicatedStorage.types.gametypes)

--duh. sort them sensibly, fallback to name.
module.BadgeSort = function(a: tt.badgeDescriptor, b: tt.badgeDescriptor)
	if a.badgeClass ~= b.badgeClass then
		return a.badgeClass < b.badgeClass
	end
	if a.baseNumber ~= nil and b.baseNumber ~= nil then
		return a.baseNumber < b.baseNumber
	end
	if a.order ~= nil and b.order ~= nil then
		return a.order < b.order
	end
	if a.order ~= nil and b.order == nil then
		return true
	end
	if a.order == nil and b.order ~= nil then
		return false
	end
	return a.name < b.name
end

module.BadgeAttainmentSort = function(a: tt.badgeAttainment, b: tt.badgeAttainment)
	return module.BadgeSort(a.badge, b.badge)
end

_annotate("end")
return module
