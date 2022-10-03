local module = {}

local settingDomains: { [string]: string } = {
	Surveys = "Surveys",
	Marathons = "Marathons",
	UserSettings = "UserSettings",
}

module.settingDomains = settingDomains

local settingNames: { [string]: string } = {}

module.settingNames = settingNames

return module
