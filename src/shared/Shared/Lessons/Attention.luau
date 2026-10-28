--!strict
-- Module 4: Attention (CLAUDE.md §7.5).
-- Running example: English → French, "the European Economic Area" → "la zone économique
-- européenne", where the word order flips (as in Bahdanau, Cho & Bengio, 2014, figure 3).
-- Ground truth: Bahdanau et al. (2014); Luong et al. (2015); Jain & Wallace (2019).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local ENGLISH = { "the", "European", "Economic", "Area" }
local FRENCH = { "la", "zone", "économique", "européenne" }

-- Toy 2-D keys and values for the four English words, and three decoder queries. Hand-picked so
-- each query lines up with one word; every score, weight and blend is computed from them.
local BLEND = {
	words = ENGLISH,
	keys = { { 0.2, 0.1 }, { 1.0, -0.2 }, { 0.1, 1.0 }, { -0.8, 0.4 } },
	values = { { 0.1, 0.0 }, { 0.9, 0.2 }, { 0.2, 0.9 }, { 0.6, 0.6 } },
	queries = {
		{ label = "zone", vector = { -1.2, 0.6 } },
		{ label = "économique", vector = { 0.2, 1.4 } },
		{ label = "européenne", vector = { 1.4, -0.3 } },
	},
}

-- Hand-authored alignment weights in the spirit of Bahdanau et al.'s figure. Rows: French words,
-- columns: English words. Shown with an "Illustrative" badge; each row sums to 1.
local ALIGNMENT = {
	source = ENGLISH,
	target = FRENCH,
	weights = {
		{ 0.88, 0.04, 0.03, 0.05 }, -- la
		{ 0.06, 0.05, 0.09, 0.80 }, -- zone
		{ 0.02, 0.10, 0.84, 0.04 }, -- économique
		{ 0.03, 0.85, 0.07, 0.05 }, -- européenne
	},
}

local LONG_SENTENCE = {
	"the", "agreement", "on", "the", "European", "Economic", "Area", "was", "signed", "in", "August", "1992",
}

