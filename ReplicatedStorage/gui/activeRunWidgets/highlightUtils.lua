--!strict
-- highlightUtils.lua (ReplicatedStorage/gui/activeRunWidgets/highlightUtils.lua)
-- Shared highlight utilities for widget picker cards and widget frames.
-- Provides pulsing glow effects for visual feedback during configuration.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local TweenService = game:GetService("TweenService")

local colors = require(game.ReplicatedStorage.util.colors)

local module = {}

-- Highlight configuration (all colors from colors.lua)
local HIGHLIGHT_COLOR = colors.neonYellow
local HIGHLIGHT_GLOW_COLOR = colors.highlightGlow
local HIGHLIGHT_THICKNESS = 8
local HIGHLIGHT_FADE_DURATION = 0.4

-- Highlight mode determines animation intensity
export type HighlightMode = "normal" | "aggressive"

-- Track active highlights and their tweens for cleanup
type HighlightState = {
	stroke: UIStroke,
	glowStroke: UIStroke?,
	pulseTween: Tween?,
	glowPulseTween: Tween?,
	fadeTween: Tween?,
}

local activeHighlights: { [Frame]: HighlightState } = {}

-- Create a pulsing highlight on a frame
-- mode: "normal" for self-hover, "aggressive" for cross-element highlighting
function module.Highlight(frame: Frame, mode: HighlightMode?)
	if not frame or not frame.Parent then
		return
	end

	-- Clear any existing highlight on this frame
	module.ClearHighlight(frame, true)

	local isAggressive = mode == "aggressive"

	-- Animation parameters based on mode
	local pulseSpeed = if isAggressive then 0.15 else 0.3
	local strokePulseAdd = if isAggressive then 8 else 4
	local glowPulseAdd = if isAggressive then 16 else 10
	local glowStartAdd = if isAggressive then 8 else 6

	-- Create outer glow stroke (orange-yellow, very thick, semi-transparent)
	local glowStroke = Instance.new("UIStroke")
	glowStroke.Name = "HighlightGlow"
	glowStroke.Color = HIGHLIGHT_GLOW_COLOR
	glowStroke.Thickness = HIGHLIGHT_THICKNESS + glowStartAdd
	glowStroke.Transparency = 0.3
	glowStroke.Parent = frame

	-- Create main highlight stroke (bright yellow, solid)
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Highlight"
	stroke.Color = HIGHLIGHT_COLOR
	stroke.Thickness = HIGHLIGHT_THICKNESS
	stroke.Transparency = 0
	stroke.Parent = frame

	-- Animate a pulsing glow for maximum visibility
	local pulseInfo = TweenInfo.new(pulseSpeed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local pulseTween = TweenService:Create(stroke, pulseInfo, {
		Thickness = HIGHLIGHT_THICKNESS + strokePulseAdd,
	})
	local glowPulseTween = TweenService:Create(glowStroke, pulseInfo, {
		Thickness = HIGHLIGHT_THICKNESS + glowPulseAdd,
		Transparency = if isAggressive then 0.2 else 0.5,
	})
	pulseTween:Play()
	glowPulseTween:Play()

	-- Store state for cleanup
	activeHighlights[frame] = {
		stroke = stroke,
		glowStroke = glowStroke,
		pulseTween = pulseTween,
		glowPulseTween = glowPulseTween,
		fadeTween = nil,
	}
end

-- Clear highlight from a frame
-- immediate: if true, destroy instantly; if false, fade out smoothly
function module.ClearHighlight(frame: Frame, immediate: boolean?)
	local state = activeHighlights[frame]
	if not state then
		-- Check for orphaned highlight strokes and clean them up
		local orphanStroke = frame:FindFirstChild("Highlight")
		local orphanGlow = frame:FindFirstChild("HighlightGlow")
		if orphanStroke then
			orphanStroke:Destroy()
		end
		if orphanGlow then
			orphanGlow:Destroy()
		end
		return
	end

	-- Cancel any existing tweens
	if state.pulseTween then
		state.pulseTween:Cancel()
	end
	if state.glowPulseTween then
		state.glowPulseTween:Cancel()
	end
	if state.fadeTween then
		state.fadeTween:Cancel()
	end

	-- Immediate destruction
	if immediate then
		if state.glowStroke and state.glowStroke.Parent then
			state.glowStroke:Destroy()
		end
		if state.stroke and state.stroke.Parent then
			state.stroke:Destroy()
		end
		activeHighlights[frame] = nil
		return
	end

	-- Fade out animation for smooth transition
	local fadeInfo = TweenInfo.new(HIGHLIGHT_FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	-- Remove from active tracking immediately so new highlight can be created
	activeHighlights[frame] = nil

	-- Fade the main stroke
	local strokeFade = TweenService:Create(state.stroke, fadeInfo, {
		Transparency = 1,
		Thickness = HIGHLIGHT_THICKNESS - 2,
	})
	strokeFade.Completed:Connect(function()
		if state.stroke and state.stroke.Parent then
			state.stroke:Destroy()
		end
	end)
	strokeFade:Play()

	-- Fade the glow stroke
	if state.glowStroke then
		local glowFade = TweenService:Create(state.glowStroke, fadeInfo, {
			Transparency = 1,
		})
		glowFade.Completed:Connect(function()
			if state.glowStroke and state.glowStroke.Parent then
				state.glowStroke:Destroy()
			end
		end)
		glowFade:Play()
	end
end

-- Clear all active highlights (used when closing picker)
function module.ClearAllHighlights()
	for frame, _ in pairs(activeHighlights) do
		module.ClearHighlight(frame, true)
	end
end

-- Flash highlight briefly then fade (for selection feedback)
function module.FlashHighlight(frame: Frame)
	module.Highlight(frame, "aggressive")
	task.delay(0.5, function()
		module.ClearHighlight(frame, false)
	end)
end

-- Check if a frame currently has an active highlight
function module.IsHighlighted(frame: Frame): boolean
	return activeHighlights[frame] ~= nil
end

_annotate("end")
return module

