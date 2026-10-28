--!strict
-- Shared card pieces: the CardView contract, text column, terms, "Go deeper", and the
-- two-column layout (which becomes a Learn / Explore toggle in compact mode).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Types = require(Shared:WaitForChild("Types"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Context = require(UI:WaitForChild("Context"))
local Text = require(UI:WaitForChild("Text"))
local Components = UI:WaitForChild("Components")
local Button = require(Components:WaitForChild("Button"))
local Chip = require(Components:WaitForChild("Chip"))
local SegmentedControl = require(Components:WaitForChild("SegmentedControl"))

-- What every card renderer returns.
export type CardView = {
	root: GuiObject,
	primary: GuiObject?, -- gets gamepad selection when the card opens
	canAdvance: (() -> boolean)?, -- Next stays disabled while this returns false
	onOption: ((index: number) -> ())?, -- keys 1–4 on quiz cards
	activate: (() -> ())?, -- Enter when the bottom bar's Next is hidden
	destroy: () -> (),
}

export type QuizApi = {
	chosen: (cardId: string) -> number?, -- original option index the player picked, if any
	choose: (cardId: string, original: number) -> (),
	order: (cardId: string) -> { number }, -- display position → original option index
	number: (cardId: string) -> (number, number), -- this question's position, total questions
}

export type CardCtx = Context.Ctx & {
	moduleId: string,
	moduleOrder: number,
	quiz: QuizApi,
	onChanged: () -> (), -- the card's canAdvance may have changed
}

local Common = {}

function Common.list(name: string, padding: number, props: { [string]: any }?): Frame
	local frame = Create("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		Create("UIListLayout", { Padding = UDim.new(0, padding), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	if props then
		for k, v in props do
			(frame :: any)[k] = v
		end
	end
	return frame
end

-- A vertical scroller that grows with its content. Returns (scroller, content list).
function Common.scroller(name: string): (ScrollingFrame, Frame)
	local scroller = Create("ScrollingFrame", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.color.border,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		Selectable = false,
	})
	local content = Common.list("Content", Theme.space.lg, {
		Parent = scroller,
	})
	Create("UIPadding", {
		PaddingRight = UDim.new(0, Theme.space.lg), -- room for the scroll bar
		PaddingBottom = UDim.new(0, Theme.space.sm),
		Parent = content,
	})
	return scroller, content
end

-- Centers `child` horizontally with a maximum width.
function Common.centered(child: GuiObject, maxWidth: number, compactScale: number?): Frame
	local holder = Create("Frame", {
		Name = "Centered",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	})
	child.AnchorPoint = Vector2.new(0.5, 0)
	child.Position = UDim2.fromScale(0.5, 0)
	child.Size = UDim2.fromScale(1, 1)
	-- Compact text is enlarged to stay readable. Keep its width in screen pixels too,
	-- otherwise a portrait phone gets a narrow column with large empty side margins.
	Create("UISizeConstraint", { MaxSize = Vector2.new(maxWidth / (compactScale or 1), math.huge), Parent = child })
	child.Parent = holder
	return holder
end

function Common.title(ctx: CardCtx, text: string, order: number, parent: Instance)
	Text.new(ctx, "h1", text, { LayoutOrder = order, Parent = parent })
end

function Common.body(ctx: CardCtx, text: string, order: number, parent: Instance)
	Text.new(ctx, "body", text, { LayoutOrder = order, Parent = parent })
end

function Common.terms(ctx: CardCtx, terms: { string }?, order: number, parent: Instance)
	if not terms or #terms == 0 then
		return
	end
	local row = Create("Frame", {
		Name = "Terms",
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = parent,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Wraps = true,
			Padding = UDim.new(0, Theme.space.sm),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, term in terms do
		Chip.new(ctx, { text = term, layoutOrder = i }).Parent = row
	end
end

-- "Go deeper ▸" reveals optional math in place. Returns the toggle button, or nil.
function Common.deeper(ctx: CardCtx, text: string?, order: number, parent: Instance): TextButton?
	if not text or text == "" then
		return nil
	end
	local holder = Common.list("Deeper", Theme.space.sm, { LayoutOrder = order, Parent = parent })
	local panel = Create("Frame", {
		Name = "Panel",
		LayoutOrder = 2,
		Visible = false,
		BackgroundColor3 = Theme.color.surfaceRaised,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = holder,
	}, {
		Create("UICorner", { CornerRadius = Theme.radius.button }),
		Create("UIStroke", { Color = Theme.color.border, Thickness = Theme.strokeThickness }),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, Theme.space.lg),
			PaddingRight = UDim.new(0, Theme.space.lg),
			PaddingTop = UDim.new(0, Theme.space.md),
			PaddingBottom = UDim.new(0, Theme.space.md),
		}),
	})
	Text.new(ctx, "body", Text.formula(text), { TextColor3 = Theme.color.textMuted, Parent = panel })

	local open = false
	local toggle
	toggle = Button.new(ctx, {
		text = "Go deeper",
		glyphRight = "▸",
		variant = "ghost",
		layoutOrder = 1,
		onActivated = function()
			open = not open
			panel.Visible = open
			toggle:setText(if open then "Hide the math" else "Go deeper")
			local glyph = toggle.instance:FindFirstChild("Glyph") :: Frame?
			if glyph then
				glyph.Rotation = if open then 90 else 0
			end
		end,
	})
	toggle.instance.Parent = holder
	return toggle.instance
end

-- Lays out a text column (≈40%) and a visual column (≈60%). In compact mode only one shows at a
-- time, chosen with a Learn / Explore toggle. Returns (root, textParent, visualParent).
function Common.twoColumn(ctx: CardCtx, visualLabel: string?): (Frame, Frame, Frame)
	local root = Create("Frame", { Name = "TwoColumn", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	local gap = Theme.space.xxl

	if not ctx.metrics.compact then
		local left = Create("Frame", {
			Name = "TextColumn",
			BackgroundTransparency = 1,
			Size = UDim2.new(Theme.lesson.textColumn, -gap / 2, 1, 0),
			Parent = root,
		})
		local right = Create("Frame", {
			Name = "VisualColumn",
			BackgroundTransparency = 1,
			Position = UDim2.new(Theme.lesson.textColumn, gap / 2, 0, 0),
			Size = UDim2.new(1 - Theme.lesson.textColumn, -gap / 2, 1, 0),
			Parent = root,
		})
		return root, left, right
	end

	local toggleHeight = ctx.metrics.tap + 8
	local area = Create("Frame", {
		Name = "Area",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, toggleHeight + Theme.space.lg),
		Size = UDim2.new(1, 0, 1, -(toggleHeight + Theme.space.lg)),
		Parent = root,
	})
	local left = Create("Frame", { Name = "TextColumn", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = area })
	local right = Create(
		"Frame",
		{ Name = "VisualColumn", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = area }
	)
	local control = SegmentedControl.new(ctx, {
		options = { "Learn", visualLabel or "Explore" },
		selected = 1,
		fill = false,
		onChanged = function(index)
			left.Visible = index == 1
			right.Visible = index == 2
		end,
	})
	control.instance.Parent = root
	return root, left, right
end

-- A raised panel for visuals and widgets.
function Common.panel(name: string, order: number?): Frame
	return Create("Frame", {
		Name = name,
		LayoutOrder = order or 0,
		BackgroundColor3 = Theme.color.surface,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		Create("UICorner", { CornerRadius = Theme.radius.card }),
		Create("UIStroke", { Color = Theme.color.border, Thickness = Theme.strokeThickness }),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, Theme.space.xl),
			PaddingRight = UDim.new(0, Theme.space.xl),
			PaddingTop = UDim.new(0, Theme.space.xl),
			PaddingBottom = UDim.new(0, Theme.space.xl),
		}),
	})
end

-- Builds the standard text column contents (title, body, extras, terms, deeper).
-- Returns the "Go deeper" button if there is one.
function Common.textColumn(ctx: CardCtx, card: Types.Card, parent: Instance, extras: ((Frame, number) -> ())?): TextButton?
	local scroller, content = Common.scroller("TextScroll")
	scroller.Parent = parent
	if card.title then
		Common.title(ctx, card.title, 1, content)
	end
	if card.body then
		Common.body(ctx, card.body, 2, content)
	end
	if extras then
		extras(content, 3)
	end
	Common.terms(ctx, card.terms, 4, content)
	return Common.deeper(ctx, card.deeper, 5, content)
end

return Common
