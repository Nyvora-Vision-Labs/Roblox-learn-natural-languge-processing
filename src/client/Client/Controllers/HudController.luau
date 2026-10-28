--!strict
-- Around the lessons (CLAUDE.md §5.6): the journey tracker, the first-visit cards, and graduation.
--   Journey tracker: top-center, five nodes: filled (done), pulsing ring (current), outline (locked).
--   First visit: up to three welcome cards, skippable, shown once (progress.seenIntro).
--   Graduation: after Module 5, a recap screen; afterwards every portal stays lit.
-- The tracker hides while a lesson or overlay is open.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Theme = require(Shared:WaitForChild("Theme"))
local Types = require(Shared:WaitForChild("Types"))
local Lessons = Shared:WaitForChild("Lessons")
local Index = require(Lessons:WaitForChild("Index"))
local Welcome = require(Lessons:WaitForChild("Welcome"))
local Graduation = require(Lessons:WaitForChild("Graduation"))

local Client = script.Parent.Parent
local UI = Client:WaitForChild("UI")
local Create = require(UI:WaitForChild("Create"))
local Cleanup = require(UI:WaitForChild("Cleanup"))
local Scale = require(UI:WaitForChild("Scale"))
local Context = require(UI:WaitForChild("Context"))
local Text = require(UI:WaitForChild("Text"))
local Button = require(UI:WaitForChild("Components"):WaitForChild("Button"))
local Sound = require(UI:WaitForChild("Sound"))
local InputController = require(script.Parent:WaitForChild("InputController"))

export type Deps = {
	progress: {
		get: () -> Types.ProgressPayload,
		onChanged: (fn: (Types.ProgressPayload) -> ()) -> () -> (),
		onSettingsChanged: (fn: (Types.Settings) -> ()) -> () -> (),
		setSettings: ({ [string]: any }) -> (),
	},
	portals: { setGraduated: (on: boolean) -> () },
}

local NODE = 30
local LINK = 24
local TOP = 8
local TRACKER_MIN_SCALE, TRACKER_MAX_SCALE = 0.8, 1.2
local CAPTION_SIZE = 18 -- reference px; ≥ 14 px on screen at the minimum scale

local HudController = {}

local deps: Deps
local playerGui: PlayerGui
local hud: ScreenGui
local trackerHolder: Frame
local trackerCleanup = Cleanup.new()
local overlayOpen = false
local lessonOpen = false
local graduationPending = false
local wasAllDone = false

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function progress(): Types.Progress
	return deps.progress.get().progress
end

local function allDone(p: Types.Progress): boolean
	for _, id in Config.MODULE_ORDER do
		if not p.modules[id].completed then
			return false
		end
	end
	return true
end

-- The first module that is open but not completed, if any.
local function currentIndex(p: Types.Progress): number?
	for i, id in Config.MODULE_ORDER do
		if not p.modules[id].completed then
			return i
		end
	end
	return nil
end

local function controls(): any?
	local scripts = Players.LocalPlayer:FindFirstChild("PlayerScripts")
	local module = scripts and scripts:FindFirstChild("PlayerModule")
	if not module then
		return nil
	end
	local ok, playerModule = pcall(require, module)
	return if ok then playerModule:GetControls() else nil
end

