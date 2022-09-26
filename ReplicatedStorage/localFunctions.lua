--!strict

--eval 9.25.22

--localfunctions used for local script communication about settings changes.
--if you care, register to listen
--and the setttings ui will spam you

--i.e. one local ui to another.  this is likely not the ideal method.

local tt = require(game.ReplicatedStorage.types.gametypes)

local module = {}

local settingChangeFunctions = {}
module.registerSettingChangeReceiver = function(func: (player: Player, tt.userSettingValue) -> nil, name: string)
	settingChangeFunctions[name] = func
end

module.notifySettingChange = function(player: Player, setting: tt.userSettingValue)
	for name: string, otherFunc: (player: Player, tt.userSettingValue) -> nil in pairs(settingChangeFunctions) do
		-- print("calling func " .. name)
		-- print(setting)
		otherFunc(player, setting)
	end
end

return module
