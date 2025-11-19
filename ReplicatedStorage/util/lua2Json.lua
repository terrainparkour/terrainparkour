--!strict
-- rojo/ReplicatedStorage/util/lua2Json.lua
-- Converts serialized tables into Luau values and back for persistence.
-- Includes self-test coverage to guard regressions.

local config = require(game.ReplicatedStorage.config)

type Module = {
	StringTable2Lua: (data: any) -> any,
	Lua2StringTable: (data: any) -> any,
}

local module: Module = {} :: Module

-- Module internals
local function table_eq(table1, table2)
	local avoid_loops = {}
	local function recurse(t1, t2)
		-- compare value types
		local t1type = typeof(t1)
		local t2type = typeof(t2)
		if t1type ~= t2type then
			return false
		end
		-- Base case: compare simple values
		if t1type ~= "table" then
			return t1 == t2
		end
		-- Now, on to tables.
		-- First, let's avoid looping forever.
		if avoid_loops[t1] then
			return avoid_loops[t1] == t2
		end
		avoid_loops[t1] = t2
		-- Copy keys from t2
		local t2keys: { [any]: boolean } = {}
		local t2tablekeys: { any } = {}
		for k, _ in pairs(t2) do
			if typeof(k) == "table" then
				table.insert(t2tablekeys, k)
			end
			t2keys[k] = true
		end
		-- Let's iterate keys from t1
		for k1, v1 in pairs(t1) do
			local v2 = t2[k1]
			if typeof(k1) == "table" then
				-- if key is a table, we need to find an equivalent one.
				local ok = false
				for i, tk in ipairs(t2tablekeys) do
					if table_eq(k1, tk) and recurse(v1, t2[tk]) then
						table.remove(t2tablekeys, i)
						t2keys[tk] = nil
						ok = true
						break
					end
				end
				if not ok then
					return false
				end
			else
				-- t1 has a key which t2 doesn't have, fail.
				if v2 == nil then
					return false
				end
				t2keys[k1] = nil
				if not recurse(v1, v2) then
					return false
				end
			end
		end
		-- if t2 has a key which t1 doesn't have, fail.
		if next(t2keys) then
			return false
		end
		return true
	end
	return recurse(table1, table2)
end

