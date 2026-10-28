--!strict
-- Module 3: RNNs and LSTMs (CLAUDE.md §7.4).
-- Running example: "The cats that the dog chased were hungry." The verb must agree with "cats",
-- several words back, past the singular "dog". Ground truth: Goodfellow, Bengio & Courville,
-- Deep Learning, ch. 10; Hochreiter & Schmidhuber (1997); Gers et al. (2000); Cho et al. (2014);
-- Sutskever et al. (2014). Widgets compute everything with Math/Linear.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local SENTENCE = { "The", "cats", "that", "the", "dog", "chased", "were", "hungry" }

-- A toy RNN: 2-number word vectors, 3-number hidden state. Hand-picked weights so the demo is
-- readable; every hidden value shown is computed from them with the real recurrence.
local TOY_RNN = {
	words = SENTENCE,
	embeddings = {
		The = { 0.1, 0 },
		cats = { 1, 0.6 },
		that = { 0, 0.1 },
		the = { 0.1, 0 },
		dog = { 1, -0.6 },
		chased = { 0.3, 0.2 },
		were = { 0.2, 0.5 },
		hungry = { 0.4, 0.1 },
	},
	Wh = { { 0.5, 0.1, 0 }, { 0, 0.6, 0.2 }, { 0.1, 0, 0.4 } },
	Wx = { { 0.8, 0 }, { 0, 1.2 }, { 0.4, -0.5 } },
	b = { 0, 0, 0.1 },
}

-- Cell-state demo: "plural" is +1, "singular" is −1, other words write nothing.
local LSTM_STORY = {
	words = SENTENCE,
	candidates = { The = 0, cats = 1, that = 0, the = 0, dog = -1, chased = 0, were = 0, hungry = 0 },
	writeAt = "cats", -- the subject is written in fully here
	readAt = "were", -- the verb reads the memory here
}