local function ctxFor(gui: GuiBase2d): Context.Ctx
	local st = progress().settings
	return {
		metrics = Context.metrics(Scale.compute(gui.AbsoluteSize), st.textScale),
		accent = Theme.accent[Config.MODULE_ORDER[currentIndex(progress()) or #Config.MODULE_ORDER]],
		reducedMotion = st.reducedMotion,
	}
end

---------------------------------------------------------------------------
-- Journey tracker
---------------------------------------------------------------------------

local showGraduation: () -> ()

local function buildTracker()
	trackerCleanup:destroy()
	trackerCleanup = Cleanup.new()
	for _, child in trackerHolder:GetChildren() do
		child:Destroy()
	end
	local p = progress()
	local ctx = ctxFor(hud)
	local current = currentIndex(p)
	local done = allDone(p)
	local count = #Config.MODULE_ORDER

	-- A small HUD shouldn't shrink with the lesson stage on phones; clamp its scale.
	Create("UIScale", { Scale = math.clamp(ctx.metrics.scale, TRACKER_MIN_SCALE, TRACKER_MAX_SCALE), Parent = trackerHolder })

	local pill = Create("TextButton", {
		Name = "Tracker",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Theme.color.surface,
		BackgroundTransparency = 0.1,
		AutoButtonColor = false,
		Active = done,
		Selectable = done,
		Text = "",
		Parent = trackerHolder,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 18) }),
		Create("UIStroke", { Color = Theme.color.border, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, Theme.space.lg),
			PaddingRight = UDim.new(0, Theme.space.lg),
			PaddingTop = UDim.new(0, Theme.space.sm),
			PaddingBottom = UDim.new(0, Theme.space.sm),
		}),
		Create("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, Theme.space.xs),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local row = Create("Frame", {
		Name = "Nodes",
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(count * NODE + (count - 1) * LINK, NODE),
		Parent = pill,
	})
	for i, id in Config.MODULE_ORDER do
		local accent = Theme.accent[id]
		local isDone = p.modules[id].completed
		local isCurrent = i == current
		local x = (i - 1) * (NODE + LINK)
		if i < count then
			Create("Frame", {
				Name = "Link" .. i,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromOffset(x + NODE, NODE / 2),
				Size = UDim2.fromOffset(LINK, 2),
				BackgroundColor3 = if isDone then accent else Theme.color.border,
				BorderSizePixel = 0,
				Parent = row,
			})
		end
		local node = Create("TextLabel", {
			Name = "Node" .. i,
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.fromOffset(NODE, NODE),
			BackgroundColor3 = if isDone then accent else Theme.color.bg,
			Text = tostring(i),
			TextColor3 = if isDone then Theme.color.bg elseif isCurrent then accent else Theme.color.textFaint,
			FontFace = Theme.font.bold,
			TextSize = 18, -- ≥ 14 px on screen at the minimum tracker scale
			Parent = row,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		})
		local ring = Create("UIStroke", {
			Color = if isDone or isCurrent then accent else Theme.color.border,
			Thickness = if isCurrent then 3 else 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = node,
		})
		if isCurrent and not ctx.reducedMotion then
			local tween = TweenService:Create(
				ring,
				TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Transparency = 0.75 }
			)
			tween:Play()
			trackerCleanup:add(function()
				tween:Cancel()
			end)
		end
	end
	local caption
	if done then
		caption = "All five modules complete. Tap to see your recap."
	elseif current then
		local meta = Index.at(current)
		caption = `Next: {if meta then meta.title else ""}`
	else
		caption = ""
	end
	Create("TextLabel", {
		Name = "Caption",
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		Text = caption,
		TextColor3 = Theme.color.textMuted,
		FontFace = Theme.font.medium,
		TextSize = CAPTION_SIZE,
		Parent = pill,
	})
	if done then
		trackerCleanup:add(pill.Activated:Connect(function()
			showGraduation()
		end))
	end
end

local function refreshVisibility()
	hud.Enabled = not lessonOpen and not overlayOpen
end

---------------------------------------------------------------------------
-- Overlays (welcome cards, graduation)
---------------------------------------------------------------------------

type Overlay = { panel: Frame, ctx: Context.Ctx, close: () -> () }

