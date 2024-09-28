--!strict

-- centralize all coms to player through this, for font/size/etc.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local module = {}

local tt = require(game.ReplicatedStorage.types.gametypes)
--simple method to write text to output. better than assembing a giant string all at once.
local innerSendMsg = function(channel, msg: string, options: any)
	if options == nil then
		options = {}
	end
	if not options.FontSize then
		options.FontSize = Enum.FontSize.Size10
	end
	if not options.Font then
		options.Font = Enum.Font.Gotham
	end
	-- _annotate(options)
	channel:SendSystemMessage(msg, options)
end

module.sendMessage = innerSendMsg

module.usageCommandDesc = [[Admin Command examples:
/awards [username] - show awards for you or someone else.
/badges - details on your badges.
/beckon - invite people to join you.
/challenge [signName] - Show whether everybody in this server has found this sign or not!
/closest - Show the name of the closest sign you have found :)
/common - List signs you've found in common between everyone in the server.
/finders - List top finders.
/found - List of signs you have found.
/hint <username> - List of signs that user in server needs to find.
/Mazatlan - details on a sign.
/Maza-3d - details on a race.  You can use abbreviations!
/marathon [marathonName] show top runners of a specific marathon.
/marathons - Get list of available marathons.
/meta - Gives some meta information.
/missing - List a random set of the races you've run, which you're not in the top 10 for.
/nonwrs [to|from] [signname] - list random WRs you are missing (for grinding)
/popular - show popular top runs and server ranking.
/random - Give a random sign name you have found.
/randomrace or /rr - start a random race for the server between two signs!
/sign <username> [signname] - show user's sign profile, defaults to you.
/stats - Show today's stats.
/tix [username] - Find out the TIX balance for any user!
/uptime - server uptime
/pin <a>-<b> pin the race from A-B to your profile so others can see!
/unpin remove any pinned race from your profile.
/[username] - Details on user (this works on anyone in game).
/player [username] like the above but they can be in the server, or not. or /p
/version - show server version
/[c]wrs - List top [competitive] world record holders.
/chomik - find the Chomik!
k to show keyboard shortcuts
(click S in lower right for more options, including your settings.)

/? - list all commands again.
]]

_annotate("end")
return module
