# Milestone 4: Module 2 (Hidden Markov Models)

Implemented and playtested on October 28, 2026 in `Place2`. Portal 2 opens the module:
12 cards + 5 quiz questions (`src/shared/Shared/Lessons/HMM.luau`), built on Eisner's ice-cream
example as presented in Jurafsky & Martin (π = 0.8/0.2; A = 0.6/0.4, 0.5/0.5; B = 0.2/0.4/0.4, 0.5/0.4/0.1; diary 3, 1, 3).

## Math (`Math/Viterbi.luau`, checked against hand-worked values)

| Check | Expected | Result |
| --- | --- | --- |
| Rows of A and B | each sums to 1 | pass |
| Viterbi V₁, V₂, V₃ | 0.32/0.02, 0.0384/0.064, 0.0128/0.0032 | pass |
| Back-pointers, best path | H,H / C,C; Hot, Cold, Hot = 0.0128 | pass |
| Joint P(HCH, 313) | 0.0128 (equals the Viterbi best) | pass |
| Forward α₂, α₃ | 0.0404/0.069, 0.023496/0.005066 | pass |
| P(diary) | 0.028562 = Σ joint over all 8 paths | pass |
| Posteriors γ | γ₁(H) = 0.9366, γ₂(C) = 0.6039; each day sums to 1 | pass |
| Sampling | P(start Hot) ≈ 0.8, P(Hot→Hot) ≈ 0.6 over 20k draws | pass |

Per-day posteriors give Hot, Cold, Hot, the same as Viterbi for this diary; the card says so and notes they can differ in general.

## Widgets

- `WeatherMachine`: state diagram with labeled transition arrows and self-loops (drawn, no font glyphs), emission table, “Sample a week” (real draws from π, A, B, revealed day by day with the current state highlighted; instant under reduced motion), and a “Show the weather” toggle. Ice creams are drawn as scoops.
- `ViterbiTrellis`: guess first (Lock in refuses until every day has a guess), then Step/Back fills each column and prints the arithmetic; the final step traces the best path with highlighted cells and arrows and scores the guess. With `compare`, a Viterbi/Forward switch shows sums instead of maxes and ends with P(diary).

## Studio checks

| Check | Result |
| --- | --- |
| All 12 content cards | Rendered via keyboard navigation; widgets load; no errors. |
| Trellis (mouse) | Guess Hot/Cold/Hot → Lock in → Step ×4. Cells 0.3200/0.0200, 0.0384/0.0640, 0.0128/0.0032; “max(0.3200×0.6, 0.0200×0.5) × B 0.2 = 0.0384”; best path Hot, Cold, Hot, 0.0128, 3 of 3 matched; 4 pointers, 2 on the path. |
| Forward mode | 0.0404/0.0690, 0.0235/0.0051; no pointers; “P(diary) = 0.0235 + 0.0051 = 0.0286”. |
| WeatherMachine (mouse) | Sample with weather hidden shows “?” and scoop counts; toggling reveals matching Hot/Cold labels and a hot/cold count. |
| Layout | WeatherMachine was 959 px tall in a 718 px column; reorganized (shorter diagram, controls in one row, reference table last) so Sample and the week fit above the fold. No horizontal overflow on any card at desktop or iPhone 14 landscape. |
| Quiz | 5/5 → “Module complete”; server stored hmm completed, best 5 (real DataStore). Back in the Atrium, Portal 2 shows Completed and Portal 3 unlocked to Open (Module 3 content not built yet, so it shows “coming soon”). |
| Output | No errors or warnings from game code. |

## Open items

- `screen_capture` hangs during play sessions, so there are no captures for this milestone. Visual review was by geometry audits; a quick look in Studio is still worthwhile, especially the WeatherMachine self-loop arrowheads and Unicode subscripts (sₜ, oₜ, αₜ) in formulas.
- Portal 3 is now open on this account because the quiz test used the real DataStore.
