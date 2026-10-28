--!strict
-- Module 2: Hidden Markov Models (CLAUDE.md §7.3).
-- Running example: Jason Eisner's ice-cream task as presented in Jurafsky & Martin, Speech and
-- Language Processing, appendix A. Hidden weather (Hot/Cold), observed ice creams eaten (1–3).
-- Every number a widget shows is computed from this model with Math/Viterbi.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local ICE_CREAM = {
	states = { "Hot", "Cold" },
	symbols = { "1", "2", "3" }, -- ice creams eaten that day
	pi = { 0.8, 0.2 },
	A = {
		{ 0.6, 0.4 }, -- from Hot: to Hot, to Cold
		{ 0.5, 0.5 }, -- from Cold
	},
	B = {
		{ 0.2, 0.4, 0.4 }, -- Hot eats 1 / 2 / 3
		{ 0.5, 0.4, 0.1 }, -- Cold
	},
}

local DIARY = { 3, 1, 3 } -- the observed sequence

local module: Types.Module = {
	cards = {
		{
			id = "hmm-journey",
			kind = "concept",
			journey = true,
			title = "Weather you can't see",
			body = "A climate scientist finds an old diary. It doesn't mention the weather, but every day it records how many ice creams the writer ate. Can you work out which days were hot? This module builds the model that answers that.",
			bridge = "Naive Bayes treats a message as an unordered bag of words. But speech, text and weather come in sequences, where order matters.",
		},
		{
			id = "hmm-sequences",
			kind = "concept",
			title = "When order matters",
			body = "In a sequence, what happens today depends on what came before. A hot day tends to follow a hot day. In speech, one sound shapes the next. A bag-of-words model can't see any of that, so we need a model that steps through time.",
			terms = { "sequence" },
		},
		{
			id = "hmm-markov",
			kind = "interactive",
			title = "A Markov chain",
			body = "A <b>Markov chain</b> moves between states, one step at a time. Its key simplification, the <b>Markov assumption</b>: tomorrow depends only on today, not on the days before. The chances of each move form the <b>transition matrix</b> A, and each row of A sums to 1.",
			terms = { "Markov chain", "Markov assumption", "transition matrix" },
			widget = "WeatherMachine",
			widgetProps = { model = ICE_CREAM, days = 7, showHide = false },
			instruction = "Sample a week and watch the weather walk between states.",
			deeper = "Markov assumption: P({hidden|sₜ} | {hidden|s₁}, …, {hidden|sₜ₋₁}) = P({hidden|sₜ} | {hidden|sₜ₋₁}). Row “Hot” of A is (0.6, 0.4): 0.6 + 0.4 = 1.",
		},
		{
			id = "hmm-hidden",
			kind = "interactive",
			title = "What “hidden” means",
			body = "In the diary, you never see the weather. You only see its effects: the ice creams. The weather is a <b>hidden state</b>; the ice creams are <b>observations</b>. “Hidden” means unobserved, not random. Each state has its own chances of producing each observation.",
			terms = { "hidden state", "observation" },
			widget = "WeatherMachine",
			widgetProps = { model = ICE_CREAM, days = 7, showHide = true, startHidden = true },
			instruction = "Sample a week, guess the weather, then reveal it.",
		},
		{
			id = "hmm-parts",
			kind = "math",
			title = "The three ingredients",
			body = "An HMM is fully described by three tables. Here they come from the diary example. Start with π, step with A, and at every step emit an observation using B.",
			terms = { "initial probabilities", "emission probabilities" },
			formula = "λ = ({weight|π}, {weight|A}, {weight|B})",
			legend = {
				{ symbol = "states", meaning = "Hot, Cold: hidden, never observed", role = "hidden" },
				{ symbol = "observations", meaning = "1, 2 or 3 ice creams: what the diary shows", role = "input" },
				{ symbol = "π", meaning = "where to start: P(Hot) = 0.8, P(Cold) = 0.2", role = "weight" },
				{ symbol = "A", meaning = "transitions: Hot→Hot 0.6, Hot→Cold 0.4, Cold→Hot 0.5, Cold→Cold 0.5", role = "weight" },
				{ symbol = "B", meaning = "emissions: Hot eats 1/2/3 with 0.2/0.4/0.4; Cold with 0.5/0.4/0.1", role = "weight" },
			},
		},
		{
			id = "hmm-joint",
			kind = "math",
			title = "A story, scored",
			body = "An HMM is <b>generative</b>, like Naive Bayes: it tells a story of how the data was made. Multiply the start, every step and every emission, and you get the probability of a weather sequence and a diary together.",
			terms = { "generative" },
			formula = "P({hidden|s}, {input|o}) = π({hidden|s₁})·B({hidden|s₁}, {input|o₁}) · ∏ A({hidden|sₜ₋₁}, {hidden|sₜ})·B({hidden|sₜ}, {input|oₜ})",
			legend = {
				{ symbol = "s", meaning = "a hidden sequence, e.g. Hot, Cold, Hot", role = "hidden" },
				{ symbol = "o", meaning = "the observations, e.g. 3, 1, 3", role = "input" },
				{ symbol = "∏", meaning = "multiply over days t = 2 … T" },
			},
			deeper = "For Hot, Cold, Hot with diary 3, 1, 3: 0.8·0.4 × 0.4·0.5 × 0.5·0.4 = 0.32 × 0.2 × 0.2 = 0.0128.",
		},
		{
			id = "hmm-problems",
			kind = "concept",
			title = "Three classic questions",
			body = "<b>Likelihood</b>: how probable is this diary? The <b>Forward algorithm</b> answers it. <b>Decoding</b>: which weather sequence best explains it? That's <b>Viterbi</b>. <b>Learning</b>: what should π, A and B be? <b>Baum–Welch</b>, a form of expectation-maximization (EM), estimates them from diaries alone.",
			terms = { "Forward algorithm", "Viterbi algorithm", "Baum–Welch" },
			deeper = "Trying every weather sequence takes Nᵀ paths. Forward and Viterbi share work across paths day by day, so they take about N²·T steps.",
		},
		{
			id = "hmm-viterbi",
			kind = "interactive",
			title = "Decoding with Viterbi",
			body = "Viterbi fills a grid, one day at a time. Each cell holds the probability of the best path that ends in that state on that day, and remembers which state it came from. At the end, follow those arrows back.",
			widget = "ViterbiTrellis",
			widgetProps = { model = ICE_CREAM, obs = DIARY, compare = false },
			instruction = "Guess the weather for each day, then step through Viterbi.",
			deeper = "Vₜ(j) = maxᵢ Vₜ₋₁(i)·A(i, j) · B(j, oₜ). The back-pointer stores the i that won the max.",
		},
		{
			id = "hmm-forward",
			kind = "interactive",
			title = "Sum or best?",
			body = "Forward fills the same grid but adds paths instead of keeping the best one. Its last column sums to the probability of the whole diary. Viterbi's best path is the single most likely sequence; that can differ from picking each day's most likely state on its own.",
			widget = "ViterbiTrellis",
			widgetProps = { model = ICE_CREAM, obs = DIARY, compare = true },
			instruction = "Switch between Forward and Viterbi and compare the numbers.",
			deeper = "αₜ(j) = Σᵢ αₜ₋₁(i)·A(i, j) · B(j, oₜ). For this diary the two answers agree day by day; with other numbers they need not.",
		},
		{
			id = "hmm-uses",
			kind = "concept",
			title = "Where HMMs worked",
			body = "For decades HMMs powered <b>speech recognition</b>: hidden sounds, observed audio. They tagged words with parts of speech: hidden noun or verb, observed word. They found genes in DNA: hidden coding regions, observed letters. Same three tables, very different stories.",
			terms = { "speech recognition", "part-of-speech tagging" },
		},
		{
			id = "hmm-limits",
			kind = "concept",
			title = "Where HMMs fall short",
			body = "An HMM remembers only one state out of a small, fixed set, and only the last step. Language needs more: whether a verb is singular can depend on a word far back. To carry richer memory, the next module swaps the discrete state for a learned vector of numbers.",
		},
		{
			id = "hmm-recap",
			kind = "recap",
			title = "Recap",
			points = {
				"A Markov chain's next state depends only on the current one; each row of A sums to 1.",
				"An HMM has hidden states, observations, and three tables: π, A and B.",
				"It's generative: it scores a hidden sequence and observations together.",
				"Forward gives the likelihood, Viterbi the best hidden sequence, Baum–Welch learns the tables.",
				"Its memory is one discrete state, which limits how far back it can look.",
			},
		},
		{
			id = "hmm-q1",
			kind = "quiz",
			prompt = "What does the Markov assumption say?",
			options = {
				"The next state depends only on the current state",
				"Every state is equally likely",
				"States never repeat",
			},
			answer = 1,
			explain = {
				"Right. Given today, earlier days add nothing about tomorrow.",
				"Not quite. The transition probabilities can be anything, as long as each row sums to 1.",
				"Not quite. Hot can follow Hot; here that has probability 0.6.",
			},
			reviewCard = "hmm-markov",
		},
		{
			id = "hmm-q2",
			kind = "quiz",
			prompt = "In the diary example, what is hidden and what is observed?",
			options = {
				"Weather is hidden; ice creams are observed",
				"Ice creams are hidden; weather is observed",
				"Both are observed",
			},
			answer = 1,
			explain = {
				"Right. The diary records ice creams; the weather has to be inferred.",
				"Not quite. The diary shows ice creams, so those are what we see.",
				"Not quite. If the weather were observed, there'd be nothing to decode.",
			},
			reviewCard = "hmm-hidden",
		},
		{
			id = "hmm-q3",
			kind = "quiz",
			prompt = "Which algorithm finds the single most likely hidden sequence?",
			options = { "Forward", "Viterbi", "Baum–Welch" },
			answer = 2,
			explain = {
				"Not quite. Forward sums over all paths to get the likelihood.",
				"Right. It keeps the best path into each state and traces it back.",
				"Not quite. Baum–Welch learns the model's tables from data.",
			},
			reviewCard = "hmm-viterbi",
		},
		{
			id = "hmm-q4",
			kind = "quiz",
			prompt = "Is an HMM generative or discriminative?",
			options = { "Generative", "Discriminative" },
			answer = 1,
			explain = {
				"Right. It models how the states and observations are produced, P(s, o).",
				"Not quite. An HMM models the joint P(s, o), like Naive Bayes, so it's generative.",
			},
			reviewCard = "hmm-joint",
		},
		{
			id = "hmm-q5",
			kind = "quiz",
			prompt = "An HMM has N hidden states. What size is its transition matrix A?",
			options = { "N × N", "N × 1", "N × T, where T is the sequence length" },
			answer = 1,
			explain = {
				"Right. One row per current state, one column per next state.",
				"Not quite. That would be one number per state, like π.",
				"Not quite. A doesn't depend on the sequence length; it's reused at every step.",
			},
			reviewCard = "hmm-markov",
		},
	},
}

return module
