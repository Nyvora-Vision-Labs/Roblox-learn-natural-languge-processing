--!strict
-- WeatherMachine: the diary HMM as a picture. Two hidden states with labeled transition arrows,
-- the emission table, and "Sample a week", which draws real samples from π, A and B and reveals
-- them day by day. With showHide, the weather can be hidden so only the ice creams show.
-- props: model (Viterbi.HMM with two states), days, showHide, startHidden

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Viterbi = require(Shared:WaitForChild("Math"):WaitForChild("Viterbi"))

local UI = script.Parent.Parent
local Create = require(UI:WaitForChild("Create"))
local Context = require(UI:WaitForChild("Context"))
local Text = require(UI:WaitForChild("Text"))
local Components = UI:WaitForChild("Components")
local Button = require(Components:WaitForChild("Button"))
local Toggle = require(Components:WaitForChild("Toggle"))
local Widgets = require(script.Parent:WaitForChild("Index"))

local DIAGRAM_W, DIAGRAM_H = 520, 186
local BUBBLE = 84
local REVEAL_STEP = 0.22

local WeatherMachine = {}

local function fmt(p: number): string
	return string.format("%.1f", p)
end

-- A straight line between two pixel points.
local function line(parent: Instance, a: Vector2, b: Vector2, color: Color3, thickness: number): Frame
	local mid, d = (a + b) / 2, b - a
	return Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(mid.X, mid.Y),
		Size = UDim2.fromOffset(d.Magnitude, thickness),
		Rotation = math.deg(math.atan2(d.Y, d.X)),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = parent,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
	})
end

-- An arrow from a to b with a drawn chevron head (no font glyphs).
local function arrow(parent: Instance, a: Vector2, b: Vector2, color: Color3)
	line(parent, a, b, color, 3)
	local dir = (b - a).Unit
	local normal = Vector2.new(-dir.Y, dir.X)
	local head = 11
	line(parent, b, b - dir * head + normal * head * 0.7, color, 3)
	line(parent, b, b - dir * head - normal * head * 0.7, color, 3)
end

local function caption(ctx: Context.Ctx, parent: Instance, text: string, pos: Vector2, color: Color3?)
	return Create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(pos.X, pos.Y),
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Theme.color.surface,
		BackgroundTransparency = 0,
		Text = text,
		TextColor3 = color or Theme.color.text,
		FontFace = Theme.font.mono,
		TextSize = ctx.metrics.text.caption,
		ZIndex = 4,
		Parent = parent,
	}, {
		Create("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }),
	})
end

-- n small scoops in a row, drawn as circles.
local function scoops(parent: Instance, n: number, size: number)
	local row = Create("Frame", {
		Name = "Scoops",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		Parent = parent,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 3),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	})
	for _ = 1, n do
		Create("Frame", {
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = Theme.role.input,
			Parent = row,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		})
	end
	return row
end