local module: Types.Module = {
	cards = {
		{
			id = "rnn-journey",
			kind = "concept",
			journey = true,
			title = "Which verb?",
			body = "“The cats that the dog chased ___ hungry.” Was or were? You need to remember “cats” from five words back, while ignoring the singular “dog” in between. This module is about models that can carry that memory.",
			bridge = "An HMM remembers one discrete state out of a few. An RNN carries a learned vector of numbers instead.",
		},
		{
			id = "rnn-memory",
			kind = "concept",
			title = "Memory as numbers",
			body = "A <b>recurrent neural network</b> (RNN) reads one word at a time. After each word it updates a <b>hidden state</b> h: a short list of numbers summarizing what it has read so far. The memory is numbers, not stored words, and training decides what those numbers track.",
			terms = { "recurrent neural network", "hidden state vector" },
		},
		{
			id = "rnn-recurrence",
			kind = "math",
			title = "One step of an RNN",
			body = "Each step mixes the previous hidden state with the new word, then squashes the result with tanh into the range −1 to 1. The output at each step, such as a guess at the next word, is computed from hₜ.",
			formula = "{hidden|hₜ} = tanh({weight|Wₕ}·{hidden|hₜ₋₁} + {weight|Wₓ}·{input|xₜ} + {weight|b})",
			legend = {
				{ symbol = "xₜ", meaning = "the word at step t, as a vector of numbers", role = "input" },
				{ symbol = "hₜ₋₁", meaning = "the hidden state after the previous word", role = "hidden" },
				{ symbol = "hₜ", meaning = "the new hidden state", role = "hidden" },
				{ symbol = "Wₕ, Wₓ, b", meaning = "learned weights and bias, the same at every step", role = "weight" },
				{ symbol = "tanh", meaning = "squashes each number into −1 … 1" },
			},
			deeper = "An output layer reads the state: {output|yₜ} = softmax({weight|Wᵧ}·{hidden|hₜ} + {weight|c}), for example a probability for each possible next word.",
		},
		{
			id = "rnn-unroll",
			kind = "interactive",
			title = "Unrolling the loop",
			body = "Drawn compactly, an RNN is one cell with a loop. <b>Unrolling</b> it over a sentence shows one copy per word, passing h along. It's still one network: the same weights are reused at every step. That sharing is why it handles sentences of any length.",
			terms = { "unrolling", "weight sharing" },
			widget = "UnrollTheLoop",
			widgetProps = { rnn = TOY_RNN },
			instruction = "Unroll the loop, then tap a word to inspect its hidden state.",
			deeper = "The bars show real values of hₜ, computed with the formula from the previous card using small toy weights.",
		},
		{
			id = "rnn-bptt",
			kind = "concept",
			title = "Learning through time",
			body = "To train an RNN, unroll it over a sentence, measure the error at each step, and send gradients backward through every copy of the cell. That's <b>backpropagation through time</b> (BPTT). Because the copies share weights, their updates add up into one change.",
			terms = { "backpropagation through time" },
			deeper = "The gradient for Wₕ is the sum of its gradients at every step. Real systems often truncate BPTT to the last few dozen steps to save time and memory.",
		},
		{
			id = "rnn-vanishing",
			kind = "interactive",
			title = "Gradients that fade or explode",
			body = "Going back in time, the gradient is multiplied by a similar factor at every step. Below 1, it shrinks exponentially: early words barely learn. That's a <b>vanishing gradient</b>. Above 1, it blows up: an <b>exploding gradient</b>. <b>Gradient clipping</b> caps explosions; gated cells fix vanishing.",
			terms = { "vanishing gradient", "exploding gradient", "gradient clipping" },
			widget = "GradientTelephone",
			widgetProps = { steps = 20, clip = 5 },
			instruction = "Change the per-step factor and see how much gradient reaches each earlier word.",
			deeper = "Simplified to one number: after k steps back, the gradient is scaled by roughly factorᵏ. With real matrices the factor is set by the weights and the slope of tanh.",
		},
		{
			id = "rnn-lstm",
			kind = "concept",
			title = "The LSTM idea",
			body = "The <b>long short-term memory</b> (LSTM) cell (Hochreiter & Schmidhuber, 1997) adds a <b>cell state</b> c: a protected memory lane. Gates decide what to forget, what to write and what to reveal. Its forget gate came a little later (Gers et al., 2000).",
			terms = { "LSTM", "cell state", "gate" },
			deeper = "Because cₜ is updated mostly by addition, not by repeated squashing, gradients along it survive longer spans. It makes long-range learning easier, not free.",
		},
		{
			id = "rnn-gates",
			kind = "math",
			title = "Inside the cell",
			body = "Each gate is a sigmoid, so it's a dial between 0 (closed) and 1 (open). The candidate g proposes new content. The cell state keeps a fraction of the old memory and adds a fraction of the new.",
			formula = "{hidden|cₜ} = {weight|fₜ} ⊙ {hidden|cₜ₋₁} + {weight|iₜ} ⊙ gₜ      {hidden|hₜ} = {weight|oₜ} ⊙ tanh({hidden|cₜ})",
			legend = {
				{ symbol = "fₜ", meaning = "forget gate: how much old memory to keep (0 … 1)", role = "weight" },
				{ symbol = "iₜ", meaning = "input gate: how much new content to write (0 … 1)", role = "weight" },
				{ symbol = "oₜ", meaning = "output gate: how much memory to reveal (0 … 1)", role = "weight" },
				{ symbol = "gₜ", meaning = "candidate: new content, tanh(…), in −1 … 1" },
				{ symbol = "cₜ", meaning = "cell state: the memory lane", role = "hidden" },
				{ symbol = "⊙", meaning = "multiply element by element" },
			},
			deeper = "Each gate is σ(W·[{hidden|hₜ₋₁}, {input|xₜ}] + b) with its own weights; gₜ uses tanh instead of σ.",
		},
		{
			id = "rnn-lstm-play",
			kind = "interactive",
			title = "Keep “plural” alive",
			body = "Here the cell state is one number: +1 means “plural subject”, −1 “singular”. “cats” writes +1. Your gates apply to every word in between. Can you keep the signal alive past “dog” so “were” reads plural? This is a one-number simplification of a real cell.",
			widget = "LSTMGates",
			widgetProps = { story = LSTM_STORY },
			instruction = "Set the gates so the memory still says “plural” at “were”.",
		},
		{
			id = "rnn-gru",
			kind = "concept",
			title = "A simpler cousin: the GRU",
			body = "The <b>gated recurrent unit</b> (GRU) (Cho et al., 2014) merges the cell state into the hidden state and uses two gates instead of three. It has fewer weights and often performs about as well as an LSTM.",
			terms = { "GRU" },
		},
		{
			id = "rnn-seq2seq",
			kind = "concept",
			title = "Translating with two RNNs",
			body = "Sequence-to-sequence (seq2seq) models (Sutskever et al., 2014) use an <b>encoder</b> RNN to read a sentence into one final vector, and a <b>decoder</b> RNN to write the translation from it. Squeezing a whole sentence into one vector is a bottleneck. The next module fixes it.",
			terms = { "encoder–decoder", "seq2seq" },
		},
		{
			id = "rnn-recap",
			kind = "recap",
			title = "Recap",
			points = {
				"An RNN reuses one set of weights at every step and carries a hidden state vector h.",
				"Training unrolls it and backpropagates through time.",
				"Gradients shrink or blow up exponentially with distance; clipping and gates help.",
				"An LSTM's gates control a cell state c that is updated mostly by addition.",
				"Seq2seq squeezes a sentence into one vector, which sets up attention.",
			},
		},
		{
			id = "rnn-q1",
			kind = "quiz",
			prompt = "What is shared across the time steps of an RNN?",
			options = { "The weights", "The hidden state values", "The input words" },
			answer = 1,
			explain = {
				"Right. One set of weights is reused at every step.",
				"Not quite. The hidden state changes at every step; that's the memory.",
				"Not quite. Each step reads a different word.",
			},
			reviewCard = "rnn-unroll",
		},
		{
			id = "rnn-q2",
			kind = "quiz",
			prompt = "Why do gradients vanish in a plain RNN?",
			options = {
				"They're multiplied by a factor below 1 at every step back, so they shrink exponentially",
				"The training data is too small",
				"The hidden state is too large",
			},
			answer = 1,
			explain = {
				"Right. Repeated multiplication by a number below 1 drives the signal toward 0.",
				"Not quite. Vanishing happens even with plenty of data; it's about repeated multiplication.",
				"Not quite. The size of h isn't the cause; the repeated factor through time is.",
			},
			reviewCard = "rnn-vanishing",
		},
		{
			id = "rnn-q3",
			kind = "quiz",
			prompt = "What does the forget gate do?",
			options = {
				"Decides how much of the old cell state to keep",
				"Deletes words from the input",
				"Decides which word to output",
			},
			answer = 1,
			explain = {
				"Right. fₜ multiplies cₜ₋₁: near 1 keeps it, near 0 erases it.",
				"Not quite. Gates act on the cell's numbers, not on the input sentence.",
				"Not quite. That's closer to the output gate and output layer.",
			},
			reviewCard = "rnn-gates",
		},
		{
			id = "rnn-q4",
			kind = "quiz",
			prompt = "What is cₜ in an LSTM?",
			options = {
				"The cell state: a memory updated mostly by addition",
				"The current word",
				"The learning rate",
			},
			answer = 1,
			explain = {
				"Right. cₜ = fₜ⊙cₜ₋₁ + iₜ⊙gₜ is the protected memory lane.",
				"Not quite. The current word is xₜ.",
				"Not quite. The learning rate is a training setting, not part of the cell.",
			},
			reviewCard = "rnn-lstm",
		},
		{
			id = "rnn-q5",
			kind = "quiz",
			prompt = "What does backpropagation through time do?",
			options = {
				"Unrolls the RNN and sends gradients backward through every step",
				"Runs the sentence backward to make predictions",
				"Removes the loop so the network forgets",
			},
			answer = 1,
			explain = {
				"Right. The shared weights collect gradient from every step.",
				"Not quite. It's a training method; predictions still read forward.",
				"Not quite. Unrolling is a view of the same network; nothing is removed.",
			},
			reviewCard = "rnn-bptt",
		},
	},
}

return module
