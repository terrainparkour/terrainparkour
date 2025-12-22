--!strict

-- messageFormatter.lua :: ReplicatedStorage.ChatSystem.messageFormatter
-- Provides utilities for RichText formatting and command usage text.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local messageFormatter = {}

local function color3ToHex(color: Color3): string
	local r = math.floor(color.R * 255)
	local g = math.floor(color.G * 255)
	local b = math.floor(color.B * 255)
	return string.format("#%02X%02X%02X", r, g, b)
end

messageFormatter.formatWithColor = function(text: string, color: Color3): string
	local hexColor = color3ToHex(color)
	return string.format('<font color="%s">%s</font>', hexColor, text)
end

messageFormatter.formatWithFont = function(text: string, fontName: string): string
	return string.format('<font face="%s">%s</font>', fontName, text)
end

messageFormatter.formatWithStyle = function(text: string, color: Color3?, fontName: string?): string
	local result = text
	if fontName then
		result = messageFormatter.formatWithFont(result, fontName)
	end
	if color then
		local hexColor = color3ToHex(color)
		result = string.format('<font color="%s">%s</font>', hexColor, result)
	end
	return result
end

messageFormatter.formatBold = function(text: string): string
	return "<b>" .. text .. "</b>"
end

messageFormatter.formatItalic = function(text: string): string
	return "<i>" .. text .. "</i>"
end
messageFormatter.Color3ToHex = color3ToHex

messageFormatter.usageCommandDesc = [[=== PLAYER PROFILES ===

/awards [username] - show awards for you or someone else.
/badges - details on your badges.
/player [username] - details on any player (in server or not). Alias: /p
/sign <username> [signname] - show user's sign profile, defaults to you.
/tix [username] - find out the TIX balance for any user!
/[username] - details on a user currently in this server.

=== SIGN DISCOVERY ===

/challenge [signName] - show whether everybody in this server has found this sign!
/closest - show the name of the closest sign you have found.
/common - list signs you've found in common with everyone in the server.
/found - list of signs you have found.
/hint <username> - list of signs that user in server needs to find.
/random - give a random sign name you have found.
/show [username] - highlight your found signs; compare finds with another player.
/Mazatlan - details on a sign (use any sign name).

=== RACING & RESULTS ===

/9run - find a race with 9 runners you haven't run yet (snipe a top 10 spot).
/history <a>-<b> - show WR history for a-b. Alias: /h
/Maza-3d - details on a race (use any race name, abbreviations work).
/missing - list random races you've run where you're not in the top 10.
/nonwrs [to|from] [signname] - list random WRs you are missing (for grinding).
/randomrace - start a random race for the server! Alias: /rr
/res [a-b] - popup run results GUI for a race. No args = repeat last.

=== MARATHONS ===

/marathon [marathonName] - show top runners of a specific marathon.
/marathons - get list of available marathons.

=== LEADERBOARDS ===

/cwrs - list top competitive world record holders.
/finders - list top finders.
/popular - show popular top runs and server ranking.
/stats - show today's stats.
/wrs - list top world record holders.

=== PROFILE ACTIONS ===

/pin <a>-<b> - pin the race from A-B to your profile so others can see!
/unpin - remove any pinned race from your profile.

=== FAVORITES ===

/favorite <a> <b> - mark a race as a favorite. Alias: /fav
/sf - show your favorite races.
/unfavorite <a> <b> - remove a race from your favorites. Alias: /unfav

=== REMOVING RUNS ===

/cancelRemoval <id> - cancel a pending removal request (refunds tix).
/removalStatus - view your removal request history and request IDs.
/requestRemoval <a>-<b> - request removal of your fastest time. Costs 3 tix.

=== SOCIAL ===

/beckon - invite people to join you.

=== SERVER & SYSTEM ===

/changelog [version|search] - view release history. Try: /changelog 400
/chomik - find the Chomik!
/meta - gives some meta information.
/uptime - server uptime.
/version - show server version.

=== FEEDBACK ===

/bugreport <text> - direct submission of any bugs you found to verv.
/idea <text> - share your ideas for new features or improvements.

=== HELP ===
k - show keyboard shortcuts.
S button (lower right) - settings and more options.
/? - list all commands again.
]]

_annotate("end")
return messageFormatter
