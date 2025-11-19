--!strict
-- rojo/ReplicatedStorage/util/lua2JsonTests.lua
-- Validates lua2Json conversions across representative Roblox data.
-- Exposes a suite runner consumed by diagnostics to track regressions.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local HttpService = game:GetService("HttpService")

local lua2Json = require(game.ReplicatedStorage.util.lua2Json)

type FailureDetail = {
	name: string,
	message: string,
}

type SuiteResult = {
	totalCount: number,
	successCount: number,
	failureDetails: { FailureDetail },
}

type Module = {
	RunSuite: () -> SuiteResult,
}

local module: Module = {} :: Module

local FLOAT_TOLERANCE = 1e-5

local function numbersClose(lhs: number, rhs: number): boolean
	if lhs == rhs then
		return true
	end
	return math.abs(lhs - rhs) <= FLOAT_TOLERANCE
end

local function deepEqual(lhs: any, rhs: any, forwardVisited: { [any]: any }?, reverseVisited: { [any]: any }?): boolean
	if lhs == rhs then
		return true
	end

	local lhsType = typeof(lhs)
	local rhsType = typeof(rhs)
	if lhsType ~= rhsType then
		return false
	end

	if lhsType == "number" then
		return numbersClose(lhs :: number, rhs :: number)
	end

	if lhsType ~= "table" then
		return false
	end

	local forward = forwardVisited or {}
	local reverse = reverseVisited or {}
	local lhsTable = lhs :: { [any]: any }
	local rhsTable = rhs :: { [any]: any }

	if forward[lhsTable] then
		return forward[lhsTable] == rhsTable
	end
	if reverse[rhsTable] then
		return reverse[rhsTable] == lhsTable
	end

	forward[lhsTable] = rhsTable
	reverse[rhsTable] = lhsTable

	for key, value in pairs(lhsTable) do
		if not deepEqual(value, rhsTable[key], forward, reverse) then
			return false
		end
	end

	for key, _ in pairs(rhsTable) do
		if lhsTable[key] == nil then
			return false
		end
	end

	return true
end

local function describeValue(value: any): string
	if typeof(value) == "table" then
		local okRaw, encodedRaw = pcall(function()
			return HttpService:JSONEncode(value)
		end)
		if okRaw then
			return encodedRaw
		end
	end

	local okSerialized, serialized = pcall(lua2Json.Lua2StringTable, value)
	if okSerialized then
		local okEncoded, encoded = pcall(function()
			return HttpService:JSONEncode(serialized)
		end)
		if okEncoded then
			return encoded
		end
	end

	return tostring(value)
end

type RoundTripCase = {
	name: string,
	value: any,
}

type SerializedCase = {
	name: string,
	serializedValue: { [any]: any },
	expectedValue: any,
}

local COMPLEX_CFRAME = CFrame.new(12.75, -48.125, 5.5)
	* CFrame.Angles(math.rad(45), math.rad(-30), math.rad(15))
local COMPONENTS_CFRAME = CFrame.new(2, 4, -6) * CFrame.Angles(math.rad(10), math.rad(20), math.rad(30))
local COMPONENTS_TABLE = { COMPONENTS_CFRAME:GetComponents() }

local roundTripCases: { RoundTripCase } = {
	{ name = "NumberValue", value = 42.5 },
	{ name = "NegativeNumber", value = -13 },
	{ name = "BooleanTrue", value = true },
	{ name = "BooleanFalse", value = false },
	{ name = "SimpleString", value = "terrain parkour rocks" },
	{ name = "UTF8String", value = utf8.char(0x20AC) .. " sample" },
	{ name = "Vector3Value", value = Vector3.new(1024.25, -512.5, 0.03125) },
	{ name = "Vector2Value", value = Vector2.new(1920, 1080) },
	{ name = "Color3Value", value = Color3.fromRGB(128, 64, 255) },
	{ name = "UDim2Value", value = UDim2.new(0.5, -4, 1.25, 12) },
	{ name = "EnumType", value = Enum.VerticalAlignment },
	{ name = "EnumItem", value = Enum.Material.Asphalt },
	{ name = "CFrameValue", value = COMPLEX_CFRAME },
	{
		name = "NestedGameplayState",
		value = {
			playerId = 184467,
			active = true,
			stats = {
				bestMs = 48234,
				lastRun = os.time(),
				position = Vector3.new(18, 6, -12),
				viewFrame = UDim2.new(0, 280, 0, 120),
				colors = {
					primary = Color3.fromRGB(255, 185, 0),
					secondary = Color3.fromRGB(32, 90, 255),
				},
				teleportGate = COMPONENTS_CFRAME,
			},
			tags = { "Speedrun", "Verified", "DailyChallenge" },
			approvers = {
				{ username = "Shedletsky", vote = Enum.VerticalAlignment.Top },
				{ username = "StickMasterLuke", vote = Enum.VerticalAlignment.Center },
			},
		},
	},
	{
		name = "ArrayOfEnumItems",
		value = { Enum.Material.Granite, Enum.Material.Ice, Enum.Material.WoodPlanks },
	},
	{
		name = "HybridDictionaryList",
		value = {
			["spawnPositions"] = {
				Vector3.new(0, 3, 0),
				Vector3.new(12, 3, -8),
			},
			["uiLayout"] = {
				padding = UDim2.new(0, 6, 0, 6),
				order = { "title", "details", "cta" },
			},
			["checkpointSequence"] = {
				[1] = {
					signName = "Alpha",
					cframe = CFrame.new(3, 4, 5),
				},
				[2] = {
					signName = "Beta",
					cframe = CFrame.new(13, 6, -15),
				},
			},
		},
	},
}

