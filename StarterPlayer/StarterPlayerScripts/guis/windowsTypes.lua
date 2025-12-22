export type guiSpec = {
	name: string,
	rowSpecs: { rowSpec },
}

export type rowSpec = {
	name: string,
	order: number,
	tileSpecs: { tileSpec },
	-- height: UDim.new(0, pixels) = fixed pixel height; UDim.new(weight, 0) = proportional weight.
	-- Weight-based rows are normalized by applyProportionalHeights to share available space.
	-- Example: UDim.new(400, 0) means "weight 400" NOT "400 pixels"—don't confuse Scale with Offset!
	height: UDim,
	horizontalAlignment: Enum.HorizontalAlignment?, -- what does this even do?
	bottomBorderColor: Color3?, -- if set, adds a bottom border of this color
	bottomBorderThickness: number?, -- thickness of bottom border in pixels (default 2)
	timeText: string?, -- optional: used by digit-highlighted time tiles to pass time to next row
	searchText: string?, -- optional: if scrollingFrameTileSpec.searchConfig is set, used for live filtering
}

export type TooltipStyle = {
	backgroundColor: Color3?,
	textColor: Color3?,
	font: Enum.Font?, -- Legacy: Enum.Font
	fontFace: Font?, -- Preferred: FontFace for exact font matching
}

export type tileSpec = {
	name: string,
	order: number,
	width: UDim?, -- default 1
	spec: AnyTileSpec,
	tooltipText: string?,
	tooltipStyle: TooltipStyle?, -- Optional styling for tooltip (background, text color, font)
	onCreate: ((GuiObject) -> ())?, -- Optional callback invoked with created element after it's built
}

export type textTileSpec = {
	type: "text",
	text: string,
	isMonospaced: boolean?, --default false
	isBold: boolean?, --default false
	backgroundColor: Color3?, --default backgroundColor grey
	textColor: Color3?, --default textColor black
	textXAlignment: Enum.TextXAlignment?, --default left
	textYAlignment: Enum.TextYAlignment?, --default center
	textWrapped: boolean?, --default false
	textScaled: boolean?, --default true
	textSize: number?, --used when textScaled == false
	leftPadding: number?, --default 0, adds UIPadding for left-aligned text
	rightPadding: number?, --default 0, adds UIPadding for right-aligned text
	topPadding: number?, --default 0
	bottomPadding: number?, --default 0
}

export type portraitTileSpec = {
	type: "portrait",
	userId: number,
	doPopup: boolean,
	width: UDim?,
	backgroundColor: Color3?,
	rightBorderColor: Color3?, -- Adds a 1px right border if specified
}

export type imageTileSpec = {
	type: "image",
	imageId: number?, -- rbxassetid number (will be formatted as "rbxassetid://NUMBER")
	backgroundColor: Color3?,
	scaleType: Enum.ScaleType?, -- default Fit
	doPopup: boolean?, -- if true, shows larger image on hover (default false)
}

export type buttonTileSpec = {
	type: "button",
	text: string,
	isMonospaced: boolean?,
	isBold: boolean?,
	textSize: number?,
	backgroundColor: Color3?,
	hoverBackgroundColor: Color3?,
	textColor: Color3?,
	textXAlignment: Enum.TextXAlignment?,
	onClick: (inputObject: InputObject, theButton: TextButton) -> (),
}

-- Shared config for logarithmic-scaled indicator tiles
export type logScaledTileConfig = {
	logPosition: number, -- 0-1 position on the logarithmic scale
	text: string, -- Text to display
	textColor: Color3?, -- Text color (default black)
	textAlignment: Enum.TextXAlignment, -- Left or Right alignment
	paddingSide: "left" | "right", -- Which side to pad text
	showIndicatorAtZero: boolean, -- Whether to show indicator when position is 0
	indicatorColor: Color3?, -- Color of the vertical position indicator
}

-- A tile showing duration with logarithmic visual indicator
export type lastedTileSpec = {
	type: "lasted",
	text: string, -- Formatted duration text (e.g., "3d 5h")
	durationSeconds: number, -- Raw duration in seconds for positioning
	backgroundColor: Color3?,
	textColor: Color3?,
	indicatorColor: Color3?, -- Color of the vertical position indicator
}

-- A tile showing improvement with linear visual indicator (dynamic range)
export type improvementTileSpec = {
	type: "improvement",
	text: string, -- Formatted improvement text (e.g., "0.015")
	improvementMs: number, -- Raw improvement in milliseconds
	maxImprovementMs: number, -- Max improvement in the dataset (for scaling)
	backgroundColor: Color3?,
	textColor: Color3?,
	indicatorColor: Color3?, -- Color of the vertical position indicator
}

-- A tile showing time with per-digit highlighting based on comparison with previous time
-- Digits that are higher (worse) than the previous row get a red tint
-- Digits that are lower (better) than the previous row get a green tint
export type digitHighlightedTimeTileSpec = {
	type: "digitHighlightedTime",
	text: string, -- The time string to display
	previousText: string?, -- The previous time string to compare against (nil = no highlighting)
	backgroundColor: Color3?, -- Base background color
	textColor: Color3?, -- Text color (default black)
	textXAlignment: Enum.TextXAlignment?, -- Alignment of the whole time (default right)
	worseDigitColor: Color3?, -- Background tint for digits worse than previous (default subtle red)
}

--a tile which as a row within it
export type rowTileSpec = {
	type: "rowTile",
	name: string,
	tileSpecs: { tileSpec },
	width: UDim?, --default to 1,0 and will be split normally by the child tileSpecs
}

export type scrollingFrameSearchConfig = {
	placeholderText: string?, -- default "Search..."
	countNoun: string?, -- default "items" (e.g. "settings")
	autoFocus: boolean?, -- default true
}

--a type which has a scrolling frame within it
export type scrollingFrameTileSpec = {
	type: "scrollingFrameTileSpec",
	name: string,
	headerRow: rowSpec,
	dataRows: { rowSpec },
	stickyRows: { rowSpec },
	rowHeight: number,
	howManyRowsToShow: number?,
	searchConfig: scrollingFrameSearchConfig?,
}

-- Union of all tile spec types (must come after all individual types are defined)
export type AnyTileSpec = textTileSpec | portraitTileSpec | imageTileSpec | buttonTileSpec | scrollingFrameTileSpec | rowTileSpec | lastedTileSpec | improvementTileSpec | digitHighlightedTimeTileSpec

export type stickyScrollingFrameType = {
	frame: Frame, -- Container frame that holds the internal ScrollingFrame and scroll indicator
	addElement: (row: Frame, layoutOrder: number, isSticky: boolean) -> (),
	doneAdding: () -> (),
	refresh: () -> (),
}

return {}
