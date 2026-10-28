--!strict
-- Portal visuals, entry detection and locked feedback (CLAUDE.md §4.2, §5.1).
-- Portal state is per player, so every visual change here is local to this client.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Config = require(Shared:WaitForChild("Config"))
local Theme = require(Shared:WaitForChild("Theme"))
local Index = require(Shared:WaitForChild("Lessons"):WaitForChild("Index"))
local Types = require(Shared:WaitForChild("Types"))

local Client = script.Parent.Parent
local Cleanup = require(Client:WaitForChild("UI"):WaitForChild("Cleanup"))
local Create = require(Client.UI:WaitForChild("Create"))
local Glyph = require(Client.UI:WaitForChild("Components"):WaitForChild("Glyph"))

type PortalState = "locked" | "open" | "completed"

type Portal = {
	model: Model,
	moduleId: string,
	order: number,
	accent: Color3,
	trigger: BasePart,
	surface: BasePart,
	rim: BasePart,
	inlay: { BasePart },
	light: PointLight?,
	particles: ParticleEmitter?,
	beam: Beam?,
	strips: { BasePart },
	sign: {
		chip: Frame,
		chipLabel: TextLabel,
		chipIcon: Frame,
		status: TextLabel,
		accentBar: Frame,
		number: TextLabel,
	}?,
	centerIcon: Frame?,
	state: PortalState?,
	effects: Cleanup.Cleanup, -- running tweens for the current state
	inside: boolean,
	cooldownUntil: number,
}

export type Options = {
	progress: {
		get: () -> Types.ProgressPayload,
		onChanged: (fn: (Types.ProgressPayload) -> ()) -> () -> (),
		isUnlocked: (moduleId: string) -> boolean,
	},
	onEnterOpen: (moduleId: string, portal: Model) -> (),
	onEnterLocked: (moduleId: string, message: string) -> (),
}

local DIM = Theme.color.border
local SIGN_PPS = 64 -- SurfaceGui pixels per stud (sign is 9 × 5.2 studs → 576 × 333 px)

local PortalController = {}

local portals: { [Model]: Portal } = {}
local options: Options
local enabled = true
local pendingUnlocks: { Portal } = {}
local lockedSound: Sound? = nil

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function settings(): Types.Settings
	return options.progress.get().progress.settings
end

local function stateFor(moduleId: string): PortalState
	local payload = options.progress.get()
	if payload.progress.modules[moduleId].completed then
		return "completed"
	elseif options.progress.isUnlocked(moduleId) then
		return "open"
	end
	return "locked"
end

local function loop(effects: Cleanup.Cleanup, instance: Instance, period: number, goal: { [string]: any })
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(period / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		goal
	)
	tween:Play()
	effects:add(function()
		tween:Cancel()
	end)
end

