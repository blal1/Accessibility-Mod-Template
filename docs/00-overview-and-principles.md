# 00 Overview and Principles

This template is a reference guide for making any game playable with a screen reader the way Hearthstone Access (HSA) does it: a small, strict core (one focused component, declared keys, localized speech, guarded hooks) and one accessible class per game screen, built slice by slice from verified evidence.

It is written for a blind developer working with Claude Code, and for Claude Code itself. Every guide uses headings and lists, never tables.

## The path through the guides

Read them in order the first time. Later, jump to the one that matches what you are doing.

1. `docs/00-overview-and-principles.md` (this file): goals, speech principles, the architecture in one page, dos and don'ts.
2. `docs/01-setup-and-tooling.md`: setup interview, tools, loader, Tolk, decompilation into a private versioned repository, build and deploy scripts, the offline test project.
3. `docs/02-reconnaissance.md`: how to find out what the game does BEFORE writing code. The project baseline (Tier 1), then the slice workflow (G0 to G7) that starts every feature, and the grep catalogs.
4. `docs/03-architecture.md`: the HSA architecture in detail: focus model, components and elements, hooks, keys, speech, localization, compatibility. Includes "Creating the core" and migrating an older handler-based mod.
5. `docs/04-building-screens.md`: turning one surface into one accessible class: menus, lists, items, popups, game boards, text input, empty states, and the per-screen checklist.
6. `docs/05-quality-and-updates.md`: exception guarding, error handling, performance, offline tests, the compatibility report, game updates with git diff, screen-reader acceptance.
7. `docs/06-distribution.md`: packaging, releases, publishing.

Appendices (engine and loader specifics):

- `docs/appendix-a-unity-loaders-harmony.md`: MelonLoader, BepInEx, Harmony, Tolk, Unity input backends.
- `docs/appendix-b-unity-reflection.md`: private fields in Unity games, ReflectionHelper.
- `docs/appendix-c-legacy-unity.md`: Unity 5.x and older.
- `docs/appendix-d-other-engines.md`: Godot, Unreal, custom engines: how the same architecture maps.
- `docs/appendix-e-known-issues.md`: compatibility warnings checked during setup.
- `docs/appendix-f-git-github.md`: Git and GitHub for beginners.

Other parts of the template:

- `templates/shared/`: the core classes (AccessibilityMgr, AccessibleComponent, AccessibleKey, AccessibleMenu, AccessibleItem, AccessibleListOfItems, Compat, ReflectionHelper, localization) and the screen example AccessibleFEATURENAME.
- `templates/melonloader/`, `templates/bepinex/`: loader-specific Main, ScreenReader, DebugLogger, ModConfig, csproj.
- `templates/tests/`: the offline test project (localization, architecture and game compatibility checks).
- `recon/`: the reconnaissance workflow and its validator `uar` (third-party, MIT, see `THIRD-PARTY-NOTICES.md`).
- `scripts/`: build, deploy, decompile and setup checks.

## Where the ideas come from

- **Hearthstone Access** (HSA): the most complete screen-reader mod of a commercial game, maintained across years of game updates. The architecture (AccessibilityMgr with one screen and a UI stack, AccessibleComponent, AccessibleKey, AccessibleMenu, LocalizationKey with tab-separated text files, the DevTools decompile-per-version workflow) follows it. HSA's code is not copied into this template; the patterns are described and re-implemented.
- **PTCGL Access** (MIT, Copyright (c) 2026 RealAmethyst): the Unity/MelonLoader port of the same architecture to Pokemon TCG Live. The compatibility checker (Compat), the offline game-compatibility test and the exception guard come from there.
- **unity-accessibility-recon** (MIT, Copyright (c) 2026 Sheldon): the evidence-based slice workflow in `recon/` and `docs/02-reconnaissance.md`.

## Core principle: playability, not simplification

**The goal is to make the game playable for blind players in the same way sighted players experience it.** Accessibility means equal access to the gameplay, not a simplified version.

