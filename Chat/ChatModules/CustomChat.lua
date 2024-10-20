--!strict

-- CustomChat.lua
-- according to channel setup definitions do the thing.
-- oh, THIS IS ON THE SERVER!

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local tt = require(game.ReplicatedStorage.types.gametypes)
local channelDefinitions = require(game.ReplicatedStorage.chat.channelDefinitions)
local tpUtil = require(game.ReplicatedStorage.util.tpUtil)
local banning = require(game.ServerScriptService.banning)

local channels = {}
local channelsSetUp = false

local function Run(ChatService)
	if channelsSetUp then
		return
	end
	channelsSetUp = true

	local theDefinitions: { tt.channelDefinition } = channelDefinitions.getChannelDefinitions()

	local function getDef(channelName): tt.channelDefinition | nil
		for _, def in ipairs(theDefinitions) do
			if def.Name == channelName then
				return def
			end
		end
		annotater.Error("failed to get channelName def." .. channelName)
		return nil
	end

	for _, channelDef: tt.channelDefinition in pairs(theDefinitions) do
		local channel = ChatService:GetChannel(channelDef.Name)
		if channel then
			_annotate("channel found: " .. channelDef.Name)
		else
			_annotate("channel not found, creating: " .. channelDef.Name)
			channel = ChatService:AddChannel(channelDef.Name)
		end

		channel.WelcomeMessage = channelDef.WelcomeMessage
		channel.AutoJoin = channelDef.AutoJoin

		channels[channelDef.Name] = channel
	end

	--every time a message is sent, run it through here
	--if starts with '/',send to admin checker defined or kill it
	--else if normal msg check channel allows chat
	--returning true means its taken care of, don't write it to screen.
	ChatService:RegisterProcessCommandsFunction("GeneralMessageChecker", function(speakerName, message, channelName)
		local def = getDef(channelName)
		if not def then
			warn("no matching channel for channel name: " .. channelName)
			return true
		end

		if string.sub(message, 1, 1) == "/" then
			if def.adminFunc ~= nil then
				local res, err = pcall(def.adminFunc, speakerName, message, channelName, channels)
				if not res then
					warn(err)
					return true
				end
				return res
			end
			return true
		end

		if def.noTalkingInChannel then
			return true
		end
		return false
	end)

	_annotate("sending channels to channelDefinitions")
	theDefinitions.SendChannels(channels)

	local validChannelNames = {}
	for _, def in ipairs(theDefinitions) do
		validChannelNames[def.Name] = true
	end

	ChatService:RegisterProcessCommandsFunction("bannedUsersCantChat", function(speakerName, message, channelName)
		if not validChannelNames[channelName] then
			_annotate("invalid channel name: " .. channelName .. "so not setting up banned user can't chat.")
			return false
		end

		local player = tpUtil.looseGetPlayerFromUsername(speakerName)
		if player == nil then
			warn("nil player:" .. speakerName)
			return true
		end
		local bl = banning.getBanLevel(player.UserId)

		if bl ~= nil and bl > 0 then
			warn("user speaking is banned.")
			return true
		end
		--unbanned players can chat
		return false
	end)
end

return Run
