-- Builds the Atrium hub and five portals (CLAUDE.md §5.1). Not synced; run in Edit mode with
-- the MCP execute_luau tool. Rebuilds from scratch each run. Afterwards, save the place.
--
-- Layout: the path is an arc of radius R around CENTER, starting at the spawn (θ = 0, heading −Z)
-- and curving right. Portal k stands beside the path at θ = k·STEP, alternating sides, joined to
-- the path by a short spur. Portal visuals start in the neutral "locked" look; PortalController
-- (client) sets each player's real state.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.Theme)
local Config = require(Shared.Config)

local R = 110
local CENTER = Vector3.new(R, 0, 0)
local STEP = 0.3 -- radians between stations
local PATH_START, PATH_END = -0.14, 5 * STEP + 0.3
local PATH_WIDTH = 10
local SAMPLE = 0.04
local PORTAL_OFFSET = 18 -- path center to portal center
local RING_RADIUS = 7
local RING_SEGMENTS = 28
local DAIS_RADIUS = 10
local DAIS_HEIGHT = 0.6

local C = {
	floor = Color3.fromHex("#252A3A"),
	walk = Color3.fromHex("#363D52"),
	dais = Color3.fromHex("#232836"),
	frame = Color3.fromHex("#3B4255"),
	bollardCap = Color3.fromHex("#DCE4F7"),
	bollardLight = Color3.fromHex("#C9D6FF"),
	dim = Theme.color.border,
	sign = Theme.color.surface,
}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		if k ~= "Parent" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

local function decorative(p: BasePart)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function pathPoint(theta: number): Vector3
	return CENTER + Vector3.new(-math.cos(theta), 0, -math.sin(theta)) * R
end

local function outward(theta: number): Vector3
	return Vector3.new(-math.cos(theta), 0, -math.sin(theta))
end

-- A flat strip from a to b (both at floor level), `width` wide, `height` tall, top at `top`.
local function strip(a: Vector3, b: Vector3, width: number, height: number, top: number, props): Part
	local mid = (a + b) / 2
	local length = (b - a).Magnitude
	local cf = CFrame.lookAt(Vector3.new(mid.X, top - height / 2, mid.Z), Vector3.new(b.X, top - height / 2, b.Z))
	props.Size = Vector3.new(width, height, length)
	props.CFrame = cf
	return part(props)
end

---------------------------------------------------------------------------
-- Clean up
---------------------------------------------------------------------------

for _, name in { "Atrium", "Baseplate", "SpawnLocation", "SpinningPart" } do
	local old = workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

local atrium = Instance.new("Model")
atrium.Name = "Atrium"
atrium.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

---------------------------------------------------------------------------
-- Floor and spawn
---------------------------------------------------------------------------

local mid = (pathPoint(0) + pathPoint(5 * STEP)) / 2
part({
	Name = "Floor",
	Size = Vector3.new(1200, 2, 1200), -- large so the haze hides its edge
	CFrame = CFrame.new(mid.X, -1, mid.Z),
	Color = C.floor,
	Material = Enum.Material.Slate,
	Parent = atrium,
})

local spawnFolder = folder("Spawn", atrium)
local plaza = part({
	Name = "Plaza",
	Shape = Enum.PartType.Cylinder,
	Size = Vector3.new(0.2, 22, 22),
	CFrame = CFrame.new(0, 0, 4) * CFrame.Angles(0, 0, math.rad(90)),
	Color = C.walk,
	Parent = spawnFolder,
})
plaza.CanCollide = true
local plazaRim = part({
	Name = "PlazaRim",
	Shape = Enum.PartType.Cylinder,
	Size = Vector3.new(0.16, 22.6, 22.6),
	CFrame = CFrame.new(0, -0.02, 4) * CFrame.Angles(0, 0, math.rad(90)),
	Color = C.dim,
	Material = Enum.Material.Neon,
	Transparency = 0.4,
	Parent = spawnFolder,
})
decorative(plazaRim)

local spawn = Instance.new("SpawnLocation")
spawn.Name = "SpawnLocation"
spawn.Anchored = true
spawn.Neutral = true
spawn.Duration = 0
spawn.Size = Vector3.new(6, 0.2, 6)
spawn.CFrame = CFrame.new(0, 0.05, 4) -- faces −Z, down the path
spawn.Transparency = 1
spawn.CanCollide = false
spawn.CanQuery = false
local decal = spawn:FindFirstChildOfClass("Decal")
if decal then
	decal:Destroy()
