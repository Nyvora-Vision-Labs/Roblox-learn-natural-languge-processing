--!strict
-- Hidden Markov model algorithms (Jurafsky & Martin, appendix A). Pure functions, no instances.
-- States and observation symbols are 1-based indices: pi[i], A[i][j] = P(next j | current i),
-- B[i][k] = P(observation k | state i). Observation sequences are lists of symbol indices.
-- Each function is checked against hand-worked values before a widget uses it.

export type HMM = {
	states: { string },
	symbols: { string },
	pi: { number },
	A: { { number } },
	B: { { number } },
}

local Viterbi = {}

-- Forward algorithm. Returns alpha[t][i] = P(o₁…oₜ, sₜ = i) and P(o₁…o_T).
function Viterbi.forward(hmm: HMM, obs: { number }): ({ { number } }, number)
	local n = #hmm.states
	local alpha: { { number } } = { {} }
	for i = 1, n do
		alpha[1][i] = hmm.pi[i] * hmm.B[i][obs[1]]
	end
	for t = 2, #obs do
		alpha[t] = {}
		for j = 1, n do
			local sum = 0
			for i = 1, n do
				sum += alpha[t - 1][i] * hmm.A[i][j]
			end
			alpha[t][j] = sum * hmm.B[j][obs[t]]
		end
	end
	local total = 0
	for i = 1, n do
		total += alpha[#obs][i]
	end
	return alpha, total
end

-- Backward algorithm. beta[t][i] = P(oₜ₊₁…o_T | sₜ = i).
function Viterbi.backward(hmm: HMM, obs: { number }): { { number } }
	local n, T = #hmm.states, #obs
	local beta: { { number } } = {}
	beta[T] = {}
	for i = 1, n do
		beta[T][i] = 1
	end
	for t = T - 1, 1, -1 do
		beta[t] = {}
		for i = 1, n do
			local sum = 0
			for j = 1, n do
				sum += hmm.A[i][j] * hmm.B[j][obs[t + 1]] * beta[t + 1][j]
			end
			beta[t][i] = sum
		end
	end
	return beta
end

-- Per-day posteriors γ[t][i] = P(sₜ = i | o₁…o_T).
function Viterbi.posteriors(hmm: HMM, obs: { number }): { { number } }
	local alpha, total = Viterbi.forward(hmm, obs)
	local beta = Viterbi.backward(hmm, obs)
	local gamma = {}
	for t = 1, #obs do
		gamma[t] = {}
		for i = 1, #hmm.states do
			gamma[t][i] = alpha[t][i] * beta[t][i] / total
		end
	end
	return gamma
end

-- Viterbi. Returns V[t][i] (best-path probability ending in i at t), back-pointers bp[t][i]
-- (the best previous state; 0 at t = 1), the best path, and its probability.
-- Ties keep the lower state index, so results are deterministic.
function Viterbi.decode(hmm: HMM, obs: { number }): ({ { number } }, { { number } }, { number }, number)
	local n, T = #hmm.states, #obs
	local V: { { number } } = { {} }
	local bp: { { number } } = { {} }
	for i = 1, n do
		V[1][i] = hmm.pi[i] * hmm.B[i][obs[1]]
		bp[1][i] = 0
	end
	for t = 2, T do
		V[t], bp[t] = {}, {}
		for j = 1, n do
			local best, arg = -1, 1
			for i = 1, n do
				local score = V[t - 1][i] * hmm.A[i][j]
				if score > best then
					best, arg = score, i
				end
			end
			V[t][j] = best * hmm.B[j][obs[t]]
			bp[t][j] = arg
		end
	end
	local last, bestProb = 1, -1
	for i = 1, n do
		if V[T][i] > bestProb then
			last, bestProb = i, V[T][i]
		end
	end
	local path = table.create(T, 0)
	path[T] = last
	for t = T, 2, -1 do
		path[t - 1] = bp[t][path[t]]
	end
	return V, bp, path, bestProb
end

-- Joint probability P(s, o) = π(s₁)·B(s₁, o₁)·∏ A(sₜ₋₁, sₜ)·B(sₜ, oₜ).
function Viterbi.joint(hmm: HMM, states: { number }, obs: { number }): number
	local p = hmm.pi[states[1]] * hmm.B[states[1]][obs[1]]
	for t = 2, #obs do
		p *= hmm.A[states[t - 1]][states[t]] * hmm.B[states[t]][obs[t]]
	end
	return p
end

local function draw(probs: { number }, rng: Random): number
	local r = rng:NextNumber()
	local acc = 0
	for i, p in probs do
		acc += p
		if r < acc then
			return i
		end
	end
	return #probs
end

-- Samples T days from the model: hidden states, then an observation from each.
function Viterbi.sample(hmm: HMM, T: number, rng: Random): ({ number }, { number })
	local states, obs = {}, {}
	for t = 1, T do
		states[t] = if t == 1 then draw(hmm.pi, rng) else draw(hmm.A[states[t - 1]], rng)
		obs[t] = draw(hmm.B[states[t]], rng)
	end
	return states, obs
end

return Viterbi
