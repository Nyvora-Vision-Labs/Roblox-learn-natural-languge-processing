--!strict
-- Module metadata in portal order. Card content lives in one file per module (added per milestone).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

export type ModuleMeta = {
	id: string,
	order: number,
	title: string,
	era: string,
}

local META: { [string]: { title: string, era: string } } = {
	classifiers = { title = "Naive Bayes & Logistic Regression", era = "1950s–60s" },
	hmm = { title = "Hidden Markov Models", era = "1960s–80s" },
	rnn = { title = "RNNs & LSTMs", era = "1986–1997" },
	attention = { title = "Attention", era = "2014" },
	transformers = { title = "Transformers", era = "2017" },
}

local Index = {}

Index.order = Config.MODULE_ORDER

local byId: { [string]: ModuleMeta } = {}
for i, id in Config.MODULE_ORDER do
	local meta = META[id]
	assert(meta, `Lessons/Index is missing metadata for "{id}"`)
	byId[id] = { id = id, order = i, title = meta.title, era = meta.era }
end

function Index.get(moduleId: string): ModuleMeta?
	return byId[moduleId]
end

function Index.at(order: number): ModuleMeta?
	local id = Config.MODULE_ORDER[order]
	return if id then byId[id] else nil
end

return Index
