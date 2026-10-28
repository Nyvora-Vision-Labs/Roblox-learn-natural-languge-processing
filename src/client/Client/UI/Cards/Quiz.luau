--!strict
-- quiz: one question, options in this attempt's shuffled order, instant feedback with the
-- explanation for whichever option was picked. Correct/incorrect always shows an icon and a word.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Types = require(Shared:WaitForChild("Types"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Text = require(UI:WaitForChild("Text"))
local Components = UI:WaitForChild("Components")
local Button = require(Components:WaitForChild("Button"))
local Callout = require(Components:WaitForChild("Callout"))
local Sound = require(UI:WaitForChild("Sound"))
local Common = require(script.Parent:WaitForChild("Common"))

local Quiz = {}

type Row = {
	button: TextButton,
	stroke: UIStroke,
	text: TextLabel,
	badge: TextLabel,
	status: TextLabel,
	original: number,
}

function Quiz.render(ctx: Common.CardCtx, card: Types.Card): Common.CardView
	local scroller, content = Common.scroller("QuizScroll")
	local holder = Common.centered(
		scroller,
		820,
		if ctx.metrics.compact then ctx.metrics.scale else nil
	)
	local options = card.options or {}
	local order = ctx.quiz.order(card.id)
	local n, total = ctx.quiz.number(card.id)

	Text.new(ctx, "label", `Question {n} of {total}`, { LayoutOrder = 1, TextColor3 = ctx.accent, Parent = content })
	Text.new(ctx, "h2", card.prompt or "", { LayoutOrder = 2, Parent = content })

	local list = Common.list("Options", Theme.space.md, { LayoutOrder = 3, Parent = content })
	local feedbackHolder = Common.list("Feedback", 0, { LayoutOrder = 4, Parent = content })

	local rows: { Row } = {}
	local badgeSize = ctx.metrics.text.label + 12
	local statusWidth = 0 -- grows to fit the status word once answered

	local function render(animate: boolean)
		local chosen = ctx.quiz.chosen(card.id)
		for _, row in rows do
			local isChosen = chosen == row.original
			local isAnswer = row.original == card.answer
			local strokeColor, status, statusColor = Theme.color.border, "", Theme.color.textMuted
			local dim = false
			if chosen then
				if isAnswer then
					strokeColor, statusColor = Theme.color.success, Theme.color.success
					status = if isChosen then "Correct" else "Correct answer"
				elseif isChosen then
					strokeColor, statusColor = Theme.color.danger, Theme.color.danger
					status = "Your answer"
				else
					dim = true
				end
			end
			row.stroke.Color = strokeColor
			row.stroke.Thickness = if chosen and (isAnswer or isChosen) then 2 else 1
			row.status.Text = status
			row.status.TextColor3 = statusColor
			row.status.Visible = status ~= ""
			row.text.TextTransparency = if dim then 0.45 else 0
			row.badge.TextTransparency = if dim then 0.45 else 0
			row.button.Active = chosen == nil
			row.button.Selectable = chosen == nil
		end

		for _, child in feedbackHolder:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		if chosen then
			local correct = chosen == card.answer
			local explanation = if card.explain then card.explain[chosen] else nil
			local callout = Callout.new(ctx, {
				kind = if correct then "success" else "danger",
				text = explanation or (if correct then "That's right." else "That isn't it."),
			})
			callout.Parent = feedbackHolder
			if animate and not ctx.reducedMotion then
				callout.BackgroundTransparency = 1
				TweenService:Create(callout, Theme.ease.state, { BackgroundTransparency = 0 }):Play()
			end
		end
	end

	local function pick(original: number)
		if ctx.quiz.chosen(card.id) then
			return
		end
		ctx.quiz.choose(card.id, original)
		Sound.play(if original == card.answer then "correct" else "incorrect")
		render(true)
		ctx.onChanged()
	end

	for position, original in order do
		local button = Create("TextButton", {
			Name = "Option" .. position,
			LayoutOrder = position,
			AutoButtonColor = false,
			Text = "",
			BackgroundColor3 = Theme.color.surfaceRaised,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Selectable = true,
			SelectionImageObject = Button.focusRing(Theme.radius.button),
			Parent = list,
		}, {
			Create("UICorner", { CornerRadius = Theme.radius.button }),
			Create("UISizeConstraint", { MinSize = Vector2.new(0, ctx.metrics.tap) }),
			Create("UIPadding", {
				PaddingLeft = UDim.new(0, Theme.space.lg),
				PaddingRight = UDim.new(0, Theme.space.lg),
				PaddingTop = UDim.new(0, Theme.space.md),
				PaddingBottom = UDim.new(0, Theme.space.md),
			}),
		})
		local stroke = Create("UIStroke", {
			Color = Theme.color.border,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = button,
		})
		local badge = Create("TextLabel", {
			Name = "Key",
			Size = UDim2.fromOffset(badgeSize, badgeSize),
			BackgroundColor3 = Theme.color.bg,
			Text = tostring(position),
			TextColor3 = Theme.color.textMuted,
			FontFace = Theme.font.bold,
			TextSize = ctx.metrics.text.label,
			Parent = button,
		}, {
			Create("UICorner", { CornerRadius = Theme.radius.chip }),
		})
		local status = Create("TextLabel", {
			Name = "Status",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, badgeSize),
			BackgroundTransparency = 1,
			Visible = false,
			Text = "",
			FontFace = Theme.font.bold,
			TextSize = ctx.metrics.text.label,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = button,
		})
		statusWidth = math.max(statusWidth, ctx.metrics.text.label * 9)
		local text = Text.new(ctx, "body", options[original] or "", {
			Name = "Text",
			Position = UDim2.fromOffset(badgeSize + Theme.space.md, math.max(0, (badgeSize - ctx.metrics.text.body * 1.3) / 2)),
			Parent = button,
		})
		rows[position] = {
			button = button,
			stroke = stroke,
			text = text,
			badge = badge,
			status = status,
			original = original,
		}
		button.Activated:Connect(function()
			pick(original)
		end)
	end
	-- Leave room on the right for the status word so it never overlaps the option text.
	for _, row in rows do
		row.text.Size = UDim2.new(1, -(badgeSize + Theme.space.md + statusWidth), 0, 0)
	end

	render(false)

	return {
		root = holder,
		primary = if ctx.quiz.chosen(card.id) then nil elseif rows[1] then rows[1].button else nil,
		canAdvance = function()
			return ctx.quiz.chosen(card.id) ~= nil
		end,
		onOption = function(position: number)
			local row = rows[position]
			if row then
				pick(row.original)
			end
		end,
		destroy = function()
			holder:Destroy()
		end,
	}
end

return Quiz