end
spawn.Parent = spawnFolder

---------------------------------------------------------------------------
-- Path: walkway + edge glow strips. Glow_k holds the strips leading to portal k.
---------------------------------------------------------------------------

local pathFolder = folder("Path", atrium)
local walkFolder = folder("Walkway", pathFolder)
local glow = {}
for k = 1, #Config.MODULE_ORDER do
	glow[k] = folder("Glow_" .. k, pathFolder)
end

local function glowIndexFor(theta: number): number
	-- Interval ((k−1)·STEP, k·STEP] leads to portal k; before spawn counts as 1, past 5 as 5.
	return math.clamp(math.ceil(theta / STEP - 1e-6), 1, #Config.MODULE_ORDER)
end

local theta = PATH_START
while theta < PATH_END - 1e-6 do
	local nextTheta = math.min(theta + SAMPLE, PATH_END)
	local a, b = pathPoint(theta), pathPoint(nextTheta)
	local dir = (b - a).Unit
	local extend = dir * 0.15 -- overlap to hide seams on the curve
	strip(a - extend, b + extend, PATH_WIDTH, 0.2, 0.1, { Name = "Walk", Color = C.walk, Parent = walkFolder })

	local k = glowIndexFor((theta + nextTheta) / 2)
	for _, side in { -1, 1 } do
		local offA = a + outward(theta) * side * (PATH_WIDTH / 2 + 0.1)
		local offB = b + outward(nextTheta) * side * (PATH_WIDTH / 2 + 0.1)
		local s = strip(offA - extend, offB + extend, 0.3, 0.14, 0.14, {
			Name = "Strip",
			Color = C.dim,
			Material = Enum.Material.Neon,
			Transparency = 0.6,
			Parent = glow[k],
		})
		decorative(s)
	end
	theta = nextTheta
end

---------------------------------------------------------------------------
-- Bollard lights along both path edges
---------------------------------------------------------------------------

local bollards = folder("Bollards", atrium)
local bt = PATH_START + 0.1
while bt < PATH_END - 0.05 do
	for _, side in { -1, 1 } do
		local p = pathPoint(bt) + outward(bt) * side * (PATH_WIDTH / 2 + 1.6)
		part({
			Name = "Bollard",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.8, 0.6, 0.6),
			CFrame = CFrame.new(p + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = C.frame,
			Material = Enum.Material.Metal,
			Parent = bollards,
		})
		local cap = part({
			Name = "Cap",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.25, 0.62, 0.62),
			CFrame = CFrame.new(p + Vector3.new(0, 1.85, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = C.bollardCap,
			Material = Enum.Material.Neon,
			Parent = bollards,
		})
		decorative(cap)
		local light = Instance.new("PointLight")
		light.Color = C.bollardLight
		light.Range = 14
		light.Brightness = 0.9
		light.Shadows = false
		light.Parent = cap
	end
	bt += 0.15
end

---------------------------------------------------------------------------
-- Portals
---------------------------------------------------------------------------

local portalsFolder = folder("Portals", atrium)

local function buildPortal(order: number, moduleId: string)
	local t = order * STEP
	local side = if order % 2 == 1 then 1 else -1 -- odd: outer (left), even: inner (right)
	local n = outward(t) * side
	local pathP = pathPoint(t)
	local q = pathP + n * PORTAL_OFFSET
	local base = CFrame.lookAt(q, pathP) -- faces the path
	local accent = Theme.accent[moduleId]

	local model = Instance.new("Model")
	model.Name = string.format("Portal_%d_%s", order, moduleId)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model:SetAttribute("ModuleId", moduleId)
	model:SetAttribute("Order", order)
	model:SetAttribute("Accent", accent)

	-- Spur from the path edge to the dais
	local spurA = pathP + n * (PATH_WIDTH / 2 - 0.5)
	local spurB = q - n * (DAIS_RADIUS - 1)
	strip(spurA, spurB, 6, 0.2, 0.1, { Name = "Spur", Color = C.walk, Parent = model })
	for _, s in { -1, 1 } do
		local lateral = base.RightVector * s * 3.1
		-- Edge strips stop just outside the dais rim
		local stripEnd = q - n * math.sqrt((DAIS_RADIUS + 0.6) ^ 2 - 3.1 ^ 2)
		local g = strip(spurA + lateral, stripEnd + lateral, 0.3, 0.14, 0.14, {
			Name = "Strip",
			Color = C.dim,
			Material = Enum.Material.Neon,
			Transparency = 0.6,
			Parent = glow[order],
		})
		decorative(g)
	end

	-- Dais and its rim
	local dais = part({
		Name = "Dais",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(DAIS_HEIGHT, DAIS_RADIUS * 2, DAIS_RADIUS * 2),
		CFrame = CFrame.new(q + Vector3.new(0, DAIS_HEIGHT / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = C.dais,
		Material = Enum.Material.Slate,
		Parent = model,
	})
	local rim = part({
		Name = "Rim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, DAIS_RADIUS * 2 + 0.7, DAIS_RADIUS * 2 + 0.7),
		CFrame = CFrame.new(q + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = C.dim,
		Material = Enum.Material.Neon,
		Transparency = 0.5,
		Parent = model,
	})
	decorative(rim)

	-- Ring frame + inner inlay
	local ringCenter = q + Vector3.new(0, DAIS_HEIGHT + RING_RADIUS + 0.6, 0)
	local look, right, up = base.LookVector, base.RightVector, Vector3.yAxis
	local frame = Instance.new("Model")
	frame.Name = "Frame"
	local inlay = Instance.new("Model")
	inlay.Name = "Inlay"
	local segLen = 2 * RING_RADIUS * math.tan(math.pi / RING_SEGMENTS) + 0.12
	for i = 0, RING_SEGMENTS - 1 do
		local a = (i + 0.5) / RING_SEGMENTS * 2 * math.pi
		local radial = right * math.cos(a) + up * math.sin(a)
		local tangent = -right * math.sin(a) + up * math.cos(a)
		local seg = part({
			Name = "Seg",
			Size = Vector3.new(segLen, 1.1, 1.6),
			CFrame = CFrame.fromMatrix(ringCenter + radial * RING_RADIUS, tangent, radial),
			Color = C.frame,
			Material = Enum.Material.Metal,
			Parent = frame,
		})
		if math.sin(a) < -0.45 then
			seg.CanCollide = false -- let players walk over the bottom of the ring
		end
		local inner = RING_RADIUS - 0.62
		local inl = part({
			Name = "Inlay",
			Size = Vector3.new(2 * inner * math.tan(math.pi / RING_SEGMENTS) + 0.06, 0.16, 1.0),
			CFrame = CFrame.fromMatrix(ringCenter + radial * inner, tangent, radial),
			Color = C.dim,
			Material = Enum.Material.Neon,
			Transparency = 0.5,
			Parent = inlay,
		})
		decorative(inl)
	end
	frame.Parent = model
	inlay.Parent = model

	-- Glowing surface (a thin disc in the ring's plane; its X axis points along `look`)
	local surface = part({
		Name = "Surface",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.12, (RING_RADIUS - 0.7) * 2, (RING_RADIUS - 0.7) * 2),
		CFrame = CFrame.fromMatrix(ringCenter, look, up),
		Color = C.dim,
		Material = Enum.Material.Glass,
		Transparency = 0.85,
		Parent = model,
	})
	decorative(surface)

	-- Entry trigger: a box spanning the ring's opening, a little deeper than the ring
	local trigger = part({
		Name = "Trigger",
		Size = Vector3.new((RING_RADIUS - 1) * 2, 2 * RING_RADIUS + 1, 3),
		CFrame = CFrame.fromMatrix(
			q + Vector3.new(0, DAIS_HEIGHT + (2 * RING_RADIUS + 1) / 2, 0),
			right,
			up
		),
		Transparency = 1,
		Parent = model,
	})
	decorative(trigger)

	-- Light, particles and beam anchors live on the dais
	local glowAtt = Instance.new("Attachment")
	glowAtt.Name = "Glow"
	glowAtt.Parent = dais
	glowAtt.WorldPosition = ringCenter -- needs a parent first
	local light = Instance.new("PointLight")
	light.Name = "Light"
	light.Color = accent
	light.Range = 22
	light.Brightness = 0.4
	light.Shadows = false
	light.Parent = glowAtt

	local particles = Instance.new("ParticleEmitter")
	particles.Name = "Particles"
	particles.Color = ColorSequence.new(accent)
	particles.LightEmission = 1
	particles.Rate = 5
	particles.Lifetime = NumberRange.new(2.5, 4)
	particles.Speed = NumberRange.new(0.4, 1.2)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Acceleration = Vector3.new(0, 0.5, 0)
	particles.Drag = 0.5
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	particles.Enabled = false
	particles.Parent = surface

	local beamBase = Instance.new("Attachment")
	beamBase.Name = "BeamBase"
	beamBase.Parent = dais
	beamBase.WorldPosition = q + Vector3.new(0, DAIS_HEIGHT, 0) -- needs a parent first
	local beamTop = Instance.new("Attachment")
	beamTop.Name = "BeamTop"
	beamTop.Parent = dais
	beamTop.WorldPosition = q + Vector3.new(0, 70, 0) -- needs a parent first
	local beam = Instance.new("Beam")
	beam.Name = "Beam"
	beam.Attachment0 = beamBase
	beam.Attachment1 = beamTop
	beam.Width0 = 9
	beam.Width1 = 2
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Segments = 1
	beam.Color = ColorSequence.new(accent)
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.86),
		NumberSequenceKeypoint.new(0.6, 0.95),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.Enabled = false
	beam.Parent = dais

	-- Sign beside the spur, facing the path
	local signPos = pathP + n * (PATH_WIDTH / 2 + 3) + base.RightVector * 6.5
	local signBase = CFrame.lookAt(signPos, signPos - n)
	part({
		Name = "SignPost",
		Size = Vector3.new(0.6, 3.4, 0.6),
		CFrame = signBase + Vector3.new(0, 1.7, 0),
		Color = C.frame,
		Material = Enum.Material.Metal,
		Parent = model,
	})
	part({
		Name = "Sign",
		Size = Vector3.new(9, 5.2, 0.3),
		CFrame = (signBase + Vector3.new(0, 4.9, 0)) * CFrame.Angles(math.rad(12), 0, 0), -- top leans back
		Color = C.sign,
		Parent = model,
	})

	model.PrimaryPart = dais
	model.Parent = portalsFolder
	CollectionService:AddTag(model, "Portal")
end

for order, moduleId in Config.MODULE_ORDER do
	buildPortal(order, moduleId)
	task.wait()
end

atrium.Parent = workspace

---------------------------------------------------------------------------
-- Lighting: a calm science museum at night
---------------------------------------------------------------------------

Lighting.ClockTime = 0
Lighting.Brightness = 2.5
Lighting.Ambient = Color3.fromHex("#5A6074")
Lighting.OutdoorAmbient = Color3.fromHex("#666C82")
Lighting.EnvironmentDiffuseScale = 0.4
Lighting.EnvironmentSpecularScale = 0.6
Lighting.ExposureCompensation = 0.5

local function effect(className: string, name: string): any
	local e = Lighting:FindFirstChild(name)
	if not (e and e.ClassName == className) then
		if e then
			e:Destroy()
		end
		e = Instance.new(className)
		e.Name = name
		e.Parent = Lighting
	end
	return e
end

local atmosphere = effect("Atmosphere", "Atmosphere")
atmosphere.Density = 0.35
atmosphere.Offset = 0.05
atmosphere.Color = Color3.fromHex("#262B3A")
atmosphere.Decay = Color3.fromHex("#0B1020")
atmosphere.Glare = 0
atmosphere.Haze = 1.2

local bloom = effect("BloomEffect", "Bloom")
bloom.Intensity = 0.6
bloom.Size = 24
bloom.Threshold = 1.2

local cc = effect("ColorCorrectionEffect", "ColorCorrection")
cc.Contrast = 0.08
cc.Saturation = -0.1
cc.Brightness = 0

-- Template effects the Atrium doesn't use
for _, name in { "SunRays", "DepthOfField" } do
	local e = Lighting:FindFirstChild(name)
	if e then
		e:Destroy()
	end
end

local count = 0
for _, d in atrium:GetDescendants() do
	if d:IsA("BasePart") then
		count += 1
	end
end
return `Atrium built: {count} parts, {#CollectionService:GetTagged("Portal")} portals`