local function tween(instance: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local t = TweenService:Create(instance, info, goal)
	t:Play()
	return t
end

local function setNeon(part: BasePart, color: Color3, transparency: number)
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = transparency
end

local function setDim(part: BasePart, transparency: number)
	part.Material = Enum.Material.Neon
	part.Color = DIM
	part.Transparency = transparency
end

---------------------------------------------------------------------------
-- Sign (SurfaceGui on the Sign part) and center icon (on the Surface disc)
---------------------------------------------------------------------------

local function buildSign(portal: Portal, signPart: BasePart)
	local meta = Index.get(portal.moduleId)
	if not meta then
		return
	end
	local surfaceGui = Create("SurfaceGui", {
		Name = "PortalSign",
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = SIGN_PPS,
		LightInfluence = 0,
		Brightness = 1.4,
		MaxDistance = 150,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	local card = Create("Frame", {
		Name = "Card",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.color.surface,
		BorderSizePixel = 0,
		Parent = surfaceGui,
	}, {
		Create("UIStroke", { Color = Theme.color.border, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})

	local accentBar = Create("Frame", {
		Name = "AccentBar",
		Size = UDim2.new(0, 10, 1, 0),
		BackgroundColor3 = DIM,
		BorderSizePixel = 0,
		Parent = card,
	})

	local content = Create("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -10, 1, 0),
		BackgroundTransparency = 1,
		Parent = card,
	}, {
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 22),
			PaddingBottom = UDim.new(0, 20),
			PaddingLeft = UDim.new(0, 28),
			PaddingRight = UDim.new(0, 28),
		}),
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- Row 1: number + era
	local header = Create("Frame", {
		Name = "Header",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		Parent = content,
	})
	local number = Create("TextLabel", {
		Name = "Number",
		Size = UDim2.fromScale(0.5, 1),
		BackgroundTransparency = 1,
		Text = string.format("%02d", portal.order),
		TextColor3 = Theme.color.textMuted,
		FontFace = Theme.font.mono,
		TextSize = 36,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})
	Create("TextLabel", {
		Name = "Era",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(0.5, 1),
		BackgroundTransparency = 1,
		Text = meta.era,
		TextColor3 = Theme.color.textMuted,
		FontFace = Theme.font.medium,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = header,
	})

	-- Row 2: title
	Create("TextLabel", {
		Name = "Title",
		LayoutOrder = 2,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = meta.title,
		TextColor3 = Theme.color.text,
		FontFace = Theme.font.bold,
		TextSize = 44,
		TextWrapped = true,
		LineHeight = 1.0,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = content,
	})

	-- Row 3: state chip
	local chip = Create("Frame", {
		Name = "Chip",
		LayoutOrder = 3,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 42),
		BackgroundColor3 = Theme.color.surfaceRaised,
		Parent = content,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 21) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 16) }),
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local chipLabel = Create("TextLabel", {
		Name = "Label",
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Theme.color.text,
		FontFace = Theme.font.bold,
		TextSize = 24,
		Parent = chip,
	})

	-- Row 4: status line
	local status = Create("TextLabel", {
		Name = "Status",
		LayoutOrder = 4,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Theme.color.textMuted,
		FontFace = Theme.font.regular,
		TextSize = 28,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = content,
	})

	surfaceGui.Parent = signPart

	local placeholder = Create("Frame", { LayoutOrder = 1, BackgroundTransparency = 1, Parent = chip })
	portal.sign = {
		chip = chip,
		chipLabel = chipLabel,
		chipIcon = placeholder,
		status = status,
		accentBar = accentBar,
		number = number,
	}
end

local function buildCenterIcon(portal: Portal)
	-- The Surface disc's X axis points at the path, so its Right face is the one players see.
	local gui = Create("SurfaceGui", {
		Name = "PortalIcon",
		Face = Enum.NormalId.Right,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 40,
		LightInfluence = 0,
		Brightness = 1,
		MaxDistance = 150,
		Parent = portal.surface,
	})
	portal.centerIcon = Create("Frame", {
		Name = "Holder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(120, 120),
		BackgroundTransparency = 1,
		Parent = gui,
	})
end

local function setIcon(holder: Frame, icon: Frame?)
	for _, child in holder:GetChildren() do
		child:Destroy()
	end
	if icon then
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.Parent = holder
	end
end

