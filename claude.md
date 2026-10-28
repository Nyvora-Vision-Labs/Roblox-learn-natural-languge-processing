# Model Academy (working title)

A Roblox experience that teaches students how sequence models evolved, from Naive Bayes to Transformers. Players explore a 3D hub with five portals. Walking into a portal opens a full-screen 2D interactive lesson. Passing a lesson's quiz unlocks the next portal.

**Audience:** motivated high-school and early-university students. Assume basic algebra and that they have seen notation like P(A). Define every other symbol before using it.

**Quality bar:** this should feel like a premium learning product, not a typical Roblox UI. Two things are non-negotiable: polished design and technically correct content.

---

## 1. Rules for Claude

- **Code lives on disk.** Edit the `.luau` files in this repo; Script Sync pushes them into Studio. Don't edit synced scripts with the MCP `multi_edit` tool — two writers will clobber each other.
- **Studio work goes through the Roblox Studio MCP server:** playtests, output, inspecting or building world geometry, screenshots, simulated input.
- **Never guess a Roblox API.** If you aren't sure a property, method or enum exists, look it up with the MCP `http_get` tool (Roblox docs) first.
- **Content is data.** Lesson text, quiz questions and widget settings live in `src/shared/Shared/Lessons/`. UI code never hardcodes lesson content.
- **Real math only.** Every number a demo shows is computed from the real formula in code. Hand-authored values (e.g., example attention weights) must show a visible "Illustrative" badge.
- **Verify before claiming done.** Run the verify loop (§3.3) after every change.
- **World edits aren't in git.** Changes made with `execute_luau` in Edit mode live in the place file. After any world change, tell the human to save/publish the place.
- **Ask first** before adding a new top-level synced folder (the human must set up sync for it), adding third-party libraries, creating badges or anything that costs Robux, or publishing.

## 2. One-time setup (done by the human)

1. In Studio, create three Folders:
   - `ReplicatedStorage/Shared`
   - `ServerScriptService/Server`
   - `StarterPlayer/StarterPlayerScripts/Client`
2. For each: right-click → **Sync to…** → choose `src/shared`, `src/server` or `src/client` in this repo → **Save**. Studio syncs into a subfolder named after the instance, so the code lives in `src/shared/Shared`, `src/server/Server` and `src/client/Client`.
3. Game Settings → Security → turn on **Enable Studio Access to API Services** (DataStores need it in Studio).
4. Assistant → … → Manage MCP Servers → turn on **Enable Studio as MCP server**; connect Claude Code.
5. `git init` this folder.

## 3. Workflow

### 3.1 Script Sync conventions

| On disk            | In Studio                  |
| ------------------ | -------------------------- |
| `Name.luau`        | ModuleScript               |
| `Name.server.luau` | Script (RunContext Server) |
| `Name.local.luau`  | LocalScript                |
| `Name/`            | Folder                     |

- Exactly one server entry (`src/server/Server/Main.server.luau`) and one client entry (`src/client/Client/Main.local.luau`). Everything else is a ModuleScript.
- Synced folders hold only scripts and folders; Script Sync ignores every other instance type. UI and remotes are created by code at runtime; world geometry lives in the place file (§5.1).
- Never put attributes or tags on scripts (Script Sync drops them, which can lose data).
- File names must be unique within their folder and filesystem-safe.
- Don't delete or rename the three root folders on disk; it breaks sync. Children are fine.
- `--!strict` type errors appear in Studio's Script Analysis window, not in the output log. Keep types simple and confirm behavior at runtime.

### 3.2 Studio MCP tools

| Need                                           | Tool                                                                                     |
| ---------------------------------------------- | ---------------------------------------------------------------------------------------- |
| Edit or Play mode?                             | `get_studio_state`                                                                       |
| Start/stop a playtest                          | `start_stop_play`                                                                        |
| Errors and prints                              | `get_console_output`                                                                     |
| See the screen                                 | `screen_capture`                                                                         |
| Walk the character somewhere                   | `character_navigation`                                                                   |
| Click, type, press keys                        | `user_mouse_input`, `user_keyboard_input`                                                |
| Run code, change state, build geometry         | `execute_luau` (pick `datamodel_type` Edit, Client or Server deliberately)               |
| Explore instances                              | `search_game_tree`, `inspect_instance`                                                   |
| Sounds, icons, models                          | `search_asset`, `insert_asset`, `upload_image` (only free assets allowed in experiences) |
| Roblox docs, best practices, device simulation | `http_get`, `skill`                                                                      |
| Long gameplay checks                           | `subagent` with type `playtest`                                                          |
| Several Studio windows open                    | `list_roblox_studios`, then pass that `studio_id`                                        |

