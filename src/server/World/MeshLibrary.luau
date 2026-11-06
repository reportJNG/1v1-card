--!strict
-- Loads generated meshes (Config/HubLayout.Models, Config/WorldProps) once each with AssetService
-- and hands out clones. A failed load is reported once and never retried in a loop, so a bad id
-- can't stall the server. Server only (CreateMeshPartAsync yields).
local AssetService = game:GetService("AssetService")

export type ModelDef = {
	mesh: string,
	texture: string,
	size: { number }, -- native size in studs at scale 1
	note: string,
}

local MeshLibrary = {}

local templates: { [string]: MeshPart | false } = {}

local function template(key: string, def: ModelDef): MeshPart?
	local cached = templates[key]
	if cached == false then
		return nil
	elseif cached ~= nil then
		return cached :: MeshPart
	end
	local ok, mesh = pcall(function()
		return AssetService:CreateMeshPartAsync(def.mesh)
	end)
	if not ok or mesh == nil then
		warn(`[MeshLibrary] could not load mesh for {key}: {mesh}`)
		templates[key] = false
		return nil
	end
	local mp = mesh :: MeshPart
	mp.TextureID = def.texture
	mp.Anchored = true
	mp.Name = key
	templates[key] = mp
	return mp
end

-- A clone of `key` scaled by `scale`, standing with its base at `base` and turned `rotY` degrees.
-- Returns nil if the mesh could not be loaded.
function MeshLibrary.place(
	key: string,
	def: ModelDef,
	base: Vector3,
	rotY: number?,
	scale: number?
): MeshPart?
	local t = template(key, def)
	if t == nil then
		return nil
	end
	local size = Vector3.new(def.size[1], def.size[2], def.size[3]) * (scale or 1)
	local m = t:Clone()
	m.Size = size
	m.CFrame = CFrame.new(base + Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, math.rad(rotY or 0), 0)
	return m
end

return MeshLibrary