function WeatherMachine.new(ctx: Context.Ctx, props: { [string]: any }): Widgets.Widget
	local hmm: Viterbi.HMM = props.model
	local days: number = props.days or 7
	local hidden = props.startHidden == true
	local rng = Random.new()
	local stateColor = Theme.role.hidden
	local revealThread: thread? = nil
	local week: { states: { number }, obs: { number } }? = nil

	local root = Create("Frame", {
		Name = "WeatherMachine",
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

	-- Diagram -------------------------------------------------------------
	local diagram = Create("Frame", {
		Name = "Diagram",
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(DIAGRAM_W, DIAGRAM_H),
		Parent = root,
	})
	local centers = {
		Vector2.new(DIAGRAM_W * 0.27, DIAGRAM_H * 0.6),
		Vector2.new(DIAGRAM_W * 0.73, DIAGRAM_H * 0.6),
	}
	local r = BUBBLE / 2
	-- Between-state arrows: Hot→Cold above, Cold→Hot below
	local up, down = Vector2.new(0, -14), Vector2.new(0, 14)
	arrow(diagram, centers[1] + Vector2.new(r, 0) + up, centers[2] - Vector2.new(r + 4, 0) + up, Theme.color.textMuted)
	arrow(diagram, centers[2] - Vector2.new(r, 0) + down, centers[1] + Vector2.new(r + 4, 0) + down, Theme.color.textMuted)
	caption(ctx, diagram, fmt(hmm.A[1][2]), (centers[1] + centers[2]) / 2 + up * 2.3, Theme.role.weight)
	caption(ctx, diagram, fmt(hmm.A[2][1]), (centers[1] + centers[2]) / 2 + down * 2.3, Theme.role.weight)

	local bubbles: { Frame } = {}
	for i, c in centers do
		-- Self-loop: a ring sitting on top of the bubble, with a chevron where it re-enters
		local loopSize = 54
		Create("Frame", {
			Name = "Loop",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(c.X, c.Y - r - loopSize * 0.32),
			Size = UDim2.fromOffset(loopSize, loopSize),
			BackgroundTransparency = 1,
			Parent = diagram,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			Create("UIStroke", { Color = Theme.color.textMuted, Thickness = 3 }),
		})
		local entry = c + Vector2.new(loopSize * 0.36, -r - 2)
		line(diagram, entry, entry + Vector2.new(-2, -12), Theme.color.textMuted, 3)
		line(diagram, entry, entry + Vector2.new(9, -9), Theme.color.textMuted, 3)
		caption(ctx, diagram, fmt(hmm.A[i][i]), c - Vector2.new(0, r + loopSize * 0.95), Theme.role.weight)

		local bubble = Create("Frame", {
			Name = hmm.states[i],
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(c.X, c.Y),
			Size = UDim2.fromOffset(BUBBLE, BUBBLE),
			BackgroundColor3 = Theme.color.surfaceRaised,
			ZIndex = 3,
			Parent = diagram,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			Create("UIStroke", { Name = "Ring", Color = stateColor, Thickness = 3 }),
			Create("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = hmm.states[i],
				TextColor3 = Theme.color.text,
				FontFace = Theme.font.bold,
				TextSize = ctx.metrics.text.label,
				ZIndex = 3,
			}),
		})
		bubbles[i] = bubble
	end
	Text.new(
		ctx,
		"caption",
		string.format("start π:  %s %s  ·  %s %s", hmm.states[1], fmt(hmm.pi[1]), hmm.states[2], fmt(hmm.pi[2])),
		{
			Position = UDim2.fromOffset(0, DIAGRAM_H - ctx.metrics.text.caption - 2),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Theme.color.textMuted,
			FontFace = Theme.font.mono,
			Parent = diagram,
		}
	)

	-- Emission table ---------------------------------------------------------
	local emissions = Create("Frame", {
		Name = "Emissions",
		LayoutOrder = 6,
		BackgroundColor3 = Theme.color.surfaceRaised,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = Theme.radius.button }),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, Theme.space.lg),
			PaddingRight = UDim.new(0, Theme.space.lg),
			PaddingTop = UDim.new(0, Theme.space.sm),
			PaddingBottom = UDim.new(0, Theme.space.sm),
		}),
		Create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local header = { "ice creams" }
	for _, symbol in hmm.symbols do
		table.insert(header, symbol)
	end
	local function tableRow(order: number, cells: { string }, color: Color3, bold: boolean)
		local row = Create("Frame", {
			LayoutOrder = order,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			Parent = emissions,
		}, {
			Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		for i, text in cells do
			Create("TextLabel", {
				LayoutOrder = i,
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(if i == 1 then 120 else 64, ctx.metrics.text.caption + 8),
				Text = text,
				TextColor3 = if i == 1 then Theme.color.textMuted else color,
				FontFace = if bold then Theme.font.monoBold else Theme.font.mono,
				TextSize = ctx.metrics.text.caption,
				TextXAlignment = if i == 1 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
				Parent = row,
			})
		end
	end
	tableRow(0, header, Theme.role.input, true)
	for i, state in hmm.states do
		local cells = { `{state} eats` }
		for _, p in hmm.B[i] do
			table.insert(cells, fmt(p))
		end
		tableRow(i, cells, Theme.role.weight, false)
	end

	-- Week strip -------------------------------------------------------------
	local strip = Create("Frame", {
		Name = "Week",
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = root,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, Theme.space.sm),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local tiles = {}
	local tileW = math.floor((DIAGRAM_W - (days - 1) * Theme.space.sm) / days)
	for d = 1, days do
		local tile = Create("Frame", {
			Name = "Day" .. d,
			LayoutOrder = d,
			Size = UDim2.fromOffset(tileW, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.color.surfaceRaised,
			Parent = strip,
		}, {
			Create("UICorner", { CornerRadius = Theme.radius.chip }),
			Create("UIStroke", { Name = "Edge", Color = Theme.color.border, Thickness = 1 }),
			Create("UIPadding", {
				PaddingTop = UDim.new(0, Theme.space.sm),
				PaddingBottom = UDim.new(0, Theme.space.sm),
			}),
			Create("UIListLayout", {
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, Theme.space.xs),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		Create("TextLabel", {
			LayoutOrder = 1,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, ctx.metrics.text.caption + 2),
			Text = "Day " .. d,
			TextColor3 = Theme.color.textFaint,
			FontFace = Theme.font.medium,
			TextSize = ctx.metrics.text.caption,
			Parent = tile,
		})
		local weather = Create("TextLabel", {
			Name = "Weather",
			LayoutOrder = 2,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, ctx.metrics.text.label + 4),
			Text = "–",
			TextColor3 = stateColor,
			FontFace = Theme.font.bold,
			TextSize = ctx.metrics.text.label,
			Parent = tile,
		})
		local holder = Create("Frame", {
			Name = "Obs",
			LayoutOrder = 3,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 14),
			Parent = tile,
		})
		tiles[d] = { tile = tile, weather = weather, obs = holder }
	end

	-- Controls row: Sample + (optional) show-weather toggle side by side
	local controls = Create("Frame", {
		Name = "Controls",
		LayoutOrder = 3,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		Parent = root,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, Theme.space.xl),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local status = Text.new(ctx, "caption", "", {
		LayoutOrder = 4,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.color.textMuted,
		Parent = root,
	})

	-- Behaviour -------------------------------------------------------------
	local function highlight(state: number?)
		for i, bubble in bubbles do
			local on = i == state
			local ring = bubble:FindFirstChild("Ring") :: UIStroke
			local goal = { BackgroundColor3 = if on then stateColor else Theme.color.surfaceRaised }
			if ctx.reducedMotion then
				bubble.BackgroundColor3 = goal.BackgroundColor3
			else
				TweenService:Create(bubble, Theme.ease.state, goal):Play()
			end
			ring.Thickness = if on then 5 else 3
			local label = bubble:FindFirstChildOfClass("TextLabel") :: TextLabel
			label.TextColor3 = if on then Theme.color.bg else Theme.color.text
		end
	end

	local function showDay(d: number)
		if not week then
			return
		end
		local t = tiles[d]
		local state = week.states[d]
		t.weather.Text = if hidden then "?" else hmm.states[state]
		t.weather.TextColor3 = if hidden then Theme.color.textMuted else stateColor
		for _, child in t.obs:GetChildren() do
			child:Destroy()
		end
		local s = scoops(t.obs, week.obs[d], 12)
		s.AnchorPoint = Vector2.new(0.5, 0)
		s.Position = UDim2.fromScale(0.5, 0)
		;(t.tile:FindFirstChild("Edge") :: UIStroke).Color = Theme.color.border
	end

	local function clearDays()
		for _, t in tiles do
			t.weather.Text = "–"
			t.weather.TextColor3 = Theme.color.textFaint
			for _, child in t.obs:GetChildren() do
				child:Destroy()
			end
		end
	end

	local function refreshStatus()
		if not week then
			status.Text = "Each day: pick tomorrow's weather from A, then the ice creams from B."
		elseif hidden then
			status.Text = "Only the ice creams are visible. Which days do you think were hot?"
		else
			local hot = 0
			for _, s in week.states do
				if s == 1 then
					hot += 1
				end
			end
			local function count(n: number, word: string): string
				return `{n} {word} day{if n == 1 then "" else "s"}`
			end
			status.Text = `This week: {count(hot, "hot")} and {count(days - hot, "cold")}.`
		end
	end

	local function stopReveal()
		if revealThread then
			pcall(task.cancel, revealThread)
			revealThread = nil
		end
	end

	local sample = Button.new(ctx, {
		text = "Sample a week",
		name = "Sample",
		layoutOrder = 1,
		onActivated = function()
			stopReveal()
			local states, obs = Viterbi.sample(hmm, days, rng)
			week = { states = states, obs = obs }
			clearDays()
			if ctx.reducedMotion then
				for d = 1, days do
					showDay(d)
				end
				highlight(nil)
				refreshStatus()
				return
			end
			revealThread = task.spawn(function()
				for d = 1, days do
					if not hidden then
						highlight(states[d])
					end
					showDay(d)
					;(tiles[d].tile:FindFirstChild("Edge") :: UIStroke).Color = stateColor
					task.wait(REVEAL_STEP)
					;(tiles[d].tile:FindFirstChild("Edge") :: UIStroke).Color = Theme.color.border
				end
				highlight(nil)
				refreshStatus()
				revealThread = nil
			end)
		end,
	})
	sample.instance.Parent = controls

	local hideToggle: TextButton? = nil
	local function buildToggle()
		if hideToggle then
			hideToggle:Destroy()
		end
		hideToggle = Toggle.new(ctx, {
			label = "Show the weather",
			value = not hidden,
			layoutOrder = 2,
			onChanged = function(show)
				hidden = not show
				if week then
					for d = 1, days do
						if tiles[d].obs:FindFirstChild("Scoops") then
							showDay(d)
						end
					end
				end
				refreshStatus()
			end,
		})
		local toggle = hideToggle :: TextButton
		toggle.Size = UDim2.fromOffset(300, ctx.metrics.tap)
		toggle.Parent = controls
	end
	if props.showHide then
		buildToggle()
	end

	refreshStatus()

	return {
		root = root,
		illustrative = false,
		reset = function()
			stopReveal()
			week = nil
			hidden = props.startHidden == true
			clearDays()
			highlight(nil)
			if props.showHide then
				buildToggle()
			end
			refreshStatus()
		end,
		destroy = function()
			stopReveal()
			root:Destroy()
		end,
	}
end

return WeatherMachine
