--!strict
-- The lesson screen (CLAUDE.md §5.2–5.5): enter/leave transitions, the shell (top bar, body,
-- bottom bar), card navigation, the quiz and its results, and the settings modal.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Theme = require(Shared:WaitForChild("Theme"))
local Types = require(Shared:WaitForChild("Types"))
local Index = require(Shared:WaitForChild("Lessons"):WaitForChild("Index"))

local Client = script.Parent.Parent
local UI = Client:WaitForChild("UI")
local Create = require(UI:WaitForChild("Create"))
local Cleanup = require(UI:WaitForChild("Cleanup"))
local Scale = require(UI:WaitForChild("Scale"))
local Context = require(UI:WaitForChild("Context"))
local Text = require(UI:WaitForChild("Text"))
local Components = UI:WaitForChild("Components")
local Button = require(Components:WaitForChild("Button"))
local IconButton = require(Components:WaitForChild("IconButton"))
local ProgressBar = require(Components:WaitForChild("ProgressBar"))
local Modal = require(Components:WaitForChild("Modal"))
local SegmentedControl = require(Components:WaitForChild("SegmentedControl"))
local Toggle = require(Components:WaitForChild("Toggle"))
local Cards = UI:WaitForChild("Cards")
local Common = require(Cards:WaitForChild("Common"))
local Result = require(Cards:WaitForChild("Result"))
local InputController = require(script.Parent:WaitForChild("InputController"))

local RENDERERS: { [string]: { render: (Common.CardCtx, Types.Card) -> Common.CardView } } = {
	concept = require(Cards:WaitForChild("Concept")),
	interactive = require(Cards:WaitForChild("Interactive")),
	compare = require(Cards:WaitForChild("Compare")),
	math = require(Cards:WaitForChild("Math")),
	quiz = require(Cards:WaitForChild("Quiz")),
	recap = require(Cards:WaitForChild("Recap")),
}

local REPORT_DELAY = 1 -- seconds; card-position reports are batched to stay under the rate limit

export type Deps = {
	progress: {
		get: () -> Types.ProgressPayload,
		report: (Types.LessonReport) -> (),
		setSettings: ({ [string]: any }) -> (),
		onSettingsChanged: (fn: (Types.Settings) -> ()) -> () -> (),
	},
	portals: {
		setEnabled: (on: boolean) -> (),
		suppress: (moduleId: string, seconds: number) -> (),
		getPortal: (moduleId: string) -> Model?,
	},
	toast: (text: string, kind: string?) -> (),
}

type Session = {
	moduleId: string,
	order: number,
	title: string,
	accent: Color3,
	cards: { Types.Card },
	quizIds: { string },
	index: number, -- 1..#cards, or #cards + 1 for the results screen
	answers: { [string]: number },
	orders: { [string]: { number } },
	attempt: number,
	reported: boolean,
	best: number,

	cleanup: Cleanup.Cleanup, -- lives as long as the session
	shellCleanup: Cleanup.Cleanup, -- rebuilt with the shell
	backdrop: ScreenGui,
	tint: Frame,
	wipe: Frame,
	ui: ScreenGui,
	stage: Frame,
	scaleHandle: Scale.ScaleHandle,
	shell: Frame?,
	cover: Frame,
	body: Frame?,
	page: CanvasGroup?,
	view: Common.CardView?,
	progressBar: ProgressBar.ProgressBar?,
	counter: TextLabel?,
	back: Button.Button?,
	nextButton: Button.Button?,
	ctx: Common.CardCtx?,
	modal: Modal.Modal?,
	settingsOpen: boolean,

	blur: BlurEffect,
	coreGui: { [Enum.CoreGuiType]: boolean },
	reportIndex: number?,
	reportScheduled: boolean,
}

local LessonController = {}

local deps: Deps
local session: Session? = nil
local busy = false

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------

local function settings(): Types.Settings
	return deps.progress.get().progress.settings
end

local function controls(): any?
	local playerModule = Players.LocalPlayer:FindFirstChild("PlayerScripts")
		and Players.LocalPlayer.PlayerScripts:FindFirstChild("PlayerModule")
	if not playerModule then
		return nil
	end
	local ok, module = pcall(require, playerModule)
	return if ok then module:GetControls() else nil
end

