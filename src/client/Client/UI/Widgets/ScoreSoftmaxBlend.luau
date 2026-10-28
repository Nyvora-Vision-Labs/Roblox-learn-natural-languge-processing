--!strict
-- ScoreSoftmaxBlend: pick a decoder query; dot-product scores against each key, softmax with a
-- temperature (sharpness) slider, and the weighted blend of values = the context vector.
-- Everything is computed with Math/Linear and Math/Prob.
-- props: words, keys, values, queries { { label, vector } }

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Prob = require(Shared:WaitForChild("Math"):WaitForChild("Prob"))
local Linear = require(Shared:WaitForChild("Math"):WaitForChild("Linear"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Context = require(UI:WaitForChild("Context"))
local Text = require(UI:WaitForChild("Text"))
local Components = UI:WaitForChild("Components")
local SegmentedControl = require(Components:WaitForChild("SegmentedControl"))
local Slider = require(Components:WaitForChild("Slider"))
local Plot = require(script.Parent:WaitForChild("Plot"))
local Widgets = require(script.Parent:WaitForChild("Index"))

local ROW_H = 40
local WORD_W, BAR_W, NUM_W = 120, 150, 64
local SCORE_RANGE = 2.5 -- score bars saturate here

local ScoreSoftmaxBlend = {}

local function vec(v: { number }): string
	return "(" .. Plot.num(v[1], 2) .. ", " .. Plot.num(v[2], 2) .. ")"
end

function ScoreSoftmaxBlend.new(ctx: Context.Ctx, props: { [string]: any }): Widgets.Widget
	local words: { string } = props.words
	local keys: { { number } } = props.keys
	local values: { { number } } = props.values
	local queries = props.queries
	local q = 1
	local tau = 1

	local root = Create("Frame", {
		Name = "ScoreSoftmaxBlend",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, Theme.space.md),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local queryLabels = {}
	for _, item in queries do
		table.insert(queryLabels, item.label)
	end
	local queryText = Text.new(ctx, "caption", "", {
		LayoutOrder = 2,
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.font.mono,
		TextColor3 = Theme.role.query,
		Parent = root,
	})

	-- Table: word | score bar + value | weight bar + value
	local tableW = WORD_W + 2 * (BAR_W + NUM_W) + 24
	local grid = Create("Frame", {
		Name = "Table",
		LayoutOrder = 3,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(tableW, ROW_H * (#words + 1)),
		Parent = root,
	})
	local function headerCell(text: string, x: number, w: number)
		Create("TextLabel", {
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.fromOffset(w, ROW_H),
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = Theme.color.textMuted,
			FontFace = Theme.font.medium,
			TextSize = ctx.metrics.text.caption,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = grid,
		})
	end
	local scoreX = WORD_W
	local weightX = WORD_W + BAR_W + NUM_W + 24
	headerCell("key word", 0, WORD_W)
	headerCell("score = query · key", scoreX, BAR_W + NUM_W)
	headerCell("weight = softmax", weightX, BAR_W + NUM_W)

	local rows = {}
	for k, word in words do
		local y = ROW_H * k
		Create("TextLabel", {
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.fromOffset(WORD_W, ROW_H),
			BackgroundTransparency = 1,
			Text = word,
			TextColor3 = Theme.role.input,
			FontFace = Theme.font.bold,
			TextSize = ctx.metrics.text.label,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = grid,
		})
		-- Score bar is signed around a center line
		local scoreTrack = Create("Frame", {
			Position = UDim2.fromOffset(scoreX, y + ROW_H / 2 - 7),
			Size = UDim2.fromOffset(BAR_W, 14),
			BackgroundColor3 = Theme.color.surfaceRaised,
			Parent = grid,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, 3) }),
			Create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.new(0, 2, 1, 0),
				BackgroundColor3 = Theme.color.border,
				BorderSizePixel = 0,
			}),
		})
		local scoreBar = Create("Frame", {
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = Theme.role.query,
			BorderSizePixel = 0,
			Parent = scoreTrack,
		})
		local scoreNum = Create("TextLabel", {
			Position = UDim2.fromOffset(scoreX + BAR_W + 6, y),
			Size = UDim2.fromOffset(NUM_W, ROW_H),
			BackgroundTransparency = 1,
			TextColor3 = Theme.color.text,
			FontFace = Theme.font.mono,
			TextSize = ctx.metrics.text.caption,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = grid,
		})
		local weightTrack = Create("Frame", {
			Position = UDim2.fromOffset(weightX, y + ROW_H / 2 - 7),
			Size = UDim2.fromOffset(BAR_W, 14),
			BackgroundColor3 = Theme.color.surfaceRaised,
			Parent = grid,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, 3) }),
		})
		local weightBar = Create("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = Theme.role.query,
			BorderSizePixel = 0,
			Parent = weightTrack,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, 3) }),
		})
		local weightNum = Create("TextLabel", {
			Position = UDim2.fromOffset(weightX + BAR_W + 6, y),
			Size = UDim2.fromOffset(NUM_W, ROW_H),
			BackgroundTransparency = 1,
			TextColor3 = Theme.color.text,
			FontFace = Theme.font.mono,
			TextSize = ctx.metrics.text.caption,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = grid,
		})
		rows[k] = { scoreBar = scoreBar, scoreNum = scoreNum, weightBar = weightBar, weightNum = weightNum }
	end

	local context = Text.new(ctx, "body", "", {
		LayoutOrder = 4,
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.font.mono,
		TextSize = ctx.metrics.text.caption + 2,
		Parent = root,
	})

	local function render(animate: boolean)
		local query = queries[q].vector
		queryText.Text = `query for “{queries[q].label}” = {vec(query)}`
		local scores = {}
		for k, key in keys do
			scores[k] = Linear.dot(query, key)
		end
		local weights = Prob.softmax(scores, tau)
		local blend = Linear.weightedSum(weights, values)
		local bestK = 1
		for k, w in weights do
			if w > weights[bestK] then
				bestK = k
			end
			local r = rows[k]
			local s = math.clamp(scores[k] / SCORE_RANGE, -1, 1) * 0.5
			local scoreGoal = {
				Position = UDim2.fromScale(if s >= 0 then 0.5 else 0.5 + s, 0),
				Size = UDim2.fromScale(math.abs(s), 1),
			}
			local weightGoal = { Size = UDim2.fromScale(w, 1) }
			if animate and not ctx.reducedMotion then
				TweenService:Create(r.scoreBar, Theme.ease.state, scoreGoal):Play()
				TweenService:Create(r.weightBar, Theme.ease.state, weightGoal):Play()
			else
				r.scoreBar.Position, r.scoreBar.Size = scoreGoal.Position, scoreGoal.Size
				r.weightBar.Size = weightGoal.Size
			end
			r.scoreNum.Text = Plot.num(scores[k], 2)
			r.weightNum.Text = string.format("%.2f", w)
		end
		local sum = 0
		for _, w in weights do
			sum += w
		end
		context.Text = string.format(
			'weights sum to %.2f  ·  most weight on “%s”\ncontext c = Σ weight·value = <font color="#%s"><b>%s</b></font>',
			sum,
			words[bestK],
			Theme.role.output:ToHex(),
			vec(blend)
		)
	end

	local switch = SegmentedControl.new(ctx, {
		options = queryLabels,
		selected = 1,
		layoutOrder = 1,
		onChanged = function(index)
			q = index
			render(true)
		end,
	})
	switch.instance.Parent = root

	local slider = Slider.new(ctx, {
		label = "sharpness: temperature τ (smaller is sharper)",
		min = 0.25,
		max = 3,
		step = 0.05,
		value = tau,
		format = function(v)
			return string.format("τ = %.2f", v)
		end,
		layoutOrder = 5,
		onChanged = function(v)
			tau = v
			render(true)
		end,
	})
	slider.instance.Parent = root

	render(false)

	return {
		root = root,
		illustrative = false,
		reset = function()
			q, tau = 1, 1
			switch:select(1)
			slider:set(tau, true)
			render(true)
		end,
		destroy = function()
			slider:destroy()
			root:Destroy()
		end,
	}
end

return ScoreSoftmaxBlend
