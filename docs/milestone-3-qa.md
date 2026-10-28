# Milestone 3: Module 1 (classifiers)

Implemented and playtested on October 28, 2026 in `Place2`. Portal 1 now opens the real module:
13 cards + 5 quiz questions (`src/shared/Shared/Lessons/Classifiers.luau`). The Preview stand-in was removed.

## Math (checked against hand-worked values before wiring)

| Check | Expected | Result |
| --- | --- | --- |
| P(free \| spam), add-one | 4/19 = 0.2105 | pass |
| P(spam \| free, win), add-one | 0.0177285 / 0.0237285 = 0.7471 | pass |
| P(spam \| free, win, agenda), raw | 0 (agenda never in spam) | pass |
| Same, add-one | 0.000933 / 0.001833 = 0.5090 | pass |
| Empty message | prior 0.40 | pass |
| Log-loss {0.8, 0.3} vs {1, 0} | 0.289909 | pass |
| 1-D loss/gradients at w=1, b=−3, x=2, y=0 | 0.313262 / 0.537883 / 0.268941 | pass |
| Gaussian fit, Box–Muller | mean 1, sd 1; N(0,1) moments | pass |
| 1-D fit on study data | boundary x = 2.75, loss 0.251 | pass |
| 2-D fit on 22 points | converges (29k steps, 56 ms), \|∇\| < 1e-4 | pass |

## Studio checks

| Check | Result |
| --- | --- |
| All 13 content cards | Rendered via keyboard navigation; three widgets load; no errors. |
| SpamDetective | Live UI shows 0.25 vs 0.08 (×3.2) raw and P(spam) = 0.00; mouse click on smoothing → 0.21 vs 0.10, agenda ×0.4, P(spam) = 0.51 “Spam”. |
| SigmoidLab | Starts at log-loss 0.693 (ln 2). Auto (Enter on selected button) converges in 1,220 steps to boundary x = 2.75, loss 0.251. |
| TwoWaysToClassify | Generate samples labeled points from the fitted Gaussians; boundary side labels follow the score's sign. |
| Quiz | Keys 1–5 + →: 5/5, “Module complete”; server stored completed = true, best 5 (real DataStore). Enter on results closes; no lesson GUIs remain. |
| Layout | No horizontal overflow on any card at desktop (scale 1.35) or iPhone 14 landscape (scale 0.458, Explore view). |
| Output | No errors or warnings from game code. |

## Open items

- Screenshots: Studio's `screen_capture` hung/timed out during these runs, so visual review was done by geometry audits, not images. A visual pass is still worth doing.
- On phones, label and caption text renders at ~12–13 px (body text is clamped to ≥ 15 px). This is shell-wide, not Module 1 specific.
- The fail path, retry shuffle and review links were verified on the Preview module in Milestone 2 with the same code; Module 1's review-card ids were checked statically.