### 3.3 Verify loop (after every change)

1. Give Script Sync a moment, then `start_stop_play`.
2. `get_console_output`: zero errors, no warnings from our code.
3. Exercise the change for real: walk into the portal, click through cards, answer the quiz.
4. `screen_capture` at desktop (1920×1080), tablet (1024×768) and phone landscape (~844×390) using device emulation. Check for clipped or overlapping text, misalignment, contrast and tap-target size.
5. Stop play. Commit with a short message.

Use the debug hooks (§4.5) to jump straight to what you're testing.

## 4. Architecture

### 4.1 Layout

```
src/
  shared/Shared/                -> ReplicatedStorage.Shared
    Config.luau                 module order, pass mark, constants
    Types.luau                  Card, Module, Progress, Settings types
    Theme.luau                  design tokens (§6); the only place colors/sizes are defined
    Assets.luau                 asset ids (icons, sounds)
    Lessons/
      Index.luau                module metadata (title, era) in portal order
      Classifiers.luau  HMM.luau  RNN.luau  Attention.luau  Transformers.luau
      Glossary.luau
    Math/                       pure functions, no instances
      Prob.luau                 sigmoid, softmax, log-loss, Naive Bayes posterior
      Linear.luau               small vector/matrix helpers
      Viterbi.luau              forward algorithm + Viterbi
  server/Server/                -> ServerScriptService.Server
    Main.server.luau
    Remotes.luau                creates ReplicatedStorage.Remotes
    ProgressService.luau        DataStore load/save/merge, validation
    DebugHooks.luau
  client/Client/                -> StarterPlayerScripts.Client
    Main.local.luau
    ProgressClient.luau         client copy of progress; fetch + ProgressChanged
    Controllers/
      PortalController.luau     portal visuals per player, entry detection, locked feedback
      LessonController.luau     open/close, transitions, card navigation, quiz
      HudController.luau        journey tracker, toasts, settings, first-visit cards
      InputController.luau      keyboard / gamepad / touch mapping
      DebugHooks.luau
    UI/
      Create.luau               instance factory: Create(className, props, children)
      Cleanup.luau              tracks connections/instances; one call cleans up
      Scale.luau                UIScale + compact mode (§6.2)
      Components/               Button, IconButton, Chip, Slider, Toggle, SegmentedControl,
                                ProgressBar, Toast, Tooltip, Modal, Callout, FormulaBlock, Legend,
                                Glyph (frame-drawn placeholder icons, e.g. the lock)
      Cards/                    one renderer per card kind
      Widgets/                  one file per interactive demo (§7)
tools/
  BuildAtrium.luau              not synced; rebuilds the Atrium + portals via execute_luau (Edit)
```

### 4.2 Runtime flow

1. Server `Main` creates `ReplicatedStorage.Remotes`, starts ProgressService, and loads each joining player's progress.
2. Client `Main` waits for `Remotes` and the player's progress (`WaitForChild`; replication can lag), then starts the controllers.
3. PortalController finds every instance tagged `Portal` (CollectionService), reads attributes `ModuleId` (string) and `Order` (number), and sets each portal's look. Portal state is per player, so all portal visuals change locally on the client.
4. Every ~0.1 s it checks whether the HumanoidRootPart is inside a portal's `Trigger` box (`Trigger.CFrame:PointToObjectSpace(pos)` within half the size on each axis). Don't use `Touched` for this.
5. Inside an open portal → LessonController opens that module at its saved card. Inside a locked one → toast.
6. Quiz passed → client fires `ReportLesson` → server validates and saves → server fires `ProgressChanged` → the next portal plays its unlock animation.

### 4.3 Networking (`ReplicatedStorage.Remotes`, created by the server)

- `GetProgress` — RemoteFunction, client → server
- `ProgressChanged` — RemoteEvent, server → client
- `ReportLesson` — RemoteEvent, client → server: `{ kind: "opened" | "card" | "completed", moduleId, cardIndex?, score? }`
- `SaveSettings` — RemoteEvent, client → server

