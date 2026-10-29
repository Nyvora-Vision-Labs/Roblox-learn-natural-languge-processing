# Model Academy

A Roblox experience that teaches how sequence models evolved, from Naive Bayes to Transformers.
Players walk a night-time Atrium with five portals; each opens a full-screen, hands-on lesson.
Passing a lesson's quiz (4 out of 5) unlocks the next portal. After the fifth, a graduation recap
plays and every portal lights up.

**Play on Roblox:** [Learn Natural Language Processing](https://www.roblox.com/games/72565218405440/Learn-Natural-Language-Processing)

| Portal | Module | Hands-on widgets |
| --- | --- | --- |
| 1 | Naive Bayes & Logistic Regression | SpamDetective, SigmoidLab, TwoWaysToClassify |
| 2 | Hidden Markov Models | WeatherMachine, ViterbiTrellis |
| 3 | RNNs & LSTMs | UnrollTheLoop, GradientTelephone, LSTMGates |
| 4 | Attention | Bottleneck, ScoreSoftmaxBlend, AlignmentHeatmap |
| 5 | Transformers | WhoIsIt, QKVCalculator, CausalMask, BuildTheBlock |

Every number a widget shows is computed from the real formula (`src/shared/Shared/Math`); widgets
that show hand-authored weights carry an “Illustrative” badge.

## Working on it

- **Spec and rules:** [`claude.md`](claude.md) is the source of truth for design, content and conventions.
- **Code:** `src/` is synced into Studio with Script Sync:
  `src/shared/Shared` → `ReplicatedStorage.Shared`, `src/server/Server` → `ServerScriptService.Server`,
  `src/client/Client` → `StarterPlayer.StarterPlayerScripts.Client`.
- **World:** the Atrium and portals live in the saved place file, not in git.
  `tools/BuildAtrium.luau` rebuilds them from scratch (run in Edit mode via `execute_luau`).
- **Progress:** saved per player in the DataStore `Progress_v1` (key `u_<UserId>`), with an in-memory fallback.
- **Studio-only debug hooks** (attributes, see `claude.md` §4.5): `Debug_UnlockAll`, `Debug_ResetProgress`,
  `Debug_ReloadProgress` on the server player, `Debug_OpenLesson = "hmm:4"` on the client player.

## Status

All milestones in `claude.md` §9 are built and playtested: scaffold, Atrium and portals, lesson shell,
all five modules, and polish (journey tracker, first-visit cards, graduation, sound, device QA).
QA notes per milestone are in [`docs/`](docs).

Known gaps:

- Studio's `screen_capture` hung during later play sessions, so Modules 2–5 and the polish pass were
  verified by layout audits and math checks rather than screenshots; a final visual pass is worthwhile.
- Not exercised on physical gamepad or touch hardware.
- The optional `NextToken` widget (§7.6) was not built.
- Badges were intentionally left optional.