local function updateSign(portal: Portal, state: PortalState)
	local sign = portal.sign
	if not sign then
		return
	end
	local payload = options.progress.get()
	local chipColor, chipText, textColor, icon
	if state == "locked" then
		chipColor, chipText, textColor = Theme.color.surfaceRaised, "LOCKED", Theme.color.textMuted
		icon = Glyph.lock(22, Theme.color.textMuted, Theme.color.surfaceRaised)
		local previous = Index.at(portal.order - 1)
		sign.status.Text = `Finish {if previous then previous.title else "the previous module"} to unlock.`
	elseif state == "open" then
		chipColor, chipText, textColor = portal.accent, "OPEN", Theme.color.bg
		icon = Glyph.text(22, "→", Theme.color.bg, Theme.font.bold)
		sign.status.Text = "Walk into the portal to begin."
	else
		chipColor, chipText, textColor = Theme.color.surfaceRaised, "COMPLETED", Theme.color.success
		icon = Glyph.text(24, "✓", Theme.color.success, Theme.font.bold)
		local best = payload.progress.modules[portal.moduleId].bestScore
		sign.status.Text = `Best score {best}/{Config.QUIZ_LENGTH}. Walk in to review.`
	end

	sign.chip.BackgroundColor3 = chipColor
	sign.chipLabel.Text = chipText
	sign.chipLabel.TextColor3 = textColor
	sign.chipIcon:Destroy()
	icon.LayoutOrder = 1
	icon.Parent = sign.chip
	sign.chipIcon = icon
	sign.accentBar.BackgroundColor3 = if state == "locked" then DIM else portal.accent
	sign.number.TextColor3 = if state == "locked" then Theme.color.textMuted else portal.accent

	if portal.centerIcon then
		if state == "locked" then
			setIcon(portal.centerIcon, Glyph.lock(120, Theme.color.textMuted, Theme.color.bg))
		elseif state == "completed" then
			setIcon(portal.centerIcon, Glyph.text(120, "✓", Theme.color.text, Theme.font.extraBold))
		else
			setIcon(portal.centerIcon, nil)
		end
	end
end

---------------------------------------------------------------------------
-- States
---------------------------------------------------------------------------

local function applyState(portal: Portal, state: PortalState)
	portal.effects:destroy()
	portal.effects = Cleanup.new()
	local reduced = settings().reducedMotion
	local accent = portal.accent

	if state == "locked" then
		portal.surface.Material = Enum.Material.Glass
		portal.surface.Color = DIM
		portal.surface.Transparency = 0.85
		setDim(portal.rim, 0.6)
		for _, p in portal.inlay do
			setDim(p, 0.6)
		end
		for _, p in portal.strips do
			setDim(p, 0.6)
		end
		if portal.light then
			portal.light.Enabled = false
		end
		if portal.particles then
			portal.particles.Enabled = false
		end
		if portal.beam then
			portal.beam.Enabled = false
		end
	elseif state == "open" then
		-- Neon washes toward white when nearly opaque; these transparencies keep the hue.
		setNeon(portal.surface, accent, 0.55)
		setNeon(portal.rim, accent, 0.25)
		for _, p in portal.inlay do
			setNeon(p, accent, 0.15)
		end
		for _, p in portal.strips do
			setNeon(p, accent, 0.3)
		end
		if portal.light then
			portal.light.Enabled = true
			portal.light.Brightness = 2
		end
		if portal.particles then
			portal.particles.Rate = 6
			portal.particles.Enabled = true
		end
		if portal.beam then
			portal.beam.Enabled = true
		end
		if not reduced then
			-- Slow pulse; the path toward this portal breathes with it.
			loop(portal.effects, portal.surface, 3.2, { Transparency = 0.78 })
			if portal.light then
				loop(portal.effects, portal.light, 3.2, { Brightness = 1.2 })
			end
			for _, p in portal.strips do
				loop(portal.effects, p, 3.2, { Transparency = 0.6 })
			end
		end
	else -- completed: calm, steady glow
		setNeon(portal.surface, accent, 0.8)
		setNeon(portal.rim, accent, 0.45)
		for _, p in portal.inlay do
			setNeon(p, accent, 0.35)
		end
		for _, p in portal.strips do
			setNeon(p, accent, 0.6)
		end
		if portal.light then
			portal.light.Enabled = true
			portal.light.Brightness = 1
		end
		if portal.particles then
			portal.particles.Rate = 2
			portal.particles.Enabled = true
		end
		if portal.beam then
			portal.beam.Enabled = false
		end
	end

	updateSign(portal, state)
end

