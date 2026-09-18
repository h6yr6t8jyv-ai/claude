--!strict
-- Procedurally builds a starter map: a central plaza, the DupeDeal warehouse
-- (shop), the ShipFast Customs Dock (shipping/customs), and the ThriftLyst
-- Bazaar (resale market), connected by paths. It's a clean, colour-coded
-- low-poly layout meant as a strong starting point — for a truly "viral"
-- looking map, keep polishing it visually in Studio (terrain, trees, extra
-- lighting/decals) on top of this generated base.
--
-- Runs once per server start and rebuilds deterministically, so it's always
-- safe to re-run (e.g. after editing this script) without leaving duplicates.

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local ROOT_NAME = "GeneratedMap"

local existing = Workspace:FindFirstChild(ROOT_NAME)
if existing then
	existing:Destroy()
end

local root = Instance.new("Folder")
root.Name = ROOT_NAME
root.Parent = Workspace

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = props.Size
	p.CFrame = props.CFrame or CFrame.new(props.Position or Vector3.zero)
	p.Color = props.Color or Color3.fromRGB(200, 200, 200)
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Name = props.Name or "Part"
	p.Parent = props.Parent or root
	return p
end

local function sign(props)
	local billboard = Instance.new("Part")
	billboard.Anchored = true
	billboard.Size = props.Size or Vector3.new(0.5, 6, 16)
	billboard.CFrame = props.CFrame
	billboard.Color = Color3.fromRGB(10, 10, 14)
	billboard.Material = Enum.Material.Neon
	billboard.Name = (props.Text or "Sign") .. "_Sign"
	billboard.Parent = props.Parent or root

	local gui = Instance.new("SurfaceGui")
	gui.Face = props.Face or Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.PixelsPerStud = 36
	gui.Parent = billboard

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = props.Text or ""
	label.TextColor3 = props.TextColor or Color3.fromRGB(255, 255, 255)
	label.Parent = gui

	return billboard
end

--------------------------------------------------------------------------
-- Ground
--------------------------------------------------------------------------
part({
	Name = "Baseplate",
	Size = Vector3.new(400, 4, 400),
	Position = Vector3.new(0, -2, 0),
	Color = Color3.fromRGB(38, 38, 48),
	Material = Enum.Material.Concrete,
})

--------------------------------------------------------------------------
-- Central plaza
--------------------------------------------------------------------------
local plaza = Instance.new("Folder")
plaza.Name = "Plaza"
plaza.Parent = root

part({
	Name = "PlazaFloor",
	Size = Vector3.new(70, 0.4, 70),
	Position = Vector3.new(0, 0.2, 0),
	Color = Color3.fromRGB(60, 58, 70),
	Material = Enum.Material.SmoothPlastic,
	Parent = plaza,
})

-- Spawn ring
for i = 1, 6 do
	local angle = (i / 6) * math.pi * 2
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(math.cos(angle) * 12, 1, math.sin(angle) * 12)
	spawn.Color = Color3.fromRGB(255, 62, 165)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.3
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Duration = 0
	spawn.Name = "PlazaSpawn"
	spawn.Parent = plaza
end

sign({
	Text = "REPLICA RUSH",
	CFrame = CFrame.new(0, 14, -30) * CFrame.Angles(0, math.pi, 0),
	Size = Vector3.new(0.5, 8, 34),
	TextColor = Color3.fromRGB(255, 62, 165),
	Parent = plaza,
})

part({
	Name = "PlazaCenterpiece",
	Size = Vector3.new(4, 10, 4),
	Position = Vector3.new(0, 5, 0),
	Color = Color3.fromRGB(255, 210, 70),
	Material = Enum.Material.Neon,
	Parent = plaza,
})

