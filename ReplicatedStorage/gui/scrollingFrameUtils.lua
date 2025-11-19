--!strict

-- scrollingFrameUtils.lua
-- Generic utilities for enhancing ScrollingFrame instances.
-- Note: PreventCameraScrollOnHover requires client-side execution (uses ContextActionService).

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local ContextActionService = game:GetService("ContextActionService")

local module = {}

-- Prevents camera zoom when scrolling over a ScrollingFrame by sinking mouse wheel input.
-- Call this on any ScrollingFrame instance to enable the behavior.
-- CLIENT-SIDE ONLY: This function uses ContextActionService and must be called from client scripts.
module.PreventCameraScrollOnHover = function(scrollingFrame: ScrollingFrame)
	local actionName = string.format("ScrollingFrame_PreventCameraScroll_%s", tostring(scrollingFrame))
	
	local function handleMouseWheel(
		_actionName: string,
		inputState: Enum.UserInputState,
		inputObject: InputObject
	): Enum.ContextActionResult
		if inputState ~= Enum.UserInputState.Change then
			return Enum.ContextActionResult.Pass
		end
		
		-- Check if mouse is over the scrolling frame
		local mouse = game:GetService("Players").LocalPlayer:GetMouse()
		local mouseX, mouseY = mouse.X, mouse.Y
		local framePos = scrollingFrame.AbsolutePosition
		local frameSize = scrollingFrame.AbsoluteSize
		
		if mouseX < framePos.X or mouseX > framePos.X + frameSize.X then
			return Enum.ContextActionResult.Pass
		end
		if mouseY < framePos.Y or mouseY > framePos.Y + frameSize.Y then
			return Enum.ContextActionResult.Pass
		end
		
		_annotate(string.format("[PreventCameraScroll] Sinking scroll for %s", scrollingFrame.Name))
		
		-- Sink the input to prevent camera from also scrolling
		return Enum.ContextActionResult.Sink
	end
	
	-- Bind mouse wheel handler using ContextActionService to sink input and prevent camera scrolling
	ContextActionService:BindAction(actionName, handleMouseWheel, false, Enum.UserInputType.MouseWheel)
	
	-- Unbind action when frame is destroyed
	scrollingFrame.Destroying:Connect(function()
		ContextActionService:UnbindAction(actionName)
	end)
	
	_annotate(string.format("Enabled camera scroll prevention for %s", scrollingFrame.Name))
end

_annotate("end")
return module