The server checks every argument's type and range, enforces unlock order (module N can't complete before N−1), and rate-limits. Never use `InvokeClient`.

### 4.4 Persistence

DataStore key `u_<UserId>`, versioned:

```lua
{
  v = 1,
  modules = { [moduleId] = { completed = false, bestScore = 0, lastCard = 1 } },
  settings = { textScale = 1, reducedMotion = false, muted = false },
  seenIntro = false,
}
```

- `pcall` + retries with backoff. Use `UpdateAsync` and **merge** instead of overwriting (`completed = old or new`, `bestScore = max`).
- Save when a module completes, on `PlayerRemoving`, in `BindToClose`, and every few minutes if dirty.
- If the DataStore fails, keep playing from memory and show a quiet toast: "Progress won't be saved this session."

### 4.5 Debug hooks (Studio only, guarded by `RunService:IsStudio()`)

Attribute-driven so `execute_luau` can trigger them:

- Server: set Player attribute `Debug_UnlockAll = true`, `Debug_ResetProgress = true` or `Debug_ReloadProgress = true` (save, drop the session, load it back).
- Client: set LocalPlayer attribute `Debug_OpenLesson = "hmm:4"` to open a module at a given card.

## 5. Experience design

### 5.1 The Atrium (3D hub)

- Mood: a calm science museum at night. Dark materials, soft lighting, subtle bloom; each portal's accent color is the brightest thing in its area.
- Five portals in order along a gently curving path from spawn, framed as a walk through history:

| #   | ModuleId       | Title                             | Era       | Accent |
| --- | -------------- | --------------------------------- | --------- | ------ |
| 1   | `classifiers`  | Naive Bayes & Logistic Regression | 1950s–60s | Teal   |
| 2   | `hmm`          | Hidden Markov Models              | 1960s–80s | Violet |
| 3   | `rnn`          | RNNs & LSTMs                      | 1986–1997 | Amber  |
| 4   | `attention`    | Attention                         | 2014      | Pink   |
| 5   | `transformers` | Transformers                      | 2017      | Sky    |

- Each portal is a Model tagged `Portal` with attributes `ModuleId` and `Order`, containing: the frame (arch or ring), a glowing surface in the accent color, an invisible non-colliding `Trigger` part, a sign (SurfaceGui: number, title, era, status), a PointLight and subtle particles.
- States:
  - **Locked:** desaturated, surface off, lock icon; sign reads "Finish <previous module> to unlock."
  - **Open:** full color, slow pulse, light beam. The floor path glows toward the next open portal.
  - **Completed:** check mark and best score on the sign; calm, steady glow.

### 5.2 Entering and leaving

- **Enter an open portal:** disable character controls (PlayerModule `GetControls():Disable()`), set the camera to Scriptable and ease it toward the portal, play a quick accent-tinted wipe, then reveal the lesson screen. Whole transition ≤ 0.8 s.
- **Enter a locked portal:** soft sound + toast. Nothing else.
- **While a lesson is open:** blur the world with a `BlurEffect` parented to `workspace.CurrentCamera`; hide the player list and chat via `StarterGui:SetCoreGuiEnabled`; sink movement and arrow-key input. Restore everything on close.
- **Leave:** close button, keyboard `X`, or gamepad B. Never Esc (Roblox reserves it for its menu). Reverse the transition, place the character ~8 studs in front of the portal facing away, restore the camera and controls, and ignore re-entry for 2 s. Next visit resumes at the saved card.
- **Reduced motion:** no camera move; a 0.2 s fade instead.

### 5.3 The lesson screen

```
┌────────────────────────────────────────────────────────────────────┐
│ ● Module 2 · Hidden Markov Models      ▬▬▬▬▬▬▭▭▭▭▭▭  6/12   ⚙   ✕  │  top bar
├────────────────────────────────────────────────────────────────────┤
│  Card title                       │                                │
│  Body text, ≤ 70 words            │     Visual / interactive       │
│  Key-term chips                   │     panel                      │
│  [ Go deeper ▸ ]                  │                                │
│  ← text column ~40%               │     visual column ~60% →       │
├────────────────────────────────────────────────────────────────────┤
│ [ ← Back ]                                             [ Next → ]  │  bottom bar
└────────────────────────────────────────────────────────────────────┘
```