local module: Types.Module = {
	cards = {
		{
			id = "att-journey",
			kind = "concept",
			journey = true,
			title = "One vector isn't enough",
			body = "Try translating a long sentence after hearing it once, without notes. Hard, right? A translator glances back at the source as they go. This module gives neural networks the same ability: to look back.",
			bridge = "A seq2seq encoder squeezes the whole input sentence into one fixed-size vector. That bottleneck hurts on long sentences.",
		},
		{
			id = "att-bottleneck",
			kind = "interactive",
			title = "The bottleneck",
			body = "In plain seq2seq, every word of the source has to fit through one final hidden vector before the decoder writes anything. Long sentences overflow it, and translation quality drops as sentences get longer. <b>Attention</b> lets the decoder reach back to every source word instead.",
			terms = { "attention", "bottleneck" },
			widget = "Bottleneck",
			widgetProps = { words = LONG_SENTENCE },
			instruction = "Switch between the two designs and compare what the decoder can see.",
		},
		{
			id = "att-idea",
			kind = "concept",
			title = "Look back at every word",
			body = "Bahdanau, Cho and Bengio (2014) kept every encoder hidden state, not only the last. At each output step, the decoder scores all of them, focuses on the relevant ones, and blends them into a <b>context vector</b> for that step. Luong et al. (2015) simplified the scoring.",
			terms = { "context vector" },
			deeper = "Bahdanau scored with a small neural network (additive attention); Luong proposed simpler forms, including a plain dot product.",
		},
		{
			id = "att-mechanics",
			kind = "math",
			title = "Score, softmax, blend",
			body = "Three steps at every output word: score each encoder state against the decoder's current state, turn the scores into weights with softmax, then take the weighted sum of the states.",
			formula = "{query|αᵢ} = softmax(score({query|s}, {hidden|hᵢ}))      {output|c} = Σᵢ {query|αᵢ}·{hidden|hᵢ}",
			legend = {
				{ symbol = "s", meaning = "the decoder's current state: what it needs next", role = "query" },
				{ symbol = "hᵢ", meaning = "encoder state for source word i", role = "hidden" },
				{ symbol = "αᵢ", meaning = "attention weight on word i: ≥ 0, and all of them sum to 1", role = "query" },
				{ symbol = "c", meaning = "context vector: the blend handed to the decoder", role = "output" },
			},
			terms = { "softmax" },
			deeper = "softmax(z)ᵢ = e^(zᵢ) / Σⱼ e^(zⱼ). Exponentials are positive and the division normalizes, so the weights are non-negative and sum to 1.",
		},
		{
			id = "att-qkv",
			kind = "concept",
			title = "Query, key, value",
			body = "A helpful way to name the parts: the <b>query</b> is what I'm looking for. Each item's <b>key</b> is what it can be matched on. Its <b>value</b> is what it hands back if chosen. Scores come from comparing the query with each key, often by a dot product.",
			terms = { "query", "key", "value" },
			deeper = "In Bahdanau-style attention the keys and values are both the encoder states hᵢ; Transformers compute them separately (next module).",
		},
		{
			id = "att-blend",
			kind = "interactive",
			title = "Watch the weights form",
			body = "Pick which French word the decoder is producing. Its query is compared with each English key by a dot product, softmax turns the scores into weights, and the weighted blend of values becomes the context vector. Sharpness changes how peaked softmax is.",
			widget = "ScoreSoftmaxBlend",
			widgetProps = BLEND,
			instruction = "Choose a query, then drag sharpness and watch the weights.",
			deeper = "Sharpness divides the scores by a temperature τ before softmax: smaller τ makes the largest weight dominate; larger τ spreads weight evenly.",
		},
		{
			id = "att-alignment",
			kind = "interactive",
			title = "Attention as alignment",
			body = "Plot each French word's weights over the English words and you get a soft <b>alignment</b>. French puts the adjectives after the noun, so the bright cells leave the diagonal and cross over. That bend is the reordering, learned without anyone labeling it.",
			terms = { "alignment" },
			widget = "AlignmentHeatmap",
			widgetProps = ALIGNMENT,
			instruction = "Tap a French word to see which English words it attends to.",
		},
		{
			id = "att-caveats",
			kind = "concept",
			title = "What the weights don't tell you",
			body = "Attention weights are a handy window into a model, but an imperfect explanation: different weights can sometimes lead to the same output (Jain & Wallace, 2019). Weights show where the model looked, not that it understood.",
		},
		{
			id = "att-history",
			kind = "concept",
			title = "Attention came to RNNs first",
			body = "Attention began as an add-on to RNN encoder–decoders. It worked so well that a natural question followed: if attention can connect any two positions directly, do we still need the recurrence at all? That's the next module.",
		},
		{
			id = "att-recap",
			kind = "recap",
			title = "Recap",
			points = {
				"Plain seq2seq squeezes a sentence into one vector, a bottleneck for long inputs.",
				"Attention scores every encoder state, softmaxes the scores, and blends the states.",
				"Softmax weights are non-negative and sum to 1 for each query.",
				"Query: what I'm looking for; key: what each item matches on; value: what it gives back.",
				"Attention weights look like alignments, but they aren't proof of understanding.",
			},
		},
		{
			id = "att-q1",
			kind = "quiz",
			prompt = "What problem did attention first solve?",
			options = {
				"Squeezing a whole sentence into one fixed-size vector",
				"Training was too slow on GPUs",
				"Words had no vector representation",
			},
			answer = 1,
			explain = {
				"Right. The decoder can now look back at every encoder state instead of one summary.",
				"Not quite. Speed came later, when Transformers dropped recurrence.",
				"Not quite. Words already had vectors; the problem was the single summary vector.",
			},
			reviewCard = "att-bottleneck",
		},
		{
			id = "att-q2",
			kind = "quiz",
			prompt = "What does softmax guarantee about one query's attention weights?",
			options = {
				"They are non-negative and sum to 1",
				"Exactly one weight is 1",
				"They are all equal",
			},
			answer = 1,
			explain = {
				"Right. That's what lets us read them as a distribution over the words.",
				"Not quite. Softmax is soft: several words can share the weight.",
				"Not quite. They're equal only when all the scores are equal.",
			},
			reviewCard = "att-mechanics",
		},
		{
			id = "att-q3",
			kind = "quiz",
			prompt = "What is the context vector?",
			options = {
				"The attention-weighted sum of the encoder states",
				"The decoder's final output word",
				"The first word of the source sentence",
			},
			answer = 1,
			explain = {
				"Right. c = Σ αᵢ·hᵢ, recomputed at every output step.",
				"Not quite. The context vector feeds the decoder; it isn't the output.",
				"Not quite. It blends every source state, weighted by attention.",
			},
			reviewCard = "att-blend",
		},
		{
			id = "att-q4",
			kind = "quiz",
			prompt = "In query/key/value terms, which statement is right?",
			options = {
				"The query is compared with keys; the chosen values are blended",
				"Keys are blended; values are compared with the query",
				"The query is blended with itself",
			},
			answer = 1,
			explain = {
				"Right. Scores come from query·key; the output mixes the values.",
				"Not quite. It's the other way round: match on keys, return values.",
				"Not quite. The query only drives the scoring.",
			},
			reviewCard = "att-qkv",
		},
		{
			id = "att-q5",
			kind = "quiz",
			prompt = "Why does the translation heatmap's bright diagonal bend?",
			options = {
				"French orders adjectives and nouns differently, so words align out of order",
				"The model made a mistake",
				"Softmax always shuffles the weights",
			},
			answer = 1,
			explain = {
				"Right. “zone” attends to “Area” and “européenne” to “European”: the reordering shows up as the bend.",
				"Not quite. The bend is the correct reordering, not an error.",
				"Not quite. Softmax only normalizes scores; it doesn't reorder anything.",
			},
			reviewCard = "att-alignment",
		},
	},
}

return module