local function convertStringTableToLua(data: any): any
	if typeof(data) ~= "table" then
		return data
	end

	-- now we check to see if there is a type inside here. If so it means
	-- we have to recreate the lua object of that type and then assign the values based
	-- on the keys to the table.
	local dataTable = data :: { [any]: any }
	local itemTypeValue = dataTable.type :: string?
	if itemTypeValue then
		if itemTypeValue == "Vector3" then
			local xValue = dataTable.x
			local yValue = dataTable.y
			local zValue = dataTable.z
			if typeof(xValue) ~= "number" or typeof(yValue) ~= "number" or typeof(zValue) ~= "number" then
				error("Vector3 serialization missing numeric components")
			end
			return (Vector3.new(xValue, yValue, zValue)) :: any
		elseif itemTypeValue == "Vector2" then
			local xValue = dataTable.x
			local yValue = dataTable.y
			if typeof(xValue) ~= "number" or typeof(yValue) ~= "number" then
				error("Vector2 serialization missing numeric components")
			end
			return (Vector2.new(xValue, yValue)) :: any
		elseif itemTypeValue == "Color3" then
			local rValue = dataTable.r
			local gValue = dataTable.g
			local bValue = dataTable.b
			if typeof(rValue) ~= "number" or typeof(gValue) ~= "number" or typeof(bValue) ~= "number" then
				error("Color3 serialization missing numeric components")
			end
			local colorComponents = { rValue, gValue, bValue }
			local colorConstructor = (Color3 :: any).new
			return colorConstructor(
				math.clamp(colorComponents[1], 0, 1),
				math.clamp(colorComponents[2], 0, 1),
				math.clamp(colorComponents[3], 0, 1)
			)
		elseif itemTypeValue == "UDim2" then
			local xScale = dataTable.xScale
			local xOffset = dataTable.xOffset
			local yScale = dataTable.yScale
			local yOffset = dataTable.yOffset
			if
				typeof(xScale) ~= "number"
				or typeof(xOffset) ~= "number"
				or typeof(yScale) ~= "number"
				or typeof(yOffset) ~= "number"
			then
				error("UDim2 serialization missing numeric components")
			end
			return (UDim2.new(xScale, xOffset, yScale, yOffset)) :: any
		elseif itemTypeValue == "EnumItem" then
			local enumType = dataTable.enumType
			local enumValue = dataTable.value
			if typeof(enumType) ~= "string" or typeof(enumValue) ~= "string" then
				error("EnumItem serialization missing enum type or value")
			end
			local enumContainer = Enum[enumType]
			if not enumContainer then
				error(string.format("unknown enum type: %s", enumType))
			end
			local enumItem = enumContainer[enumValue]
			if not enumItem then
				error(string.format("unknown enum value %s for enum %s", enumValue, enumType))
			end
			return enumItem :: any
		elseif itemTypeValue == "Enum" then
			local enumType = dataTable.enumType
			if typeof(enumType) ~= "string" then
				error("Enum serialization missing enum type")
			end
			local enumObject = Enum[enumType]
			if not enumObject then
				error(string.format("unknown enum type: %s", enumType))
			end
			return enumObject :: any
		elseif itemTypeValue == "CFrame" then
			local componentsValue = dataTable.components
			if typeof(componentsValue) ~= "table" then
				error("CFrame serialization missing components")
			end
			local componentNumbers: { number } = {}
			for index, value in ipairs(componentsValue :: { any }) do
				if typeof(value) ~= "number" then
					error(string.format("CFrame component %d is not a number", index))
				end
				componentNumbers[index] = value
			end
			return (CFrame.new(table.unpack(componentNumbers))) :: any
		else
			error(string.format("unknown type found: %s", itemTypeValue))
		end
	end

	local res: { [any]: any } = {}
	for a, b in pairs(dataTable) do
		res[a] = convertStringTableToLua(b)
	end
	return res
end

local function convertLuaToStringTable(data: any): any
	if typeof(data) == "table" then
		local newData: { [any]: any } = {}
		for k, v in pairs(data) do
			newData[k] = convertLuaToStringTable(v)
		end
		return newData
	elseif typeof(data) == "Vector3" then
		return {
			type = "Vector3",
			x = data.X,
			y = data.Y,
			z = data.Z,
		} :: any
	elseif typeof(data) == "Vector2" then
		return {
			type = "Vector2",
			x = data.X,
			y = data.Y,
		} :: any
	elseif typeof(data) == "Color3" then
		return {
			type = "Color3",
			r = data.R,
			g = data.G,
			b = data.B,
		} :: any
	elseif typeof(data) == "UDim2" then
		return {
			type = "UDim2",
			xScale = data.X.Scale,
			xOffset = data.X.Offset,
			yScale = data.Y.Scale,
			yOffset = data.Y.Offset,
		} :: any
	elseif typeof(data) == "Enum" then
		local enumString = tostring(data)
		local match = string.match(enumString, "^Enum%.(.+)$")
		local enumTypeName = match or enumString
		return {
			type = "Enum",
			enumType = enumTypeName,
		} :: any
	elseif typeof(data) == "EnumItem" then
		local enumItem: EnumItem = data
		local enumItemString = tostring(enumItem)
		local itemNameMatch = string.match(enumItemString, "^Enum%.[^.]+%.(.+)$")
		local itemName = itemNameMatch or enumItemString
		return {
			type = "EnumItem",
			enumType = tostring(enumItem.EnumType),
			value = itemName,
		} :: any
	elseif typeof(data) == "boolean" then
		return data
	elseif typeof(data) == "string" or typeof(data) == "number" then
		return data
	elseif typeof(data) == "CFrame" then
		return {
			type = "CFrame",
			components = { data:GetComponents() },
		} :: any
	else
		warn(string.format("Unhandled data: %s", tostring(data)))
		warn(string.format("Type: %s", typeof(data)))
		return data
	end
