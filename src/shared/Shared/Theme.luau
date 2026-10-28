--!strict
-- Design tokens (CLAUDE.md §6). The only place colors, fonts and sizes are defined.

local Theme = {}

Theme.color = {
	bg = Color3.fromHex("#0B1020"),
	surface = Color3.fromHex("#121A2E"),
	surfaceRaised = Color3.fromHex("#1A2440"),
	border = Color3.fromHex("#2A3658"),
	text = Color3.fromHex("#F4F6FB"),
	textMuted = Color3.fromHex("#A7B1CC"),
	textFaint = Color3.fromHex("#7C88A8"),
	success = Color3.fromHex("#3DD68C"),
	danger = Color3.fromHex("#FF6B6B"),
	warning = Color3.fromHex("#FFC857"),
	focus = Color3.fromHex("#FFFFFF"),
}

-- Module accents. Text on an accent fill uses color.bg.
Theme.accent = {
	classifiers = Color3.fromHex("#2DD4BF"), -- Teal
	hmm = Color3.fromHex("#A78BFA"), -- Violet
	rnn = Color3.fromHex("#FBBF24"), -- Amber
	attention = Color3.fromHex("#F472B6"), -- Pink
	transformers = Color3.fromHex("#38BDF8"), -- Sky
} :: { [string]: Color3 }

-- Diagram roles, identical in every module and in formulas.
Theme.role = {
	input = Color3.fromHex("#60A5FA"),
	hidden = Color3.fromHex("#C084FC"),
	weight = Color3.fromHex("#FBBF24"),
	output = Color3.fromHex("#34D399"),
	query = Color3.fromHex("#F472B6"),
}

Theme.font = {
	regular = Font.fromName("BuilderSans", Enum.FontWeight.Regular),
	medium = Font.fromName("BuilderSans", Enum.FontWeight.Medium),
	bold = Font.fromName("BuilderSans", Enum.FontWeight.Bold),
	extraBold = Font.fromName("BuilderSans", Enum.FontWeight.ExtraBold),
	mono = Font.fromName("Inconsolata"),
}

export type TextStyle = { font: Font, size: number, lineHeight: number }

-- Type scale in reference px. Nothing below 16.
Theme.text = {
	display = { font = Theme.font.extraBold, size = 48, lineHeight = 1.1 },
	h1 = { font = Theme.font.bold, size = 36, lineHeight = 1.15 },
	h2 = { font = Theme.font.bold, size = 26, lineHeight = 1.2 },
	body = { font = Theme.font.regular, size = 20, lineHeight = 1.3 },
	label = { font = Theme.font.medium, size = 18, lineHeight = 1.2 },
	caption = { font = Theme.font.regular, size = 16, lineHeight = 1.25 },
	mono = { font = Theme.font.mono, size = 20, lineHeight = 1.2 },
} :: { [string]: TextStyle }

-- 4 px grid
Theme.space = {
	xs = 4,
	sm = 8,
	md = 12,
	lg = 16,
	xl = 24,
	xxl = 32,
	xxxl = 48,
	huge = 64,
}
Theme.cardPadding = 32

Theme.radius = {
	chip = UDim.new(0, 8),
	input = UDim.new(0, 8),
	button = UDim.new(0, 12),
	card = UDim.new(0, 20),
}
Theme.strokeThickness = 1
Theme.focusThickness = 2

-- Durations in seconds
Theme.duration = {
	hover = 0.12,
	state = 0.2,
	screen = 0.32,
	explain = 0.6,
	reducedFade = 0.2,
	portalTransition = 0.8,
}
Theme.cardSlide = 24

Theme.ease = {
	enter = TweenInfo.new(Theme.duration.screen, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
	exit = TweenInfo.new(Theme.duration.screen, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	hover = TweenInfo.new(Theme.duration.hover, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	state = TweenInfo.new(Theme.duration.state, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
}

-- Layout (§6.2)
Theme.stage = Vector2.new(1280, 720)
Theme.maxScale = 1.35
Theme.compactBelow = 0.75
Theme.compactTextMultiplier = 1.5
Theme.minTapTarget = 48 -- reference px
Theme.minTapPoints = 44 -- on-screen points
Theme.textColumnMaxWidth = 640

return Theme