- Text-only cards use one centered column, max ~640 px wide.
- "Go deeper" expands optional math in place. The core path never requires it.
- The text column scrolls (ScrollingFrame + AutomaticCanvasSize) when needed. Text never shrinks to fit.
- Every widget has a one-line instruction above it ("Drag w until the curve separates the dots") and a Reset button.

### 5.4 Card kinds

`concept` (text + optional static visual), `interactive` (text + widget), `compare` (two columns), `math` (formula + a plain-language legend for each symbol), `quiz`, `recap`.

```lua
{
  id = "nb-naive",
  kind = "interactive",
  title = "Why “naive”?",
  body = "Naive Bayes assumes every word is independent of the others <b>once you know the class</b>. ...",
  widget = "SpamDetective",
  widgetProps = { showIndependence = true },
  deeper = "P(x₁, …, xₙ | y) = ∏ᵢ P(xᵢ | y)",
  terms = { "conditional independence" },
}

{
  id = "nb-q1",
  kind = "quiz",
  prompt = "Which model learns P(x | y)?",
  options = { "Naive Bayes", "Logistic regression" },
  answer = 1,
  explain = {
    "Right. It models how each class generates its features.",
    "Not quite. Logistic regression models P(y | x) directly.",
  },
  reviewCard = "gen-vs-disc",
}
```

### 5.5 Quizzes and unlocking

- 5 questions per module, one per screen, instant feedback with the explanation for whichever option was chosen.
- Pass mark 4/5 (`Config.PASS_MARK`). Passing completes the module, shows a short celebration, and after returning to the Atrium the next portal plays its unlock animation.
- Below 4/5: list the cards to review (`reviewCard`) and offer "Try again" with shuffled option order. No timers, no penalties; keep the best score.

### 5.6 Around the lessons

- **Journey tracker:** top-center HUD, 5 nodes on a line: filled (done), pulsing ring (current), outline (locked).
- **First visit:** up to 3 welcome cards (what this is, how portals work, "walk into Portal 1"). Skippable, shown once.
- **Graduation:** after Module 5, a recap screen with one line per module, and every portal in the Atrium lights up. Per-module badges are optional; ask the human before creating any.

## 6. Design system (`Theme.luau` is the single source of truth)

### 6.1 Principles

1. One idea per card. If a card needs "and also", split it.
2. Show, then tell. Most cards have a visual; every visual has a one-line instruction.
3. Calm by default: dark neutral surfaces, the module accent for emphasis, other colors only when they carry meaning.
4. Consistency over novelty: build every screen from the component kit. No one-off styling.
5. Motion explains cause and effect (values flowing through a network, weights shifting), never decoration.

### 6.2 Layout and scaling

- Two ScreenGuis per lesson:
  - `LessonBackdrop`: `ScreenInsets = None`, `ClipToDeviceSafeArea = false`. Non-interactive tint/gradient only.
  - `LessonUI`: `ScreenInsets = CoreUISafeInsets`. All interactive content. Don't set `IgnoreGuiInset` on it (that switches it to DeviceSafeInsets).
- Design on a 1280×720 reference stage, centered. `UIScale = min(w / 1280, h / 720, 1.35)` from `LessonUI.AbsoluteSize`, recomputed on resize. Space outside the stage shows the backdrop.
- **Compact mode** (UIScale < 0.75, i.e., phones): the stage fills the whole safe area instead of letterboxing, text is multiplied (~1.5, tune it), and when two columns don't both stay usable, the card switches to a Learn / Explore toggle.
- Tap targets: height ≥ max(48, 44 / UIScale) reference px, so they're at least 44 pt on screen everywhere.
- On every device, body text must land between 14 and 30 px on screen. If it doesn't, adjust the type scale or multipliers, never individual labels.

### 6.3 Color

| Token                            | Hex                               | Use                                 |
| -------------------------------- | --------------------------------- | ----------------------------------- |
| `bg`                             | `#0B1020`                         | backdrop                            |
| `surface`                        | `#121A2E`                         | cards                               |
| `surfaceRaised`                  | `#1A2440`                         | buttons, inputs, popovers           |
| `border`                         | `#2A3658`                         | 1 px strokes                        |
| `text`                           | `#F4F6FB`                         | primary text                        |
| `textMuted`                      | `#A7B1CC`                         | secondary text                      |
| `textFaint`                      | `#7C88A8`                         | captions only, never essential info |
| `success` / `danger` / `warning` | `#3DD68C` / `#FF6B6B` / `#FFC857` | feedback                            |
| `focus`                          | `#FFFFFF`                         | 2 px focus ring                     |

