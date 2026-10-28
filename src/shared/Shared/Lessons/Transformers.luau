--!strict
-- Module 5: Transformers (CLAUDE.md §7.6).
-- Running example: "The animal didn't cross the street because it was too tired." vs "…too wide."
-- Ground truth: Vaswani et al. (2017), "Attention Is All You Need"; Devlin et al. (2019, BERT);
-- Radford et al. (2018/2019, GPT). Calculator numbers are computed with Math/Linear.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local IT_SENTENCE = { "The", "animal", "didn't", "cross", "the", "street", "because", "it", "was", "too" }

-- Hand-authored weights for what "it" attends to, in the spirit of published visualizations.
-- Shown with an "Illustrative" badge. Each row sums to 1.
local WHO_IS_IT = {
	tokens = IT_SENTENCE,
	endings = { "tired", "wide" },
	focus = 8, -- "it"
	weights = {
		tired = { 0.03, 0.62, 0.02, 0.04, 0.02, 0.09, 0.03, 0.10, 0.03, 0.02 },
		wide = { 0.03, 0.08, 0.02, 0.05, 0.03, 0.63, 0.03, 0.09, 0.02, 0.02 },
	},
	-- Weights for other tokens: mostly themselves and their neighbors (also illustrative).
	neighborWeight = 0.5,
}

-- Three tokens with tiny 2-D query/key/value vectors (dₖ = 2). The first query is editable.
local QKV = {
	tokens = { "it", "animal", "street" },
	Q = { { 1.0, 0.5 }, { 0.2, 0.8 }, { 0.6, -0.4 } },
	K = { { 0.3, 0.3 }, { 1.2, 0.4 }, { -0.2, 1.0 } },
	V = { { 0.2, 0.2 }, { 1.0, 0.0 }, { 0.0, 1.0 } },
}

local CAUSAL = { tokens = { "The", "cat", "sat", "on", "the", "mat" } }

local BLOCK = {
	pieces = {
		{ name = "Token embeddings", line = "Each token becomes a vector." },
		{ name = "+ Positional encoding", line = "Add a position signal, so word order isn't lost." },
		{ name = "Multi-head self-attention", line = "Every token attends to every token, in several heads at once." },
		{ name = "Add & norm", line = "Add the input back (a residual connection), then normalize." },
		{ name = "Feed-forward network", line = "The same small two-layer network, applied to each position separately." },
		{ name = "Add & norm", line = "Another residual connection and layer normalization." },
		{ name = "× N", line = "Stack N identical blocks; the original paper used N = 6." },
	},
}