-- Locked → open celebration: the path lights up toward the portal, then the portal flares.
local function playUnlock(portal: Portal)
	if settings().reducedMotion then
		applyState(portal, "open")
		return
	end
	portal.effects:destroy()
	portal.effects = Cleanup.new()
	local accent = portal.accent
	local fx = portal.effects

	-- Strips: farthest from the portal first, so the light travels toward it.
	local pivot = portal.model:GetPivot().Position
	local strips = table.clone(portal.strips)
	table.sort(strips, function(a, b)
		return (a.Position - pivot).Magnitude > (b.Position - pivot).Magnitude
	end)
	local travel = 0.6
	for i, p in strips do
		local delay = (i - 1) / math.max(#strips, 1) * travel
		fx:add(task.delay(delay, function()
			setNeon(p, Color3.new(1, 1, 1), 0)
			tween(p, Theme.ease.state, { Color = accent, Transparency = 0.3 })
		end))
	end

	fx:add(task.delay(travel, function()
		setNeon(portal.surface, Color3.new(1, 1, 1), 1)
		setNeon(portal.rim, accent, 0.25)
		for _, p in portal.inlay do
			setNeon(p, Color3.new(1, 1, 1), 0)
			tween(p, TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Color = accent,
				Transparency = 0.15,
			})
		end
		tween(portal.surface, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Transparency = 0.55,
			Color = accent,
		})
		if portal.light then
			portal.light.Enabled = true
			portal.light.Brightness = 8
			tween(portal.light, TweenInfo.new(0.9, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Brightness = 2 })
		end
		if portal.particles then
			portal.particles.Enabled = true
			portal.particles:Emit(60)
		end
		if portal.beam then
			portal.beam.Enabled = true
			local width = portal.beam.Width0
			portal.beam.Width0 = 0
			tween(portal.beam, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Width0 = width })
		end
	end))

	-- Untracked on purpose: applyState destroys `fx`, which would cancel this very thread.
	task.delay(travel + 1, function()
		if portal.effects == fx and portal.state == "open" then
			applyState(portal, "open")
		end
	end)
	updateSign(portal, "open")
end

local function refresh(animate: boolean)
	for _, portal in portals do
		local nextState = stateFor(portal.moduleId)
		local previous = portal.state
		if table.find(pendingUnlocks, portal) and nextState == "open" then
			continue -- already queued to animate when detection resumes
		end
		if nextState ~= previous then
			portal.state = nextState
			if animate and previous == "locked" and nextState == "open" then
				if enabled then
					playUnlock(portal)
				else
					applyState(portal, "locked") -- keep it locked-looking until the player is back
					portal.state = "locked"
					table.insert(pendingUnlocks, portal)
				end
			else
				applyState(portal, nextState)
			end
		end
	end
end

---------------------------------------------------------------------------
-- Registration
---------------------------------------------------------------------------

local function collectStrips(order: number): { BasePart }
	local list = {}
	local atrium = workspace:FindFirstChild("Atrium")
	local pathFolder = atrium and atrium:FindFirstChild("Path")
	local glow = pathFolder and pathFolder:FindFirstChild("Glow_" .. order)
	if glow then
		for _, d in glow:GetChildren() do
			if d:IsA("BasePart") then
				table.insert(list, d)
			end
		end
	end
	return list
end

local function register(model: Instance)
	if not model:IsA("Model") or portals[model] then
		return
	end
	local moduleId = model:GetAttribute("ModuleId")
	local order = model:GetAttribute("Order")
	if type(moduleId) ~= "string" or type(order) ~= "number" or not Config.moduleIndex(moduleId) then
		return
	end

	local trigger = model:WaitForChild("Trigger", 10)
	local surface = model:WaitForChild("Surface", 10)
	local rim = model:WaitForChild("Rim", 10)
	local inlayModel = model:WaitForChild("Inlay", 10)
	local dais = model:WaitForChild("Dais", 10)
	local signPart = model:WaitForChild("Sign", 10)
	if not (trigger and surface and rim and inlayModel and dais and signPart) then
		return
	end

	local inlay = {}
	for _, p in inlayModel:GetChildren() do
		if p:IsA("BasePart") then
			table.insert(inlay, p)
		end
	end
	local glowAtt = dais:FindFirstChild("Glow")
	local accent = Theme.accent[moduleId]

	local portal: Portal = {
		model = model,
		moduleId = moduleId,
		order = order,
		accent = accent,
		trigger = trigger :: BasePart,
		surface = surface :: BasePart,
		rim = rim :: BasePart,
		inlay = inlay,
		light = glowAtt and glowAtt:FindFirstChildOfClass("PointLight") or nil,
		particles = surface:FindFirstChildOfClass("ParticleEmitter"),
		beam = dais:FindFirstChildOfClass("Beam"),
		strips = collectStrips(order),
		state = nil,
		effects = Cleanup.new(),
		inside = false,
		cooldownUntil = 0,
	}
	buildSign(portal, signPart :: BasePart)
	buildCenterIcon(portal)
	portals[model] = portal

	local state = stateFor(moduleId)
	portal.state = state
	applyState(portal, state)
