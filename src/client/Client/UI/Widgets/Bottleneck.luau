--!strict
-- Bottleneck (illustrative): the same long sentence fed to a plain seq2seq model, where every word
-- funnels into one small vector, vs. attention, where the decoder reaches back to every word.
-- No numbers are computed here; the widget carries the "Illustrative" badge.
-- props: words

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Context = require(UI:WaitForChild("Context"))
local Text = require(UI:WaitForChild("Text"))
local SegmentedControl = require(UI:WaitForChild("Components"):WaitForChild("SegmentedControl"))
local Widgets = require(script.Parent:WaitForChild("Index"))

local W, H = 560, 250
local WORD_Y = 30
local DECODER_Y = 210

local Bottleneck = {}

local function line(parent: Instance, a: Vector2, b: Vector2, color: Color3, thickness: number, transparency: number): Frame
	local mid, d = (a + b) / 2, b - a
	local frame = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(mid.X, mid.Y),
		Size = UDim2.fromOffset(d.Magnitude, thickness),
		Rotation = math.deg(math.atan2(d.Y, d.X)),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		Parent = parent,
	})
	frame:SetAttribute("Base", transparency) -- resting transparency for the fade-in
	return frame
end

function Bottleneck.new(ctx: Context.Ctx, props: { [string]: any }): Widgets.Widget
	local words: { string } = props.words
	local n = #words
	local hiddenColor = Theme.role.hidden

	local root = Create("Frame", {
		Name = "Bottleneck",
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

	local stage = Create("Frame", {
		Name = "Stage",
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(W, H),
		Parent = root,
	})

	-- Source words as small encoder-state dots with labels
	local wordPos = {}
	for k, word in words do
		local x = (k - 0.5) / n * W
		wordPos[k] = Vector2.new(x, WORD_Y)
		Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(x, WORD_Y),
			Size = UDim2.fromOffset(12, 12),
			BackgroundColor3 = hiddenColor,
			ZIndex = 3,
			Parent = stage,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		})
		Create("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromOffset(x, WORD_Y - 10),
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			Text = word,
			TextColor3 = Theme.role.input,
			FontFace = Theme.font.regular,
			TextSize = ctx.metrics.text.caption,
			Rotation = -30,
			Parent = stage,
		})
	end

	Create("TextLabel", {
		Name = "Decoder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(W * 0.5, DECODER_Y),
		Size = UDim2.fromOffset(150, 44),
		BackgroundColor3 = Theme.color.surfaceRaised,
		Text = "decoder",
		TextColor3 = Theme.color.text,
		FontFace = Theme.font.bold,
		TextSize = ctx.metrics.text.label,
		ZIndex = 3,
		Parent = stage,
	}, {
		Create("UICorner", { CornerRadius = Theme.radius.button }),
		Create("UIStroke", { Color = Theme.role.output, Thickness = 2 }),
	})

	-- Seq2seq layer: everything funnels into one small vector
	local funnel = Create("Frame", { Name = "Funnel", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = stage })
	local squeeze = Vector2.new(W * 0.5, 118)
	for _, p in wordPos do
		line(funnel, p, squeeze, hiddenColor, 2, 0.55)
	end
	Create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(squeeze.X, squeeze.Y),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = hiddenColor,
		Text = "",
		ZIndex = 3,
		Parent = funnel,
	}, {
		Create("UICorner", { CornerRadius = Theme.radius.chip }),
	})
	Create("TextLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(squeeze.X + 28, squeeze.Y),
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Text = "one fixed-size vector",
		TextColor3 = hiddenColor,
		FontFace = Theme.font.medium,
		TextSize = ctx.metrics.text.caption,
		Parent = funnel,
	})
	line(funnel, squeeze, Vector2.new(W * 0.5, DECODER_Y - 22), hiddenColor, 3, 0)

	-- Attention layer: the decoder reaches every encoder state; thicker = more weight (illustrative)
	local attention = Create("Frame", { Name = "Attention", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = stage })
	local focus = math.ceil(n * 0.45)
	for k, p in wordPos do
		local closeness = math.exp(-((k - focus) / 1.6) ^ 2)
		line(attention, Vector2.new(W * 0.5, DECODER_Y - 22), p, Theme.role.query, 1 + 4 * closeness, 0.75 - 0.6 * closeness)
	end

	local caption = Text.new(ctx, "caption", "", {
		LayoutOrder = 3,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.color.textMuted,
		Parent = root,
	})

	local function show(mode: number)
		funnel.Visible = mode == 1
		attention.Visible = mode == 2
		caption.Text = if mode == 1
			then `All {n} words must fit through one vector before the decoder writes anything.`
			else "At each output word, the decoder looks back at every source word, weighting the relevant ones."
		if not ctx.reducedMotion then
			local layer = if mode == 1 then funnel else attention
			for _, child in layer:GetChildren() do
				local target = child:GetAttribute("Base")
				if child:IsA("Frame") and type(target) == "number" then
					child.BackgroundTransparency = 1
					TweenService:Create(child, Theme.ease.state, { BackgroundTransparency = target }):Play()
				end
			end
		end
	end

	local switch = SegmentedControl.new(ctx, {
		options = { "Seq2seq", "With attention" },
		selected = 1,
		layoutOrder = 1,
		onChanged = show,
	})
	switch.instance.Parent = root
	show(1)

	return {
		root = root,
		illustrative = true,
		reset = function()
			switch:select(1)
			show(1)
		end,
		destroy = function()
			root:Destroy()
		end,
	}
end

return Bottleneck
