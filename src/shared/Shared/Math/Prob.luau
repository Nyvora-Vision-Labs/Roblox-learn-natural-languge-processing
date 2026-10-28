--!strict
-- Probability helpers. Pure functions, no instances.
-- Each function is checked against hand-worked values before a widget uses it.

local Prob = {}

-- σ(z) = 1 / (1 + e^(−z)). Written in two branches so large |z| never overflows math.exp.
function Prob.sigmoid(z: number): number
	if z >= 0 then
		return 1 / (1 + math.exp(-z))
	end
	local e = math.exp(z)
	return e / (1 + e)
end

-- softmax(z)ᵢ = e^(zᵢ/τ) / Σⱼ e^(zⱼ/τ). τ (temperature, default 1) > 0; smaller τ is sharper.
-- Subtracts the max first so large scores never overflow.
function Prob.softmax(scores: { number }, temperature: number?): { number }
	local tau = temperature or 1
	local maxScore = -math.huge
	for _, z in scores do
		maxScore = math.max(maxScore, z / tau)
	end
	local exps, sum = {}, 0
	for i, z in scores do
		exps[i] = math.exp(z / tau - maxScore)
		sum += exps[i]
	end
	for i in exps do
		exps[i] /= sum
	end
	return exps
end

---------------------------------------------------------------------------
-- Naive Bayes (multinomial, binary word counts; Jurafsky & Martin ch. 4)
---------------------------------------------------------------------------

export type NBClass = {
	docs: number, -- training messages in this class
	counts: { [string]: number }, -- word → occurrences in this class's messages
}

export type NBModel = {
	vocab: { string },
	classes: { [string]: NBClass },
}

-- Total word occurrences in a class (over the vocabulary).
function Prob.nbTotal(model: NBModel, class: string): number
	local total = 0
	for _, word in model.vocab do
		total += model.classes[class].counts[word] or 0
	end
	return total
end

-- P(class): the fraction of training messages in that class.
function Prob.nbPrior(model: NBModel, class: string): number
	local all = 0
	for _, c in model.classes do
		all += c.docs
	end
	return model.classes[class].docs / all
end

-- P(word | class) = (count + α) / (total + α·|V|). α = 1 is add-one (Laplace) smoothing; α = 0 is none.
function Prob.nbLikelihood(model: NBModel, word: string, class: string, alpha: number): number
	local count = model.classes[class].counts[word] or 0
	local denominator = Prob.nbTotal(model, class) + alpha * #model.vocab
	if denominator == 0 then
		return 0
	end
	return (count + alpha) / denominator
end

-- Posterior over classes for a message (a set of words, each counted once).
-- Returns (posterior by class or nil when every class scores 0, unnormalized scores by class).
function Prob.nbPosterior(model: NBModel, words: { string }, alpha: number): ({ [string]: number }?, { [string]: number })
	-- Work in log space so long messages never underflow.
	local logScores: { [string]: number } = {}
	local scores: { [string]: number } = {}
	local best = -math.huge
	for class in model.classes do
		local logScore = math.log(Prob.nbPrior(model, class))
		for _, word in words do
			local p = Prob.nbLikelihood(model, word, class, alpha)
			logScore += if p > 0 then math.log(p) else -math.huge
		end
		logScores[class] = logScore
		if logScore > best then
			best = logScore
		end
	end
	for class, logScore in logScores do
		scores[class] = if logScore == -math.huge then 0 else math.exp(logScore)
	end
	if best == -math.huge then
		return nil, scores -- every class has a zero factor: the posterior is undefined
	end
	local sum = 0
	for _, logScore in logScores do
		sum += if logScore == -math.huge then 0 else math.exp(logScore - best)
	end
	local posterior = {}
	for class, logScore in logScores do
		posterior[class] = if logScore == -math.huge then 0 else math.exp(logScore - best) / sum
	end
	return posterior, scores
end

---------------------------------------------------------------------------
-- Logistic regression
---------------------------------------------------------------------------

local EPS = 1e-12

-- Mean log-loss −(1/N) Σ [y log p + (1 − y) log(1 − p)], p clamped away from 0 and 1.
function Prob.logLoss(probs: { number }, labels: { number }): number
	local total = 0
	for i, p in probs do
		local q = math.clamp(p, EPS, 1 - EPS)
		local y = labels[i]
		total -= y * math.log(q) + (1 - y) * math.log(1 - q)
	end
	return total / #probs
end

-- 1-D model p = σ(w·x + b). Returns (mean log-loss, ∂L/∂w, ∂L/∂b).
function Prob.logistic1D(xs: { number }, ys: { number }, w: number, b: number): (number, number, number)
	local probs = {}
	local dw, db = 0, 0
	for i, x in xs do
		local p = Prob.sigmoid(w * x + b)
		probs[i] = p
		dw += (p - ys[i]) * x
		db += p - ys[i]
	end
	local n = #xs
	return Prob.logLoss(probs, ys), dw / n, db / n
end

-- One gradient-descent step on the 1-D model.
function Prob.logisticStep1D(xs: { number }, ys: { number }, w: number, b: number, rate: number): (number, number)
	local _, dw, db = Prob.logistic1D(xs, ys, w, b)
	return w - rate * dw, b - rate * db
end

-- 2-D model p = σ(w₁x₁ + w₂x₂ + b), fitted by gradient descent until the gradient is tiny.
-- points: { {x1, x2, y} }. Returns (w1, w2, b, steps).
function Prob.fitLogistic2D(points: { { number } }, rate: number, maxSteps: number, tolerance: number): (number, number, number, number)
	local w1, w2, b = 0, 0, 0
	local n = #points
	for step = 1, maxSteps do
		local g1, g2, gb = 0, 0, 0
		for _, pt in points do
			local err = Prob.sigmoid(w1 * pt[1] + w2 * pt[2] + b) - pt[3]
			g1 += err * pt[1]
			g2 += err * pt[2]
			gb += err
		end
		g1, g2, gb = g1 / n, g2 / n, gb / n
		w1 -= rate * g1
		w2 -= rate * g2
		b -= rate * gb
		if math.sqrt(g1 * g1 + g2 * g2 + gb * gb) < tolerance then
			return w1, w2, b, step
		end
	end
	return w1, w2, b, maxSteps
end

---------------------------------------------------------------------------
-- Gaussians (for the generative view)
---------------------------------------------------------------------------

-- Per-dimension mean and (maximum-likelihood) standard deviation of 2-D points.
function Prob.fitGaussian2D(points: { { number } }): (Vector2, Vector2)
	local n = #points
	local mx, my = 0, 0
	for _, pt in points do
		mx += pt[1]
		my += pt[2]
	end
	mx, my = mx / n, my / n
	local vx, vy = 0, 0
	for _, pt in points do
		vx += (pt[1] - mx) ^ 2
		vy += (pt[2] - my) ^ 2
	end
	return Vector2.new(mx, my), Vector2.new(math.sqrt(vx / n), math.sqrt(vy / n))
end

-- One standard-normal draw (Box–Muller).
function Prob.standardNormal(rng: Random): number
	local u1 = math.max(rng:NextNumber(), 1e-12)
	local u2 = rng:NextNumber()
	return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

return Prob
