--!strict
-- Module 1: Naive Bayes, logistic regression, generative vs discriminative (CLAUDE.md §7.2).
-- Running example: spam vs not spam. Ground truth: Jurafsky & Martin, Speech and Language
-- Processing, ch. 4–5; Ng & Jordan (2002). Toy datasets live here as widget props; every number a
-- widget shows is computed from them with Math/Prob.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

-- Toy training set: 10 messages (4 spam, 6 not spam), word occurrences per class.
-- "agenda" never appears in a spam message, which sets up the zero-probability problem.
local SPAM_MODEL = {
	vocab = { "free", "win", "money", "prize", "lunch", "meeting", "agenda" },
	classes = {
		spam = {
			docs = 4,
			counts = { free = 3, win = 3, money = 2, prize = 2, lunch = 1, meeting = 1, agenda = 0 },
		},
		ham = {
			docs = 6,
			counts = { free = 1, win = 1, money = 1, prize = 1, lunch = 3, meeting = 4, agenda = 2 },
		},
	},
}

-- Hours studied → passed (1) or not (0). Not perfectly separable, so the best fit is finite.
local STUDY = {
	xs = { 0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5 },
	ys = { 0, 0, 0, 0, 1, 0, 1, 1, 1, 1 },
}

-- Two made-up message features; label 1 = spam, 0 = not spam. Slight overlap on purpose.
local TWO_D = {
	{ 2, 3, 0 }, { 3, 2, 0 }, { 2.5, 4, 0 }, { 3.5, 3.5, 0 }, { 1.5, 2, 0 },
	{ 4, 2.5, 0 }, { 3, 4.5, 0 }, { 2, 1.5, 0 }, { 4.5, 4, 0 }, { 3.5, 1, 0 }, { 6, 5.8, 0 },
	{ 6, 6.5, 1 }, { 7, 6, 1 }, { 6.5, 7.5, 1 }, { 7.5, 7, 1 }, { 5.5, 6, 1 },
	{ 8, 8, 1 }, { 6, 8, 1 }, { 7, 5, 1 }, { 5, 7, 1 }, { 4.5, 5.5, 1 }, { 4, 4.2, 1 },
}