- **No cheats without asking:** only suggest cheats or simplifications when there is absolutely no other way to make a mechanic accessible.
- **Never add them automatically:** never implement cheats or shortcuts without asking first.
- **Full game experience:** all mechanics, challenges and decisions stay with the player. The mod never silently chooses dialogue, targets, routes, purchases or other meaningful outcomes.
- **Use the game's own paths:** every action goes through the method or button the game itself uses (see "Game integration" in `docs/03-architecture.md`).

## Technical goals

- Speech through a screen reader bridge (Tolk on Windows: NVDA, JAWS, SAPI fallback).
- Full keyboard play; no mouse required anywhere.
- Linear, well-structured text: no tables, no graphics, no spatial layouts.
- The mod speaks the game's language.
- The mod survives game updates: broken parts are reported, never crash the game.

## The architecture in one page

Details in `docs/03-architecture.md`. The short version:

- **AccessibilityMgr** holds ONE current screen and a STACK of popups (UIs) over it. Only the focused component (top UI, else the screen) receives keys and may speak. Everything else is silent. There is no state machine to keep in sync: focus is the state.
- **AccessibleScreen / AccessibleUI**: one class per game surface (title screen, shop, battle, a confirmation popup), named `Accessible<Name>`. It implements three methods: `HandleInput()`, `GetHelp()`, `OnGainedFocus()`.
- **Elements** (AccessibleMenu, AccessibleListOfItems, AccessibleItem) are reusable building blocks owned by a component; they speak through it, so they fall silent with it.
- **Hooks**: nested Harmony patches on the game's own open and close methods call `SetScreen`, `ClearScreen`, `ShowUI`, `HideUI`, always inside `AccessibilityMgr.Guard(...)`, so a mod bug can never break the game.
- **AccessibleKey**: every key the mod uses is declared once with its exact modifiers. Features never read raw keys.
- **Localization**: every spoken text is a `LocalizationKey` with English text in `Localization/en/*.txt` (tab-separated), translations next to it, and the game's own strings preferred where they exist.
- **Compat**: every hook class is applied on its own; a hook whose target was renamed by an update is reported (log, F1, startup speech) and the rest of the mod keeps working. The offline test checks every name against the installed game before you even start it.

## Speech principles

### What to announce

