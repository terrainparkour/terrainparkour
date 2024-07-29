--!strict

-- hide chat window and leaderboard when the user hits tab.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local UserInputService = game:GetService("UserInputService")
local showLB: boolean = true
local showChat: boolean = true

local PlayersService = game:GetService("Players")

local localPlayer = PlayersService.LocalPlayer
local settingEnums = require(game.ReplicatedStorage.UserSettings.settingEnums)
local localFunctions = require(game.ReplicatedStorage.localFunctions)
local tt = require(game.ReplicatedStorage.types.gametypes)
local ignoreChatWhenHittingX = false