- Module accents: Teal `#2DD4BF`, Violet `#A78BFA`, Amber `#FBBF24`, Pink `#F472B6`, Sky `#38BDF8`. Text on an accent fill uses `bg`.
- Diagram roles, identical in every module and in formulas: input/observation `#60A5FA`, hidden state `#C084FC`, weights/parameters `#FBBF24`, output/prediction `#34D399`, attention/query `#F472B6`. Always pair color with a label or shape.

### 6.4 Typography

- UI text: Builder Sans — `Font.fromName("BuilderSans", Enum.FontWeight.Regular | Medium | Bold | ExtraBold)`.
- Numbers, vectors, matrices: Inconsolata — `Font.fromName("Inconsolata")` — so digits line up.
- Scale (reference px): Display 48 ExtraBold · H1 36 Bold · H2 26 Bold · Body 20 Regular (LineHeight 1.3) · Label 18 Medium · Caption 16 Regular. Nothing below 16.
- Paragraphs: `RichText = true`, `TextWrapped = true`, `AutomaticSize = Y`. Never `TextScaled` for paragraphs.
- Rich text supports `b i u s br font(color/size/weight/family/transparency) stroke mark uc sc`. There are no sub/superscript tags: use Unicode (xᵢ, hₜ, Wᵀ, √dₖ) and check them in a screenshot; if a glyph renders as a box, fall back to `x_i`. Escape `<`, `>`, `&` as `&lt;`, `&gt;`, `&amp;`.
- In formulas, color each variable by its diagram role.
- Probabilities show 2 decimals or a percentage; keep full precision internally.

### 6.5 Spacing, shape, motion

- 4 px grid: 4, 8, 12, 16, 24, 32, 48, 64. Card padding 32; gap between blocks 16–24.
- Radius: 8 (chips, inputs), 12 (buttons), 20 (cards). 1 px `border` strokes via UIStroke.
- Depth comes from surface contrast + stroke. No fake drop shadows unless they render crisply.
- Durations: 120 ms hover/press, 200 ms state change, 320 ms card/screen change, up to 600 ms for explanatory animation. Quart/Quint Out on enter, Quad In on exit. No bounce/elastic except the unlock celebration. Card change = 24 px slide + fade, mirrored for Back.
- Reduced motion: fades only; step-by-step animations become manual Step buttons.

### 6.6 Components

Button (primary / secondary / ghost × default / hover / pressed / focused / disabled), IconButton, Chip, Slider (value label; keyboard and gamepad adjustable), Toggle, SegmentedControl, ProgressBar (segmented), Toast, Tooltip, Modal, Callout (info / warning / "Illustrative"), FormulaBlock, Legend.

Each is built with `UI/Create`, styled only from `Theme`, works with mouse, touch, keyboard and gamepad, and exposes `destroy()`.

Icons: one consistent set, white, tinted with `ImageColor3`, ids in `Assets.luau`. Until they're uploaded, use text glyphs (← → ✓ ✕) as placeholders.

### 6.7 Input and accessibility

- Keyboard: ← / → change cards, Enter activates, 1–4 pick quiz options, X closes.
- Gamepad: LB / RB change cards, A selects, B closes. Set `GuiService.SelectedObject` to the primary button whenever a card opens; every interactive element is `Selectable`.
- Touch: everything reachable with visible buttons; no swipe-only actions.
- Settings (⚙): text size 100 / 115 / 130 %, reduced motion, sound. Saved with progress.
- Body text contrast ≥ 4.5:1. Correct/incorrect always shows an icon and a word, never color alone.
- No free-text input shown to other players. If player-typed text is ever displayed, it must go through TextService filtering.

## 7. Curriculum

### 7.1 How every module teaches

