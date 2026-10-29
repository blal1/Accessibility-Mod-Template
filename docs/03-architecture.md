# 03 Architecture

The Hearthstone Access (HSA) architecture, as implemented by the templates in `templates/shared/`. This is the reference for how every part of the mod is shaped. `docs/04-building-screens.md` applies it to concrete screens.

## Project layout

```
MODNAME.csproj               from templates/<loader>/csproj.template
Main.cs                      starts everything, forwards Update; no feature code ever
ScreenReader.cs              Tolk bridge; only AccessibilityMgr calls it
DebugLogger.cs               Info/Warn/Error always, Log(...) only in debug mode (F12)
ModConfig.cs                 stored settings (MelonPreferences / BepInEx config)
Accessibility/
    AccessibilityMgr.cs      focus, speech, input dispatch, exception guard
    AccessibleComponent.cs   AccessibleComponent, AccessibleScreen, AccessibleUI, AccessibleElement, [AccessibilityPoller]
    AccessibleKey.cs         common keys; AccessibleKey.<Feature>.cs per feature
    AccessibleMenu.cs, AccessibleItem.cs, AccessibleListOfItems.cs
    AccessibleModSettings.cs
    Compat.cs, ReflectionHelper.cs
    Localization/
        LocalizationKey.cs   global keys; LocalizationKey.<Feature>.cs per feature
        LocalizationTable.cs, LocalizationUtils.cs
    Screens/<Area>/Accessible<Name>.cs     one file per game surface
Localization/
    en/Global.txt, en/<Feature>.txt        English (required, the fallback)
    de/Global.txt, ...                      one folder per language
Tests/                       from templates/tests (dotnet test Tests)
decompiled/                  PRIVATE git repo, one branch per game version (never published)
recon-records/               PRIVATE slice records (docs/02-reconnaissance.md)
```

## The focus model

AccessibilityMgr holds:

- **one current screen** (`AccessibleScreen`): the base surface the game shows (title, hub, world, battle),
- **a stack of UIs** (`AccessibleUI`): popups, overlays, dialogs, sub-menus over the screen.

**Focused** = the top UI if any is open, else the screen. Only the focused component:

- receives `HandleInput()` each frame,
- is heard when it calls `AccessibilityMgr.Output(this, text)`: speech from anyone else is dropped.

Everything follows from this one rule:

- A popup opening over the shop silences the shop and takes the keys. No flag to set.
- When the popup closes, the shop gets focus again and `OnGainedFocus()` re-announces where the player is.
- A screen that changes while a popup is open waits silently underneath and announces itself when the last UI closes.
- `HideUI` works from anywhere in the stack: the game closes things when it pleases, also under another popup. A dead UI left buried would later surface owning the keyboard with nothing to drive.
- Showing a UI that is already in the stack moves it to the top instead of adding a duplicate.
- When the game window loses focus, speech stops; anything dropped meanwhile makes the focused component re-announce itself when the window comes back.

### Why this replaces state managers and handler flags

Older versions of this template had `[Feature]Handler` classes, each polling "am I open?" every frame, plus an AccessStateManager or boolean flags to decide who may react to Enter. That design produces the classic bugs: one Enter press triggering two handlers in the same frame, a closed menu activating the one behind it, stale lists after returning from an overlay. They needed input consumption helpers, update-order rules and cache-clearing events.

With one focused component, none of that exists: only one component is ever asked for input, covered components cannot speak, and every component reads live data when it gains focus. The only coordination left is the game's own open and close events, which the hooks forward.

## Components

A component implements `AccessibleScreen` or `AccessibleUI`; both are `AccessibleComponent`:

```csharp
void HandleInput();     // every frame while focused; read keys with AccessibleKey.X.IsPressed()
string GetHelp();       // F1: the keys that work RIGHT NOW, localized
void OnGainedFocus();   // shown, a UI above closed, window came back: say where the player is
```

Rules:

- **One class per game surface**, `Accessible<Name>`, sealed, in `Accessibility/Screens/<Area>/`. It comes from one row of the surface lifecycle matrix (`docs/02-reconnaissance.md`, "From records to code").
- **One instance**, held in a static field; the hooks call into it.
- It keeps a **reference** to the game object it wraps (the hook's `__instance`), valid between its open and close hooks.
- `OnGainedFocus()` says the title and the current element; nothing more. Help and hints go to F1 or are queued.
- `GetHelp()` describes only what works now, in the player's language, using key names from AccessibleKey (localized).
- Components never call ScreenReader, never read `Input` directly, never speak when not focused. The architecture tests in `Tests/` enforce the first two.

Screen or UI?

- `AccessibleScreen` when the surface replaces the previous one (modal depth 0). Only one at a time: `SetScreen` / `ClearScreen`.
- `AccessibleUI` when the surface appears over something and returns to it when closed (modal depth 1 or more): `ShowUI` / `HideUI`.

## Elements

Reusable building blocks owned by a component. They speak THROUGH their parent (`Output` checks the parent's focus), so they fall silent with it. Each `HandleInput()` returns true when the key was for it, so the component can chain them:

```csharp
public void HandleInput()
{
    if (_menu.HandleInput()) return;
    if (AccessibleKey.SHOP_READ_GOLD.IsPressed()) AccessibilityMgr.Output(this, ReadGold());
}
```

- **AccessibleMenu**: a vertical list of options (text or live text, plus an action). Up and Down read, Home and End jump, number keys jump to the Nth option, Enter or Space select, Backspace or Escape go back (if a back action was given). Speaks "Play, 1 of 4". Stops at its edges: no wraparound, the edge is silent and the player stays put; Home, End and numbers make wrapping unnecessary. (Older guides used wraparound with "first item" / "last item"; HSA's edge-stop proved easier to orient with. If a game's own lists wrap, follow the game.)
- **AccessibleListOfItems&lt;T&gt;**: a horizontal row of items (a hand of cards, a party, an inventory row). Left and Right move, Home and End jump, numbers jump; the focused item handles Up and Down itself. Items are fetched LIVE on every key, so the list follows the game. Takes an empty text: never silence. Several lists on one screen are separate instances; Tab and Shift+Tab switch between them.
- **AccessibleItem**: something read line by line (a card, an item, a quest). `GetLines()` is rebuilt from live data on every read; empty lines are dropped. Down and Up go line by line, Shift+Up repeats the current line, Shift+Down reads to the end. The first line is the short form spoken when the item gets focus.

Add your own elements for repeated patterns of your game (a grid, a slider row, a board): subclass `AccessibleElement`, take the parent in the constructor, use `Output`.

## Hooks

The game tells the mod when a surface opens and closes. Hooks are nested `[HarmonyPatch]` classes inside the component they serve, so the component and its triggers live in one file:

```csharp
[HarmonyPatch(typeof(ShopScreen), "Open")]
private static class OpenHook
{
    private static void Postfix(ShopScreen __instance) =>
        AccessibilityMgr.Guard("AccessibleShop.OpenHook", () => _instance.OnOpened(__instance));
}
```

Rules:

- **Every hook body runs inside `AccessibilityMgr.Guard(where, action)`.** Hooks run in the game's own call stack. An exception escaping from mod code can kill the game method or coroutine that called it; in a real mod, an exception thrown from a modal's open hook killed the coroutine driving an online match and hard-froze the game. Guard logs each distinct error once and returns; the game continues.
- Hooks only hand the component to AccessibilityMgr (`SetScreen`, `ClearScreen`, `ShowUI`, `HideUI`), call the component's own methods, or send a notification. No speaking, no logic.
- Target names come from `decompiled/` and from the runtime probe of the slice, never from memory.
- Prefer Postfix: the game has finished building the surface. Use Prefix only to capture state that the method destroys.
- A close hook checks that it closes the same instance it opened (`if (game != _game) return;`).
- Patches are applied by `Compat.PatchAll(harmony, assembly)`, one class at a time: a hook whose target was renamed by an update is reported and the rest still works. Never call `harmony.PatchAll()`.
- HSA patches the game's source directly (it is integrated into the game build); a loader mod achieves the same with Harmony. The rule is the same: the hook point is where the GAME decides the surface is open, not a guess from polling.

Surfaces with no hookable method (detected only by state) use a poller: a static parameterless method marked `[AccessibilityPoller]`, run every frame by AccessibilityMgr whatever has focus, guarded like a hook. Keep it to a cheap check (a cached reference's `activeInHierarchy`), and prefer any hook. The mod settings menu uses one to watch for its own open key.

## Game integration

**Always use the game's own methods for actions.** Picking up, buying, selecting, confirming: call the method or button the game uses.

Why:

- The game tracks statistics, achievements, progress.
- Sounds and visual feedback play (sighted helpers and partially sighted players rely on them).
- Other systems get notified (quests, tutorials, network).
- No desyncs or broken states.

```csharp
// BAD: bypasses game logic; achievements, sounds and stats won't trigger
player.inventory.items.Add(item);
itemOnGround.SetActive(false);

// GOOD: the game's pickup path
player.PickupItem(item);

// BAD: direct gold manipulation
player.gold += 100;

// GOOD
shop.SellItem(item);

// GOOD for UI: press the game's own button
button.onClick.Invoke();
```

Only manipulate data directly when there is no alternative, and record why in `docs/game-api.md`.

## Keys

`AccessibleKey` declares every key the mod reacts to, ONCE, with its EXACT modifiers:

- Shift+Up is never also Up; Ctrl+Enter is never also Enter. A key with modifiers only fires with exactly those held (except keys declared with `anyModifiers`, like F1).
- Features never call `Input.GetKeyDown`: they declare `AccessibleKey.<NAME>` in their own partial file (`AccessibleKey.Shop.cs`) and test `KEY.IsPressed()`. The whole key map stays greppable and two features cannot silently grab the same combination. The architecture test enforces it.
- Reuse the common keys (CONFIRM, BACK, arrows, Home and End, numbers, Tab) so every screen feels the same.
- Only keys from "Safe Mod Keys" in `docs/game-api.md`. Never take a game key.
- `ToString()` is the key's localized spoken name, so help texts are `Format(KEY_HELP, AccessibleKey.SHOP_READ_GOLD)` and stay right when keys or languages change.
- `TryGetPressedNumber()` gives 1 to 9 (and 0 as 10) for number jumps; `IsHoldingShift/Ctrl/Alt` for quantity multipliers.
- Input backend: the template reads legacy `UnityEngine.Input`. For a game using only the Input System package, swap the two low-level methods and resolve letters by the character they type (layout-aware), see `docs/appendix-a-unity-loaders-harmony.md`, "Input System vs legacy Input".

Global keys handled by AccessibilityMgr before any component: F8 (mod on or off), F1 (help: focused component, then global keys, then the compatibility warning if any). Main handles F12 (debug log) itself so it works even when the mod is broken. AccessibleModSettings opens with Ctrl+F11.

Game keys and mod keys: a key the mod uses is often also read by the game in the same frame. Options, in order of preference:

1. Use only keys the game ignores on that screen (the safe-key list).
2. Let the game act and describe the result (the game's Enter on a focused button is often exactly right; the component then only speaks).
3. Block the game's input for that key with a Prefix on the game's input method, only while the component is focused (see `docs/04-building-screens.md`, "Key capture").

## Speech

- Components: `AccessibilityMgr.Output(this, text, interrupt)`. Interrupt (default) for the answer to a key press; `interrupt: false` for queued follow-ups.
- Game events that matter wherever the player is: `AccessibilityMgr.OutputNotification(text)`, queued by default.
- Elements: `Output(text)` through their parent.
- Nothing else speaks. ScreenReader is called only by AccessibilityMgr (and Main for the load message), enforced by the architecture test.
- Speech is dropped while the mod is off (F8) or the game window is in the background.

Patterns, interrupt versus queue, and priorities: `docs/00-overview-and-principles.md`, "Speech principles".

## Localization

The mod speaks the game's language from day one.

- **The game's own text first.** Button labels, item names, card text, descriptions: read them from the game (its UI text or its localization lookup) so they are official and in every language the game ships. `LocalizationUtils.GetGame("game_string_id", LocalizationKey.FALLBACK)` asks the game and falls back to the mod's text.
- **The mod's own words** are `LocalizationKey`s:
  - declared as `public static readonly LocalizationKey X = new LocalizationKey(nameof(X));` in `LocalizationKey.cs` (global) or `LocalizationKey.<Feature>.cs`,
  - with a line in `Localization/en/<Feature>.txt`: three tab-separated columns `KEY`, `TEXT`, `COMMENT` (the same format as HSA's ACCESSIBILITY.txt, so translators can work in a spreadsheet),
  - and the same keys in every other language folder (`Localization/de/<Feature>.txt`).
- `LocalizationUtils.Get(key)` and `Format(key, args)`. Placeholders `{0}`, `{1}`.
- The `.txt` files are embedded in the DLL (csproj `EmbeddedResource` with LogicalName `Localization/<lang>/<file>`). No loose files to install.
- Language: `GetGameLanguageTag()` asks the game once a second, so switching language in the game options takes effect immediately. Missing language or missing line falls back to English; a translation with broken placeholders falls back to English instead of losing the announcement.
- The comment column says where and when the text is spoken and what each placeholder is. Translators need it.

Rules:

- **Whole sentences with placeholders, never glued fragments.** Grammar and word order differ:

```csharp
// BAD: word order breaks in other languages
var text = LocalizationUtils.Get(LocalizationKey.YOU_HAVE) + " " + count + " " + LocalizationUtils.Get(LocalizationKey.ITEMS);

// GOOD: "You have {0} items" / "Du hast {0} Gegenstände"
var text = LocalizationUtils.Format(LocalizationKey.INVENTORY_COUNT, count);
```

- **Never cache a translated string in a static field**: it keeps the language that was active when first read. Read `Get(...)` when speaking.
- Key prefix = feature (`GLOBAL_`, `MENU_`, `KEY_`, `SETTINGS_`, `SHOP_` ...), so files and keys line up.
- No string literals in speech. The offline test fails when a key has no English line, a line has no key, a translation drops a placeholder, or code speaks a literal.
- No machine translation without review by a speaker. Short, consistent terminology per language.

Adding a language: create `Localization/<tag>/` with the same file names and keys, translate the TEXT column, keep the COMMENT. Nothing in code changes. `dotnet test Tests` reports missing lines and placeholders.

Language detection on other engines (Godot `TranslationServer.GetLocale()`, Unreal `FInternationalization`): `docs/appendix-d-other-engines.md`.

## Compatibility and reflection

The mod reaches into the game by name (hook targets, private fields). A game update that renames one used to make a screen go silent with no explanation. Here every break is visible:

- `Compat.PatchAll` applies each hook class separately and records failures.
- `Compat.ScanStatics` finds `static readonly` FieldInfo, MethodInfo and PropertyInfo fields that resolved to null.
- `ReflectionHelper` (GetPrivateField, GetPrivateFieldValue, SetPrivateField, GetTextFromPrivateField) caches each lookup, walks base types, and reports a missing name to Compat once.
- `Compat.ReportStartup` logs every problem ("COMPAT:" lines) and speaks the count once; F1 repeats it.
- Offline, before even launching a new game version: `GameCompatTests` resolves every name the mod uses (hook targets and ReflectionHelper calls with literal names) against the installed game assemblies.

Rules:

- Pass member names to ReflectionHelper as string literals (or `nameof` on a public member), so the offline test can find and check them.
- Never "try several field names in a row" to survive updates: it hides which one is right. One verified name; if an update renames it, Compat and the test report it and you fix it once.
- Unity reflection details: `docs/appendix-b-unity-reflection.md`.

## Text input

When the player types into a game text field (name entry, search, chat), every key must reach the field. The component owning the field calls `AccessibilityMgr.AllowTextInput()` when the field gets focus and `DisallowTextInput()` when it is submitted or left. While allowed, AccessibilityMgr skips the focused component's `HandleInput()`; F1 and F8 still work. Announce the field's label and current content on focus, and the content again on request.

## Forced keys and tutorials (HSA extras)

HSA has a few more tools around the core. Add them when a game needs them; they are not in the template by default:

- **Forced key**: "Press Enter to continue". AccessibilityMgr waits for one specific key, runs an action, and ignores everything else; F1 answers "Press {0} to continue". Useful for story text, tutorial steps, end-of-match screens. Implementation: a nullable key plus an action in AccessibilityMgr, checked before the focused component.
- **Notification with a dismiss button**: when the game shows a blocking notice with one button, Enter presses that button wherever focus is, and F1 says so.
- **Key whitelist and blacklist**: tutorials often allow only certain actions at each step. HSA can disable all keys, enable a whitelist with an overridden F1 text for this step, and blacklist specific keys (for example "end turn" during the first tutorial). Implementation: an enabled flag per AccessibleKey, checked in `IsPressed()`.
- **Help override**: a step-specific F1 text that replaces the component's help until reset.
- **Narration and waiting**: speak a text and run an action when speech is expected to end (estimated from length and speech rate), for scripted sequences. Any key press interrupts narration.
- **Speech rate keys**: for SAPI users, keys to change rate; with a screen reader the reader's own settings apply.
- **Transitioning UIs**: during a scene transition, HSA marks UIs as transitioning so the next screen's announcement is not cut off by the closing popups' re-announcements.
- **Dialogue queues**: when the game queues dialogue or popups, announce the next one only when the game actually shows it (hook the show method), never from the queue itself.

## Settings

`AccessibleModSettings` is an AccessibleUI with a menu over `ModConfig` (Ctrl+F11). ModConfig only stores values (MelonPreferences or the BepInEx config file); the menu changes and saves them. Add a setting: a property in ModConfig, an option in the menu, its text keys in `Global.txt` (or a Settings feature file).

## Creating the core

Phase 2 of `docs/01-setup-and-tooling.md`. Replace `NAMESPACE` and `MODNAME` in every template.

1. From `templates/<loader>/`: `MODNAME.csproj` (csproj.template), `Main.cs`, `ScreenReader.cs`, `DebugLogger.cs`, `ModConfig.cs`.
2. From `templates/shared/` into `Accessibility/`: `AccessibilityMgr.cs`, `AccessibleComponent.cs`, `AccessibleKey.cs`, `AccessibleMenu.cs`, `AccessibleItem.cs`, `AccessibleListOfItems.cs`, `AccessibleModSettings.cs`, `Compat.cs`, `ReflectionHelper.cs`.
3. Into `Accessibility/Localization/`: `LocalizationKey.cs`, `LocalizationTable.cs`, `LocalizationUtils.cs`.
4. `Localization/en/Global.txt` from `templates/shared/Localization/en/Global.txt.template`, and one folder per additional language (German template included).
5. Fill `LocalizationUtils.GetGameLanguageTag()` and `GetGame()` from `docs/game-api.md`, "Localization".
6. Adjust `AccessibleKey.cs` to the safe-key list (F8, Ctrl+F11 and the common keys must not collide with game keys).
7. `Tests/` from `templates/tests/` (rename `Tests.csproj.template` to `Tests.csproj`, the others to `.cs`). Run `dotnet test Tests`.
8. The csproj references `Unity.TextMeshPro.dll` because ReflectionHelper and the screen template read `TMPro.TMP_Text`. If the game has no TextMeshPro, remove the reference and those calls.
9. Build, deploy, start the game. Expected: "MODNAME loaded" spoken; F1 answers "Loading, please wait" and the global keys; F8 toggles; F12 toggles debug logging; Ctrl+F11 opens the settings menu.
10. The first slice: one AccessibleScreen from `AccessibleFEATURENAME.cs.template` (`docs/04-building-screens.md`).

## Migrating an existing handler-based mod

For a mod built with the older template (`[Feature]Handler` classes, AccessStateManager, `Loc.Get("key")`, `ScreenReader.Say` everywhere):

1. Create the core next to the old code (steps above). Main calls both the old handlers and `AccessibilityMgr.Update()` during the migration.
2. Move one handler at a time, starting with the one players meet first:
   - The class becomes `Accessible<Name> : AccessibleScreen` (or `AccessibleUI` for popups).
   - Its `IsOpen()` polling becomes open and close hooks (look for the methods that set what IsOpen checked). If there truly is none, an `[AccessibilityPoller]` that calls SetScreen or ShowUI on change.
   - `OnOpen()` content goes into `OnGainedFocus()`; `GetHelpText()` becomes `GetHelp()`; per-frame key checks go into `HandleInput()` with AccessibleKey entries.
   - `ScreenReader.Say(x)` becomes `AccessibilityMgr.Output(this, x)`; `ScreenReader.SayQueued(x)` becomes `Output(this, x, interrupt: false)`.
   - Its AccessStateManager state and any input-consumption or debounce code are deleted.
3. Localization: each `Loc.Get("inventory_opened")` becomes `LocalizationUtils.Get(LocalizationKey.INVENTORY_OPENED)`; the strings from `Loc.cs`'s `Add(...)` calls go into `Localization/<lang>/<Feature>.txt` (one column per language becomes one folder per language). A small script can convert the Add calls; `dotnet test Tests` then finds every leftover.
4. Remove the handler from Main. When none are left, delete AccessStateManager, Loc and the handler registration code.
5. After each step: build, `dotnet test Tests`, and test the moved screen with a screen reader.
