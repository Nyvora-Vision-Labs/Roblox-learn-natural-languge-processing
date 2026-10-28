--!strict
-- Glossary: every bolded term, defined in plain language. Keys match the cards' `terms`.

local Glossary: { [string]: { module: string, definition: string } } = {
	-- Module 1
	classifier = { module = "classifiers", definition = "A model that predicts a label y from features x." },
	label = { module = "classifiers", definition = "The answer a classifier predicts, such as spam or not spam." },
	features = { module = "classifiers", definition = "The inputs x a model looks at, such as the words in a message." },
	prior = { module = "classifiers", definition = "P(y): how common a label is before seeing any features." },
	likelihood = { module = "classifiers", definition = "P(x | y): how typical the features are for a given label." },
	posterior = { module = "classifiers", definition = "P(y | x): how likely a label is after seeing the features." },
	["conditional independence"] = {
		module = "classifiers",
		definition = "Once you know the class, knowing one feature tells you nothing more about another.",
	},
	["add-one smoothing"] = {
		module = "classifiers",
		definition = "Adding 1 to every count so no word ever gets probability exactly 0. Also called Laplace smoothing.",
	},
	overconfident = {
		module = "classifiers",
		definition = "Giving probabilities closer to 0 or 1 than the evidence justifies.",
	},
	["logistic regression"] = {
		module = "classifiers",
		definition = "A classifier that computes a weighted score z = w·x + b and turns it into a probability with σ.",
	},
	weight = { module = "classifiers", definition = "A learned number saying how strongly a feature pushes toward a label." },
	bias = { module = "classifiers", definition = "A learned number added to the score, shifting the boundary." },
	sigmoid = { module = "classifiers", definition = "σ(z) = 1 / (1 + e^(−z)): squashes any number into the range 0 to 1." },
	["decision boundary"] = {
		module = "classifiers",
		definition = "Where the model is exactly 50/50; for logistic regression, where w·x + b = 0.",
	},
	["log-loss"] = {
		module = "classifiers",
		definition = "The average of −log of the probability the model gave the true label. Lower is better.",
	},
	["gradient descent"] = {
		module = "classifiers",
		definition = "Repeatedly nudging parameters in the direction that lowers the loss.",
	},
	["generative model"] = {
		module = "classifiers",
		definition = "Learns how data is produced, P(x | y) and P(y), so it can generate new examples.",
	},
	["discriminative model"] = {
		module = "classifiers",
		definition = "Learns P(y | x) directly, the boundary between classes, without modeling the data itself.",
	},
	-- Module 2
	sequence = { module = "hmm", definition = "Data that comes in order, where earlier items affect later ones." },
	["Markov chain"] = { module = "hmm", definition = "A model that moves between states, one step at a time, by fixed probabilities." },
	["Markov assumption"] = {
		module = "hmm",
		definition = "The next state depends only on the current state, not on the ones before it.",
	},
	["transition matrix"] = {
		module = "hmm",
		definition = "A, where A(i, j) is the probability of moving from state i to state j. Each row sums to 1.",
	},
	["hidden state"] = { module = "hmm", definition = "A state you can't observe directly and must infer, like the weather in the diary." },
	observation = { module = "hmm", definition = "What you actually see at each step, like the ice creams in the diary." },
	["initial probabilities"] = { module = "hmm", definition = "π: the probability of starting in each state." },
	["emission probabilities"] = {
		module = "hmm",
		definition = "B, where B(i, k) is the probability that state i produces observation k.",
	},
	generative = { module = "hmm", definition = "Models how the data is produced, so it scores (and can sample) whole sequences." },
	["Forward algorithm"] = {
		module = "hmm",
		definition = "Computes the probability of an observation sequence by summing over all hidden paths, day by day.",
	},
	["Viterbi algorithm"] = {
		module = "hmm",
		definition = "Finds the single most likely hidden sequence by keeping the best path into each state, day by day.",
	},
	["Baum–Welch"] = {
		module = "hmm",
		definition = "Learns an HMM's tables from observations alone; a form of expectation-maximization (EM).",
	},
	["speech recognition"] = { module = "hmm", definition = "Turning recorded speech into text." },
	["part-of-speech tagging"] = {
		module = "hmm",
		definition = "Labeling each word in a sentence as a noun, verb, adjective and so on.",
	},
	-- Module 3
	["recurrent neural network"] = { module = "rnn", definition = "A network that reads a sequence one step at a time, carrying a hidden state forward." },
	["hidden state vector"] = { module = "rnn", definition = "h: the list of numbers an RNN carries from step to step, summarizing what it has read." },
	unrolling = { module = "rnn", definition = "Drawing an RNN as one copy per time step, to show how the hidden state passes along." },
	["weight sharing"] = { module = "rnn", definition = "Reusing the same weights at every time step (or position)." },
	["backpropagation through time"] = { module = "rnn", definition = "Training an RNN by unrolling it and sending gradients backward through every step." },
	["vanishing gradient"] = { module = "rnn", definition = "A training signal that shrinks exponentially as it travels back through many steps." },
	["exploding gradient"] = { module = "rnn", definition = "A training signal that grows exponentially as it travels back through many steps." },
	["gradient clipping"] = { module = "rnn", definition = "Capping the size of a gradient so one huge step can't wreck training." },
	LSTM = { module = "rnn", definition = "Long short-term memory: a gated RNN cell with a separate cell state for long-range memory." },
	["cell state"] = { module = "rnn", definition = "c: an LSTM's memory lane, updated mostly by addition, cₜ = fₜ⊙cₜ₋₁ + iₜ⊙gₜ." },
	gate = { module = "rnn", definition = "A sigmoid dial between 0 and 1 that controls how much information passes." },
	GRU = { module = "rnn", definition = "Gated recurrent unit: a simpler gated RNN cell with two gates and no separate cell state." },
	["encoder–decoder"] = { module = "rnn", definition = "One network reads the input into vectors; another writes the output from them." },
	seq2seq = { module = "rnn", definition = "Sequence-to-sequence: mapping one sequence to another, such as a sentence to its translation." },
	-- Module 4
	attention = { module = "attention", definition = "Letting a model weight and blend every input position when producing each output." },
	bottleneck = { module = "attention", definition = "Forcing all information through one small, fixed-size vector." },
	["context vector"] = { module = "attention", definition = "The attention-weighted sum of encoder states handed to the decoder at one output step." },
	softmax = { module = "attention", definition = "Turns a list of scores into non-negative weights that sum to 1." },
	query = { module = "attention", definition = "What the current position is looking for." },
	key = { module = "attention", definition = "What each position can be matched on." },
	value = { module = "attention", definition = "What each position hands back when it's attended to." },
	alignment = { module = "attention", definition = "Which input words each output word corresponds to." },
	-- Module 5
	["self-attention"] = { module = "transformers", definition = "Attention where every token of a sequence attends to every token of the same sequence." },
	["scaled dot-product attention"] = { module = "transformers", definition = "softmax(QKᵀ / √dₖ)·V: attention scored by dot products and scaled by the key length." },
	["multi-head attention"] = { module = "transformers", definition = "Several attention operations in parallel, each with its own weights, combined at the end." },
	["positional encoding"] = { module = "transformers", definition = "Position information added to each token, since attention alone ignores order." },
	["residual connection"] = { module = "transformers", definition = "Adding a layer's input to its output, so information and gradients can skip the layer." },
	["layer normalization"] = { module = "transformers", definition = "Rescaling each token's vector to a standard mean and spread, which stabilizes training." },
	["cross-attention"] = { module = "transformers", definition = "Attention where the decoder's queries look at the encoder's outputs." },
	["causal mask"] = { module = "transformers", definition = "Blocks each position from attending to later positions." },
	["quadratic cost"] = { module = "transformers", definition = "Work that grows with the square of the sequence length, as all-pairs attention does." },
	["language model"] = { module = "transformers", definition = "A model that assigns probabilities to sequences of words or tokens." },
	["next-token prediction"] = { module = "transformers", definition = "Training a model to predict P(next token | previous tokens)." },
}

return Glossary
