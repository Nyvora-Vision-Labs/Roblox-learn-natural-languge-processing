--!strict
-- Shared types. Keep them simple; strict-mode errors only show in Script Analysis.

export type ModuleProgress = {
	completed: boolean,
	bestScore: number,
	lastCard: number,
}

export type Settings = {
	textScale: number,
	reducedMotion: boolean,
	muted: boolean,
}

export type Progress = {
	v: number,
	modules: { [string]: ModuleProgress },
	settings: Settings,
	seenIntro: boolean,
}

-- What GetProgress returns and ProgressChanged sends.
export type ProgressPayload = {
	progress: Progress,
	persistent: boolean, -- false = DataStore unavailable, playing from memory
}

export type ReportKind = "opened" | "card" | "completed"

export type LessonReport = {
	kind: ReportKind,
	moduleId: string,
	cardIndex: number?,
	score: number?,
}

export type CardKind = "concept" | "interactive" | "compare" | "math" | "quiz" | "recap"

-- Diagram roles (Theme.role); formulas mark variables as {role|text}, e.g. "P({output|y} | {input|x})".
export type Role = "input" | "hidden" | "weight" | "output" | "query"

export type LegendRow = { symbol: string, meaning: string, role: Role? }

export type CompareSide = { title: string, body: string, points: { string }? }

-- One card. Fields beyond id/kind depend on the kind (see CLAUDE.md §5.4).
export type Card = {
	id: string,
	kind: CardKind,
	title: string?,
	body: string?,
	terms: { string }?,
	deeper: string?, -- optional math, revealed by "Go deeper"
	journey: boolean?, -- concept: show the five-module journey (card 1 of every module)
	bridge: string?, -- concept + journey: the link from the previous module
	-- interactive
	widget: string?,
	widgetProps: { [string]: any }?,
	instruction: string?, -- one line above the widget
	-- compare
	left: CompareSide?,
	right: CompareSide?,
	-- math
	formula: string?,
	legend: { LegendRow }?,
	-- recap
	points: { string }?,
	-- quiz
	prompt: string?,
	options: { string }?,
	answer: number?,
	explain: { string }?,
	reviewCard: string?,
}

-- A module's content file returns this; title/era come from Lessons/Index.
export type Module = {
	cards: { Card },
}

return {}
