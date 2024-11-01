export type guiSpec = {
	name: string,
	rowSpecs: { rowSpec },
}

export type rowSpec = {
	name: string,
	order: number,
	tileSpecs: { tileSpec },
	height: UDim, --if a scale is included, it's stretchable vertically. if just an offset is included, it's not and it's a fixed height.
	horizontalAlignment: Enum.HorizontalAlignment?, -- what does this even do?
}

export type AnyTileSpec = textTileSpec | portraitTileSpec | buttonTileSpec | scrollingFrameTileSpec | rowTileSpec

export type tileSpec = {
	name: string,
	order: number,
	width: UDim?, -- default 1
	spec: AnyTileSpec,
	tooltipText: string?,
}

export type textTileSpec = {
	type: "text",
	text: string,
	isMonospaced: boolean?, --default false
	isBold: boolean?, --default false
	backgroundColor: Color3?, --default backgroundColor grey
	textColor: Color3?, --default textColor black
	textXAlignment: Enum.TextXAlignment?, --default left
	includeTextSizeConstraint: boolean?, --default true
}

export type portraitTileSpec = {
	type: "portrait",
	userId: number,
	doPopup: boolean,
	width: UDim?,
	backgroundColor: Color3?,
}

export type buttonTileSpec = {
	type: "button",
	text: string,
	isMonospaced: boolean?,
	isBold: boolean?,
	backgroundColor: Color3?,
	textColor: Color3?,
	textXAlignment: Enum.TextXAlignment?,
	onClick: (inputObject: InputObject, theButton: TextButton) -> (),
}

--a tile which as a row within it
export type rowTileSpec = {
	type: "rowTile",
	name: string,
	tileSpecs: { tileSpec },
	width: UDim?, --default to 1,0 and will be split normally by the child tileSpecs
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
}

export type stickyScrollingFrameType = {
	frame: Frame,
	addElement: (element: Instance, order: number, isSticky: boolean, stickTo: "top" | "bottom" | nil) -> Instance,
}

return {}
