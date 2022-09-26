--!strict

--eval 9.24.22

local module = {}

-- controlling which server endpoints/debugging status should be used.
module.isInStudio = function()
	local forceProd = false
	if forceProd then
		print("FORCE PROD....")
		return false
	end

	local isInStudio = false
	if game.JobId == "" then
		isInStudio = true
	end
	if game.JobId == "00000000-0000-0000-0000-000000000000" then
		isInStudio = true
	end
	return isInStudio
end

return module