local function play(instance: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local tween = TweenService:Create(instance, info, goal)
	tween:Play()
	return tween
end

local function shuffle(list: { number }): { number }
	local out = table.clone(list)
	for i = #out, 2, -1 do
		local j = math.random(1, i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

local function cardIndexById(s: Session, id: string): number?
	for i, card in s.cards do
		if card.id == id then
			return i
		end
	end
	return nil
end

local function flushReport(s: Session)
	if s.reportIndex then
		deps.progress.report({ kind = "card", moduleId = s.moduleId, cardIndex = s.reportIndex })
		s.reportIndex = nil
	end
end

local function reportCard(s: Session, index: number)
	s.reportIndex = index
	if not s.reportScheduled then
		s.reportScheduled = true
		task.delay(REPORT_DELAY, function()
			s.reportScheduled = false
			flushReport(s)
		end)
	end
end

---------------------------------------------------------------------------
-- Quiz
---------------------------------------------------------------------------

local function quizApi(s: Session): Common.QuizApi
	return {
		chosen = function(cardId: string): number?
			return s.answers[cardId]
		end,
		choose = function(cardId: string, original: number)
			if s.answers[cardId] == nil then
				s.answers[cardId] = original
			end
		end,
		order = function(cardId: string): { number }
			local existing = s.orders[cardId]
			if existing then
				return existing
			end
			local index = cardIndexById(s, cardId)
			local card = if index then s.cards[index] else nil
			local identity = {}
			for i = 1, if card and card.options then #card.options else 0 do
				identity[i] = i
			end
			-- Authored order on the first attempt, shuffled on retries.
			local order = if s.attempt > 1 then shuffle(identity) else identity
			s.orders[cardId] = order
			return order
		end,
		number = function(cardId: string): (number, number)
			return table.find(s.quizIds, cardId) or 0, #s.quizIds
		end,
	}
end

local function score(s: Session): number
	local total = 0
	for _, id in s.quizIds do
		local card = s.cards[cardIndexById(s, id) :: number]
		if s.answers[id] ~= nil and s.answers[id] == card.answer then
			total += 1
		end
	end
	return total
end

local function reviewList(s: Session): { { id: string, title: string } }
	local list, seen = {}, {}
	for _, id in s.quizIds do
		local card = s.cards[cardIndexById(s, id) :: number]
		if s.answers[id] ~= card.answer and card.reviewCard and not seen[card.reviewCard] then
			local target = cardIndexById(s, card.reviewCard)
			if target then
				seen[card.reviewCard] = true
				table.insert(list, { id = card.reviewCard, title = s.cards[target].title or card.reviewCard })
			end
		end
	end
	return list
end

---------------------------------------------------------------------------
-- Rendering
---------------------------------------------------------------------------

local goTo: (s: Session, index: number, direction: number) -> ()
local close: () -> ()
local openSettings: (s: Session) -> ()

local function refreshNav(s: Session)
	local total = #s.cards
	local onResult = s.index > total
	if s.progressBar then
		s.progressBar:set(math.min(s.index, total))
	end
	if s.counter then
		s.counter.Text = `{math.min(s.index, total)}/{total}`
	end
	if s.back then
		s.back:setEnabled(s.index > 1)
	end
	local nextButton = s.nextButton
	if nextButton then
		nextButton.instance.Visible = not onResult
		local view = s.view
		local can = not (view and view.canAdvance) or (view.canAdvance :: () -> boolean)()
		nextButton:setEnabled(can)
		nextButton:setText(if s.index == total then "See results" else "Next")
	end
end

local function selectPrimary(s: Session)
	if not InputController.usingGamepad() then
		return
	end
	if s.modal then
		GuiService.SelectedObject = s.modal.closeButton
		return
	end
	local target = s.view and s.view.primary
	local ancestor: Instance? = target
	while ancestor and ancestor ~= s.ui do
		if ancestor:IsA("GuiObject") and not ancestor.Visible then
			target = nil
			break
		end
		ancestor = ancestor.Parent
	end
	if not target or not target.Selectable then
		target = if s.nextButton and s.nextButton.instance.Visible then s.nextButton.instance else nil
	end
	GuiService.SelectedObject = target
end

local function resultData(s: Session): Result.Data
	local value = score(s)
	local passed = value >= Config.PASS_MARK
	if not s.reported then
		s.reported = true
		s.best = math.max(s.best, value)
		deps.progress.report({ kind = "completed", moduleId = s.moduleId, score = value })
	end
	return {
		score = value,
		total = #s.quizIds,
		passMark = Config.PASS_MARK,
		passed = passed,
		best = s.best,
		isLastModule = s.order == #Config.MODULE_ORDER,
		review = reviewList(s),
		onRetry = function()
			s.attempt += 1
			s.answers = {}
			s.orders = {}
			s.reported = false
			local first = cardIndexById(s, s.quizIds[1])
			goTo(s, first or 1, -1)
		end,
		onExit = function()
			close()
		end,
		onReview = function(cardId: string)
			local target = cardIndexById(s, cardId)
			if target then
				goTo(s, target, -1)
			end
		end,
	}
end

local function renderView(s: Session, index: number): Common.CardView
	local ctx = s.ctx :: Common.CardCtx
	if index > #s.cards then
		return Result.render(ctx, resultData(s))
	end
	local card = s.cards[index]
	local renderer = RENDERERS[card.kind]
	if not renderer then
		local label = Text.new(ctx, "body", `Card kind "{card.kind}" has no renderer.`)
		return {
			root = label,
			destroy = function()
				label:Destroy()
			end,
		}
	end
	return renderer.render(ctx, card)
end

goTo = function(s: Session, index: number, direction: number)
	local body = s.body
	if not body then
		return
	end
	index = math.clamp(index, 1, #s.cards + 1)
	local animate = direction ~= 0
	local reduced = settings().reducedMotion

	-- Outgoing page
	local oldPage, oldView = s.page, s.view
	if oldPage then
		if animate then
			local goal: { [string]: any } = { GroupTransparency = 1 }
			if not reduced then
				goal.Position = UDim2.fromOffset(-Theme.cardSlide * direction, 0)
			end
			local info = if reduced
				then TweenInfo.new(Theme.duration.reducedFade)
				else TweenInfo.new(Theme.duration.screen * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			play(oldPage, info, goal).Completed:Connect(function()
				if oldView then
					oldView.destroy()
				end
				oldPage:Destroy()
			end)
		else
			if oldView then
				oldView.destroy()
			end
			oldPage:Destroy()
		end
	end

	-- Incoming page
	s.index = index
	local page = Create("CanvasGroup", {
		Name = "Page",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		GroupTransparency = if animate then 1 else 0,
		Position = UDim2.fromOffset(if animate and not reduced then Theme.cardSlide * direction else 0, 0),
	})
	local view = renderView(s, index)
	view.root.Parent = page
	page.Parent = body
	s.page, s.view = page, view
	if animate then
		local info = if reduced then TweenInfo.new(Theme.duration.reducedFade) else Theme.ease.enter
		play(page, info, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) })
	end

	refreshNav(s)
	selectPrimary(s)
	if index <= #s.cards then
		reportCard(s, index)
	end
end

local function next(s: Session)
	if busy or s.settingsOpen or s.index > #s.cards then
		return
	end
	local view = s.view
	if view and view.canAdvance and not view.canAdvance() then
		return
	end
	goTo(s, s.index + 1, 1)
end

local function prev(s: Session)
	if busy or s.settingsOpen or s.index <= 1 then
		return
	end
	goTo(s, s.index - 1, -1)
end

local function buildShell(s: Session)
	-- Preserve visibility before destroying the old shell. The transition cover lives on
	-- the stage so a resize or settings change cannot replace an in-flight fade.
	local visible = s.shell == nil or s.shell.Visible
	s.shellCleanup:destroy()
	s.shellCleanup = Cleanup.new()
	if s.modal then
		s.modal:destroy()
		s.modal = nil
	end
	local current = s.view
	if current then
		current.destroy()
		s.view = nil
	end
	s.page = nil

	local st = settings()
	local metrics = Context.metrics(s.scaleHandle:get(), st.textScale)
	local ctx: Common.CardCtx = {
		metrics = metrics,
		accent = s.accent,
		reducedMotion = st.reducedMotion,
		moduleId = s.moduleId,
		moduleOrder = s.order,
		quiz = quizApi(s),
		onChanged = function()
			refreshNav(s)
			if s.view and s.view.canAdvance and s.view.canAdvance() and InputController.usingGamepad() then
				GuiService.SelectedObject = if s.nextButton then s.nextButton.instance else nil
			end
		end,
	}
	s.ctx = ctx

	local shell = s.shellCleanup:add(Create("Frame", {
		Name = "Shell",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = visible,
		SelectionGroup = true,
		Parent = s.stage,
	}))
	s.shell = shell
	local pad = Theme.space.xl
	local bar = metrics.bar

	-- Top bar: module title · progress · counter · settings · close
	local top = Create("Frame", {
		Name = "TopBar",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, bar),
		Parent = shell,
	}, {
		Create("UIPadding", { PaddingLeft = UDim.new(0, pad), PaddingRight = UDim.new(0, pad) }),
		Create("Frame", {
			Name = "Divider",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, -pad, 1, 0),
			Size = UDim2.new(1, 2 * pad, 0, 1),
			BackgroundColor3 = Theme.color.border,
			BorderSizePixel = 0,
		}),
	})
	local dot = metrics.text.label * 0.6
	Create("Frame", {
		Name = "AccentDot",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(dot, dot),
		BackgroundColor3 = s.accent,
		Parent = top,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
	})
	local right = Create("Frame", {
		Name = "Right",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, metrics.tap),
		BackgroundTransparency = 1,
		Parent = top,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, Theme.space.sm),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local counterWidth = math.ceil(metrics.text.mono * 3.2)
	s.counter = Create("TextLabel", {
		Name = "Counter",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(counterWidth, metrics.tap),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Theme.color.textMuted,
		FontFace = Theme.font.mono,
		TextSize = metrics.text.label,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = right,
	})
	IconButton.new(ctx, {
		glyph = "⚙",
		name = "Settings",
		layoutOrder = 2,
		onActivated = function()
			openSettings(s)
		end,
	}).Parent = right
	IconButton.new(ctx, {
		glyph = "✕",
		name = "Close",
		layoutOrder = 3,
		onActivated = function()
			close()
		end,
	}).Parent = right

	local rightWidth = counterWidth + 2 * metrics.tap + 2 * Theme.space.sm
	local narrow = s.stage.AbsoluteSize.X < 560
	local titleShare = if metrics.compact then 0.5 else 0.42
	Create("TextLabel", {
		Name = "Title",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, dot + Theme.space.md, 0.5, 0),
		Size = if narrow
			then UDim2.new(1, -(rightWidth + dot + 2 * Theme.space.md), 0, metrics.text.label * 1.4)
			else UDim2.new(titleShare, -(dot + Theme.space.md), 0, metrics.text.label * 1.4),
		BackgroundTransparency = 1,
		Text = if narrow then `Module {s.order}` else `Module {s.order} · {s.title}`,
		TextColor3 = Theme.color.text,
		FontFace = Theme.font.medium,
		TextSize = metrics.text.label,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = top,
	})
	local progressBar = ProgressBar.new(ctx, #s.cards)
	progressBar.instance.AnchorPoint = Vector2.new(0, 0.5)
	progressBar.instance.Position = UDim2.new(titleShare, Theme.space.xl, 0.5, 0)
	progressBar.instance.Size = UDim2.new(1 - titleShare, -(rightWidth + 2 * Theme.space.xl), 0, 6)
	if narrow then
		progressBar.instance.AnchorPoint = Vector2.new(0, 1)
		progressBar.instance.Position = UDim2.fromScale(0, 1)
		progressBar.instance.Size = UDim2.new(1, 0, 0, 6)
	end
	progressBar.instance.Parent = top
	s.progressBar = progressBar

	-- Bottom bar: Back · Next
	local bottom = Create("Frame", {
		Name = "BottomBar",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, bar),
		BackgroundTransparency = 1,
		Parent = shell,
	}, {
		Create("UIPadding", { PaddingLeft = UDim.new(0, pad), PaddingRight = UDim.new(0, pad) }),
		Create("Frame", {
			Name = "Divider",
			Position = UDim2.fromOffset(-pad, 0),
			Size = UDim2.new(1, 2 * pad, 0, 1),
			BackgroundColor3 = Theme.color.border,
			BorderSizePixel = 0,
		}),
	})
	local back = Button.new(ctx, {
		text = "Back",
		glyphLeft = "←",
		variant = "secondary",
		onActivated = function()
			prev(s)
		end,
	})
	back.instance.AnchorPoint = Vector2.new(0, 0.5)
	back.instance.Position = UDim2.fromScale(0, 0.5)
	back.instance.Parent = bottom
	s.back = back
	local nextButton = Button.new(ctx, {
		text = "Next",
		glyphRight = "→",
		name = "Next",
		onActivated = function()
			next(s)
		end,
	})
	nextButton.instance.AnchorPoint = Vector2.new(1, 0.5)
	nextButton.instance.Position = UDim2.fromScale(1, 0.5)
	nextButton.instance.Parent = bottom
	s.nextButton = nextButton

	-- Body between the bars
	s.body = Create("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, bar),
		Size = UDim2.new(1, 0, 1, -2 * bar),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = shell,
	}, {
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, Theme.cardPadding),
			PaddingRight = UDim.new(0, Theme.cardPadding),
			PaddingTop = UDim.new(0, Theme.space.xl),
			PaddingBottom = UDim.new(0, Theme.space.lg),
		}),
	})

	goTo(s, s.index, 0)
	if s.settingsOpen then
		openSettings(s)
	end
