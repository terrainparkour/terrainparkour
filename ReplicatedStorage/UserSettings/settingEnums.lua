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
}

module.settingNames = settingNames

return module
