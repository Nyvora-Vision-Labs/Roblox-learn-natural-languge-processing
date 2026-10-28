# Milestones 5–7: Modules 3–5 (RNNs & LSTMs, Attention, Transformers)

Implemented and playtested on October 28, 2026 in `Place2`. All five portals now have content.

| Module | File | Cards | Widgets |
| --- | --- | --- | --- |
| 3 · RNNs & LSTMs | `Lessons/RNN.luau` | 12 + 5 quiz | UnrollTheLoop, GradientTelephone, LSTMGates |
| 4 · Attention | `Lessons/Attention.luau` | 10 + 5 quiz | Bottleneck*, ScoreSoftmaxBlend, AlignmentHeatmap* |
| 5 · Transformers | `Lessons/Transformers.luau` | 13 + 5 quiz | WhoIsIt*, QKVCalculator, CausalMask, BuildTheBlock |

\* Hand-authored weights; these widgets show the “Illustrative” badge. `NextToken` (optional in the spec) was not built.

## Math (`Math/Prob.softmax`, `Math/Linear.luau`, checked against hand-worked values)

softmax {1, 2, 3} = 0.0900 / 0.2447 / 0.6652; temperature 0.5 on {1, 2}; no overflow at 1000; matrix product, transpose, mat·vec;
RNN step h₁ = tanh 1 = 0.7616, h₂ = tanh(0.5·h₁) = 0.3634; LSTM c = 0.5·1 + 1·(−1) = −0.5, h = tanh(−0.5);
attention softmax(QKᵀ/√2)V on a 1×2 example (weights 0.6698 / 0.3302, output (1.6605, 2.6605)); causal mask zeroes future
weights and renormalizes. All pass (one hand value of mine was off in the 5th decimal; the code was right).

Content checks: every quiz has a valid answer, one explanation per option and an existing review card; every body ≤ 70
words; every term has a glossary entry; illustrative weight rows sum to 1; each blend query's top key is the intended word;
QKV row “it” = 0.2593 / 0.5075 / 0.2332 → (0.5594, 0.2851); LSTM start gates give c = −0.1875 at the verb.

## Studio checks

| Check | Result |
| --- | --- |
| All 35 content cards | Walked with ← / →; every widget loads; no horizontal overflow at desktop; no errors. |
| QKVCalculator (mouse) | Stage 5 shows “it” weights 0.26 / 0.51 / 0.23 → output (0.56, 0.29), matching the hand-worked values. |
| WhoIsIt (mouse) | “it” → “animal” (0.62) with “tired”; switching to “wide” → “street” (0.63). Illustrative badge present. |
| Module 3 quiz | 5/5 → server stored rnn completed, best 5 (real DataStore; portal 4 is now open on this account). |
| Output | No errors or warnings from game code. |

## Open items

- `screen_capture` still hangs in play sessions, so this pass had no visual captures. A visual check in Studio is worth doing, particularly the WeatherMachine/UnrollTheLoop loop arrows, BuildTheBlock's residual lines and Unicode marks (ᵀ, √, subscripts).
- Interactive checks of LSTMGates, GradientTelephone, ScoreSoftmaxBlend, AlignmentHeatmap, CausalMask and BuildTheBlock were by rendering + math checks, not click-throughs.
- Polish milestone (journey tracker, first-visit cards, graduation, sound, full device QA) is next.
