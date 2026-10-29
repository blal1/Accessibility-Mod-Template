# 02 Reconnaissance

How to find out what the game really does before writing code. Two layers:

1. **Project baseline (Phase 1, Tier 1)**: done once, before the core is created. Structure, input, UI system, focus model, language system. Without it nothing can be built safely.
2. **The slice workflow (G0 to G7)**: done for EVERY feature. One small player goal at a time, evidence graded by strength, an explicit readiness verdict before implementation. This is the way every feature starts.

Tools: the decompiled code in `decompiled/` (made with `scripts/Decompile-Game.ps1`, see `docs/01-setup-and-tooling.md`), the `uar` validator in `recon/`, and the running game with the mod's debug mode.

## Never guess, always verify

**Before writing a component, using a game mechanic or naming a UI element, search the decompiled source in `decompiled/`.** Guessed class names, method names or mechanics always lead to bugs.

Why this matters:

- Games use unexpected names (`CardZone` instead of `Hand`, `UIManager` instead of `GameUI`).
- Internal mechanics rarely work the way they look from outside.
- Wrong assumptions produce code that compiles but does nothing, which is hard to debug.
- Reflection on a field that does not exist fails silently (the template's ReflectionHelper and Compat at least report it).

What to check BEFORE every implementation:

- For a new screen or popup: the exact class name; its open, show, close and hide methods; its parent and child structure; events and callbacks it fires.
- For a game mechanic: the relevant classes (`InventoryManager`, `PlayerInventory`, `ItemStorage`?); public properties and fields; singleton instances and how to reach them; the methods that change state.
- For UI elements: exact component types (Text, TextMeshProUGUI, Button, ...), field names, nesting.
- For keys: how the game reads input (legacy Input, Input System, its own layer); which keys are taken; whether there are input blockers or a focus system.

Typical search patterns:

```
UI screens:
- "class.*Menu" or "class.*Screen" or "class.*Panel"
- "public static.*Instance" (singletons)
- "void Show" or "void Open" or "void Display"

Game mechanics:
- "class.*Manager" or "class.*Controller"
- "public.*List<" or "public.*Dictionary<" (collections)
- "static.*Current" or "static.*Active" (active state)

Specific features:
- the English word for the mechanic
- a text that is visible in the game (it leads to the localization id, and the id leads to the code)
- variable names that seem logical
```

Checklist before writing code:

- [ ] Relevant classes found in `decompiled/`
- [ ] Exact names noted (case-sensitive!)
- [ ] Access path understood (singleton, FindObjectOfType, reference from a hook's `__instance`)
- [ ] Public API of the class known (methods, properties)
- [ ] Findings written to `docs/game-api.md`

Wrong versus right:

```csharp
// WRONG (guessing): "the inventory is surely called InventoryPanel..."
var inventory = GameObject.Find("InventoryPanel");
// Does nothing: the real name is UI_Inventory_Main
```

```
RIGHT (researching):
1. Grep decompiled/ for "Inventory"
2. Found: class UI_Inventory_Main : MonoBehaviour
3. Its Show() and Hide() methods are the hook targets
4. Code: [HarmonyPatch(typeof(UI_Inventory_Main), "Show")]
```

Research again:

- for EVERY new screen and every new mechanic,
- whenever code unexpectedly does nothing,
- whenever reflection or a hook is reported missing,
- after game updates (names change; `git -C decompiled diff` shows exactly which).

## Project baseline (Phase 1)

**PREREQUISITE: the decompiled source MUST be in `decompiled/`.** Phase 1 works exclusively with the decompiled code, not with internet research, wikis or guesses. If `decompiled/` is empty, go back to Step 7 of `docs/01-setup-and-tooling.md`. All grep commands below target `decompiled/`.

Don't do everything at once:

- **Tier 1 (essential, before ANY code):** 1.1 to 1.5: structure, input, UI, focus model mapping, localization system.
- **Tier 2 (just in time, inside the slice of the feature that needs it):** 1.6 to 1.8: mechanics, status, events. Analyze the inventory right before building AccessibleInventory, not months ahead.
- **Tier 3 (when relevant):** 1.9 and 1.10: documentation, tutorial.

### 1.1 Structure overview (Tier 1)

Namespace inventory:

```
Grep pattern: ^namespace\s+
```

Categorize into UI/Menus, Gameplay, Audio, Input, Save/Load, Network, Other.

Singletons (the main access points into the game):

```
Grep pattern: static.*instance
Grep pattern: \.instance\.
Grep pattern: static.*Get\(\)
```

List each with class name, what it manages, important properties.

### 1.2 Input system (Tier 1, CRITICAL)

All key bindings:

```
Grep pattern: KeyCode\.
Grep pattern: Input\.GetKey
Grep pattern: Input\.GetKeyDown
Grep pattern: Input\.GetKeyUp
Grep pattern: Keyboard\.current
Grep pattern: InputAction
```

For EVERY hit: file and line, key, what happens, in which context.

Mouse input:

```
Grep pattern: Input\.GetMouseButton
Grep pattern: OnClick
Grep pattern: OnPointerClick
Grep pattern: OnPointerEnter
```

Input controllers:

```
Grep pattern: class.*Input.*Controller
Grep pattern: class.*InputManager
```

Also note WHICH input backend the game uses: legacy `UnityEngine.Input`, the Input System package (`Keyboard.current`, `InputAction`), or both. AccessibleKey must read the same backend (`docs/appendix-a-unity-loaders-harmony.md`, "Input System vs legacy Input").

Result: the list of keys the game does NOT use = safe mod keys.

**MANDATORY OUTPUT, now, not later:**

1. Write ALL game key bindings to `docs/game-api.md`, section "Game Key Bindings".
2. Write the safe mod keys to `docs/game-api.md`, section "Safe Mod Keys".
3. Check off the input items in `project_status.md`.

Do not continue to 1.3 until both sections exist. Key conflicts are the most common mod bug, and this is the step most often skipped.

### 1.3 UI system (Tier 1, CRITICAL)

UI systems are the heart of an accessibility mod. How the game builds and opens its screens decides where every hook goes.

UI base classes:

```
Grep pattern: class.*Form.*:
Grep pattern: class.*Panel.*:
Grep pattern: class.*Window.*:
Grep pattern: class.*Dialog.*:
Grep pattern: class.*Popup.*:
Grep pattern: class.*Menu.*:
Grep pattern: class.*Screen.*:
Grep pattern: class.*Canvas.*:
```

Find out: a common base class? How are windows opened and closed (one central manager with a stack, or each panel by itself)? Is there a "current screen" or "scene mode"?

Text display:

```
Grep pattern: \.text\s*=
Grep pattern: SetText\(
Grep pattern: TextMeshPro
```

Tooltips:

```
Grep pattern: Tooltip
Grep pattern: hover
Grep pattern: description
```

Private serialized fields (very common in Unity):

```csharp
[SerializeField]
private TextMeshProUGUI title;
```

The text is then not reachable through public properties. Search:

```
Grep pattern: \[SerializeField\]
Grep pattern: private.*Text
Grep pattern: private.*TMP
Grep pattern: private.*Button
```

Many hits mean ReflectionHelper will be used a lot (`docs/appendix-b-unity-reflection.md`).

Document in `docs/game-api.md`:

- UI base classes and their hierarchy, with the text access path for each.
- Which fields are private, and the naming convention (`m_PascalCase` or `camelCase`).
- Example snippets for common access patterns.

After this step you know:

1. how to get the text of any UI element (property, method or private field),
2. how selection and focus work in the game (focus system? highlight events?),
3. which methods open and close screens and popups (the future hook targets).

### 1.4 Focus model mapping (Tier 1)

This replaces the old "state manager decision". With the HSA architecture there is nothing to decide about coordination: AccessibilityMgr gives keys and voice to exactly one component (see `docs/03-architecture.md`, "The focus model"). What you decide here is how the game's surfaces map onto it:

- **Base screens** (one at a time): title, main menu, hub, world, battle, collection. Each becomes an `AccessibleScreen`. Which game method or event marks the change of base screen? (scene load, a scene manager's mode change, a screen controller's Show)
- **Overlays** (stacked over a screen): popups, confirmation dialogs, reward screens, settings, sub-menus. Each becomes an `AccessibleUI`. Which methods open and close them? Can several be open at once? Can one close while another covers it?
- **Notifications**: things that happen wherever the player is (toasts, opponent actions, timers). They become `AccessibilityMgr.OutputNotification(...)` from a hook.
- **Text fields**: where the player types (names, search, chat). Their components call `AllowTextInput()` / `DisallowTextInput()`.
- **Surfaces with no open or close method** (detected only by state): candidates for an `[AccessibilityPoller]`. Note them; prefer any hookable method.

Write the result to `project_status.md`, "Architecture Decisions": the list of screens and UIs you expect, with their open and close methods. It is a first draft; each slice refines it.

### 1.5 Localization system (Tier 1)

The mod speaks the game's language from day one (`docs/03-architecture.md`, "Localization"). Even a mod that ships only English needs the game's language detection, so translations can be added later without touching code, and the game's own string lookup, so the mod can reuse official names.

```
Grep pattern: Locali
Grep pattern: Language
Grep pattern: Translate
Grep pattern: GetString
Grep pattern: currentLanguage
Grep pattern: getAlias
Grep pattern: SystemLanguage
```

Find:

- How the game stores and detects its current language (a singleton or static property such as `LocalizationManager.CurrentLanguage`, an options value, PlayerPrefs).
- The format of language codes ("en", "de-DE", "English", an enum) and how to turn it into a tag like "en" or "de".
- The game's own string lookup (`Localization.Get(id)`, `I2.Loc`, a table asset) and what it returns for an unknown id (often the id itself or a marker).
- Where the game's translation files are.

Document in `docs/game-api.md`, section "Localization". These answers fill `LocalizationUtils.GetGameLanguageTag()` and `LocalizationUtils.GetGame()` in Phase 2. Other engines: `docs/appendix-d-other-engines.md`.

### Tier 1 completion gate

**STOP. Before the core (Phase 2) and before the first slice, ALL of these must be done:**

1. `docs/game-api.md` has a complete "Game Key Bindings" section.
2. `docs/game-api.md` has a "Safe Mod Keys" section.
3. `docs/game-api.md` documents the UI base classes and text access patterns.
4. `docs/game-api.md` documents the game's language detection and string lookup.
5. `project_status.md` has all Tier 1 checkboxes checked and "Game Key Bindings (Original)" filled in.
6. `project_status.md` "Architecture Decisions" lists the expected screens and UIs with their open and close methods (1.4).
7. The build fingerprint exists (`recon-records/build-fingerprint.json`, gate G1 below): every later piece of evidence names this build.

If any is missing, do it now. Every key-conflict bug ever reported could have been prevented by this gate.

### 1.6 Game mechanics (Tier 2, per slice)

Player:

```
Grep pattern: class.*Player
Grep pattern: class.*Character
Grep pattern: class.*Controller.*:.*MonoBehaviour
```

Inventory:

```
Grep pattern: class.*Inventory
Grep pattern: class.*Item
Grep pattern: class.*Slot
```

Interaction:

```
Grep pattern: Interact
Grep pattern: OnUse
Grep pattern: IInteractable
```

Other systems, depending on the game:

- Quest: `class.*Quest`, `class.*Mission`
- Dialogue: `class.*Dialog`, `class.*Conversation`, `class.*NPC`
- Combat: `class.*Combat`, `class.*Attack`, `class.*Health`
- Crafting: `class.*Craft`, `class.*Recipe`
- Resources: `class.*Currency`, `Gold`, `Coins`

### 1.7 Status and feedback (Tier 2, per slice)

```
Grep pattern: Health
Grep pattern: Stamina
Grep pattern: Mana
Grep pattern: Energy
```

Notifications:

```
Grep pattern: Notification
Grep pattern: Message
Grep pattern: Toast
Grep pattern: Popup
```

### 1.8 Events and hook points (Tier 2, per slice)

Events:

```
Grep pattern: delegate\s+
Grep pattern: event\s+
Grep pattern: Action<
Grep pattern: UnityEvent
Grep pattern: \.Invoke\(
```

Good hook targets:

```
Grep pattern: OnOpen
Grep pattern: OnClose
Grep pattern: OnShow
Grep pattern: OnHide
Grep pattern: OnSelect
Grep pattern: OnEnable
Grep pattern: OnDisable
```

Prefer a method that runs exactly once per open or close and receives the instance. `OnEnable`/`OnDisable` of the panel's own MonoBehaviour are reliable fallbacks. Avoid per-frame methods (`Update`) as hook targets.

### 1.9 Document results (ongoing)

`docs/game-api.md` should contain:

1. Overview: game description, engine version, backend (Mono or IL2CPP), game version.
2. Singleton access points.
3. Game key bindings (ALL).
4. Safe mod keys.
5. UI system, in detail: base classes and hierarchy, text access per class, naming convention, example snippets, which classes need ReflectionHelper.
6. Localization: language detection, string lookup.
7. Game mechanics, status systems.
8. Hook targets per screen (method, what `__instance` is, when it fires).

Every screen will need to read UI text. Documented once, the access pattern is reused everywhere.

### 1.10 Tutorial (Tier 3, when planning it)

Why the tutorial matters:

- It explains mechanics step by step: exactly what must become accessible.
- It often has a simpler structure: a good early slice.
- If the tutorial is accessible, blind players can learn the game at all.
- Its code shows which UI elements and interactions exist.
- Tutorials often restrict which actions are allowed; HSA mirrors this with a key whitelist and an overridden F1 text (`docs/03-architecture.md`, "Forced keys and tutorials").

Search in the code:

```
Grep pattern: Tutorial
Grep pattern: class.*Tutorial
Grep pattern: FirstTime
Grep pattern: Introduction
Grep pattern: HowToPlay
Grep pattern: Onboarding
```

Search the game directory for files with "tutorial", "intro", "howto" in the name (often separate scenes or levels).

Questions:

1. Is there a tutorial, and how does it start?
2. Which mechanics does it introduce?
3. How are instructions shown (text, popups, voice)?
4. Which interactive elements must become accessible?
5. Can it be skipped?

Result: tutorial start method in `docs/game-api.md`; the tutorial on the feature plan (usually high priority).

## Feature plan (Phase 1.5)

The feature plan is a list of slices: small player goals, in the order a player meets them. Each slice later goes through the workflow below.

For the most important slices, document in detail:

```
Slice: Main menu
- Player goal: reach "Play" and "Options" from the title screen and start a match
- Surfaces in scope: title screen (AccessibleScreen), options popup (AccessibleUI)
- Out of scope: news panel, store (reason: not needed to start playing)
- Expected hooks: MainMenu.Show / MainMenu.Hide (to verify in G3)
- Keys: arrows, Enter (common keys), nothing new
- Dependencies: core created (Phase 2)
- Known challenge: buttons have no common text property
```

For less important ones, roughly:

```
Slice: Achievement announcements
- Brief: read achievement popups as notifications
- Complexity: simple
- Depends on: the notification hook of the toast system
```

Ask the user which slice to start with. Guiding principle: what a player meets first comes first, so testing starts early and the game is playable from the beginning. Typical order (adapt):

1. Startup popups and title or main menu (first contact).
2. Settings, if reachable from the main menu.
3. Basic status announcements (health, resources).
4. Tutorial or starting area.
5. Core gameplay (the most frequent actions).
6. Inventory and in-game menus.
7. Special features (crafting, trading, dialogue).
8. Optional features (achievements, statistics).

Some games start directly in gameplay, some force the tutorial first; status announcements can run in parallel. The plan will change; that is expected.

## The slice workflow (G0 to G7)

This is the start of EVERY feature. It comes from unity-accessibility-recon (`recon/`, MIT) and keeps three promises:

- Only the dependencies of the current player goal are investigated: no whole-game census before useful work.
- Every claim says how strong its evidence is. File evidence is never reported as "works in game".
- The slice gets an explicit verdict before implementation, and the verdict covers only that slice.

The full procedure, with all record fields: `recon/skills/unity-accessibility-reconnaissance-en/SKILL.md` and its references. What follows is how this template uses it.

### Roles

- **Claude (the agent)** collects the minimum files, investigates, keeps the records, runs `uar`, fixes clear local problems, writes the code.
- **The user** chooses the player goal and scope, approves scope changes and anything sensitive (launching the game, installing a loader, saves, accounts), and does the final acceptance with a real screen reader and keyboard.
- The blind user is never asked to visually enumerate screens, read screenshots, guess the Unity hierarchy, or manage the records.

### Where the records live

- `recon-records/` at the project root (create it with the first slice). It is git-ignored by default: records can contain proprietary names, paths and hashes. Keep it private like `decompiled/`.
- Start each record from `recon/shared/templates/` (blank CSV, JSON and YAML files).
- Contracts (JSON Schema) are in `recon/shared/contracts/`. Phase ids, grades, gates and verdicts: `recon/shared/phase-ids.yaml`.

### The gates

**G0 Authorization.** Once per project, extended when needed. Record: the product and where it was bought, that the user owns it, allowed read-only folders (game folder, `decompiled/`), excluded sensitive data (saves, profiles, account data, logs with personal data), and which actions need a separate yes (launching the game, installing the loader, injecting input, touching saves, pushing, publishing). Reversible read-only steps inside scope need no new question.

**G1 Build fingerprint.** Once per game version. Product version, engine version, Mono or IL2CPP, architecture, loader candidate, hashes and sizes of key files (the game's main assemblies), source manifest digest. Make it before extracting. The version is the same name as the `decompiled/` branch (`scripts/Decompile-Game.ps1 -Version`). Evidence from two builds is never mixed: after a game update, a new fingerprint, and an explicit decision which old evidence still holds (the `git diff` between the two decompiled branches answers that).

**G2 Extraction coverage.** Which source families the slice needs (assemblies, localization tables, input assets, scenes and prefabs, ...) and how each was extracted: `extracted`, `partial`, `excluded-with-reason`, `unsupported`, `failed`, `not-present`. A failure in a family the slice does not need does not block it. `DUMP-PARTIAL` is an honest result if each gap has an owner and a re-open trigger. For most slices the decompiled assemblies plus the game's localization files are enough.

**G3 Static UI discovery.** The static UI ledger: the classes, fields, buttons, texts, localization ids, callbacks and input actions that touch this slice, each with its source evidence. Include inactive templates, pooled objects and dynamically created entries, labelled as discovery evidence (existing in code does not mean visible or usable). Every in-scope candidate ends as a semantic candidate, an explicit exclusion, or a gap.

**G4 Surface lifecycle matrix.** One row per surface in scope (`recon/shared/templates/surface-lifecycle-matrix.csv`): entry and exit predicates, owner candidates, modal depth, required and optional controls, initial focus, child transitions, how the parent is restored, input owner, interaction model, privacy class, conditional dependencies. Unrelated surfaces go on a short out-of-scope list with a reason.

**G5 Runtime coverage.** Separate permission: the game runs. With debug mode on (F12), observe the real owner of each surface and its live controls, speech-free first. Watch for surface generations (a popup that is destroyed and recreated), inactive parents behind modals, and focus restoration when a child closes. Advance each surface through the coverage gates below.

**G6 Native input and postconditions.** For each action of the slice: precondition, physical key, the game-owned path it takes (the button's onClick, the game's method), and the resulting game state, observed exactly once. A callable method is not proof that the player can trigger it; an announcement of the intended action is not proof that it happened. Only when the native path is absent or unusable, add a surface-scoped fallback.

**G7 Slice readiness.** The readiness record (`first-slice-readiness.yaml`, also used for every later slice) names the player goal, surfaces in and out of scope, claims, gaps, the runtime probe and which claims it challenges, Code QA status and the authorization boundary, and declares one verdict.

### Claim grades (how strong is a finding)

From weakest to strongest; never promote without new evidence:

1. `SOURCE-IDENTIFIED`: exact source and build identity recorded.
2. `STATIC-CONFIRMED`: the code, asset, localization id, callback or binding exists in the extracted build.
3. `RUNTIME-OBSERVED`: the owner, state or transition was seen in the running game (says nothing yet about the keyboard).
4. `PHYSICAL-INPUT-PROVEN`: a real key went through the intended game-owned path.
5. `POSTCONDITION-PROVEN`: the intended game state changed exactly once.
6. `SPEECH-DISPATCH-PROVEN`: the screen reader bridge accepted the exact text (not proof that anyone heard it).
7. `NVDA-MANUAL-CONFIRMED`: the user heard it and accepted the speech and keyboard path.

And `OPEN / DYNAMIC-UNVERIFIED`: evidence missing, conditional, parser-limited, or from another build.

Every claim the slice depends on that is only `SOURCE-IDENTIFIED`, `STATIC-CONFIRMED` or `OPEN` needs a small runtime challenge test: one live check that would show the assumption is wrong.

### Coverage gates (how far is a surface)

Each in-scope surface advances through, in order:

1. `STATIC-MAPPED`
2. `RUNTIME-OWNER-OBSERVED`
3. `ACTIVE-CONTROLS-INVENTORIED`
4. `SEMANTIC-MODELED`
5. `NATIVE-FOCUS-PROVEN`
6. `NATIVE-ACTION-POSTCONDITION-PROVEN`
7. `NVDA-MANUAL-CONFIRMED`
8. `COVERAGE-CLOSED`: every currently meaningful control has a spoken entry, an explicit exclusion, or a reproducible gap.

Claim grades and coverage gates are two separate scales. Do not convert one into the other.

### Verdicts

Each applies only to the named slice:

- `READY FOR RUNTIME PROBE`: the records agree and the next falsification test is defined. Offline findings are not runtime truth yet. Next: run the probe (usually: build a minimal component with hooks that only log in debug mode, start the game, open the surface).
- `READY FOR SLICE IMPLEMENTATION`: a recorded runtime probe passed, every challenged claim is `RUNTIME-OBSERVED` or stronger, and each shares evidence with that probe. Next: `docs/04-building-screens.md`.
- `BLOCKED FOR THIS SLICE`: mixed builds, a preservation failure, a failed probe, an applicable blocker, or inconsistent records. Next: the smallest evidence named in the gap ledger, or a smaller slice.

### Running the validator

From `recon/` (installed with `uv sync --dev`, see `docs/01-setup-and-tooling.md`):

```powershell
cd recon
uv run uar validate-foundation --build ..\recon-records\build-fingerprint.json --source ..\recon-records\source-manifest.json --coverage ..\recon-records\extraction-coverage.json
uv run uar validate-ledgers --build-id BUILD-ID --static-ui ..\recon-records\static-ui-ledger.json --lifecycle ..\recon-records\surface-lifecycle-matrix.csv --runtime-coverage ..\recon-records\static-to-runtime-coverage.csv --gaps ..\recon-records\gap-ledger.csv
uv run uar assess-readiness --build ..\recon-records\build-fingerprint.json --source ..\recon-records\source-manifest.json --coverage ..\recon-records\extraction-coverage.json --readiness ..\recon-records\slices\main-menu.yaml --static-ui ..\recon-records\static-ui-ledger.json --lifecycle ..\recon-records\surface-lifecycle-matrix.csv --runtime-coverage ..\recon-records\static-to-runtime-coverage.csv --gaps ..\recon-records\gap-ledger.csv
```

Without `--json`, `assess-readiness` prints the player goal, offline findings, runtime findings, unknowns, limits and the next test: give that plain-language summary to the user. It exits non-zero only for `BLOCKED FOR THIS SLICE`.

**The validator is consistency-only.** `VALIDATION_PASS` means the records agree with each other, never that the game behaves that way. Never report it as "works".

Other commands: `uv run uar check-parity --root .` (the English and Korean skills match; maintenance of `recon/` only), `uv run uar export-skills --destination <folder> --language en` (copy the skill into another agent environment).

### The phase report to the user

At each gate, short and screen-reader friendly:

1. The player goal and the exact slice boundary.
2. Findings from files, findings from the running game, assumptions, unknowns: as separate groups.
3. The next test and what a failure would mean.
4. Checks run, described as consistency checks.
5. What was fixed automatically.
6. Only the smallest decision the user really has to make.
7. What was NOT done (game not launched, nothing pushed, ...).

## From records to code

The records are not paperwork beside the code; each row becomes a specific piece of it (details in `docs/03-architecture.md` and `docs/04-building-screens.md`):

- **One surface lifecycle row = one component**: `Accessible<Name>` in `Accessibility/Screens/<Area>/`, from `templates/shared/AccessibleFEATURENAME.cs.template`.
- **modalDepth**: 0 (base screen) = `AccessibleScreen`; 1 or more (over something) = `AccessibleUI`.
- **entryPredicate / exitPredicate**: the methods the open and close hooks patch. Entry calls `SetScreen` or `ShowUI`; exit calls `ClearScreen` or `HideUI`.
- **runtimeOwner**: the class in `typeof(...)` of the hook, and the instance (`__instance`) the component keeps a reference to.
- **initialFocus**: what `OnGainedFocus()` announces and selects first.
- **requiredControls / optionalControls**: the options of the AccessibleMenu or the items of the AccessibleListOfItems; each label from the game's own text where the static ledger found one.
- **childTransitions / parentRestore**: which UIs this surface opens (each its own component) and that closing them returns focus here (AccessibilityMgr re-announces the screen automatically).
- **inputOwner, interactionModel**: whether the common menu keys suffice or the surface needs its own AccessibleKey entries (declared in `AccessibleKey.<Feature>.cs`, only from "Safe Mod Keys").
- **Runtime probe target**: the exact hook target. A probe that observed `Shop.Open` firing with the shop instance is what makes `[HarmonyPatch(typeof(Shop), "Open")]` safe to write.
- **Native input matrix**: each action's game-owned path is what the menu option invokes (`button.onClick.Invoke()`, `shop.Buy(item)`), never a re-implementation.
- **privacyClass**: sensitive fields (account names, friend codes) are not logged in debug mode.
- **Gap ledger**: open gaps become entries in `docs/game-api.md` or `project_status.md` "Known Issues"; a gap about a member that may vanish in updates becomes a Compat check (the hook or the ReflectionHelper call reports it if missing).
- **Coverage gate `NVDA-MANUAL-CONFIRMED`**: the "Pending Tests" entry in `project_status.md` the user confirms.

## Engine-neutral minimum

The recon contracts are Unity-flavoured (`unityVersion`, `scriptingBackend` is required and limited to Mono or IL2CPP). For Godot, Unreal, a custom engine or a non-Unity .NET game, use the workflow without the validator, keeping this minimum in `recon-records/` as plain Markdown or CSV:

- **G0**: the same authorization record.
- **G1**: product version, engine and version, scripting runtime (C#, GDScript, C++, Lua...), architecture, mod or injection method, hashes of the main executable and code files. Same rule: never mix builds.
- **G2**: what was extracted (decompiled assemblies, unpacked PCK or PAK, script dumps) and what failed.
- **G3 and G4**: the surface lifecycle matrix with the same columns (they are engine-neutral; leave Unity-only columns empty).
- **G5 and G6**: observed owner, controls, native action path, postcondition, per surface.
- **G7**: the same three verdicts, decided by the same rules; grades and gates as above.

How the architecture maps onto other engines: `docs/appendix-d-other-engines.md`.
