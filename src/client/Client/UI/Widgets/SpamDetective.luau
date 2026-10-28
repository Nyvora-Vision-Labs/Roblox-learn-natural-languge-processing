--!strict
-- SpamDetective: toggle words in a message and watch Naive Bayes update. Shows the prior, each
-- word's likelihood ratio, and P(spam | words), all computed from the toy counts in props.model.
-- props: model (Prob.NBModel with classes spam/ham), start { words }, smoothing, showSmoothing

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Prob = require(Shared:WaitForChild("Math"):WaitForChild("Prob"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Context = require(UI:WaitForChild("Context"))
local Text = require(UI:WaitForChild("Text"))
local Components = UI:WaitForChild("Components")
local Button = require(Components:WaitForChild("Button"))
local Toggle = require(Components:WaitForChild("Toggle"))
local Widgets = require(script.Parent:WaitForChild("Index"))

local MAX_LOG2 = 3 -- likelihood-ratio bars saturate at ×8 either way

local SpamDetective = {}

local function hex(c: Color3): string
	return "#" .. c:ToHex()
end

local function pct(p: number): string
	return string.format("%.2f", p)
end

function SpamDetective.new(ctx: Context.Ctx, props: { [string]: any }): Widgets.Widget
	local model: Prob.NBModel = props.model
	local startWords: { string } = props.start or {}
	local startSmoothing: boolean = props.smoothing ~= false
	local selected: { [string]: boolean } = {}
	local smoothing = startSmoothing
	local spamColor = Theme.role.output
	local hamColor = Theme.role.input

	local root = Create("Frame", {
		Name = "SpamDetective",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		Create("UIListLayout", { Padding = UDim.new(0, Theme.space.lg), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local spamDocs, hamDocs = model.classes.spam.docs, model.classes.ham.docs
	Text.new(ctx, "caption", `Toy training set: {spamDocs} spam and {hamDocs} not-spam messages.`, {
		LayoutOrder = 1,
		TextColor3 = Theme.color.textMuted,
		Parent = root,
	})

	-- Word chips
	local chipsRow = Create("Frame", {
		Name = "Words",
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = root,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Wraps = true,
			Padding = UDim.new(0, Theme.space.sm),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local smoothingRow: TextButton? = nil
	local evidence = Create("Frame", {
		Name = "Evidence",
		LayoutOrder = 4,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = root,
	}, {
		Create("UIListLayout", { Padding = UDim.new(0, Theme.space.sm), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	-- Verdict meter
	local verdict = Create("Frame", {
		Name = "Verdict",
		LayoutOrder = 5,
		BackgroundColor3 = Theme.color.surfaceRaised,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = Theme.radius.button }),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, Theme.space.lg),
			PaddingRight = UDim.new(0, Theme.space.lg),
			PaddingTop = UDim.new(0, Theme.space.md),
			PaddingBottom = UDim.new(0, Theme.space.md),
		}),
		Create("UIListLayout", { Padding = UDim.new(0, Theme.space.sm), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local verdictText = Text.new(ctx, "body", "", { LayoutOrder = 1, Parent = verdict })
	local meter = Create("Frame", {
		Name = "Meter",
		LayoutOrder = 2,
		BackgroundColor3 = hamColor,
		BackgroundTransparency = 0.55,
		Size = UDim2.new(1, 0, 0, 14),
		Parent = verdict,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
	})
	local meterFill = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = spamColor,
		Size = UDim2.fromScale(0, 1),
		Parent = meter,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
	})
	Create("Frame", { -- the 0.5 mark
		Name = "Half",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 2, 1, 8),
		BackgroundColor3 = Theme.color.text,
		BorderSizePixel = 0,
		Parent = meter,
	})
	local meterLabels = Create("Frame", {
		Name = "Ends",
		LayoutOrder = 3,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, ctx.metrics.text.caption + 4),
		Parent = verdict,
	})
	Create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.5, 1),
		Text = "← not spam",
		TextColor3 = hamColor,
		FontFace = Theme.font.medium,
		TextSize = ctx.metrics.text.caption,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = meterLabels,
	})
	Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(0.5, 1),
		Text = "spam →",
		TextColor3 = spamColor,
		FontFace = Theme.font.medium,
		TextSize = ctx.metrics.text.caption,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = meterLabels,
	})

	local alphaOf = function(): number
		return if smoothing then 1 else 0
	end

	-- One evidence row: label, a bar pointing toward the class the factor favors, and its value.
	local function evidenceRow(order: number, label: string, ratio: number?, detail: string)
		local row = Create("Frame", {
			Name = "Row" .. order,
			LayoutOrder = order,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = evidence,
		})
		local labelWidth = 0.26
		Create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(labelWidth, 0, 0, ctx.metrics.text.body + 6),
			Text = label,
			TextColor3 = Theme.role.input,
			FontFace = Theme.font.monoBold,
			TextSize = ctx.metrics.text.body,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})
		local barArea = Create("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(labelWidth, 0),
			Size = UDim2.new(0.34, 0, 0, ctx.metrics.text.body + 6),
			Parent = row,
		})
		Create("Frame", { -- center line = no evidence either way
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.new(0, 2, 1, 0),
			BackgroundColor3 = Theme.color.border,
			BorderSizePixel = 0,
			Parent = barArea,
		})
		if ratio then
			local l2 = if ratio <= 0 then -MAX_LOG2 elseif ratio == math.huge then MAX_LOG2 else math.log(ratio, 2)
			local t = math.clamp(l2 / MAX_LOG2, -1, 1) * 0.5
			Create("Frame", {
				AnchorPoint = Vector2.new(if t >= 0 then 0 else 1, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(math.abs(t), 0, 0, 12),
				BackgroundColor3 = if t >= 0 then spamColor else hamColor,
				BorderSizePixel = 0,
				Parent = barArea,
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 3) }),
			})
		end
		Text.new(ctx, "caption", detail, {
			Position = UDim2.new(labelWidth + 0.36, 0, 0, 2),
			Size = UDim2.fromScale(1 - labelWidth - 0.36, 0),
			TextColor3 = Theme.color.textMuted,
			Parent = row,
		})
	end

	local function render()
		for _, child in evidence:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local alpha = alphaOf()
		local words = {}
		for _, word in model.vocab do
			if selected[word] then
				table.insert(words, word)
			end
		end

		-- Prior row: ratio of priors
		local pSpam, pHam = Prob.nbPrior(model, "spam"), Prob.nbPrior(model, "ham")
		evidenceRow(0, "prior", pSpam / pHam, `P(spam) = {pct(pSpam)}, P(not) = {pct(pHam)}`)

		for i, word in words do
			local ls = Prob.nbLikelihood(model, word, "spam", alpha)
			local lh = Prob.nbLikelihood(model, word, "ham", alpha)
			local ratio, detail
			if ls == 0 and lh == 0 then
				ratio, detail = nil, "never seen in training: 0 for both"
			elseif lh == 0 then
				ratio, detail = math.huge, "never seen in not-spam: rules it out"
			elseif ls == 0 then
				ratio, detail = 0, "never seen in spam: P = 0 rules spam out"
			else
				ratio = ls / lh
				detail = `{pct(ls)} vs {pct(lh)}  (×{string.format("%.1f", ratio)})`
			end
			evidenceRow(i, word, ratio, detail)
		end

		local posterior = Prob.nbPosterior(model, words, alpha)
		local p: number
		if posterior then
			p = posterior.spam
			local isSpam = p >= 0.5
			local verdictWord = if isSpam then "Spam" else "Not spam"
			verdictText.Text = string.format(
				'P(spam | words) = <font color="%s"><b>%.2f</b></font>   →   <b>%s</b>',
				hex(spamColor),
				p,
				verdictWord
			)
		else
			p = 0.5
			verdictText.Text = "<b>Undefined.</b> Both classes have a zero factor, so there's nothing to compare."
		end
		local goal = { Size = UDim2.fromScale(math.clamp(p, 0, 1), 1) }
		if ctx.reducedMotion then
			meterFill.Size = goal.Size
		else
			TweenService:Create(meterFill, Theme.ease.state, goal):Play()
		end
	end

	-- Word toggles (own buttons: their fill shows state, so no hover recoloring)
	local chipButtons: { [string]: TextButton } = {}
	local function styleChip(word: string)
		local b = chipButtons[word]
		local on = selected[word] == true
		b.BackgroundColor3 = if on then ctx.accent else Theme.color.surfaceRaised
		b.TextColor3 = if on then Theme.color.bg else Theme.color.text
		-- The sign says what a tap does (add / remove), so state never relies on color alone.
		b.Text = (if on then "− " else "+ ") .. word
	end
	for i, word in model.vocab do
		local b = Create("TextButton", {
			Name = "Word_" .. word,
			LayoutOrder = i,
			AutoButtonColor = true,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, ctx.metrics.tap),
			BackgroundColor3 = Theme.color.surfaceRaised,
			FontFace = Theme.font.bold,
			TextSize = ctx.metrics.text.label,
			Selectable = true,
			SelectionImageObject = Button.focusRing(Theme.radius.button),
			Parent = chipsRow,
		}, {
			Create("UICorner", { CornerRadius = Theme.radius.button }),
			Create("UIStroke", {
				Color = Theme.color.border,
				Thickness = Theme.strokeThickness,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			Create("UIPadding", { PaddingLeft = UDim.new(0, Theme.space.lg), PaddingRight = UDim.new(0, Theme.space.lg) }),
		})
		b.Activated:Connect(function()
			selected[word] = not selected[word]
			styleChip(word)
			render()
		end)
		chipButtons[word] = b
	end

	if props.showSmoothing then
		smoothingRow = Toggle.new(ctx, {
			label = "Add-one smoothing",
			value = smoothing,
			layoutOrder = 3,
			onChanged = function(value)
				smoothing = value
				render()
			end,
		})
		;(smoothingRow :: TextButton).Parent = root
	end

	local function resetState()
		table.clear(selected)
		for _, word in startWords do
			selected[word] = true
		end
		smoothing = startSmoothing
		for word in chipButtons do
			styleChip(word)
		end
		render()
	end
	resetState()

	return {
		root = root,
		illustrative = false,
		reset = function()
			resetState()
			if smoothingRow then
				-- Rebuild the toggle so its switch matches the reset value.
				local order = smoothingRow.LayoutOrder
				smoothingRow:Destroy()
				smoothingRow = Toggle.new(ctx, {
					label = "Add-one smoothing",
					value = smoothing,
					layoutOrder = order,
					onChanged = function(value)
						smoothing = value
						render()
					end,
				})
				;(smoothingRow :: TextButton).Parent = root
			end
		end,
		destroy = function()
			root:Destroy()
		end,
	}
end

return SpamDetective
