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

return Prob
