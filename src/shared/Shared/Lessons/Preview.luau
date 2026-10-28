--!strict
-- Lesson-shell preview: one card of every kind, plus a 5-question quiz on exactly what these
-- cards teach. Stands in for Module 1 until Milestone 3 replaces it with Classifiers.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local module: Types.Module = {
	cards = {
		{
			id = "pv-welcome",
			kind = "concept",
			journey = true,
			title = "Where this module sits",
			body = "Every model in this academy answers one question: given what you can see, what is the most likely answer? This first stop covers two classic ways to answer it.",
			bridge = "This is the start of the journey. Each later module builds on this one.",
		},
		{
			id = "pv-classify",
			kind = "concept",
			title = "What is classification?",
			body = "A <b>classifier</b> predicts a <b>label</b> y from <b>features</b> x. For an email, x could be the words it contains and y is spam or not spam. Training shows the model many labeled examples so it can label new ones.",
			terms = { "classifier", "label", "features" },
			deeper = "A classifier is a function f that maps a feature vector x to a label: f(x) = y, with y ∈ {0, 1} for two classes.",
		},
		{
			id = "pv-sigmoid",
			kind = "interactive",
			title = "From a score to a probability",
			body = "Logistic regression adds up evidence into a score, z = w·x + b. The <b>sigmoid</b> function σ turns any score into a number between 0 and 1, which we read as P(y = 1 | x). A score of 0 gives exactly 50/50.",
			terms = { "sigmoid" },
			widget = "SigmoidPeek",
			widgetProps = { min = -6, max = 6, step = 1 },
			instruction = "Change z and watch σ(z) move between 0 and 1.",
			deeper = "σ(z) = 1 / (1 + e^(−z)). Large positive z pushes σ toward 1; large negative z pushes it toward 0. It never quite reaches either.",
		},
		{
			id = "pv-gen-disc",
			kind = "compare",
			title = "Two ways to classify",
			body = "Both kinds of model predict y from x. They differ in what they learn on the way.",
			left = {
				title = "Generative",
				body = "Learns how each class produces data: P(x | y) and P(y). Because it models the data itself, it can generate new examples.",
				points = { "Example: Naive Bayes" },
			},
			right = {
				title = "Discriminative",
				body = "Learns the boundary between classes directly: P(y | x). It has nothing to generate examples from.",
				points = { "Example: logistic regression" },
			},
			terms = { "generative", "discriminative" },
		},
		{
			id = "pv-bayes",
			kind = "math",
			title = "Bayes' rule",
			body = "Bayes' rule flips a conditional probability around. Naive Bayes uses it to go from “how spam emails tend to look” to “how likely this email is spam.”",
			formula = "P({output|y} | {input|x}) = P({input|x} | {output|y}) · P({output|y}) / P({input|x})",
			legend = {
				{ symbol = "y", meaning = "the label, e.g. spam or not spam", role = "output" },
				{ symbol = "x", meaning = "the features, e.g. the words in the email", role = "input" },
				{ symbol = "P(y | x)", meaning = "posterior: how likely the label is after seeing x" },
				{ symbol = "P(x | y)", meaning = "likelihood: how likely these features are for that label" },
				{ symbol = "P(y)", meaning = "prior: how common the label is before seeing anything" },
				{ symbol = "P(x)", meaning = "evidence: how likely these features are overall" },
			},
		},
		{
			id = "pv-recap",
			kind = "recap",
			title = "Recap",
			points = {
				"A classifier predicts a label y from features x.",
				"The sigmoid turns a score z = w·x + b into a probability; z = 0 gives 0.5.",
				"Generative models learn P(x | y) and P(y); discriminative models learn P(y | x).",
				"Bayes' rule turns P(x | y) and P(y) into P(y | x).",
			},
		},
		{
			id = "pv-q1",
			kind = "quiz",
			prompt = "Which model learns P(x | y)?",
			options = { "Naive Bayes", "Logistic regression" },
			answer = 1,
			explain = {
				"Right. It models how each class generates its features.",
				"Not quite. Logistic regression models P(y | x) directly.",
			},
			reviewCard = "pv-gen-disc",
		},
		{
			id = "pv-q2",
			kind = "quiz",
			prompt = "What does σ(w·x + b) = 0.5 mean?",
			options = {
				"The model is certain the label is 1",
				"The point sits exactly on the decision boundary",
				"All the weights are zero",
			},
			answer = 2,
			explain = {
				"Not quite. 0.5 is a 50/50 prediction, the opposite of certain.",
				"Right. σ(z) = 0.5 exactly when z = w·x + b = 0, which is the decision boundary.",
				"Not necessarily. Any x with w·x + b = 0 gives 0.5, whatever the weights are.",
			},
			reviewCard = "pv-sigmoid",
		},
		{
			id = "pv-q3",
			kind = "quiz",
			prompt = "Bayes' rule turns P(x | y) and P(y) into what?",
			options = {
				"P(y | x), the probability of the label given the features",
				"A larger training set",
				"The decision boundary w·x + b = 0",
			},
			answer = 1,
			explain = {
				"Right. It flips the conditional: from features-given-label to label-given-features.",
				"Not quite. Bayes' rule is a formula for probabilities; it doesn't create data.",
				"Not quite. That boundary belongs to logistic regression, not Bayes' rule.",
			},
			reviewCard = "pv-bayes",
		},
		{
			id = "pv-q4",
			kind = "quiz",
			prompt = "Which family can generate new examples?",
			options = { "Generative", "Discriminative" },
			answer = 1,
			explain = {
				"Right. It models how data is produced, so it can sample new data.",
				"Not quite. A discriminative model only learns the boundary, so it has nothing to sample from.",
			},
			reviewCard = "pv-gen-disc",
		},
		{
			id = "pv-q5",
			kind = "quiz",
			prompt = "What does a classifier predict?",
			options = {
				"A label y from features x",
				"Features x from a label y",
				"The next word in a sentence",
			},
			answer = 1,
			explain = {
				"Right. Features in, label out.",
				"Not quite. That's the other direction; a classifier goes from features to a label.",
				"Not quite. Predicting the next word is a sequence task you'll meet in Module 5.",
			},
			reviewCard = "pv-classify",
		},
	},
}

return module