end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------

local function closeSettings(s: Session)
	s.settingsOpen = false
	if s.modal then
		s.modal:destroy()
		s.modal = nil
	end
	selectPrimary(s)
end

openSettings = function(s: Session)
	if s.modal then
		return
	end
	local ctx = s.ctx :: Common.CardCtx
	s.settingsOpen = true
	local modal = Modal.new(ctx, {
		title = "Settings",
		parent = s.shell :: Frame,
		width = if ctx.metrics.compact then 900 else 600,
		onClose = function()
			closeSettings(s)
		end,
	})
	s.modal = modal
	local st = settings()

	Text.new(ctx, "label", "Text size", { LayoutOrder = 1, TextColor3 = Theme.color.textMuted, Parent = modal.content })
	local selected = 1
	for i, value in Config.TEXT_SCALES do
		if math.abs(value - st.textScale) < 1e-3 then
			selected = i
		end
	end
	local sizes = {}
	for _, value in Config.TEXT_SCALES do
		table.insert(sizes, `{math.floor(value * 100 + 0.5)}%`)
	end
	local segmented = SegmentedControl.new(ctx, {
		options = sizes,
		selected = selected,
		layoutOrder = 2,
		onChanged = function(index)
			deps.progress.setSettings({ textScale = Config.TEXT_SCALES[index] })
		end,
	})
	segmented.instance.Parent = modal.content
	Toggle.new(ctx, {
		label = "Reduce motion",
		value = st.reducedMotion,
		layoutOrder = 3,
		onChanged = function(value)
			deps.progress.setSettings({ reducedMotion = value })
		end,
	}).Parent = modal.content
	Toggle.new(ctx, {
		label = "Sound",
		value = not st.muted,
		layoutOrder = 4,
		onChanged = function(value)
			deps.progress.setSettings({ muted = not value })
		end,
	}).Parent = modal.content

	if InputController.usingGamepad() then
		GuiService.SelectedObject = segmented.instance:FindFirstChild("Option" .. selected) :: any
	end
