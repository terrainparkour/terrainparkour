--!strict

-- commandTypes.lua :: ReplicatedStorage.ChatSystem.commandTypes
-- Shared types for command modules.

export type CommandHandler = (player: Player, parts: { string }) -> boolean

export type CommandVisibility = "private" | "public"
export type ChannelRestriction = "data_only" | "any"

export type CommandModule = {
	Execute: CommandHandler,
	Visibility: CommandVisibility,
	ChannelRestriction: ChannelRestriction,
	AutocompleteVisible: boolean,
	Aliases: { string }?,
}

return {}
