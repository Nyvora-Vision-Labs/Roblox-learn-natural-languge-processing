# Polish milestone

Implemented and playtested on October 28, 2026 in `Place2`.

## What was added

- **Journey tracker** (`Controllers/HudController.luau`): top-center pill with five nodes: filled in the module's accent (done), pulsing accent ring (current; static under reduced motion), outline (locked), and a caption (“Next: Attention”). Hidden while a lesson or overlay is open. After graduation it reads “All five modules complete. Tap to see your recap.” and reopens the recap.
- **First-visit cards** (`Lessons/Welcome.luau`): three skippable cards with step dots; closing saves `seenIntro`, so they show once.
- **Graduation** (`Lessons/Graduation.luau`): appears 0.8 s after returning to the Atrium when the last module completes (deferred if a lesson is open). One line per module plus the lineage. Closing it lights every portal: completed portals keep their beams and brighter lights from then on.
- **Sound** (`UI/Sound.luau`, ids in `Assets.luau`): correct/incorrect quiz answers, module complete, portal unlock and locked portal. All free Creator Store audio, all verified to load; everything respects the Sound setting. The incorrect sound reuses the soft click, never a penalty buzz.
- **Readability**: labels, captions and numbers now have a 14 px on-screen floor (`Theme.minSmallScreenPx`); on phones they were ~12–13 px.
- **Overlays fit small screens**: the overlay card is capped at the stage height and scrolls beyond that.

## Checks

| Check | Result |
| --- | --- |
| Tracker states | Real progress (1–3 done, 4 open): nodes 1–3 filled in teal/violet/amber, node 4 pink 3 px ring, node 5 outline; caption “Next: Attention”. |
| Welcome | Shown on first load (seenIntro false); Next ×3 → closes, tracker reappears, server seenIntro = true. |
| Hide during lessons | Tracker hidden while LessonUI exists. |
| Sounds | correct 1.88 s, incorrect 1.41 s, complete 2.43 s, unlock 1.91 s: all load. |
| Graduation | Controlled all-complete `ProgressChanged` packet (not stored) sent during a lesson: nothing shown until close, then the recap appears. Closing lights all five portals (beam on, light 1.8). Tapping the tracker reopens it. `Debug_ReloadProgress` restored the real data: portals and tracker returned to normal; server shows attention/transformers not completed. |
| Leak check | Three open/close cycles through widget-heavy lessons: PlayerGui descendants 31 → 31, SoundService 4 → 4, camera children 1 → 1. |
| Phone (iPhone 14 landscape) | Tracker 213×51 px, node digits 14.4 px. Graduation card was 349 px in a 330 px screen; now 11–319 px and scrolls. 23 Module 3–5 cards (all widget cards, Explore view): no horizontal overflow, smallest text 14.2 px. |
| Output | No errors or warnings from game code. |

## Open items

- `screen_capture` still hangs in play sessions; visual review in Studio is still worth doing (tracker, overlays, widget drawings, Unicode marks).
- Physical gamepad/touch hardware and a tablet run of the new overlays were not exercised.
