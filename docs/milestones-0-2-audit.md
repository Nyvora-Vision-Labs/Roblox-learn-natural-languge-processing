# Milestones 0–2 audit

Audited against `claude.md` on October 28, 2026. The implementation is present through Milestone 2. This audit found and fixed six gaps; full Milestone 2 QA still has the verification limits listed below.
The audited implementation snapshot includes fix commit `f012434`. New in-progress Module 1 content/math files appearing in the shared working tree are outside this audit.

| Milestone | Implementation | Evidence |
| --- | --- | --- |
| 0 — Scaffold | Complete | 44 scripts, all marked strict, one server entry and one client entry, three synced roots, four remotes, validated versioned progress, retries/merge, memory fallback, and Studio-only debug hooks. Real DataStore persistence passed previous cold-restart checks and the final audit reload. |
| 1 — Atrium and portals | Complete | Saved place `114279091823022` contains all five tagged portals in order. Each has its surface, trigger, rim/inlay, sign, light, particles, and beam. Triggers are anchored, invisible, and non-colliding. Completed/open/locked states are present together at runtime. Entry, locked feedback, unlock animation, cooldown, and improved-score updates were checked. |
| 2 — Lesson shell | Complete in code; QA qualified | Both ScreenGuis, scaling/compact layout, bars, entry/exit, all six renderers, quiz/results/retry/review, settings, and input bindings are implemented. The full preview flow passed after the audit fixes. Physical input checks and refreshed large-device captures remain pending. |

## Gaps fixed during this audit

| Finding | Before | After / verification |
| --- | --- | --- |
| Best-score sign | A completed portal stayed at 4/5 after an update to 5/5 because its state had not changed. | The sign refreshes even when the portal remains completed. Controlled progress updates now show 5/5. |
| Withdrawn queued unlock | A queued unlock could still play after progress was reset before leaving the lesson. | The queue rechecks current progress on return. A withdrawn unlock leaves Portal 2 locked. |
| Widget cleanup | Closing a lesson destroyed its GUI without calling the active card/widget cleanup function. | Cleanup calls the card destructor before releasing the shell. An instrumented interactive card records exactly one widget cleanup call on exit. |
| Text-size range | Large desktop body text reached 31.05/35.1 px at 115%/130%. Portrait rounding also fell slightly below the theme's 15 px target. | Body text now clamps to the theme's 15–30 px range after scaling. All 12 device/text-size combinations passed, with 15.125–29.7 px body text and tap metrics at least 44 px. Large desktop body text caps at the readability limit; headings and control labels retain the selected multiplier. |
| Phone toast overflow | The locked-portal message was 469 px wide in a 388 px portrait safe area and extended off screen. | Toasts wrap, constrain their width, and reflow on resize. The same message now measures 373 px, fits the safe area, and remains in bounds after rotation. |
| Save-failure feedback | A write failure left persistence marked available and never notified the client. | Failed writes retain in-memory progress, set persistence unavailable, and notify the client once. Later saves can recover. A separate guard still prevents overwriting data whose initial load failed. |

## Verification performed

- [Isolated storage verification script](../tools/VerifyProgressService.luau): all 14 checks passed. It tests malformed stored data, invalid remote arguments, unlock order, rate limiting, sticky completion/best score, failed writes and retry/recovery, failed reads without overwriting stored data, and the memory fallback's progress/settings round trip. It runs copies of ProgressService with fake storage and does not access production keys. Its two intentional failures produce expected warnings in that test session.
- A fresh production playtest then exercised the preview from the journey card through every renderer, a failed quiz, retry, a shuffled successful quiz, and exit. The saved best score stayed 5/5. The final production startup/reload log was empty.
- The preview has 11 cards, all six card kinds, five valid quiz questions/review targets, and a maximum card body length of 43 words. Sigmoid values match the hand-worked checks.
- [Structured audit results](qa/milestone-2/audit-verification.json) record the checks, measurements, and restored final progress. [The new portrait-toast capture](qa/milestone-2/audit-portrait-toast.jpg) shows the overflow fix. The earlier [Milestone 2 QA report](milestone-2-qa.md) contains the desktop/tablet/phone captures and persistence evidence.
- The final persistent progress matches the pre-audit baseline: Portal 1 completed at 5/5, saved card 2, other modules unchanged, and settings restored to 100% text, reduced motion off, sound on. Temporary probes and storage fixtures existed only in play mode.

## Verification limits

- Physical gamepad A/stick/D-pad navigation and real-device touch gestures have not been tested. Keyboard, mouse, simulated shoulder/B bindings, and console initial selection have been checked.
- Fresh post-fix desktop/tablet/phone captures could not all be collected because Studio's screenshot requests repeatedly timed out. Restarting restored simulated input, and the full lesson flow passed. Current text bounds were checked numerically across devices, and the portrait toast was captured, but a fresh complete visual pass should still be signed off.
- Studio's editor Script Analysis diagnostics were not exported, and no standalone Luau analyzer, StyLua, or selene is installed. Runtime parsing/execution and source checks passed; this report does not claim zero editor type diagnostics.

Full Module 1 content and its larger widgets belong to Milestone 3. The remaining curriculum, journey HUD, welcome/graduation screens, and final polish are later milestones, so they are not missing Milestone 2 work.

Studio is stopped and reset to its default viewport. No world geometry was changed.