end

local function unregister(model: Instance)
	local portal = portals[model :: Model]
	if portal then
		portal.effects:destroy()
		portals[model :: Model] = nil
	end
end

---------------------------------------------------------------------------
-- Entry detection (polled; Touched is unreliable for this)
---------------------------------------------------------------------------

local function isInside(trigger: BasePart, position: Vector3): boolean
	local localPos = trigger.CFrame:PointToObjectSpace(position)
	local half = trigger.Size / 2
	return math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z
end

local function lockedMessage(portal: Portal): string
	local previous = Index.at(portal.order - 1)
	return `Finish {if previous then previous.title else "the previous module"} to unlock this portal.`
end

local function playLockedSound()
	if settings().muted then
		return
	end
	if not lockedSound then
		local sound = Instance.new("Sound")
		sound.Name = "PortalLocked"
		sound.SoundId = Assets.sound.locked
		sound.Volume = 0.35
		sound.Parent = SoundService
		lockedSound = sound
	end
	(lockedSound :: Sound):Play()
end

local function poll()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local position = root.Position
	local now = os.clock()
	for _, portal in portals do
		local inside = isInside(portal.trigger, position)
		local entered = inside and not portal.inside
		portal.inside = inside
		if entered and enabled and now >= portal.cooldownUntil then
			portal.cooldownUntil = now + Config.PORTAL_REENTRY_COOLDOWN
			if portal.state == "locked" then
				playLockedSound()
				options.onEnterLocked(portal.moduleId, lockedMessage(portal))
			else
				options.onEnterOpen(portal.moduleId, portal.model)
			end
		end
	end
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function PortalController.start(opts: Options)
	options = opts

	CollectionService:GetInstanceAddedSignal("Portal"):Connect(function(instance)
		task.spawn(register, instance)
	end)
	CollectionService:GetInstanceRemovedSignal("Portal"):Connect(unregister)
	for _, instance in CollectionService:GetTagged("Portal") do
		task.spawn(register, instance)
	end

	opts.progress.onChanged(function()
		refresh(true)
	end)

	task.spawn(function()
		while true do
			task.wait(Config.PORTAL_POLL_INTERVAL)
			poll()
		end
	end)
end

-- Pauses entry detection (e.g. while a lesson is open). Unlocks that happened meanwhile
-- play when detection resumes, so the player sees them on returning to the Atrium.
function PortalController.setEnabled(on: boolean)
	enabled = on
	if on then
		local queued = pendingUnlocks
		pendingUnlocks = {}
		for _, portal in queued do
			portal.state = "open"
			playUnlock(portal)
		end
	end
end

-- Ignores entry into a portal for `seconds` (used after leaving a lesson).
function PortalController.suppress(moduleId: string, seconds: number)
	for _, portal in portals do
		if portal.moduleId == moduleId then
			portal.cooldownUntil = os.clock() + seconds
		end
	end
end

-- Re-applies every portal's look (e.g. after reduced motion changes).
function PortalController.refreshAll()
	for _, portal in portals do
		if portal.state then
			applyState(portal, portal.state)
		end
	end
end

function PortalController.getPortal(moduleId: string): Model?
	for model, portal in portals do
		if portal.moduleId == moduleId then
			return model
		end
	end
	return nil
end

return PortalController