- Arc: hook (a question or puzzle) → intuition with visuals → interactive → light math (in "Go deeper") → link back to the previous module → recap → quiz.
- Card 1 of every module shows the five-module journey with this one highlighted, plus the bridge from the previous module.
- 10–14 cards + 5 quiz questions; ≤ 70 words per card body; ~12–15 minutes per module. One running example per module.
- Voice: friendly, direct, second person, short sentences, concrete before abstract. Never "simply", "just" or "obviously".
- Bold a term the first time it appears and add it to `Glossary.luau`.
- Ground truth: standard definitions from Jurafsky & Martin, _Speech and Language Processing_; Goodfellow, Bengio & Courville, _Deep Learning_; and the papers named below. When a card simplifies, it says so.

### 7.2 Module 1 — Naive Bayes, Logistic Regression, Generative vs Discriminative

Students can:

- describe classification as predicting a label y from features x;
- use Bayes' rule: P(y | x) = P(x | y) · P(y) / P(x);
- explain Naive Bayes' conditional-independence assumption, P(x₁ … xₙ | y) = ∏ P(xᵢ | y), and why it needs smoothing (one unseen word zeroes the whole product);
- read logistic regression as P(y = 1 | x) = σ(w·x + b), with σ(z) = 1 / (1 + e^(−z)), and find its decision boundary where w·x + b = 0;
- contrast **generative** models (learn how data is produced — P(x | y)·P(y), i.e., the joint P(x, y) — and can generate new examples) with **discriminative** models (learn P(y | x), the boundary, directly);
- state the tradeoff: Naive Bayes often does better with little data, logistic regression with more (Ng & Jordan, 2002).

Running example: spam vs not-spam messages over a tiny vocabulary.

Widgets:

- `SpamDetective`: toggle word chips in a message; see the prior, each word's likelihood ratio as a bar, and P(spam | words) update live. Includes a word never seen in training to show the zero-probability problem, with an add-one smoothing toggle.
- `SigmoidLab`: 1-D data (hours studied → passed?); sliders for w and b; draws σ(wx + b), the 0.5 threshold and the live log-loss. Step runs one gradient-descent update; Auto runs to convergence.
- `TwoWaysToClassify`: one 2-D dataset shown two ways — generative (a blob per class, plus "Generate an example", which samples a new point) vs discriminative (only the boundary line, nothing to generate from).

Address: logistic regression is a classifier despite its name; "naive" names an assumption, not a weakness; Naive Bayes is often overconfident when features are correlated; neither family always wins.

Quiz: which model learns P(x | y); what "naive" assumes; what σ(w·x + b) = 0.5 means; why smoothing; which family can generate new samples.

### 7.3 Module 2 — Hidden Markov Models

Bridge: Naive Bayes treats a message as an unordered bag of words, but speech, text and weather come in sequences.

Students can:

- explain a Markov chain: the next state depends only on the current one; each row of the transition matrix sums to 1;
- name an HMM's parts: hidden states, observations, initial probabilities π, transitions A, emissions B;
- see that an HMM is generative: P(s, o) = π(s₁)·B(s₁, o₁)·∏ A(sₜ₋₁, sₜ)·B(sₜ, oₜ), with the product over t = 2 … T;
- match the three classic problems to their algorithms: likelihood → Forward; most likely hidden sequence → Viterbi; learning the parameters → Baum–Welch (EM);
- name historical uses (speech recognition, part-of-speech tagging, gene finding) and limits (a small, fixed set of discrete states; short memory).

Running example, adapted from Jason Eisner's ice-cream example in Jurafsky & Martin: hidden weather Hot/Cold; observed ice creams eaten per day (1, 2 or 3). Suggested parameters: π(Hot) = 0.8, π(Cold) = 0.2; A: Hot→Hot 0.6, Hot→Cold 0.4, Cold→Hot 0.5, Cold→Cold 0.5; B: Hot emits 1/2/3 with 0.2/0.4/0.4, Cold with 0.5/0.4/0.1. Observation sequence: 3, 1, 3.

Widgets:

- `WeatherMachine`: animated Markov chain (state bubbles, arrows labeled with probabilities). "Sample a week" generates states and observations; "Hide the weather" shows only what an observer sees.
- `ViterbiTrellis`: 2 states × T days. Students guess the hidden sequence first; then Step / Back fills each cell with its best-path probability and back-pointer (from `Math/Viterbi`), and the last step traces the best path.
- `ForwardVsViterbi` (optional): same trellis; toggle "sum over all paths" (Forward) vs "best single path" (Viterbi).

Address: "hidden" means unobserved, not random; Viterbi returns the single most likely sequence, which can differ from picking each day's individually most likely state.

