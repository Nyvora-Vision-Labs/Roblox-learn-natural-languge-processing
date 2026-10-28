--!strict
-- Graduation recap (CLAUDE.md §7.7): one line per module, ending with the full lineage.

return {
	title = "You walked the whole history",
	-- Each line follows the module's title on screen, so it starts with the idea, not the name.
	lines = {
		classifiers = "Count the evidence, weigh it, and turn a score into a probability.",
		hmm = "Add order: a hidden state stepping through time.",
		rnn = "Swap that state for a learned vector, with gates to keep memory alive.",
		attention = "Let the decoder look back at every word instead of one summary.",
		transformers = "Keep only attention, run it in parallel, and scale up into language models.",
	},
	lineage = "Bayes → HMMs → RNNs/LSTMs → Attention → Transformers → today's language models",
}
