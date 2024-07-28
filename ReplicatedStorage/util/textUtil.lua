--!strict

--the ACTUAL first import - do not include the annotater setup here.

local module = {}

module.stringJoin = function(sep: string, input: { string | number }): string
	local res = ""
	local ii = 1
	for _, el in ipairs(input) do
		res = res .. tostring(el)
		if ii == #input then
			continue
		end
		res = res .. sep
		ii += 1
	end
	return res
end

--cannot be ideal - but this gets you the string version of something like "the first character of a string"
module.getFirstCodepointAsString = function(input: string): string
	for position, codepoint in utf8.codes(input) do
		-- body
		return utf8.char(codepoint)
	end
	error("no such first letter.")
end

module.stringSplit = function(str: string, pat: string)
	local t = {}
	local fpat = "(.-)" .. pat
	local last_end = 1
	local s, e: number?, cap: string = str:find(fpat, 1)

	while s do
		if s ~= 1 or cap ~= "" then
			table.insert(t, cap)
		end
		last_end = e + 1
		s, e, cap = str:find(fpat, last_end)
	end
	if last_end <= #str then
		cap = str:sub(last_end)
		table.insert(t, cap)
	end
	return t
end

module.getStringifiedTable = function(tbl: any): { [string]: string }
	local res = {}
	for k, v in pairs(tbl) do
		res[k] = tostring(v)
	end
	return res
end

module.table_print = function(tt: any, inputIndent: number?, done: any): string
	done = done or {}
	local indent: number = inputIndent or 0

	local sb = {}
	for key, value in pairs(tt) do
		table.insert(sb, string.rep(" ", indent)) -- indent it
		if type(value) == "table" and not done[value] then
			done[value] = true
			table.insert(sb, "{\n")
			table.insert(sb, module.table_print(value, indent + 2, done))
			table.insert(sb, string.rep(" ", indent)) -- indent it
			table.insert(sb, "}\n")
		elseif "number" == type(key) then
			table.insert(sb, string.format('"%s"\n', tostring(value)))
		else
			table.insert(sb, string.format('%s = "%s"\n', tostring(key), tostring(value)))
		end
	end
	return table.concat(sb)
end

module.serializeTable = function(tbl: any)
	if "nil" == type(tbl) then
		return tostring(nil)
	elseif "table" == type(tbl) then
		return module.table_print(tbl, nil, nil)
	elseif "string" == type(tbl) then
		return tbl
	else
		return tostring(tbl)
	end
end

--coalesce remaining string keys >=start into a space-separated single string.
module.coalesceFrom = function(tbl: any, start: number): string
	local combined = ""
	for index, el in ipairs(tbl) do
		if index < start then
			continue
		end
		if el == nil then
			continue
		end
		if combined == "" then
			combined = el
		else
			combined = combined .. " " .. el
		end
	end
	return combined
end

return module