- Context changes: screen transitions, popups, mode and phase changes.
- The currently focused element, with position.
- Game state updates the player needs (health, resources, turn changes).
- Results of actions, and errors.
- Events from elsewhere that matter wherever the player is (opponent's move, match found): these are notifications.

### How to announce

- Plain text optimized for screen readers.
- Concise but complete. Detail goes into navigable lines (an item read line by line), not into one long sentence.
- Most important information first: the name, then the state, then the details.
- Only on change, never every frame.
- Repeatable: the player can always hear the current item again and press F1 for the keys that work right now.

### Announcement patterns

Use the same format everywhere. All of them are full localized sentences with placeholders, never glued fragments.

Menu or list navigation:

```
[Element], [Position] of [Total]
Example: "Health Potion, 3 of 12"
```

Opening a screen or popup:

```
[Title], [first element]
Example: "Inventory, Health Potion, 1 of 12"
```

Status change:

```
[What] [direction] [value] (optional: [context])
Example: "Health dropped to 45 of 100"
```

Action confirmation:

```
[Action] [object] (optional: [result])
Example: "Used Health Potion, health full"
```

Error or refusal:

```
[Reason]
Example: "Cannot do that: inventory full"
```

Disabled element (listed, not hidden):

```
[Label], disabled
Example: "Continue, disabled"
```

### Interrupting and queued speech

- **Interrupting** (default for the answer to a key press): stops the previous speech and speaks at once. The player pressed a key and wants the new answer, not the end of the old one.
- **Queued**: waits until the previous speech is finished. Use it for follow-ups after a main announcement: available keys after a popup opens, response options after dialogue text, hints after a confirmation.
- **Notifications** (AccessibilityMgr.OutputNotification) are queued by default so they do not cut off what the player is reading.

```csharp
AccessibilityMgr.Output(this, LocalizationUtils.Format(LocalizationKey.QUEST_ACCEPTED, quest.Title));
AccessibilityMgr.Output(this, LocalizationUtils.Format(LocalizationKey.QUEST_LOG_HINT, AccessibleKey.OPEN_QUEST_LOG), interrupt: false);
```

### Priority when much happens at once

This is game-specific; rough guidance:

- Usually interrupt: critical state (health critical, game over), screen or mode transitions, dialogue text and choices, errors.
- Usually queue: status updates, hints, tooltips, key hints after opening a panel.
- The focus model already removes most conflicts, because covered screens cannot speak.
- Only if a game floods the player with simultaneous events (real-time strategy, busy action RPG) add filtering on top: duplicate suppression, summarizing ("3 enemies defeated"), a verbosity setting. Start without it.
- When in doubt: test with a screen reader and listen. Important information drowned out: raise its priority. Context missed because everything interrupts: queue more.

## Output formatting for screen readers

This applies to everything the mod speaks AND to everything Claude writes for the user (docs, reports, chat).

Avoid:

- Tables (pipe symbols are read aloud one by one).
- ASCII art or graphics.
- Meaning carried by position or columns.

Prefer:

- Headings and bullet lists.
- One item per line.
- Related information grouped under a clear label.
- The same order of information every time.

Example format instead of a table:

**Item name**
- Property: value
- Property: value

## Keyboard design

- Never take a key the game uses. The list of game keys and safe mod keys is made during reconnaissance (`docs/game-api.md`).
- The same meaning on every screen: arrows navigate, Enter confirms, Backspace goes back, Home and End jump, F1 is help.
- Exact modifiers: Shift+Up is never also Up.
- F1 is context-sensitive: the focused component's keys, then the global keys.
- F8 turns the mod off and on (for sighted helpers and for debugging), F12 toggles debug logging, Ctrl+F11 opens the mod settings. Change them if the game uses them.
- Bulk actions with modifiers where the game has quantities (for example Shift for 5, Ctrl for 10, Alt for 100), announced when the panel opens.
- Handle rapid presses: every key press reads live state and answers once.

## Dos and don'ts

Do:

- Verify every class, method and field name in `decompiled/` before using it. Never guess.
- Prefer the game's own text and localization over anything the mod writes.
- Read live game data on every key press; cache object references only, never values.
- Give every screen a `GetHelp()` answer for F1.
- Announce empty states explicitly ("No items").
- Test with a real screen reader.

Don't:

- No long announcements that block the screen reader.
- No tables or ASCII art in output.
- No redundant announcements (the same thing twice).
- **Never override game keys.**
- **Never silently fall back to a cached value** when a live read fails: log it, say so, fail visibly. A blind player cannot see that the information is stale.
- **Never bypass game methods** (adding items to a list directly instead of calling the pickup method breaks achievements, sounds, statistics and sync).
- Never let an exception escape from a hook into the game.
- Never speak from anywhere but the focused component (or a notification).

## Common pitfalls

- Announcing too much at once, or announcing every frame.
- Not announcing important state changes.
- Different keys or different wording for the same action on different screens.
- Assuming visual context that was never spoken.
- A generic "read whatever is selected" cursor instead of one class per surface: it reads wrong things on half the screens and nothing on the rest.
- Starting with a whole-game map instead of the next small slice.
- Treating "it compiled" or "the method was called" as "it works for the player". Only the player hearing it and acting on it proves that.

## Quick reference: best practices

1. Announce on change, never every frame.
2. Always give the position ("3 of 12") in lists.
3. Explicit empty states: never silence.
4. Confirm actions: what was done and the new state.
5. Key hints when a panel opens, queued.
6. Same actions, same announcements, everywhere.
7. Logging always available (debug mode, F12).
8. One accessible class per surface, opened and closed by the game's own methods.
