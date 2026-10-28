--!strict
-- The screen after the last quiz question: score, then either a short celebration and the way back
-- to the Atrium, or the cards to review and "Try again".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Text = require(UI:WaitForChild("Text"))
local Button = require(UI:WaitForChild("Components"):WaitForChild("Button"))
local Common = require(script.Parent:WaitForChild("Common"))

export type Data = {
	score: number,
	total: number,
	passMark: number,
	passed: boolean,
	best: number,
	isLastModule: boolean,
	review: { { id: string, title: string } },
	onRetry: () -> (),
	onExit: () -> (),
	onReview: (cardId: string) -> (),
}

local BADGE = 120

local Result = {}

function Result.render(ctx: Common.CardCtx, data: Data): Common.CardView
	local scroller, content = Common.scroller("ResultScroll")
	local holder = Common.centered(
		scroller,
		720,
		if ctx.metrics.compact then ctx.metrics.scale else nil
	)
	local layout = content:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local tint = if data.passed then Theme.color.success else Theme.color.warning
	local badge = Create("Frame", {
		Name = "Badge",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(BADGE, BADGE),
		BackgroundColor3 = Theme.color.surfaceRaised,
		Parent = content,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		Create("UIStroke", { Color = tint, Thickness = 4 }),
		Create("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = `{data.score}/{data.total}`,
			TextColor3 = tint,
			FontFace = Theme.font.extraBold,
			TextSize = ctx.metrics.text.h1,
		}),
	})
	if not ctx.reducedMotion then
		local scale = Create("UIScale", { Scale = 0.6, Parent = badge })
		TweenService:Create(
			scale,
			TweenInfo.new(Theme.lesson.celebrateDuration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
	end

	local center = { TextXAlignment = Enum.TextXAlignment.Center }
	local function centered(style: string, text: string, order: number, color: Color3?)
		local label = Text.new(ctx, style, text, { LayoutOrder = order, Parent = content })
		label.TextXAlignment = center.TextXAlignment
		if color then
			label.TextColor3 = color
		end
	end

	if data.passed then
		centered("h1", "Module complete", 2)
		local next = if data.isLastModule
			then "You've finished every module."
			else "The next portal opens when you return to the Atrium."
		centered("body", `You scored {data.score} out of {data.total}. {next}`, 3, Theme.color.textMuted)
	else
		centered("h1", "Almost there", 2)
		centered(
			"body",
			`You scored {data.score} out of {data.total}. You need {data.passMark} to pass. Your best is {data.best}.`,
			3,
			Theme.color.textMuted
		)
	end

	local primary
	if data.passed then
		primary = Button.new(ctx, { text = "Back to the Atrium", layoutOrder = 10, onActivated = data.onExit })
		primary.instance.Parent = content
	else
		if #data.review > 0 then
			centered("label", "Review these cards", 5, Theme.color.text)
			local list = Common.list("Review", Theme.space.sm, { LayoutOrder = 6, Parent = content })
			for i, item in data.review do
				local b = Button.new(ctx, {
					text = item.title,
					variant = "secondary",
					glyphRight = "→",
					fill = true,
					align = "left",
					layoutOrder = i,
					onActivated = function()
						data.onReview(item.id)
					end,
				})
				b.instance.Parent = list
			end
		end
		primary = Button.new(ctx, { text = "Try again", layoutOrder = 4, onActivated = data.onRetry })
		primary.instance.Parent = content
	end

	return {
		root = holder,
		primary = primary.instance,
		activate = if data.passed then data.onExit else data.onRetry,
		destroy = function()
			holder:Destroy()
		end,
	}
end

return Result
