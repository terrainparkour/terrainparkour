--!strict

--eval 9.21

local module = {}

local tt = require(game.ReplicatedStorage.types.gametypes)

module.BadgeSort = function(a: tt.badgeDescriptor, b: tt.badgeDescriptor)
	if a.badgeClass ~= b.badgeClass then
		return a.badgeClass < b.badgeClass
	end
	if a.baseNumber ~= nil and b.baseNumber ~= nil then
		return a.baseNumber < b.baseNumber
	end
	return a.name < b.name
end

module.BadgeAttainmentSort = function(a: tt.badgeAttainment, b: tt.badgeAttainment)
	return module.BadgeSort(a.badge, b.badge)
end

return module