local serializedCases: { SerializedCase } = {
	{
		name = "SerializedVector3",
		serializedValue = { type = "Vector3", x = 1.5, y = -3.25, z = 9 },
		expectedValue = Vector3.new(1.5, -3.25, 9),
	},
	{
		name = "SerializedEnumItem",
		serializedValue = { type = "EnumItem", enumType = "VerticalAlignment", value = "Bottom" },
		expectedValue = Enum.VerticalAlignment.Bottom,
	},
	{
		name = "SerializedEnumType",
		serializedValue = { type = "Enum", enumType = "Material" },
		expectedValue = Enum.Material,
	},
	{
		name = "SerializedUDim2",
		serializedValue = {
			type = "UDim2",
			xScale = 0.25,
			xOffset = -12,
			yScale = 0,
			yOffset = 96,
		},
		expectedValue = UDim2.new(0.25, -12, 0, 96),
	},
	{
		name = "SerializedColor3",
		serializedValue = { type = "Color3", r = 0.25, g = 0.5, b = 0.75 },
		expectedValue = Color3.new(0.25, 0.5, 0.75),
	},
	{
		name = "SerializedCFrame",
		serializedValue = {
			type = "CFrame",
			components = COMPONENTS_TABLE,
		},
		expectedValue = COMPONENTS_CFRAME,
	},
	{
		name = "SerializedNestedTable",
		serializedValue = {
			inventory = {
				slot1 = { type = "EnumItem", enumType = "HumanoidRigType", value = "R15" },
				slot2 = { type = "Vector3", x = 5, y = 1, z = 2 },
			},
			settings = {
				volume = 0.75,
				display = {
					type = "UDim2",
					xScale = 0,
					xOffset = 320,
					yScale = 0,
					yOffset = 180,
				},
			},
		},
		expectedValue = {
			inventory = {
				slot1 = Enum.HumanoidRigType.R15,
				slot2 = Vector3.new(5, 1, 2),
			},
			settings = {
				volume = 0.75,
				display = UDim2.new(0, 320, 0, 180),
			},
		},
	},
}

local function runRoundTripCase(testCase: RoundTripCase): FailureDetail?
	local okSerialize, serialized = pcall(lua2Json.Lua2StringTable, testCase.value)
	if not okSerialize then
		return {
			name = testCase.name,
			message = string.format("Lua2StringTable error: %s", tostring(serialized)),
		}
	end

	local okParse, parsed = pcall(lua2Json.StringTable2Lua, serialized)
	if not okParse then
		return {
			name = testCase.name,
			message = string.format("StringTable2Lua error: %s", tostring(parsed)),
		}
	end

	if not deepEqual(testCase.value, parsed) then
		return {
			name = testCase.name,
			message = string.format(
				"Roundtrip mismatch expected=%s got=%s",
				describeValue(testCase.value),
				describeValue(parsed)
			),
		}
	end

	local okSerializeAgain, serializedAgain = pcall(lua2Json.Lua2StringTable, parsed)
	if not okSerializeAgain then
		return {
			name = testCase.name,
			message = string.format("Second Lua2StringTable error: %s", tostring(serializedAgain)),
		}
	end

	if not deepEqual(serialized, serializedAgain) then
		return {
			name = testCase.name,
			message = string.format(
				"Canonicalization mismatch expected=%s got=%s",
				describeValue(serialized),
				describeValue(serializedAgain)
			),
		}
	end

	return nil
end

local function runSerializedCase(testCase: SerializedCase): FailureDetail?
	local okParse, parsed = pcall(lua2Json.StringTable2Lua, testCase.serializedValue)
	if not okParse then
		return {
			name = testCase.name,
			message = string.format("StringTable2Lua error: %s", tostring(parsed)),
		}
	end

	if not deepEqual(parsed, testCase.expectedValue) then
		return {
			name = testCase.name,
			message = string.format(
				"Deserialization mismatch expected=%s got=%s",
				describeValue(testCase.expectedValue),
				describeValue(parsed)
			),
		}
	end

	return nil
end

function module.RunSuite(): SuiteResult
	local successCount = 0
	local totalCount = 0
	local failures: { FailureDetail } = {}

	for _, caseDef in ipairs(roundTripCases) do
		totalCount += 1
		local failure = runRoundTripCase(caseDef)
		if failure then
			table.insert(failures, failure)
		else
			successCount += 1
		end
	end

	for _, serializedCase in ipairs(serializedCases) do
		totalCount += 1
		local serializedFailure = runSerializedCase(serializedCase)
		if serializedFailure then
			table.insert(failures, serializedFailure)
		else
			successCount += 1
		end
	end

	return {
		totalCount = totalCount,
		successCount = successCount,
		failureDetails = failures,
	}
end

_annotate("end")
return module

