--!strict

--special luau types for movement.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local module = {}

export type avatarEventDetails = {
	relatedSignId: number?,
	relatedSignName: string?,
	floorMaterial: Enum.Material?, --this is either a terrain or a non-terrain, you need to check.
	newMoveDirection: Vector3?,
	oldMoveDirection: Vector3?,
	newState: Enum.HumanoidStateType?,
	oldState: Enum.HumanoidStateType?,
	warpSourceSignName: string?,
	warpDestinationSignName: string?,
	oldSpeed: number?,
	newSpeed: number?,
	oldJumpPower: number?,
	newJumpPower: number?,
	reason: string?,
}

export type avatarEvent = {
	eventType: number,
	timestamp: number,
	details: avatarEventDetails?,
}

--the types of all the events broadcast by avatarEventMonitor.
local avatarEventTypes: { [string]: number } = {
	CHARACTER_ADDED = 1, --when the character is added.
	RUN_START = 2,
	RUN_COMPLETE = 3,
	RUN_KILL = 4,
	RETOUCH_SIGN = 5,
	TOUCH_SIGN = 6, --distinct from retouch, end, run_start.

	-- CHANGE_DIRECTION = 6, --this is the roblox property, which contains both the movement vector3 (direction), which also will turn to 0,0,0 if the player totally stops.
	FLOOR_CHANGED = 7,
	STATE_CHANGED = 8, --this is where we load all swimming, jumping
	AVATAR_STOPPED_MOVING = 9, --since change direction is sent way too often when currently all we actually care about is if they have stopped
	AVATAR_STARTED_MOVING = 10,
	AVATAR_CHANGED_DIRECTION = 101,

	AVATAR_RESET = 11, -- resetting avatar.

	KEYBOARD_WALK = 12, --inputs from keyboard.
	KEYBOARD_RUN = 13,

	RESET_MORPHS = 14,

	DO_SPEED_CHANGE = 15, --when I do my own, movementV2 related speedups.
	DO_JUMPPOWER_CHANGE = 16,

	AVATAR_DIED = 17,
	CHARACTER_REMOVING = 18,
	GET_READY_FOR_WARP = 19, -------warper sends this out to shut down other options for users.
	MORPHING_WARPER_READY = 20,
	MOVEMENT_WARPER_READY = 21,
	RACING_WARPER_READY = 22,
	MARATHON_WARPER_READY = 23,

	WARP_DONE_RESTART_MORPHS = 50,
	WARP_DONE_RESTART_MOVEMENT = 51,
	WARP_DONE_RESTART_RACING = 52,
	WARP_DONE_RESTART_MARATHONS = 53,

	MORPHING_RESTARTED = 54,
	MOVEMENT_RESTARTED = 55,
	RACING_RESTARTED = 56,
	MARATHON_RESTARTED = 57,
}

local avatarEventTypesReverse = {}
for k, v in pairs(avatarEventTypes) do
	avatarEventTypesReverse[v] = k
end

module.avatarEventTypes = avatarEventTypes
module.avatarEventTypesReverse = avatarEventTypesReverse

_annotate("end")
return module