end

type DiagnosticSample = {
	name: string,
	value: any,
}

local DIAGNOSTIC_INTERVAL_SECONDS = 300
local diagnosticsRunning = false
local lastDiagnosticRunClock = 0

local diagnosticSamples: { DiagnosticSample } = {
	{
		name = "VectorPayload",
		value = {
			position = Vector3.new(124.5, 8, -32.25),
			lookOffset = Vector2.new(0.25, -0.75),
			tint = Color3.fromRGB(245, 85, 35),
			bounds = UDim2.new(0, 320, 0, 120),
		},
	},
	{
		name = "LeaderboardRow",
		value = {
			userId = 123456,
			username = "Trailblazer",
			stats = {
				runs = 42,
				bestTimeMs = 32567,
				averageSpeed = 18.4,
			},
			route = {
				Vector3.new(1, 2, 3),
				Vector3.new(4, 5.5, 6),
				Vector3.new(7.25, 8, 9),
			},
			cameraFrame = CFrame.new(12, 6, -14),
		},
	},
	{
		name = "EnumCoverage",
		value = {
			alignmentEnum = Enum.VerticalAlignment,
			alignment = Enum.VerticalAlignment.Center,
			material = Enum.Material.Neon,
			inputState = Enum.UserInputState.End,
		},
	},
	{
		name = "UiLayout",
		value = {
			size = UDim2.new(0.5, 10, 0, 96),
			padding = Vector2.new(12, 18),
			colors = {
				primary = Color3.fromRGB(25, 170, 255),
				secondary = Color3.fromRGB(255, 200, 120),
			},
			isVisible = true,
		},
	},
	{
		name = "NestedScenario",
		value = {
			checkpoints = {
				{ index = 1, cframe = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(15), 0) },
				{ index = 2, cframe = CFrame.new(10, 5, -3) },
			},
			metadata = {
				creatorUserId = 481516,
				tags = { "speedrun", "marathon" },
				preferredMaterials = { Enum.Material.Ice, Enum.Material.Grass },
			},
		},
	},
	{
		name = "SettingsPayload",
		value = {
			name = "signHighlighting",
			kind = "LUA",
			booleanPreference = false,
			luaValue = {
				enabled = true,
				thresholds = { warm = 0.25, hot = 0.75 },
				colors = {
					Color3.fromRGB(255, 90, 90),
					Color3.fromRGB(255, 200, 90),
				},
			},
		},
	},
}

local function valuesMatch(a: any, b: any): boolean
	local typeA = typeof(a)
	local typeB = typeof(b)
	if typeA ~= typeB then
		return false
	end

	if typeA == "table" then
		return table_eq(a, b)
	end

	return a == b
end

local function runDiagnosticSample(sample: DiagnosticSample): (boolean, string?)
	local ok, result = pcall(function()
		local serialized = convertLuaToStringTable(sample.value)
		local roundTrip = convertStringTableToLua(serialized)
		if not valuesMatch(sample.value, roundTrip) then
			return { success = false, reason = "roundtrip mismatch" }
		end

		local reSerialized = convertLuaToStringTable(roundTrip)
		if not table_eq(serialized, reSerialized) then
			return { success = false, reason = "re-serialization mismatch" }
		end

		return { success = true, reason = "" }
	end)

	if not ok then
		return false, tostring(result)
	end

	local resultTable = result :: { success: boolean, reason: string? }
	if resultTable.success then
		return true, nil
	end

	return false, resultTable.reason
end

