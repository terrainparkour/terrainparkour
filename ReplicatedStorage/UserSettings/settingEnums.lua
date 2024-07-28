--!strict

--enums for usersetting domain and setting names.  gradually expand this.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local settingDomains: { [string]: string } = {
	SURVEYS = "Surveys",
	MARATHONS = "Marathons",
	USERSETTINGS = "UserSettings",
}

module.settingDomains = settingDomains

local settingNames: { [string]: string } = {
	ENABLE_DYNAMIC_RUNNING = "enable dynamic running",
	HIDE_LEADERBOARD = "hide leaderboard",
	SHORTEN_CONTEST_DIGIT_DISPLAY = "shorten contest digit display",
	X_BUTTON_IGNORES_CHAT = "x button ignores chat",
}

--this system fails when i add one here but don't create the userSetting in the db.
-- I should have a way to automatically at least do a getOrCreate there, like I do with signs.

export type settingRequest = { domain: string?, settingName: string?, includeDistributions: boolean }

module.settingNames = settingNames

_annotate("end")
return module
