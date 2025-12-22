--!strict
-- hostSecret.example.lua - TEMPLATE (copy to hostSecret.lua)
-- This file shows the structure. Copy to hostSecret.lua and fill in real values.
-- hostSecret.lua is gitignored and will NOT be checked in.

local environment = require(game.ReplicatedStorage.environment)

local module = {}

-- Server URLs by environment
-- Only production URL is truly sensitive; localhost is just for local dev
local function setupHOST()
	local env = environment.GetEnvironment()

	if env == "studio" then
		-- Local development: always point to local Django
		module.HOST = "127.0.0.1:8000/"
		print("HOST: localhost (studio)")
	elseif env == "production" then
		-- PRODUCTION: Replace with your actual production server IP
		module.HOST = "YOUR_PRODUCTION_IP_HERE/"
		print("HOST: production")
	else
		-- Test/dev published game: can point to test server or localhost
		module.HOST = "YOUR_TEST_IP_HERE/"
		print("HOST: test")
	end
end

setupHOST()

-- API secret for request validation
-- This should match what your Django backend expects
module.addSecretTbl = function(tbl: any)
	tbl.secret = "YOUR_SECRET_HERE"
end

return module

