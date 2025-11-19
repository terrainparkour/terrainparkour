--!strict

-- MessageFormatter.lua :: ReplicatedStorage.ChatSystem.MessageFormatter
-- Provides utilities for RichText formatting and command usage text.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local MessageFormatter = {}

local function color3ToHex(color: Color3): string
	local r = math.floor(color.R * 255)
	local g = math.floor(color.G * 255)
	local b = math.floor(color.B * 255)
	return string.format("#%02X%02X%02X", r, g, b)
end

MessageFormatter.formatWithColor = function(text: string, color: Color3): string
	local hexColor = color3ToHex(color)
	return string.format('<font color="%s">%s</font>', hexColor, text)
end

MessageFormatter.formatWithFont = function(text: string, fontName: string): string
	return string.format('<font face="%s">%s</font>', fontName, text)
end

MessageFormatter.formatWithStyle = function(text: string, color: Color3?, fontName: string?): string
	local result = text
	if fontName then
		result = MessageFormatter.formatWithFont(result, fontName)
	end
	if color then
		local hexColor = color3ToHex(color)
		result = string.format('<font color="%s">%s</font>', hexColor, result)
	end
	return result
end

MessageFormatter.formatBold = function(text: string): string
	return "<b>" .. text .. "</b>"
end

MessageFormatter.formatItalic = function(text: string): string
	return "<i>" .. text .. "</i>"
end
MessageFormatter.Color3ToHex = color3ToHex

MessageFormatter.usageCommandDesc = [[Admin Command examples:
/awards [username] - show awards for you or someone else.
/badges - details on your badges.
/beckon - invite people to join you.
/challenge [signName] - Show whether everybody in this server has found this sign or not!
/closest - Show the name of the closest sign you have found :)
/common - List signs you've found in common between everyone in the server.
/finders - List top finders.
/found - List of signs you have found.
/hint <username> - List of signs that user in server needs to find.
/history <a>-<b> - show WR history for a-b. (abbreviation: 'h')
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
/res <a>-<b> - popup the run results GUI for race A-B
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
return MessageFormatter