local module: Types.Module = {
	cards = {
		{
			id = "cl-journey",
			kind = "concept",
			journey = true,
			title = "Spam or not spam?",
			body = "Your inbox decides, in a blink, whether each new message is spam. How could a program make that call? This module builds two classic answers and compares how they think.",
			bridge = "This is the first stop. These models read a message as a whole. Later modules add word order, memory and attention.",
		},
		{
			id = "cl-classify",
			kind = "concept",
			title = "What a classifier does",
			body = "A <b>classifier</b> predicts a <b>label</b> y from <b>features</b> x. Here x is the words in a message and y is spam or not spam. We train it on messages someone already labeled, then ask it about new ones.",
			terms = { "classifier", "label", "features" },
			deeper = "Formally, a classifier is a function from a feature vector x = (x₁, …, xₙ) to a label y. With two labels we often write y ∈ {0, 1}.",
		},
		{
			id = "cl-bayes",
			kind = "math",
			title = "Bayes' rule",
			body = "Counting is easy in one direction: how often does “free” show up in spam? We want the other direction: given “free”, how likely is spam? <b>Bayes' rule</b> flips one into the other.",
			terms = { "prior", "likelihood", "posterior" },
			formula = "P({output|y} | {input|x}) = P({input|x} | {output|y}) · P({output|y}) / P({input|x})",
			legend = {
				{ symbol = "y", meaning = "the label: spam or not spam", role = "output" },
				{ symbol = "x", meaning = "the features: the words in the message", role = "input" },
				{ symbol = "P(y)", meaning = "prior: how common the label is before reading anything" },
				{ symbol = "P(x | y)", meaning = "likelihood: how typical these words are for that label" },
				{ symbol = "P(y | x)", meaning = "posterior: how likely the label is after reading the words" },
				{ symbol = "P(x)", meaning = "evidence: how likely these words are at all" },
			},
			deeper = "P(x) is the same for every label, so to compare labels you can compare P(x | y) · P(y) and divide by their sum at the end.",
		},
		{
			id = "cl-naive",
			kind = "interactive",
			title = "Why “naive”?",
			body = "Naive Bayes assumes each word is independent of the others <b>once you know the class</b>. That turns one hard probability into a product of easy ones, each counted from training data. The name describes this assumption, not a weakness.",
			terms = { "conditional independence" },
			widget = "SpamDetective",
			widgetProps = { model = SPAM_MODEL, start = { "free", "win" }, smoothing = true, showSmoothing = false },
			instruction = "Tap words to put them in the message. Watch each word's evidence and the verdict.",
			deeper = "P({input|x₁}, …, {input|xₙ} | {output|y}) = ∏ᵢ P({input|xᵢ} | {output|y}). Multiplying many small numbers underflows, so real code adds their logarithms instead.",
		},
		{
			id = "cl-smoothing",
			kind = "interactive",
			title = "One unseen word",
			body = "“agenda” never appeared in a spam training message, so its raw count gives P(agenda | spam) = 0. One zero wipes out the whole product, however spammy the other words are. <b>Add-one smoothing</b> adds 1 to every count so nothing is ever exactly impossible.",
			terms = { "add-one smoothing" },
			widget = "SpamDetective",
			widgetProps = { model = SPAM_MODEL, start = { "free", "win", "agenda" }, smoothing = false, showSmoothing = true },
			instruction = "Turn smoothing off and on with “agenda” in the message.",
			deeper = "With smoothing, P(w | c) = (count(w, c) + 1) / (total words in c + |V|), where |V| is the vocabulary size (7 here).",
		},
		{
			id = "cl-overconfident",
			kind = "concept",
			title = "Naive, but useful",
			body = "Real words aren't independent: “win” and “prize” tend to arrive together. Naive Bayes counts that evidence twice, so its probabilities are often <b>overconfident</b>, too close to 0 or 1. Its yes/no decisions are still often good, and it trains in one pass of counting.",
			terms = { "overconfident" },
		},
		{
			id = "cl-score",
			kind = "concept",
			title = "Another approach: weigh the evidence",
			body = "<b>Logistic regression</b> skips modeling how messages are written. It gives each feature a <b>weight</b> w, adds them up with a <b>bias</b> b, and gets a score z = w·x + b. A big positive score means spam. Despite its name, it's a classifier.",
			terms = { "logistic regression", "weight", "bias" },
			deeper = "w·x is the dot product w₁x₁ + w₂x₂ + … + wₙxₙ. A positive weight pushes toward label 1; a negative weight pushes toward label 0.",
		},
		{
			id = "cl-sigmoid",
			kind = "interactive",
			title = "From a score to a probability",
			body = "The <b>sigmoid</b> σ squashes any score into a number between 0 and 1, read as P(y = 1 | x). Where the score is 0, σ = 0.5: that's the <b>decision boundary</b>. Here a single feature, hours studied, predicts passing a test.",
			terms = { "sigmoid", "decision boundary" },
			widget = "SigmoidLab",
			widgetProps = { data = STUDY, xLabel = "hours studied", start = { w = 1, b = -1 }, showTraining = false },
			instruction = "Drag w and b until the curve separates passed from failed.",
			deeper = "σ(z) = 1 / (1 + e^(−z)). The boundary sits where {weight|w}{input|x} + {weight|b} = 0, so at x = −b / w.",
		},
		{
			id = "cl-training",
			kind = "interactive",
			title = "Learning the weights",
			body = "<b>Log-loss</b> measures how surprised the model is by the true labels: confident and wrong costs a lot. <b>Gradient descent</b> nudges w and b in the direction that lowers the loss, a small step at a time.",
			terms = { "log-loss", "gradient descent" },
			widget = "SigmoidLab",
			widgetProps = { data = STUDY, xLabel = "hours studied", start = { w = 0, b = 0 }, showTraining = true },
			instruction = "Press Step to take one gradient step, or Auto to run until it settles.",
			deeper = "L = −(1/N) Σ [y log p + (1 − y) log(1 − p)], with p = σ(wx + b). Each step: w ← w − η·∂L/∂w and b ← b − η·∂L/∂b, where η is the step size.",
		},
		{
			id = "cl-gen-disc",
			kind = "compare",
			title = "Two kinds of model",
			body = "Both predict y from x. They differ in what they learn on the way there.",
			left = {
				title = "Generative",
				body = "Learns how each class produces data: P(x | y) and P(y), which together give the joint P(x, y). Because it models the data, it can generate new examples.",
				points = { "Example: Naive Bayes" },
			},
			right = {
				title = "Discriminative",
				body = "Learns P(y | x) directly: only the boundary between classes. It has no model of the data, so it can't generate examples.",
				points = { "Example: logistic regression" },
			},
			terms = { "generative model", "discriminative model" },
		},
		{
			id = "cl-two-ways",
			kind = "interactive",
			title = "The same data, two ways",
			body = "On the left, a generative model fits a cloud to each class and can sample new points from it. On the right, a discriminative model draws only the line between the classes. Both are fitted to the same 22 messages.",
			widget = "TwoWaysToClassify",
			widgetProps = { points = TWO_D, xLabel = "feature x₁", yLabel = "feature x₂" },
			instruction = "Switch views. In the generative view, generate a new example.",
			deeper = "The clouds are Gaussians: each class gets a mean and a spread per feature, fitted from its points. The line is where σ(w₁x₁ + w₂x₂ + b) = 0.5, found by gradient descent on log-loss.",
		},
		{
			id = "cl-tradeoff",
			kind = "concept",
			title = "Which one wins?",
			body = "Neither, always. Ng and Jordan (2002) found Naive Bayes often reaches its best accuracy with less training data, while logistic regression usually ends up more accurate once data is plentiful. Pick the tool for the data you have.",
			deeper = "Simplified: with few examples, Naive Bayes' strong assumption helps more than it hurts. With many examples, logistic regression's freedom to fit the boundary pays off.",
		},
		{
			id = "cl-recap",
			kind = "recap",
			title = "Recap",
			points = {
				"A classifier predicts a label y from features x.",
				"Naive Bayes uses Bayes' rule and assumes words are independent given the class.",
				"Without smoothing, one unseen word can zero out a whole class.",
				"Logistic regression scores z = w·x + b and squashes it with σ; σ = 0.5 is the boundary.",
				"Generative models learn P(x | y) and P(y); discriminative models learn P(y | x).",
			},
		},
		{
			id = "cl-q1",
			kind = "quiz",
			prompt = "Which model learns P(x | y)?",
			options = { "Naive Bayes", "Logistic regression" },
			answer = 1,
			explain = {
				"Right. It models how each class generates its words.",
				"Not quite. Logistic regression models P(y | x) directly.",
			},
			reviewCard = "cl-gen-disc",
		},
		{
			id = "cl-q2",
			kind = "quiz",
			prompt = "What does the “naive” in Naive Bayes assume?",
			options = {
				"Words are independent of each other once you know the class",
				"Spam and not-spam are equally common",
				"The training data has no mistakes",
			},
			answer = 1,
			explain = {
				"Right. Conditional independence lets it multiply one probability per word.",
				"Not quite. The class prior P(y) is learned from the data; it needn't be 50/50.",
				"Not quite. “Naive” names the independence assumption, not a claim about the data's quality.",
			},
			reviewCard = "cl-naive",
		},
		{
			id = "cl-q3",
			kind = "quiz",
			prompt = "What does σ(w·x + b) = 0.5 mean?",
			options = {
				"The model is certain the label is 1",
				"x sits exactly on the decision boundary",
				"All the weights are zero",
			},
			answer = 2,
			explain = {
				"Not quite. 0.5 is a 50/50 prediction, the opposite of certain.",
				"Right. σ(z) = 0.5 exactly when z = w·x + b = 0.",
				"Not necessarily. Any x with w·x + b = 0 gives 0.5, whatever the weights are.",
			},
			reviewCard = "cl-sigmoid",
		},
		{
			id = "cl-q4",
			kind = "quiz",
			prompt = "Why does Naive Bayes need smoothing?",
			options = {
				"So one word never seen with a class can't make that class's probability exactly 0",
				"To make training faster",
				"To make the words independent",
			},
			answer = 1,
			explain = {
				"Right. A single zero factor wipes out the whole product; adding 1 to every count prevents it.",
				"Not quite. Smoothing changes the counts, not the speed.",
				"Not quite. Independence is an assumption the model makes; smoothing doesn't change it.",
			},
			reviewCard = "cl-smoothing",
		},
		{
			id = "cl-q5",
			kind = "quiz",
			prompt = "Which family can generate new examples?",
			options = { "Generative", "Discriminative" },
			answer = 1,
			explain = {
				"Right. It models how data is produced, so it can sample new data.",
				"Not quite. A discriminative model only learns the boundary, so it has nothing to sample from.",
			},
			reviewCard = "cl-two-ways",
		},
	},
}

return module