local function maybeRunDiagnostics()
	if not config.ENABLE_LUA2JSON_DIAGNOSTICS then
		return
	end

	if diagnosticsRunning then
		return
	end

	local now = os.clock()
	if lastDiagnosticRunClock > 0 and now - lastDiagnosticRunClock < DIAGNOSTIC_INTERVAL_SECONDS then
		return
	end

	diagnosticsRunning = true
	lastDiagnosticRunClock = now

	local runOk, runResult = pcall(function()
		local sampleCount = #diagnosticSamples
		local successCount = 0
		local startTime = os.clock()

		for _, sample in ipairs(diagnosticSamples) do
			local sampleOk, reason = runDiagnosticSample(sample)
			if sampleOk then
				successCount += 1
			else
				warn(
					string.format(
						"[lua2Json diagnostics] sample '%s' failed: %s",
						sample.name,
						reason or "unknown failure"
					)
				)
			end
		end

		local elapsed = os.clock() - startTime
		return {
			elapsed = elapsed,
			successCount = successCount,
			sampleCount = sampleCount,
		}
	end)

	diagnosticsRunning = false

	if not runOk then
		warn(string.format("[lua2Json diagnostics] diagnostics aborted: %s", tostring(runResult)))
		return
	end

	local resultTable = runResult :: { elapsed: number, successCount: number, sampleCount: number }
	local sampleCount = resultTable.sampleCount
	local successRate = if sampleCount > 0 then resultTable.successCount / sampleCount else 0

	warn(
		string.format(
			"[lua2Json diagnostics] ran %d samples in %.3fs (%.1f%% success)",
			sampleCount,
			resultTable.elapsed,
			successRate * 100
		)
	)
end

local function stringTable2Lua(data: any): any
	maybeRunDiagnostics()
	return convertStringTableToLua(data)
end

local function lua2StringTable(data: any): any
	maybeRunDiagnostics()
	return convertLuaToStringTable(data)
end

module.StringTable2Lua = stringTable2Lua
module.Lua2StringTable = lua2StringTable

local function doTestOfLua2StringEtc()
	local test1string = {
		type = "Vector3",
		x = 1,
		y = 2,
		z = 3,
	}

	local t1_lua = module.StringTable2Lua(test1string)
	local t1_string = module.Lua2StringTable(t1_lua)
	local compare1a = table_eq(test1string, t1_string)
	local compare1b = table_eq(t1_string, test1string)
	if not compare1a or not compare1b then
		error("test1string failed")
	end

	-------------------------------------------------------------

	local test2lua = Vector3.new(1, 2, 3)
	local t2_string = module.Lua2StringTable(test2lua)
	local t2_lua = module.StringTable2Lua(t2_string)
	local compare2a = table_eq(t2_lua, test2lua)
	local compare2b = table_eq(test2lua, t2_lua)
	if not compare2a or not compare2b then
		error("test2lua failed")
	end

	-------------------------------------------------------------

	local test3lua = {
		vector3s = Vector3.new(1, 2, 3),
		vector2s = Vector2.new(4, 5),
		color3s = Color3.fromRGB(6, 7, 8),
		solution = UDim2.new(9, 10, 11, 12),
		prohibitedValues = { a = Enum.VerticalAlignment.Top, b = Enum.HorizontalAlignment.Center },
		prohibitedValues2 = {
			a = Enum.VerticalAlignment.Top,
			b = Enum.HorizontalAlignment.Center,
			cc = {
				a = 1,
				b = 2,
				c = 3,
				d = Vector3.new(0, 0, 3),
			},
		},
	}

	local t3_string = module.Lua2StringTable(test3lua)
	local t3_lua = module.StringTable2Lua(t3_string)
	local compare3 = table_eq(test3lua, t3_lua)
	local compare3r = table_eq(t3_lua, test3lua)
	if not compare3 or not compare3r then
		error("test3lua failed")
	end
end

doTestOfLua2StringEtc()

return module
