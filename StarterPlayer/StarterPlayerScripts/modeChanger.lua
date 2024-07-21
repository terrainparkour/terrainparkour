--!strict

local module = {}

local modeChangeDebounce = false
local modeChangeCurrentReason = ""

module.getReason = function()
	return modeChangeCurrentReason
end

module.freeModeChangeLock = function(reason: string)
	--annotate("killing mode due to:", reason)
	modeChangeDebounce = false
	modeChangeCurrentReason = ""
end

module.getModeChangeLock = function(kind: string)
	while modeChangeDebounce do
		wait()
		-- annotate("wait for mode lock." .. kind)
	end
	--store this so that we can kill repeated attempts to retry?
	-- annotate("setting mode to: ", kind)
	modeChangeCurrentReason = kind
	modeChangeDebounce = true
	-- annotate("locked for " .. kind)
end

return module