Quiz: the Markov assumption; what's hidden vs observed; which algorithm finds the most likely state sequence; generative or discriminative; the size of A for N states (N × N).

### 7.4 Module 3 — RNNs and LSTMs

Bridge: an HMM remembers one discrete state out of a few. An RNN carries a learned vector of numbers instead.

Students can:

- read the recurrence hₜ = tanh(Wₕ·hₜ₋₁ + Wₓ·xₜ + b), see that the same weights are reused at every step, and that the output yₜ is computed from hₜ;
- picture unrolling through time and training with backpropagation through time (BPTT);
- explain vanishing/exploding gradients: going back in time, the gradient is multiplied by similar factors at each step, so it shrinks or blows up exponentially with distance. Fixes: gradient clipping (exploding) and gated cells (vanishing);
- explain the LSTM (Hochreiter & Schmidhuber, 1997; forget gate added by Gers et al., 2000): the cell state cₜ is a protected memory lane; sigmoid gates in [0, 1] — forget fₜ, input iₜ, output oₜ; candidate gₜ = tanh(…); cₜ = fₜ ⊙ cₜ₋₁ + iₜ ⊙ gₜ; hₜ = oₜ ⊙ tanh(cₜ). The mostly additive update lets gradients survive longer spans;
- recognize the GRU as a simpler gated cousin (Cho et al., 2014), one card at most;
- see the seq2seq encoder–decoder (Sutskever et al., 2014), which sets up Module 4.

Running example: "The cats that the dog chased were hungry." The verb must agree with "cats", several words back, past the singular "dog".

Widgets:

- `UnrollTheLoop`: an RNN cell with a self-loop; "Unroll" animates it into a chain over the sentence, passing the hidden state along as a small colored bar vector. Tap a step to inspect it.
- `GradientTelephone`: a 20-step chain; a slider sets the per-step factor (0.5–1.5); bars show how much gradient reaches each earlier step (∝ factorᵏ, simplified scalar case, labeled as such), plus a clipping toggle.
- `LSTMGates`: the cell diagram with sliders for the three gates and the candidate; the cell state updates by the real equations. Challenge: keep the "plural" signal from "cats" alive until "were".

Address: an RNN is one network reused at every step, not a new network per word; LSTMs make long-range learning easier, not free; the "memory" is numbers, not stored words.

Quiz: what's shared across time steps; why gradients vanish; the forget gate's job; what cₜ is; what BPTT does.

### 7.5 Module 4 — Attention

Bridge: a seq2seq encoder squeezes the whole input sentence into one fixed-size vector, a bottleneck that hurts on long sentences.

Students can:

- explain that attention lets the decoder look back at every encoder state at each output step (Bahdanau, Cho & Bengio, 2014; Luong et al., 2015);
- walk through the mechanics: score each encoder state against the current decoder state → softmax the scores into weights (non-negative, summing to 1) → context vector = weighted sum of encoder states;
- use the query / key / value framing: the query is what I'm looking for, keys are what each item can be matched on, values are what each item hands back; dot products as scores;
- read attention weights as a soft alignment (translation heatmaps), with the caveat that weights are a helpful but imperfect explanation of model behavior.

