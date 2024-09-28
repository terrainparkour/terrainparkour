--!strict

-- lua2Json.lua
-- an even more special module.

local HttpService = game:GetService("HttpService")

local module = {}

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
		if type(t1) ~= "table" then
			return t1 == t2
		end
		-- Now, on to tables.
		-- First, let's avoid looping forever.
		if avoid_loops[t1] then
			return avoid_loops[t1] == t2
		end
		avoid_loops[t1] = t2
		-- Copy keys from t2
		local t2keys = {}
		local t2tablekeys = {}
		for k, _ in pairs(t2) do
			if type(k) == "table" then
				table.insert(t2tablekeys, k)
			end
			t2keys[k] = true
		end
		-- Let's iterate keys from t1
		for k1, v1 in pairs(t1) do
			local v2 = t2[k1]
			if type(k1) == "table" then
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

module.StringTable2Lua = function(data)
	local res = {}
	local theType = typeof(data)
	if theType == "table" then
		-- now we check to see if there is a type inside here. If so it means
		-- we have to recreate the lua object of that type and then assign the values based
		-- on the keys to the table.
		local itemType = data.type
		if itemType then
			if itemType == "Vector3" then
				return Vector3.new(data.x, data.y, data.z)
			elseif itemType == "Vector2" then
				return Vector2.new(data.x, data.y)
			elseif itemType == "Color3" then
				return Color3.new(data.r, data.g, data.b)
			elseif itemType == "UDim2" then
				return UDim2.new(data.xScale, data.xOffset, data.yScale, data.yOffset)
			elseif itemType == "EnumItem" then
				return Enum[data.enumType][data.value]
			elseif itemType == "CFrame" then
				return CFrame.new(unpack(data.components))
			else
				error(string.format("unknown type found: %s", itemType))
			end
		else
			for a, b in pairs(data) do
				res[a] = module.StringTable2Lua(b)
			end
			return res
		end
	else
		return data
		-- error("you sent in a non-table? " .. theType)
	end
end

module.Lua2StringTable = function(data: any)
	if typeof(data) == "table" then
		local newData = {}
		for k, v in pairs(data) do
			newData[k] = module.Lua2StringTable(v)
		end
		return newData
	elseif typeof(data) == "Vector3" then
		return {
			type = "Vector3",
			x = data.X,
			y = data.Y,
			z = data.Z,
		}
	elseif typeof(data) == "Vector2" then
		return {
			type = "Vector2",
			x = data.X,
			y = data.Y,
		}
	elseif typeof(data) == "Color3" then
		return {
			type = "Color3",
			r = data.R,
			g = data.G,
			b = data.B,
		}
	elseif typeof(data) == "UDim2" then
		return {
			type = "UDim2",
			xScale = data.X.Scale,
			xOffset = data.X.Offset,
			yScale = data.Y.Scale,
			yOffset = data.Y.Offset,
		}
	elseif typeof(data) == "Enum" then
		return {
			type = "Enum",
			enumType = tostring(data.EnumType),
			value = tostring(data),
		}
	elseif typeof(data) == "EnumItem" then
		return {
			type = "EnumItem",
			enumType = tostring(data.EnumType),
			value = data.Name,
		}
	elseif typeof(data) == "boolean" then
		return data
	elseif typeof(data) == "string" or typeof(data) == "number" then
		return data
	elseif typeof(data) == "CFrame" then
		return {
			type = "CFrame",
			components = {data:GetComponents()}
		}
	else
		warn(string.format("Unhandled data: %s", tostring(data)))
		warn(string.format("Type: %s", typeof(data)))
		return data
	end
end

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
		color3s = Color3.new(6, 7, 8),
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
