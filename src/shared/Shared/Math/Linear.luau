--!strict
-- Small vector/matrix helpers plus the recurrent and attention computations built from them.
-- Vectors are { number }, matrices are row-major { { number } }. Pure functions, no instances.
-- Each function is checked against hand-worked values before a widget uses it.

local Prob = require(script.Parent:WaitForChild("Prob"))

export type Vec = { number }
export type Mat = { { number } }

local Linear = {}

function Linear.dot(a: Vec, b: Vec): number
	local s = 0
	for i, x in a do
		s += x * b[i]
	end
	return s
end

function Linear.add(a: Vec, b: Vec): Vec
	local out = {}
	for i, x in a do
		out[i] = x + b[i]
	end
	return out
end

function Linear.scale(a: Vec, k: number): Vec
	local out = {}
	for i, x in a do
		out[i] = x * k
	end
	return out
end

-- M·v
function Linear.matVec(m: Mat, v: Vec): Vec
	local out = {}
	for i, row in m do
		out[i] = Linear.dot(row, v)
	end
	return out
end

function Linear.transpose(m: Mat): Mat
	local out = {}
	for i, row in m do
		for j, x in row do
			out[j] = out[j] or {}
			out[j][i] = x
		end
	end
	return out
end

-- A·B
function Linear.matMul(a: Mat, b: Mat): Mat
	local bt = Linear.transpose(b)
	local out = {}
	for i, row in a do
		out[i] = {}
		for j, col in bt do
			out[i][j] = Linear.dot(row, col)
		end
	end
	return out
end

-- Σᵢ weights[i] · vectors[i]
function Linear.weightedSum(weights: { number }, vectors: { Vec }): Vec
	local out = table.create(#vectors[1], 0)
	for i, w in weights do
		for k, x in vectors[i] do
			out[k] += w * x
		end
	end
	return out
end

function Linear.tanh(v: Vec): Vec
	local out = {}
	for i, x in v do
		out[i] = math.tanh(x)
	end
	return out
end

---------------------------------------------------------------------------
-- Recurrent networks
---------------------------------------------------------------------------

-- One RNN step: hₜ = tanh(Wₕ·hₜ₋₁ + Wₓ·xₜ + b). The same Wₕ, Wₓ, b are reused at every step.
function Linear.rnnStep(h: Vec, x: Vec, Wh: Mat, Wx: Mat, b: Vec): Vec
	return Linear.tanh(Linear.add(Linear.add(Linear.matVec(Wh, h), Linear.matVec(Wx, x)), b))
end

-- Runs an RNN over a sequence from h₀. Returns { h₁, …, h_T }.
function Linear.rnnRun(h0: Vec, xs: { Vec }, Wh: Mat, Wx: Mat, b: Vec): { Vec }
	local hs, h = {}, h0
	for t, x in xs do
		h = Linear.rnnStep(h, x, Wh, Wx, b)
		hs[t] = h
	end
	return hs
end

-- One LSTM cell update from gate values (scalar form, as in the LSTMGates widget):
-- cₜ = fₜ·cₜ₋₁ + iₜ·gₜ and hₜ = oₜ·tanh(cₜ). Returns (cₜ, hₜ).
function Linear.lstmCell(cPrev: number, f: number, i: number, g: number, o: number): (number, number)
	local c = f * cPrev + i * g
	return c, o * math.tanh(c)
end

---------------------------------------------------------------------------
-- Attention
---------------------------------------------------------------------------

export type AttentionResult = {
	scores: Mat, -- Q·Kᵀ
	scaled: Mat, -- Q·Kᵀ / √dₖ (masked entries are −∞)
	weights: Mat, -- softmax of each row
	output: Mat, -- weights · V
}

-- Scaled dot-product attention, softmax(Q·Kᵀ / √dₖ)·V (Vaswani et al., 2017).
-- With causal = true, query i may only attend to keys j ≤ i.
function Linear.attention(Q: Mat, K: Mat, V: Mat, causal: boolean?): AttentionResult
	local dk = #K[1]
	local scores = Linear.matMul(Q, Linear.transpose(K))
	local scaled, weights, output = {}, {}, {}
	for i, row in scores do
		scaled[i] = {}
		local visible = {}
		for j, s in row do
			if causal and j > i then
				scaled[i][j] = -math.huge
			else
				scaled[i][j] = s / math.sqrt(dk)
				table.insert(visible, j)
			end
		end
		local logits = {}
		for k, j in visible do
			logits[k] = scaled[i][j]
		end
		local probs = Prob.softmax(logits)
		weights[i] = table.create(#row, 0)
		for k, j in visible do
			weights[i][j] = probs[k]
		end
		output[i] = Linear.weightedSum(weights[i], V)
	end
	return { scores = scores, scaled = scaled, weights = weights, output = output }
end

return Linear
