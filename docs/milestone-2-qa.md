# Milestone 2: lesson shell

Implemented and playtested on October 28, 2026 in Studio's existing `Place2`.
Portal 1 uses the 11-card preview; full Module 1 content remains Milestone 3.

## Fixes

- The opening transition referenced the initial shell after resize callbacks could replace it. It now reveals the current shell, and the transition cover lives on the persistent stage.
- Resizing notifies layout subscribers even when the scale remains constant. Portrait headers move progress below the controls, and compact text uses the available width.
- Settings block background card navigation and contain gamepad selection. Console entry selects an initial button.
- Mobile movement controls hide during lessons and restore on exit. Segmented buttons retain a minimum 44-pixel target after padding.
- Essential check, close, and disclosure icons use drawn shapes. The sigmoid plot leaves room for axis labels; retry appears above the review list.

## Studio checks

| Check | Result |
| --- | --- |
| Walk into Portal 1 | Lesson appears after the normal camera/wipe transition. |
| Resize during entry | Phone scale changed from 0.4583 to 0.5389 and back. The shell instance changed, its replacement was visible, and the cover was hidden. |
| All card kinds | Concept, interactive, compare, math, recap, and quiz exercised. Go deeper, sigmoid controls, Reset, and scrollable content work. |
| Quiz fail | 0/5 shows explanations and a deduplicated review list. Review links open the matching card. Mouse and Enter activate Try again; answers clear and options shuffle. |
| Quiz pass | Both 4/5 and 5/5 complete the lesson. Portal 2 remains visually locked during the lesson and opens on returning. |
| Best score | A later 0/5 retains the previous 4/5 and completed state. |
| Resume | Reopening at saved quiz progress starts at question 1 with no saved answers. |
| Settings | 100%, 115%, and 130% rebuild the current card while keeping settings open. Reduced motion and sound toggles update server settings. |
| Reduced motion | Camera CFrame remains unchanged during entry; portal pulsing stops. |
| Sound | Locked sound loads when enabled. Muting prevents creating/playing it. |
| Save/reload | Completion, best score, and settings survive the server's debug save/reload using the memory backend. |
| Keyboard | Left/Right, Enter, number choices, and X exercised. W and Space cause zero character displacement while a lesson is open. Settings block Left/Right navigation. |
| Console emulation | Xbox entry selects Next. Simulated LB, RB, and B bindings work; selected controls activate with Enter. |
| Cleanup | Three close/reopen cycles leave zero lesson ScreenGuis after close. Camera, chat, player list, touch controls, and action bindings restore. |
| Other portals | Unlocked Portal 2 shows “coming soon” without opening an empty lesson. |
| Completed portal | Both the sign and central check mark are legible. |
| Output | Final gameplay runs have no errors or warnings from project code. Studio prints the expected unpublished-place memory-backend message. |

## Visual checks

The place uses `ScreenOrientation.Sensor`; both phone orientations were checked. Interactive content uses `CoreUISafeInsets`, while the backdrop uses `None`. Studio downsizes device captures, so image dimensions differ from the selected device preset. Longer phone content intentionally scrolls.

| Preset | Captures |
| --- | --- |
| Desktop, 1920 × 1080 | [Lesson](qa/milestone-2/desktop.jpg), [pass](qa/milestone-2/pass.jpg), [fail](qa/milestone-2/fail.jpg) |
| iPad 6th Generation, 1024 × 768 | [Lesson](qa/milestone-2/tablet.jpg) |
| iPhone 14 landscape, 844 × 390 | [Explore](qa/milestone-2/phone-landscape.jpg), [quiz feedback](qa/milestone-2/phone-quiz.jpg) |
| iPhone 14 portrait, 390 × 844 | [Concept](qa/milestone-2/phone-portrait.jpg), [130% settings](qa/milestone-2/phone-portrait-settings.jpg) |
| Atrium | [Completed portal](qa/milestone-2/completed-portal.jpg) |

## Remaining environment checks

- The Studio input tool injects gamepad A and D-pad codes as keyboard events. Physical A-button, stick/D-pad navigation, and real-device touch gestures still need hardware verification. Mouse interaction and scrolling were exercised in mobile emulation.
- `Place2` is unpublished, so cross-session DataStore persistence cannot be verified here. The existing memory fallback and save/reload path work; publishing was not performed.
- Save the Studio place to preserve the existing Atrium geometry. Git stores the scripts and these captures, not the place's world geometry.

Play is stopped and Studio is reset to its default viewport.