local module: Types.Module = {
	cards = {
		{
			id = "tf-journey",
			kind = "concept",
			journey = true,
			title = "What does “it” mean?",
			body = "“The animal didn't cross the street because it was too tired.” Here “it” is the animal. Change “tired” to “wide” and “it” becomes the street. To resolve “it”, a model must connect words that sit far apart, depending on context. Transformers do that directly.",
			bridge = "If attention can connect any two positions directly, do we still need recurrence? “Attention Is All You Need” (Vaswani et al., 2017) says no.",
		},
		{
			id = "tf-self-attention",
			kind = "concept",
			title = "Self-attention",
			body = "In <b>self-attention</b>, every token makes its own query, key and value, using learned matrices W_Q, W_K and W_V. Then every token attends to every token in the same sentence. All positions are computed at once, in parallel, with no step-by-step recurrence.",
			terms = { "self-attention" },
			deeper = "For token vectors stacked as rows of X: {query|Q} = X·{weight|W_Q}, {query|K} = X·{weight|W_K}, {output|V} = X·{weight|W_V}.",
		},
		{
			id = "tf-who-is-it",
			kind = "interactive",
			title = "Who is “it”?",
			body = "In a trained model, some attention heads link “it” to the noun it refers to. Switch the last word and watch where “it” looks. The weights here are illustrative, not taken from a real model.",
			widget = "WhoIsIt",
			widgetProps = WHO_IS_IT,
			instruction = "Tap a word to see its attention. Switch “tired” and “wide”.",
		},
		{
			id = "tf-scaled",
			kind = "math",
			title = "Scaled dot-product attention",
			body = "All the scores come from one matrix product, QKᵀ. Dividing by √dₖ stops the scores growing with the vector size, which would push softmax into putting nearly all weight on one token and leave tiny gradients.",
			formula = "Attention({query|Q}, {query|K}, {output|V}) = softmax({query|Q}{query|K}ᵀ / √dₖ) · {output|V}",
			legend = {
				{ symbol = "Q", meaning = "queries: one row per token, what it's looking for", role = "query" },
				{ symbol = "K", meaning = "keys: one row per token, what it can be matched on", role = "query" },
				{ symbol = "V", meaning = "values: one row per token, what it hands back", role = "output" },
				{ symbol = "dₖ", meaning = "the length of each key vector" },
				{ symbol = "softmax", meaning = "applied to each row, so each token's weights sum to 1" },
			},
			terms = { "scaled dot-product attention" },
			deeper = "If query and key entries have variance 1, their dot product has variance dₖ. Dividing by √dₖ brings it back to about 1.",
		},
		{
			id = "tf-calculator",
			kind = "interactive",
			title = "Compute it yourself",
			body = "Three tokens, vectors of length 2. Step through QKᵀ, the division by √2, the softmax of each row, and the weighted sum of values. Edit the first token's query and every number updates.",
			widget = "QKVCalculator",
			widgetProps = QKV,
			instruction = "Step through the stages. Then drag the first query and watch the weights shift.",
		},
		{
			id = "tf-multihead",
			kind = "concept",
			title = "Many heads at once",
			body = "<b>Multi-head attention</b> runs several attention operations in parallel, each with its own W_Q, W_K and W_V. Each head is free to pick up a different relationship, such as nearby words or what a pronoun refers to. Nobody assigns those roles; they emerge in training. The heads' outputs are concatenated and projected.",
			terms = { "multi-head attention" },
			deeper = "The original model used 8 heads, each with dₖ = 64, for a model width of 512.",
		},
		{
			id = "tf-position",
			kind = "concept",
			title = "Where is each word?",
			body = "Attention alone treats a sentence like a bag: shuffle the words and each token's output is the same, just shuffled. So position information is added to each token. The original paper used fixed sine and cosine waves; many later models learn positions or use rotary encodings.",
			terms = { "positional encoding" },
			deeper = "Sinusoidal: PE(pos, 2i) = sin(pos / 10000^(2i/d)), PE(pos, 2i + 1) = cos(pos / 10000^(2i/d)).",
		},
		{
			id = "tf-block",
			kind = "interactive",
			title = "Build the block",
			body = "A Transformer layer is a short recipe, repeated. Self-attention mixes information across tokens; a feed-forward network processes each token on its own. <b>Residual connections</b> and <b>layer normalization</b> keep deep stacks trainable.",
			terms = { "residual connection", "layer normalization" },
			widget = "BuildTheBlock",
			widgetProps = BLOCK,
			instruction = "Step through the block, one piece at a time.",
		},
		{
			id = "tf-enc-dec",
			kind = "compare",
			title = "Encoders and decoders",
			body = "The original Transformer was an encoder–decoder for translation, joined by cross-attention: the decoder's queries attend to the encoder's outputs. Later models often keep just one half.",
			left = {
				title = "Encoder",
				body = "Every token sees every other token, both directions. Good for understanding a whole text.",
				points = { "Example: BERT-style models" },
			},
			right = {
				title = "Decoder",
				body = "A causal mask hides future tokens, so each token sees only what came before. Good for generating text one token at a time.",
				points = { "Example: GPT-style models" },
			},
			terms = { "cross-attention", "causal mask" },
		},
		{
			id = "tf-causal",
			kind = "interactive",
			title = "No peeking ahead",
			body = "When a decoder learns to predict the next word, it mustn't see that word. The <b>causal mask</b> blocks attention to every later position. That's also why a decoder generates text one token at a time: each new token becomes visible only after it's chosen.",
			widget = "CausalMask",
			widgetProps = CAUSAL,
			instruction = "Toggle the mask and tap a row to see what that token can attend to.",
		},
		{
			id = "tf-why",
			kind = "concept",
			title = "Why Transformers won",
			body = "Training is parallel: every position is computed at once, unlike an RNN's word-by-word loop. Any two tokens are one attention step apart, so long-range links are short paths. The main cost: attention compares every pair of tokens, so it grows quadratically with sequence length.",
			terms = { "quadratic cost" },
			deeper = "For a sequence of n tokens, self-attention computes n × n scores per head per layer.",
		},
		{
			id = "tf-llm",
			kind = "concept",
			title = "Closing the loop",
			body = "Most of today's large language models are decoder-only Transformers, pretrained to predict the next token: P(next token | previous tokens). That makes them a <b>generative model</b> (Module 1) of sequences (Module 2), built from attention (Module 4) instead of recurrence (Module 3). A Transformer is an architecture, not a chatbot.",
			terms = { "language model", "next-token prediction" },
		},
		{
			id = "tf-recap",
			kind = "recap",
			title = "Recap",
			points = {
				"Self-attention: every token makes a query, key and value, and attends to every token.",
				"softmax(QKᵀ/√dₖ)·V; the √dₖ keeps scores from saturating softmax.",
				"Multi-head attention learns several relationships in parallel.",
				"Positional encodings add word order, which attention alone ignores.",
				"Decoders use a causal mask and generate one token at a time.",
			},
		},
		{
			id = "tf-q1",
			kind = "quiz",
			prompt = "Why divide by √dₖ?",
			options = {
				"To keep scores from growing with vector size and saturating softmax",
				"To make the weights sum to 1",
				"To hide future tokens",
			},
			answer = 1,
			explain = {
				"Right. Large scores make softmax nearly one-hot, with tiny gradients.",
				"Not quite. Softmax already makes the weights sum to 1.",
				"Not quite. That's the causal mask's job.",
			},
			reviewCard = "tf-scaled",
		},
		{
			id = "tf-q2",
			kind = "quiz",
			prompt = "Why do Transformers need positional encodings?",
			options = {
				"Attention alone ignores word order",
				"To make training faster",
				"To reduce the number of weights",
			},
			answer = 1,
			explain = {
				"Right. Without them, shuffling the words would just shuffle the outputs.",
				"Not quite. They add information; they don't speed anything up.",
				"Not quite. They don't change the number of weights in attention.",
			},
			reviewCard = "tf-position",
		},
		{
			id = "tf-q3",
			kind = "quiz",
			prompt = "What does the causal mask prevent?",
			options = {
				"A token attending to tokens after it",
				"A token attending to itself",
				"Two heads learning the same thing",
			},
			answer = 1,
			explain = {
				"Right. Each position may only look at itself and earlier positions.",
				"Not quite. A token can still attend to itself.",
				"Not quite. The mask controls which positions are visible, not what heads learn.",
			},
			reviewCard = "tf-causal",
		},
		{
			id = "tf-q4",
			kind = "quiz",
			prompt = "What is one advantage of Transformers over RNNs?",
			options = {
				"All positions can be computed in parallel during training",
				"Their cost grows linearly with sequence length",
				"They don't need any training data",
			},
			answer = 1,
			explain = {
				"Right. There's no word-by-word loop, so training uses hardware efficiently.",
				"Not quite. Self-attention grows quadratically with length; that's its main cost.",
				"Not quite. They need a great deal of data.",
			},
			reviewCard = "tf-why",
		},
		{
			id = "tf-q5",
			kind = "quiz",
			prompt = "What does multi-head attention add?",
			options = {
				"Several attention patterns in parallel, each free to learn a different relationship",
				"A second sentence to translate",
				"A fixed role for each head, assigned by hand",
			},
			answer = 1,
			explain = {
				"Right. Their outputs are concatenated and projected back together.",
				"Not quite. Heads all read the same input; they just attend differently.",
				"Not quite. Nobody assigns head roles; they emerge during training.",
			},
			reviewCard = "tf-multihead",
		},
	},
}

return module
