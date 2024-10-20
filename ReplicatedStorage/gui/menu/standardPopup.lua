--!strict

-- standardPopup: Module for creating standard popup windows
-- Used in both client and server scripts

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)
local tt = require(game.ReplicatedStorage.types.gametypes)
local LLMGeneratedUIFunctions = require(game.ReplicatedStorage.gui.menu.LLMGeneratedUIFunctions)

local module = {}

export type PopupConfig = {
	title: string,
	size: Vector2,
	parent: Instance,
	closeCallback: () -> (),
}

export type RowConfig = {
	type: "text" | "image" | "chipped" | "detail",
	data: any,
	color: Color3?,
	sizeProportion: number?,
}

function module.createPopup(config: PopupConfig): { [string]: any }
	local popup = LLMGeneratedUIFunctions.createFrame({
		Name = "StandardPopup",
		Size = UDim2.new(0, config.size.X, 0, config.size.Y),
		Position = UDim2.new(0.5, -config.size.X / 2, 0.5, -config.size.Y / 2),
		BackgroundColor3 = Color3.fromRGB(40, 40, 40),
		Parent = config.parent,
	})

	local title = LLMGeneratedUIFunctions.createTextLabel({
		Name = "Title",
		Text = config.title,
		Size = UDim2.new(1, -20, 0, 40),
		Position = UDim2.new(0, 10, 0, 10),
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 24,
		Font = Enum.Font.SourceSansBold,
		Parent = popup,
	})

	local closeButton = LLMGeneratedUIFunctions.createTextButton({
		Name = "CloseButton",
		Text = "X",
		Size = UDim2.new(0, 30, 0, 30),
		Position = UDim2.new(1, -40, 0, 10),
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = Color3.fromRGB(200, 0, 0),
		Parent = popup,
	})
	closeButton.Activated:Connect(config.closeCallback)

	local contentFrame = LLMGeneratedUIFunctions.createScrollingFrame({
		Name = "ContentFrame",
		Size = UDim2.new(1, -20, 1, -60),
		Position = UDim2.new(0, 10, 0, 50),
		BackgroundTransparency = 1,
		Parent = popup,
	})

	LLMGeneratedUIFunctions.createLayout("UIListLayout", contentFrame, {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 5),
	})

	return {
		Popup = popup,
		ContentFrame = contentFrame,
	}
end

function module.addRow(parent: Instance, rowConfig: RowConfig): Instance
	local row

	if rowConfig.type == "text" then
		row = LLMGeneratedUIFunctions.createTextLabel({
			Text = rowConfig.data,
			Size = UDim2.new(1, 0, 0, 30),
			TextColor3 = rowConfig.color or Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			Parent = parent,
		})
	elseif rowConfig.type == "image" then
		row = LLMGeneratedUIFunctions.createImageLabel({
			Image = rowConfig.data,
			Size = UDim2.new(0, 30, 0, 30),
			BackgroundTransparency = 1,
			Parent = parent,
		})
	elseif rowConfig.type == "chipped" then
		row = LLMGeneratedUIFunctions.createChippedRow(rowConfig.data, {
			Size = UDim2.new(1, 0, 0, 30),
			Parent = parent,
		})
	end

	if rowConfig.sizeProportion then
		row.Size = UDim2.new(rowConfig.sizeProportion, 0, 0, 30)
	end

	return row
end

_annotate("end")
return module
