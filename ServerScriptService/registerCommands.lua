--!strict

-- registerCommands.lua :: ServerScriptService.registerCommands
-- SERVER-ONLY: Registers all slash commands as TextChatCommand instances.
-- This tells Roblox they are commands so they won't appear in chat/bubbles.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local CommandService = require(game.ReplicatedStorage.ChatSystem.commandService)

type Module = {
	Init: () -> (),
}

local module: Module = {} :: Module

function module.Init()
	_annotate("Registering TextChatCommand instances to suppress commands from chat/bubbles")
	
	-- Track which commands we've registered to avoid duplicates
	local registeredCommands: { [string]: TextChatCommand } = {}
	local commandCount = 0
	
	for commandName, commandModule in pairs(CommandService.Commands) do
		-- Skip if we already registered this command module
		local existingCommand = registeredCommands[tostring(commandModule)]
		if existingCommand then
			continue
		end
		
		local textChatCommand = Instance.new("TextChatCommand")
		textChatCommand.Name = "Command_" .. commandName
		textChatCommand.PrimaryAlias = "/" .. commandName
		
		-- Set autocomplete visibility from command metadata
		textChatCommand.AutocompleteVisible = commandModule.AutocompleteVisible
		
		-- Add aliases as SecondaryAlias
		if commandModule.Aliases and #commandModule.Aliases > 0 then
			textChatCommand.SecondaryAlias = "/" .. commandModule.Aliases[1]
			if #commandModule.Aliases > 1 then
				_annotate(
					string.format(
						"Warn: Command /%s has %d aliases but TextChatCommand only supports one SecondaryAlias",
						commandName,
						#commandModule.Aliases
					)
				)
			end
		end
		
		-- Connect to Triggered event to execute the command
		textChatCommand.Triggered:Connect(function(textSource: TextSource, unfilteredText: string)
			local player = Players:GetPlayerByUserId(textSource.UserId)
			if not player then
				_annotate(string.format("Warn: No player found for userId %d", textSource.UserId))
				return
			end
			
			-- Parse the command arguments
			local parts = string.split(unfilteredText, " ")
			local argParts = {}
			for i = 2, #parts do
				table.insert(argParts, parts[i])
			end
			
			_annotate(string.format("Executing command /%s for player %s", commandName, player.Name))
			commandModule.Execute(player, argParts)
		end)
		
		textChatCommand.Parent = TextChatService
		registeredCommands[tostring(commandModule)] = textChatCommand
		
		local aliasInfo = ""
		if textChatCommand.SecondaryAlias ~= "" then
			aliasInfo = string.format(" (alias: %s)", textChatCommand.SecondaryAlias)
		end
		_annotate(
			string.format(
				"Registered TextChatCommand: /%s%s [autocomplete=%s]",
				commandName,
				aliasInfo,
				tostring(commandModule.AutocompleteVisible)
			)
		)
		commandCount += 1
	end
	
	_annotate(string.format("Registered %d TextChatCommand instances total", commandCount))
end

_annotate("end")
return module