Running example: English → French, "the European Economic Area" → "la zone économique européenne" (the word order flips, as in Bahdanau et al.'s alignment figure).

Widgets:

- `Bottleneck`: a long sentence squeezed into one small vector, vs attention lines reaching back to every word. Illustrative.
- `ScoreSoftmaxBlend`: pick a query; see dot-product scores as bars → softmax weights (with a sharpness/temperature slider) → the weighted sum of value vectors. All numbers computed with `Math/Linear` and `Math/Prob`.
- `AlignmentHeatmap`: translation grid; hover or tap a French word to light up the English words it attends to. Illustrative weights.

Address: one query's weights always sum to 1; attention was first added _to_ RNNs, before Transformers dropped recurrence; attention weights aren't the model "understanding".

Quiz: the problem attention solves; what softmax guarantees; what the context vector is; the roles of Q, K and V; why the heatmap's diagonal bends.

### 7.6 Module 5 — Transformers

Bridge: if attention can connect any two positions directly, do we still need recurrence? "Attention Is All You Need" (Vaswani et al., 2017) says no.

Students can:

- explain self-attention: every token makes its own query, key and value (learned matrices W_Q, W_K, W_V) and attends to every token, all in parallel;
- read scaled dot-product attention, softmax(QKᵀ / √dₖ)·V, and why we divide by √dₖ (it keeps scores from growing with the dimension and saturating the softmax);
- describe multi-head attention: several heads attend in parallel, each free to pick up a different relationship; their outputs are concatenated and projected;
- explain positional encoding: attention alone ignores word order, so position information is added (sinusoids in the original paper; learned or rotary in many later models);
- assemble the block: self-attention → add & norm → position-wise feed-forward → add & norm (residual connections + layer normalization), stacked N times;
- distinguish encoder vs decoder: decoders use a causal mask so a token can't see the future; the original model was an encoder–decoder for translation with cross-attention; BERT-style models are encoders, GPT-style models are decoders;
- say why Transformers won (parallel training, short paths between distant tokens) and their main cost (attention grows quadratically with sequence length);
- close the loop: most modern large language models are decoder-only Transformers pretrained to predict the next token, P(next token | previous tokens) — a generative model (Module 1) of sequences (Module 2).

Running example: "The animal didn't cross the street because it was too tired." vs "…because it was too wide." What does "it" refer to?

Widgets:

- `WhoIsIt`: tap any token to see its attention lines and weights; switch "tired" / "wide" and watch "it" shift between "animal" and "street". Illustrative weights.
- `QKVCalculator`: 3–4 tokens with tiny vectors; steps through QKᵀ, ÷ √dₖ, softmax and × V with real computed numbers; sliders edit one query vector.
- `CausalMask`: a who-can-see-whom grid; toggle the mask; shows why decoders generate one token at a time.
- `BuildTheBlock`: a stepper that assembles the Transformer block piece by piece, one line of explanation per piece, ending with "stack × N".
- `NextToken` (optional): a toy next-token distribution with a temperature slider and sampling. Illustrative.

Address: Transformers aren't RNNs; word-order information isn't free; nobody assigns heads their roles by hand; "Transformer" is an architecture, not a chatbot.

Quiz: why √dₖ; why positional encodings; what the causal mask prevents; one advantage over RNNs; what multi-head adds.

### 7.7 Graduation recap

One line per module, ending: Bayes → HMMs → RNNs/LSTMs → Attention → Transformers → today's language models.

## 8. Code conventions

- `--!strict` at the top of every file; type every public function; shared types live in `Types.luau`.
- Services via `game:GetService`. On the client, `WaitForChild` for replicated folders at startup.
- Modules return a table. No globals, `_G` or `shared`.
- Every controller, card and widget exposes `destroy()`; closing a lesson disconnects everything (`UI/Cleanup`).
- Reuse instances; never create instances every frame; prefer TweenService over RenderStepped loops.
- `Math/` stays pure (no instances) so it can be checked with `execute_luau`. Check new math against a hand-worked example before wiring it into a widget.
- PascalCase for modules and components, camelCase for functions and locals, UPPER_SNAKE for constants.
- If StyLua or selene are installed, run them. Don't add tools without asking.

## 9. Milestones (in order)

0. **Scaffold:** Config, Types, Theme, Create/Cleanup/Scale, Remotes, ProgressService with in-memory fallback, debug hooks. Done when a playtest is error-free and progress saves and reloads.
1. **Atrium and portals:** build the hub and five portals (via `execute_luau` in Edit mode, tagged `Portal`); PortalController with all three states, entry detection and locked feedback. The human saves the place.
2. **Lesson shell:** both ScreenGuis, scaling and compact mode, top and bottom bars, transitions, every card renderer, quiz flow, settings, keyboard/gamepad/touch. Test with a placeholder module.
3. **Module 1** · 4. **Module 2** · 5. **Module 3** · 6. **Module 4** · 7. **Module 5** — content, widgets and quiz, one module per milestone.
4. **Polish:** journey tracker, first-visit cards, graduation, sound, a full device QA pass and a performance pass.

## 10. Definition of done

- No errors or warnings from our code in the output.
- Screenshots checked at desktop, tablet and phone sizes: nothing clipped, overlapping or off-grid.
- Works with mouse, touch, keyboard and gamepad.
- Respects reduced motion and text size.
- Progress survives leaving and rejoining.
- Content checked against §7; illustrative numbers are labeled.
- Committed.
