--!strict
-- One-time sign data logger
-- Run this on server to print out all sign properties for backup/archival.
-- Later, capture output and store as a Lua file.

local annotater = require(game.ReplicatedStorage.util.annotater)
local _annotate = annotater.getAnnotater(script)

local enums = require(game.ReplicatedStorage.util.enums)

local module = {}

local hasRun = false

local function vector3ToString(v: Vector3): string
	return string.format("Vector3.new(%.4f, %.4f, %.4f)", v.X, v.Y, v.Z)
end

local function color3ToString(c: Color3): string
	return string.format("Color3.new(%.6f, %.6f, %.6f)", c.R, c.G, c.B)
end

local function getShapeName(part: Part): string
	local shape = part.Shape
	if shape == Enum.PartType.Block then
		return "Block"
	elseif shape == Enum.PartType.Ball then
		return "Ball"
	elseif shape == Enum.PartType.Cylinder then
		return "Cylinder"
	elseif shape == Enum.PartType.Wedge then
		return "Wedge"
	elseif shape == Enum.PartType.CornerWedge then
		return "CornerWedge"
	else
		return "Unknown"
	end
end

local function getMaterialName(mat: Enum.Material): string
	return tostring(mat):gsub("Enum.Material.", "")
end

module.LogAllSignData = function()
	-- Allow multiple runs since this is now triggered on-demand from admin panel
	hasRun = true

	local signFolder = game.Workspace:FindFirstChild("Signs")
	if signFolder == nil then
		warn("[SignDataLog] No sign folder found")
		return
	end

	local signs: { Instance } = signFolder:GetChildren()
	local signCount = 0

	print("")
	print("============================================")
	print("SIGN DATA EXPORT START")
	print("============================================")
	print("-- Format: Lua table for archival")
	print("-- Generated at: " .. os.date("%Y-%m-%d %H:%M:%S"))
	print("local signData = {")

	for _, signInstance: Instance in ipairs(signs) do
		if not signInstance:IsA("BasePart") then
			continue
		end

		local sign: BasePart = signInstance :: BasePart
		local signName = sign.Name
		local signId = enums.name2signId[signName]

		signCount += 1

		-- Escape sign name for Lua string (handle special chars)
		local escapedName = signName:gsub("\\", "\\\\"):gsub('"', '\\"')

		print(string.format('\t["%s"] = {', escapedName))
		print(string.format("\t\tsignId = %s,", signId and tostring(signId) or "nil"))
		print(string.format("\t\tposition = %s,", vector3ToString(sign.Position)))
		print(string.format("\t\torientation = %s,", vector3ToString(sign.Orientation)))
		print(string.format("\t\tsize = %s,", vector3ToString(sign.Size)))
		print(string.format("\t\tcolor = %s,", color3ToString(sign.Color)))
		print(string.format('\t\tmaterial = "%s",', getMaterialName(sign.Material)))
		print(string.format("\t\ttransparency = %.2f,", sign.Transparency))
		print(string.format("\t\tanchored = %s,", tostring(sign.Anchored)))
		print(string.format("\t\tcanCollide = %s,", tostring(sign.CanCollide)))
		print(string.format("\t\tcanTouch = %s,", tostring(sign.CanTouch)))
		print(string.format("\t\tcanQuery = %s,", tostring(sign.CanQuery)))
		print(string.format("\t\tcastShadow = %s,", tostring(sign.CastShadow)))

		-- Part-specific properties
		if sign:IsA("Part") then
			local part = sign :: Part
			print(string.format('\t\tshape = "%s",', getShapeName(part)))
		elseif sign:IsA("MeshPart") then
			local meshPart = sign :: MeshPart
			print('\t\tisMeshPart = true,')
			if meshPart.MeshId ~= "" then
				print(string.format('\t\tmeshId = "%s",', meshPart.MeshId))
			end
		end

		-- Additional useful properties
		print(string.format("\t\treflectance = %.2f,", sign.Reflectance))

		-- CFrame for full transform (useful for weird orientations)
		local cf = sign.CFrame
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
		print(
			string.format(
				"\t\tcframe = CFrame.new(%.4f, %.4f, %.4f, %.6f, %.6f, %.6f, %.6f, %.6f, %.6f, %.6f, %.6f, %.6f),",
				x,
				y,
				z,
				r00,
				r01,
				r02,
				r10,
				r11,
				r12,
				r20,
				r21,
				r22
			)
		)

		print("\t},")
	end

	print("}")
	print("============================================")
	print(string.format("SIGN DATA EXPORT END - %d signs logged", signCount))
	print("============================================")
	print("")
end

_annotate("end")
return module