end

---------------------------------------------------------------------------
-- Open / close
---------------------------------------------------------------------------

local CORE_TYPES = { Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Chat }

export type OpenOptions = { instant: boolean? }

function LessonController.open(moduleId: string, startCard: number?, opts: OpenOptions?)
	if session or busy then
		return
	end
	local meta = Index.get(moduleId)
	local content = Index.content(moduleId)
	if not meta then
		return
	end
	if not content then
		deps.toast(`{meta.title} is coming soon.`, "info")
		return
	end
	busy = true
	local instant = opts and opts.instant == true
	local st = settings()
	local accent = Theme.accent[moduleId]
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	deps.portals.setEnabled(false)
	local ctl = controls()
	if ctl then
		ctl:Disable()
	end

	local quizIds = {}
	for _, card in content.cards do
		if card.kind == "quiz" then
			table.insert(quizIds, card.id)
		end
	end

	-- Resume at the saved card, but quiz attempts aren't saved: resume a quiz from its start.
	local saved = deps.progress.get().progress.modules[moduleId]
	local index = math.clamp(startCard or (if saved then saved.lastCard else 1), 1, #content.cards)
	local firstQuiz = nil
	for i, card in content.cards do
		if card.kind == "quiz" then
			firstQuiz = i
			break
		end
	end
	if firstQuiz and index > firstQuiz then
		index = firstQuiz
	end

	local cleanup = Cleanup.new()
	-- PlayerModule can leave its mobile controls visible after Disable(). Hide their
	-- ScreenGui for the session, including one created after the lesson has opened.
	local function hideTouchControls(child: Instance)
		if child.Name == "TouchGui" and child:IsA("ScreenGui") then
			local wasEnabled = child.Enabled
			child.Enabled = false
			cleanup:add(function()
				child.Enabled = wasEnabled
			end)
		end
	end
	local touchGui = playerGui:FindFirstChild("TouchGui")
	if touchGui then
		hideTouchControls(touchGui)
	end
	cleanup:connect(playerGui.ChildAdded, hideTouchControls)
	local backdrop = cleanup:add(Create("ScreenGui", {
		Name = "LessonBackdrop",
		DisplayOrder = Theme.lesson.displayOrderBackdrop,
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.None,
		ClipToDeviceSafeArea = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	}))
	local tint = Create("Frame", {
		Name = "Tint",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.color.bg,
		BackgroundTransparency = 1,
		Active = false,
		Parent = backdrop,
	}, {
		Create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Theme.color.bg, Theme.color.surface),
		}),
	})
	local wipe = Create("Frame", {
		Name = "Wipe",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = accent,
		BackgroundTransparency = 1,
		Parent = backdrop,
	})
	local ui = cleanup:add(Create("ScreenGui", {
		Name = "LessonUI",
		DisplayOrder = Theme.lesson.displayOrderUI,
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	}))
	local stage = Create("Frame", { Name = "Stage", BackgroundTransparency = 1, Parent = ui })
	local cover = Create("Frame", {
		Name = "Cover",
		BackgroundColor3 = Theme.color.bg,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 100,
		Parent = stage,
	})
	local scaleHandle = Scale.attach(ui, stage)
	cleanup:add(scaleHandle)

	local blur = Instance.new("BlurEffect")
	blur.Name = "LessonBlur"
	blur.Size = 0
	blur.Parent = workspace.CurrentCamera
	cleanup:add(blur)

	local coreGui = {}
	for _, coreType in CORE_TYPES do
		coreGui[coreType] = StarterGui:GetCoreGuiEnabled(coreType)
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreType, false)
	end

	local s: Session = {
		moduleId = moduleId,
		order = meta.order,
		title = meta.title,
		accent = accent,
		cards = content.cards,
		quizIds = quizIds,
		index = index,
		answers = {},
		orders = {},
		attempt = 1,
		reported = false,
		best = if saved then saved.bestScore else 0,
		cleanup = cleanup,
		shellCleanup = Cleanup.new(),
		backdrop = backdrop,
		tint = tint,
		wipe = wipe,
		ui = ui,
		stage = stage,
		scaleHandle = scaleHandle,
		shell = nil,
		cover = cover,
		body = nil,
		page = nil,
		view = nil,
		progressBar = nil,
		counter = nil,
		back = nil,
		nextButton = nil,
		ctx = nil,
		modal = nil,
		settingsOpen = false,
		blur = blur,
		coreGui = coreGui,
		reportIndex = nil,
		reportScheduled = false,
	}
	session = s
	cleanup:add(function()
		if s.view then
			s.view.destroy()
			s.view = nil
		end
		s.shellCleanup:destroy()
	end)

	buildShell(s)
	local initialShell = s.shell :: Frame
	initialShell.Visible = false
	cleanup:add(scaleHandle:onChanged(function()
		if session == s then
			buildShell(s)
		end
	end))
	cleanup:add(deps.progress.onSettingsChanged(function()
		if session == s then
			buildShell(s)
		end
	end))

	InputController.start({
		focus = function()
			selectPrimary(s)
		end,
		prev = function()
			prev(s)
		end,
		next = function()
			next(s)
		end,
		close = function()
			if s.modal then
				closeSettings(s)
			else
				close()
			end
		end,
		activate = function()
			if s.modal then
				return
			end
			if s.nextButton and s.nextButton.instance.Visible then
				next(s)
			elseif s.view and s.view.activate then
				s.view.activate() -- e.g. the results screen's main action
			end
		end,
		option = function(i)
			if not s.modal and s.view and s.view.onOption then
				s.view.onOption(i)
			end
		end,
	})

	deps.progress.report({ kind = "opened", moduleId = moduleId, cardIndex = index })

	-- Transition in: camera eases toward the portal, an accent wipe, then the lesson emerges.
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local portal = deps.portals.getPortal(moduleId)
	local surface = portal and portal:FindFirstChild("Surface") :: BasePart?
	local reveal = function(duration: number)
		tint.BackgroundTransparency = Theme.lesson.backdropTransparency
		local currentShell = s.shell :: Frame
		currentShell.Visible = true
		local info = TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		play(s.cover, info, { BackgroundTransparency = 1 })
		play(wipe, info, { BackgroundTransparency = 1 })
	end

	if st.reducedMotion or instant or not surface then
		blur.Size = Theme.lesson.blurSize
		local d = Theme.duration.reducedFade
		tint.BackgroundTransparency = 1
		local currentShell = s.shell :: Frame
		currentShell.Visible = true
		play(tint, TweenInfo.new(d), { BackgroundTransparency = Theme.lesson.backdropTransparency })
		play(s.cover, TweenInfo.new(d), { BackgroundTransparency = 1 })
		task.wait(d)
	else
		local surfacePart = surface :: BasePart
		local front = surfacePart.CFrame.XVector
		local target = surfacePart.Position
		play(camera, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			CFrame = CFrame.lookAt(target + front * 5 + Vector3.new(0, 0.5, 0), target),
		})
		play(blur, TweenInfo.new(0.5), { Size = Theme.lesson.blurSize })
		task.wait(0.3)
		play(wipe, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 0 })
		task.wait(0.25)
		reveal(0.25)
		task.wait(0.25)
	end
	-- Resolve the current shell here: Scale.attach can rebuild it while open yields.
	local currentShell = s.shell :: Frame
	currentShell.Visible = true
	s.cover.BackgroundTransparency = 1
	s.cover.Visible = false
	selectPrimary(s)
	busy = false