local function openOverlay(name: string, onClosed: (() -> ())?): Overlay
	overlayOpen = true
	refreshVisibility()
	local ctl = controls()
	if ctl then
		ctl:Disable()
	end
	local gui = Create("ScreenGui", {
		Name = name,
		DisplayOrder = 30,
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	local stage = Create("Frame", { Name = "Stage", BackgroundTransparency = 1, Parent = gui })
	local scaleHandle = Scale.attach(gui, stage)
	local ctx = ctxFor(gui)
	ctx.metrics = Context.metrics(scaleHandle:get(), progress().settings.textScale)
	local scrim = Create("Frame", {
		Name = "Scrim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.color.bg,
		BackgroundTransparency = if ctx.reducedMotion then 0.25 else 1,
		Parent = stage,
	})
	if not ctx.reducedMotion then
		TweenService:Create(scrim, Theme.ease.state, { BackgroundTransparency = 0.25 }):Play()
	end
	-- The card is as tall as its content but never taller than the stage; beyond that it scrolls
	-- (a phone in landscape has only ~720 reference px of height for text that's been enlarged).
	local width = if ctx.metrics.compact then 1000 else 680
	local card = Create("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, 0),
		BackgroundColor3 = Theme.color.surface,
		Parent = stage,
	}, {
		Create("UICorner", { CornerRadius = Theme.radius.card }),
		Create("UIStroke", { Color = Theme.color.border, Thickness = 1 }),
	})
	local scroll = Create("ScrollingFrame", {
		Name = "Scroll",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.color.border,
		Selectable = false,
		Parent = card,
	})
	local panel = Create("Frame", {
		Name = "Panel",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = scroll,
	}, {
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, Theme.cardPadding),
			PaddingRight = UDim.new(0, Theme.cardPadding),
			PaddingTop = UDim.new(0, Theme.cardPadding),
			PaddingBottom = UDim.new(0, Theme.cardPadding),
		}),
		Create("UIListLayout", { Padding = UDim.new(0, Theme.space.lg), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local function fit()
		local scale = math.max(scaleHandle:get().scale, 1e-3)
		local stageHeight = stage.AbsoluteSize.Y / scale
		local contentHeight = panel.AbsoluteSize.Y / scale
		card.Size = UDim2.fromOffset(width, math.min(contentHeight, stageHeight - 2 * Theme.space.xl))
	end
	panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	stage:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	task.defer(fit)
	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		GuiService.SelectedObject = nil
		scaleHandle:destroy()
		gui:Destroy()
		local c = controls()
		if c then
			c:Enable()
		end
		overlayOpen = false
		refreshVisibility()
		if onClosed then
			onClosed()
		end
	end
	return { panel = panel, ctx = ctx, close = close }
end

local function buttonRow(ctx: Context.Ctx, parent: Instance, order: number): Frame
	return Create("Frame", {
		Name = "Buttons",
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, ctx.metrics.tap),
		Parent = parent,
	})
end

local function showWelcome()
	local overlay = openOverlay("Welcome", function()
		deps.progress.setSettings({ seenIntro = true })
	end)
	local ctx, panel = overlay.ctx, overlay.panel
	local index = 1
	local title = Text.new(ctx, "h1", "", { LayoutOrder = 2, Parent = panel })
	local body = Text.new(ctx, "body", "", { LayoutOrder = 3, TextColor3 = Theme.color.textMuted, Parent = panel })
	local dots = Create("Frame", {
		Name = "Dots",
		LayoutOrder = 4,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 10),
		Parent = panel,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Theme.space.sm),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local dotFrames = {}
	for i = 1, #Welcome do
		dotFrames[i] = Create("Frame", {
			LayoutOrder = i,
			Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = Theme.color.border,
			Parent = dots,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		})
	end
	local row = buttonRow(ctx, panel, 5)
	local nextButton
	local skip = Button.new(ctx, {
		text = "Skip",
		name = "Skip",
		variant = "ghost",
		onActivated = overlay.close,
	})
	skip.instance.Parent = row
	nextButton = Button.new(ctx, {
		text = "Next",
		name = "WelcomeNext",
		glyphRight = "→",
		onActivated = function()
			if index >= #Welcome then
				overlay.close()
				return
			end
			index += 1
			title.Text = Welcome[index].title
			body.Text = Welcome[index].body
			for i, d in dotFrames do
				d.BackgroundColor3 = if i == index then ctx.accent else Theme.color.border
			end
			if index == #Welcome then
				nextButton:setText("Let's go")
			end
		end,
	})
	nextButton.instance.AnchorPoint = Vector2.new(1, 0)
	nextButton.instance.Position = UDim2.fromScale(1, 0)
	nextButton.instance.Parent = row

	title.Text = Welcome[1].title
	body.Text = Welcome[1].body
	dotFrames[1].BackgroundColor3 = ctx.accent
	if InputController.usingGamepad() then
		GuiService.SelectedObject = nextButton.instance
	end
end

showGraduation = function()
	if overlayOpen then
		return
	end
	Sound.play("complete")
	local overlay = openOverlay("Graduation", function()
		deps.portals.setGraduated(true)
	end)
	local ctx, panel = overlay.ctx, overlay.panel
	Text.new(ctx, "label", "Graduation", { LayoutOrder = 1, TextColor3 = Theme.color.success, Parent = panel })
	Text.new(ctx, "h1", Graduation.title, { LayoutOrder = 2, Parent = panel })
	local list = Create("Frame", {
		Name = "Lines",
		LayoutOrder = 3,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = panel,
	}, {
		Create("UIListLayout", { Padding = UDim.new(0, Theme.space.md), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local dot = ctx.metrics.text.body * 0.6
	for i, id in Config.MODULE_ORDER do
		local line = Create("Frame", {
			LayoutOrder = i,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = list,
		})
		Create("Frame", {
			Position = UDim2.fromOffset(0, ctx.metrics.text.body * 0.35),
			Size = UDim2.fromOffset(dot, dot),
			BackgroundColor3 = Theme.accent[id],
			Parent = line,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		})
		local meta = Index.get(id)
		Text.new(ctx, "body", `<b>{if meta then meta.title else id}.</b> {Graduation.lines[id]}`, {
			Position = UDim2.fromOffset(dot + Theme.space.md, 0),
			Size = UDim2.new(1, -(dot + Theme.space.md), 0, 0),
			Parent = line,
		})
	end
	Text.new(ctx, "label", Graduation.lineage, {
		LayoutOrder = 4,
		TextColor3 = Theme.color.text,
		Parent = panel,
	})
	local row = buttonRow(ctx, panel, 5)
	local back = Button.new(ctx, {
		text = "Back to the Atrium",
		name = "GraduationClose",
		onActivated = overlay.close,
	})
	back.instance.AnchorPoint = Vector2.new(1, 0)
	back.instance.Position = UDim2.fromScale(1, 0)
	back.instance.Parent = row
	if InputController.usingGamepad() then
		GuiService.SelectedObject = back.instance
	end
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------

function HudController.start(dependencies: Deps)
	deps = dependencies
	playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui

	hud = Create("ScreenGui", {
		Name = "Hud",
		DisplayOrder = 10,
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	trackerHolder = Create("Frame", {
		Name = "Holder",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, TOP),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Parent = hud,
	})
	buildTracker()
	hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(buildTracker)
	deps.progress.onSettingsChanged(function()
		buildTracker()
	end)

	-- Lessons: hide the tracker while one is open; graduate after returning to the Atrium.
	local function lessonChanged()
		lessonOpen = playerGui:FindFirstChild("LessonUI") ~= nil
		refreshVisibility()
		if not lessonOpen and graduationPending then
			graduationPending = false
			task.delay(0.8, showGraduation)
		end
	end
	playerGui.ChildAdded:Connect(function(child)
		if child.Name == "LessonUI" then
			lessonChanged()
		end
	end)
	playerGui.ChildRemoved:Connect(function(child)
		if child.Name == "LessonUI" then
			lessonChanged()
		end
	end)

	wasAllDone = allDone(progress())
	if wasAllDone then
		deps.portals.setGraduated(true)
	end
	deps.progress.onChanged(function(payload)
		buildTracker()
		local now = allDone(payload.progress)
		if now and not wasAllDone then
			if lessonOpen then
				graduationPending = true
			else
				task.delay(0.8, showGraduation)
			end
		elseif not now then
			deps.portals.setGraduated(false)
		end
		wasAllDone = now
	end)

	if not progress().seenIntro then
		task.delay(1, showWelcome)
	end
end

return HudController