--------------------------------------------------------------------------
-- Helper: a simple rectangular "building" with an open front doorway
--------------------------------------------------------------------------
local function buildBox(name, center, size, wallColor, roofColor, parentFolder)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parentFolder

	local halfX, halfY, halfZ = size.X / 2, size.Y / 2, size.Z / 2

	part({ Name = "Floor", Size = Vector3.new(size.X, 1, size.Z), Position = center + Vector3.new(0, 0.5, 0), Color = wallColor:Lerp(Color3.new(0, 0, 0), 0.3), Parent = folder })
	part({ Name = "Back", Size = Vector3.new(size.X, size.Y, 1), Position = center + Vector3.new(0, halfY, halfZ), Color = wallColor, Parent = folder })
	part({ Name = "Left", Size = Vector3.new(1, size.Y, size.Z), Position = center + Vector3.new(-halfX, halfY, 0), Color = wallColor, Parent = folder })
	part({ Name = "Right", Size = Vector3.new(1, size.Y, size.Z), Position = center + Vector3.new(halfX, halfY, 0), Color = wallColor, Parent = folder })
	part({ Name = "Roof", Size = Vector3.new(size.X, 1, size.Z), Position = center + Vector3.new(0, size.Y + 0.5, 0), Color = roofColor, Parent = folder })
	-- Front wall with a doorway gap (two side strips instead of one full wall)
	local doorWidth = math.min(10, size.X * 0.4)
	local sideWidth = (size.X - doorWidth) / 2
	part({ Name = "FrontLeft", Size = Vector3.new(sideWidth, size.Y, 1), Position = center + Vector3.new(-(doorWidth / 2 + sideWidth / 2), halfY, -halfZ), Color = wallColor, Parent = folder })
	part({ Name = "FrontRight", Size = Vector3.new(sideWidth, size.Y, 1), Position = center + Vector3.new((doorWidth / 2 + sideWidth / 2), halfY, -halfZ), Color = wallColor, Parent = folder })

	return folder
end

--------------------------------------------------------------------------
-- DupeDeal Warehouse (shop) — north of plaza
--------------------------------------------------------------------------
local shop = buildBox("DupeDealWarehouse", Vector3.new(0, 0, -70), Vector3.new(46, 16, 34), Color3.fromRGB(40, 40, 56), Color3.fromRGB(255, 62, 165), root)
sign({ Text = "DUPEDEAL WAREHOUSE", CFrame = CFrame.new(0, 18, -87) * CFrame.Angles(0, math.pi, 0), Size = Vector3.new(0.5, 5, 30), TextColor = Color3.fromRGB(255, 62, 165), Parent = shop })

--------------------------------------------------------------------------
-- ShipFast Customs Dock — east of plaza
--------------------------------------------------------------------------
local dock = buildBox("ShipFastCustomsDock", Vector3.new(75, 0, 0), Vector3.new(40, 14, 40), Color3.fromRGB(50, 46, 40), Color3.fromRGB(255, 210, 70), root)
sign({ Text = "SHIPFAST CUSTOMS DOCK", CFrame = CFrame.new(75, 16, -21) * CFrame.Angles(0, math.pi, 0), Size = Vector3.new(0.5, 5, 30), TextColor = Color3.fromRGB(255, 210, 70), Parent = dock })

-- Cargo containers for flavor
for i = 1, 5 do
	part({
		Name = "Container" .. i,
		Size = Vector3.new(8, 8, 20),
		Position = Vector3.new(60 + i * 9, 4, 25),
		Color = Color3.fromHSV((i * 0.15) % 1, 0.55, 0.7),
		Material = Enum.Material.Metal,
		Parent = dock,
	})
end

-- Customs checkpoint gate (visual barrier between dock and plaza)
part({ Name = "GatePostA", Size = Vector3.new(1, 8, 1), Position = Vector3.new(40, 4, 0), Color = Color3.fromRGB(255, 210, 70), Material = Enum.Material.Neon, Parent = dock })
part({ Name = "GatePostB", Size = Vector3.new(1, 8, 1), Position = Vector3.new(40, 4, 10), Color = Color3.fromRGB(255, 210, 70), Material = Enum.Material.Neon, Parent = dock })
part({ Name = "GateBar", Size = Vector3.new(1, 1, 12), Position = Vector3.new(40, 7, 5), Color = Color3.fromRGB(255, 60, 60), Material = Enum.Material.Neon, Parent = dock })

