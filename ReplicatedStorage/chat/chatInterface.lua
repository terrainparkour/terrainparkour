--!strict

--likely not used

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

local speakers = {}

module.registerSpeaker = function(channel, speaker)
	speakers[channel] = speaker
end

module.getSpeaker = function(channel)
	return speakers[channel]
end

--used for actionresults responses.
module.ChatBotSendMessage = function(message, channel, color)
	local speaker = speakers[channel]
	if speaker == nil then
		return
	end
	if color == nil then
		color = Color3.new(1, 1, 1)
	end
	if string.len(message) <= 1 then
		warn("short message!")
	end
	speaker:SayMessage(message, channel, { ChatColor = color })
end

_annotate("end")
return module
