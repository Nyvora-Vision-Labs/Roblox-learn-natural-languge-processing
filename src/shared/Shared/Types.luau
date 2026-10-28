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

-- One card. Fields beyond id/kind depend on the kind (see CLAUDE.md §5.4).
export type Card = {
	id: string,
	kind: CardKind,
	title: string?,
	body: string?,
	widget: string?,
	widgetProps: { [string]: any }?,
	deeper: string?,
	terms: { string }?,
	-- quiz
	prompt: string?,
	options: { string }?,
	answer: number?,
	explain: { string }?,
	reviewCard: string?,
}

export type Module = {
	id: string,
	title: string,
	era: string,
	cards: { Card },
}

return {}