end

close = function()
	local s = session
	if not s or busy then
		return
	end
	busy = true
	InputController.stop()
	GuiService.SelectedObject = nil
	flushReport(s)
	if s.modal then
		s.modal:destroy()
		s.modal = nil
	end
	local reduced = settings().reducedMotion
	local cover = s.cover

	-- Hide the lesson behind the cover, then restore the world underneath it.
	cover.Visible = true
	local d = if reduced then Theme.duration.reducedFade else 0.2
	play(cover, TweenInfo.new(d, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 0 })
	task.wait(d)

	-- Place the character ~8 studs in front of the portal, facing away from it.
	local character = Players.LocalPlayer.Character
	local portal = deps.portals.getPortal(s.moduleId)
	local surface = portal and portal:FindFirstChild("Surface") :: BasePart?
	local trigger = portal and portal:FindFirstChild("Trigger") :: BasePart?
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if character and surface and trigger and root then
		local front = (surface.CFrame.XVector * Vector3.new(1, 0, 1)).Unit
		local base = Vector3.new(trigger.Position.X, root.Position.Y, trigger.Position.Z) + front * 8
		root.AssemblyLinearVelocity = Vector3.zero
		character:PivotTo(CFrame.lookAt(base, base + front))
	end
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom

	s.shell.Visible = false
	local out = if reduced then Theme.duration.reducedFade else 0.35
	play(s.tint, TweenInfo.new(out), { BackgroundTransparency = 1 })
	play(s.wipe, TweenInfo.new(out), { BackgroundTransparency = 1 })
	play(s.blur, TweenInfo.new(out), { Size = 0 })
	task.wait(out)

	for coreType, enabled in s.coreGui do
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreType, enabled)
	end
	local ctl = controls()
	if ctl then
		ctl:Enable()
	end
	s.cleanup:destroy()
	session = nil
	deps.portals.suppress(s.moduleId, Config.PORTAL_REENTRY_COOLDOWN)
	deps.portals.setEnabled(true)
	busy = false
end

function LessonController.close()
	close()
end

function LessonController.isOpen(): boolean
	return session ~= nil
end

function LessonController.start(dependencies: Deps)
	deps = dependencies
end

return LessonController
