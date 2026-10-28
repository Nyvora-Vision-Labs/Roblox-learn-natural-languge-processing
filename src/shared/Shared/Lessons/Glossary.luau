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
}

return Glossary
