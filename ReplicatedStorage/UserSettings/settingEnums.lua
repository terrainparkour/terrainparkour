--!strict

--enums for usersetting domain and setting names.  gradually expand this.
-- this is the shareable replicateStorage version. client's cant directly require the actual server module userSettings.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local settingNames: { [string]: string } = {
	ENABLE_DYNAMIC_RUNNING = "enable dynamic running",
	HIDE_LEADERBOARD = "hide leaderboard",
	SHORTEN_CONTEST_DIGIT_DISPLAY = "shorten contest digit display",
	X_BUTTON_IGNORES_CHAT = "x button ignores chat",
	HIGHLIGHT_ON_RUN_COMPLETE_WARP = "do sign highlight when you click warp on a complete run",
	HIGHLIGHT_ON_KEYBOARD_1_TO_WARP = "do sign highlight when you hit 1 to warp to the completed run",
	HIGHLIGHT_AT_ALL = "do any sign highlighting at all, for example when warping to a server event run",
}

module.settingNames = settingNames

local settingDomains: { [string]: string } = {
	SURVEYS = "Surveys",
	MARATHONS = "Marathons",
	USERSETTINGS = "UserSettings",
}

module.settingDomains = settingDomains

--this system fails when i add one here but don't create the userSetting in the db.
-- I should have a way to automatically at least do a getOrCreate there, like I do with signs.

export type settingRequest = { domain: string?, settingName: string?, includeDistributions: boolean }

_annotate("end")
return module