--------------------------------------------------------------------------
-- ThriftLyst Bazaar (resale market) — west of plaza
--------------------------------------------------------------------------
local bazaar = Instance.new("Folder")
bazaar.Name = "ThriftLystBazaar"
bazaar.Parent = root

part({ Name = "BazaarFloor", Size = Vector3.new(50, 0.4, 50), Position = Vector3.new(-80, 0.2, 0), Color = Color3.fromRGB(46, 40, 56), Parent = bazaar })
sign({ Text = "THRIFTLYST BAZAAR", CFrame = CFrame.new(-80, 14, 25) * CFrame.Angles(0, math.pi, 0), Size = Vector3.new(0.5, 5, 30), TextColor = Color3.fromRGB(62, 193, 255), Parent = bazaar })

for i = 1, 6 do
	local angle = (i / 6) * math.pi * 2
	local stallPos = Vector3.new(-80 + math.cos(angle) * 16, 0, math.sin(angle) * 16)
	part({ Name = "StallPost1_" .. i, Size = Vector3.new(0.6, 8, 0.6), Position = stallPos + Vector3.new(-3, 4, -3), Color = Color3.fromRGB(90, 70, 60), Material = Enum.Material.Wood, Parent = bazaar })
	part({ Name = "StallPost2_" .. i, Size = Vector3.new(0.6, 8, 0.6), Position = stallPos + Vector3.new(3, 4, -3), Color = Color3.fromRGB(90, 70, 60), Material = Enum.Material.Wood, Parent = bazaar })
	part({ Name = "StallCanopy_" .. i, Size = Vector3.new(7, 0.5, 7), Position = stallPos + Vector3.new(0, 8, -3), Color = Color3.fromHSV((i * 0.16) % 1, 0.7, 0.85), Material = Enum.Material.Fabric, Parent = bazaar })
	part({ Name = "StallTable_" .. i, Size = Vector3.new(6, 2, 3), Position = stallPos + Vector3.new(0, 1, 0), Color = Color3.fromRGB(120, 100, 80), Material = Enum.Material.Wood, Parent = bazaar })
end

--------------------------------------------------------------------------
-- Connecting paths
--------------------------------------------------------------------------
local function path(from, to, width)
	local diff = to - from
	local length = diff.Magnitude
	local mid = from + diff / 2
	part({
		Name = "Path",
		Size = Vector3.new(width or 12, 0.3, length),
		CFrame = CFrame.new(mid, to) * CFrame.new(0, 0, 0),
		Color = Color3.fromRGB(70, 68, 80),
		Material = Enum.Material.Concrete,
		Parent = root,
	})
end

path(Vector3.new(0, 0.3, -35), Vector3.new(0, 0.3, -53))
path(Vector3.new(35, 0.3, 0), Vector3.new(55, 0.3, 0))
path(Vector3.new(-35, 0.3, 0), Vector3.new(-55, 0.3, 0))

--------------------------------------------------------------------------
-- Lighting mood
--------------------------------------------------------------------------
Lighting.Ambient = Color3.fromRGB(40, 40, 55)
Lighting.OutdoorAmbient = Color3.fromRGB(60, 55, 75)
Lighting.Brightness = 2
Lighting.ClockTime = 21
Lighting.FogColor = Color3.fromRGB(30, 20, 45)
Lighting.FogEnd = 600
Lighting.Technology = Enum.Technology.Future

if not Lighting:FindFirstChildOfClass("Atmosphere") then
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Color = Color3.fromRGB(150, 130, 200)
	atmosphere.Decay = Color3.fromRGB(70, 40, 90)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1
	atmosphere.Parent = Lighting
end

if not Lighting:FindFirstChildOfClass("BloomEffect") then
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 24
	bloom.Threshold = 1.4
	bloom.Parent = Lighting
end

print("[MapBuilder] Generated starter map (plaza, warehouse, customs dock, bazaar).")
