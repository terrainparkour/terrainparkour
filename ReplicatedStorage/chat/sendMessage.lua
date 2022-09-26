--!strict

--eval 9.24.22

-- centralize all coms to player through this, for font/size/etc.

local module = {}

local function innerSendMsg(channel, msg: string, options)
	if options == nil then
		options = {}
	end
	if not options.FontSize then
		options.FontSize = Enum.FontSize.Size10
	end
	channel:SendSystemMessage(msg, { Font = Enum.Font.Gotham }, options)
end

module.sendMessage = innerSendMsg

module.usageCommandDesc = [[Admin Command examples:
/[username] - Details on user U (this works on anyone in game)
/badges - details on your badges
/popular - show popular top runs and server ranking.
/awards [username] - show awards for you or someone else.
/Mazatlan - details on a sign.
/Maza-3d - details on a race.  You can use abbreviations!
/found - List of signs you have found.
/finders - List top finders.
/wrs - List top world record holders.
/missing - List a random set of the races you've run, which you're not in the top 10 for.
/nonwrs [to|from] [signname] - list random WRs you are missing (for grinding)
/common - List signs you've found in common between everyone in the server.
/hint [username] - List of signs that user in server needs to find.
/random - Give a random sign name you have found.
/randomrace or rr - start a random race for the server between two signs!
/closest - Show the name of the closest sign you have found :)
/challenge [signName] - Show whether everybody in this server has found this sign or not!
/chomik - find the Chomik!
/meta - Gives some meta information.
/marathon [marathonName] show top runners of a specific marathon.
/marathons - Get list of available marathons.
/stats - Show today's stats.
/uptime - server uptime
/version - show server version
/tix [username] - Find out the TIX balance for any user!
/? - list these commands again.
]]

return module
