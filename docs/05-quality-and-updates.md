# 05 Quality and Updates

Keeping the mod robust, fast, and alive across game updates.

## Never break the game

Mod code runs inside the game. The worst thing an accessibility mod can do is crash or freeze the game for the player who depends on it.

- Every call from the game into the mod is guarded. AccessibilityMgr already wraps every `HandleInput`, `GetHelp`, `OnGainedFocus` and poller call. Hooks wrap their bodies in `AccessibilityMgr.Guard("Where", () => ...)`. The same for game event handlers and coroutines the mod starts.
- Real case: an exception thrown from a modal's open hook killed the coroutine driving an online match and hard-froze the game. A guarded hook logs and returns; the game continues, and the worst case is one silent screen.
- Guard logs each distinct error once (not 60 times a second from HandleInput).
- Hooks patch with Compat.PatchAll, one class at a time, so a renamed target disables only its own hook.

## Error handling

### Rules

1. **Null-safety with logging, never silent.** If something is null, log it AND tell the player something useful.
2. **try-catch only where failure is expected**: reflection (names can change with updates), Tolk and other external libraries, game APIs that may throw. Normal code uses null checks. The guards above are the safety net for everything else; they do not replace thinking about nulls.
3. **Log levels**: `DebugLogger.Log(category, ...)` for diagnostics (only in debug mode, F12, zero cost otherwise). `DebugLogger.Info/Warn/Error` for things that must be in the log always (Tolk missing, initialization failed, compatibility problems).

### Defensive programming

```csharp
// BAD: hides the error; you never learn something is null
var text = panel?.GetComponentInChildren<Text>()?.text ?? "Unknown";

// GOOD: null-safe AND logged AND the player is told
var textComp = panel != null ? panel.GetComponentInChildren<Text>() : null;
if (textComp == null)
{
    DebugLogger.Warn("AccessibleShop: price text not found");
    AccessibilityMgr.Output(this, LocalizationUtils.Get(LocalizationKey.GLOBAL_NOT_READABLE));
    return;
}
var text = textComp.text;
```

For reflection, ReflectionHelper already catches, reports to Compat once, and returns null or the default: check the result.

```csharp
// Specific exceptions where you do catch yourself
try
{
    value = fieldInfo.GetValue(obj);
}
catch (TargetException e)
{
    DebugLogger.Warn($"Field access failed, game updated? {e.Message}");
}
```

### Graceful degradation

When something fails, don't crash; give useful feedback:

```csharp
var items = GetItems();
if (items == null)
{
    AccessibilityMgr.Output(this, LocalizationUtils.Get(LocalizationKey.INVENTORY_NOT_AVAILABLE));
    return;
}
if (items.Count == 0)
{
    AccessibilityMgr.Output(this, LocalizationUtils.Get(LocalizationKey.INVENTORY_EMPTY));
    return;
}
```

Without null checks the mod crashes on missing UI; without logging you never learn why something does not work.

## Live data and caching

**Cache object references, never values.** A sighted player sees when the screen updates. A blind player trusts whatever is spoken. A cached value shown after a failed live read is wrong information the player cannot notice: silent degradation, the worst outcome for an accessibility mod.

```csharp
// BAD: searches the scene every frame
var panel = GameObject.Find("InventoryPanel");

// GOOD: the reference comes from the hook (__instance) and is released in the close hook.

// BAD: returning the last value when the live read fails
private string _lastItemName;
string GetItemName()
{
    var name = GetLiveItemName();
    if (name != null) _lastItemName = name;
    return _lastItemName;   // silent degradation
}

// GOOD: live read, explicit failure
string GetItemName()
{
    var name = GetLiveItemName();
    if (name == null)
    {
        DebugLogger.Warn("Could not read item name");
        return LocalizationUtils.Get(LocalizationKey.GLOBAL_NOT_READABLE);
    }
    return name;
}
```

The element classes are built this way: AccessibleMenu labels can be `Func<string>`, AccessibleListOfItems calls `getItems` on every key, AccessibleItem rebuilds its lines on every read. A component that regains focus reads everything again in `OnGainedFocus`.

## Performance

### What costs nothing per frame

- `AccessibleKey.X.IsPressed()` (one `GetKeyDown` and modifier checks).
- Comparing a bool, int or float.
- Null checks.
- A cached reference's property (`_panel.activeInHierarchy`).

Even many of these every frame are unmeasurable next to what the game does (rendering, physics, AI). Only the focused component's `HandleInput` runs, so the cost does not grow with the number of screens.

### What must not happen every frame

- `GameObject.Find`, `FindObjectOfType`, `GetComponentsInChildren`: hierarchy searches.
- Reflection lookups (ReflectionHelper caches the FieldInfo; reading the value is fine on a key press).
- String building and formatting (garbage collection pressure).
- Speaking: a screen reader cannot process 60 messages a second anyway.

### Check per frame, act on change

For pollers (surfaces with no hook) and status watchers:

```csharp
private static float _lastHealth = -1;

[AccessibilityPoller]
private static void WatchHealth()
{
    var player = _player;               // reference set by a hook
    if (player == null) return;
    var health = player.health;         // cheap
    if (health == _lastHealth) return;
    _lastHealth = health;               // expensive work only on change
    AccessibilityMgr.OutputNotification(LocalizationUtils.Format(LocalizationKey.STATUS_HEALTH, health, player.maxHealth));
}
```

### Throttling

For moderately expensive checks with no event to hook (iterating a list):

```csharp
private static float _nextCheck;

[AccessibilityPoller]
private static void PollQuestLog()
{
    if (Time.unscaledTime < _nextCheck) return;
    _nextCheck = Time.unscaledTime + 0.1f;   // 10 times a second is plenty
    // moderately expensive check here
}
```

### Hooks before polling

If the game has a method that runs when something happens, hook it:

- `OnMenuOpen()`, `OnMenuClose()` instead of checking `isOpen` every frame,
- `OnItemSelected()`, `OnSelectionChanged()` instead of tracking an index,
- `TakeDamage()`, `Heal()` instead of comparing health.

Polling is legitimate only when the game offers no such method. The game's architecture decides, and the slice's runtime probe shows which one fires.

The examples use Unity APIs; other engines apply the same rules with their equivalents (`docs/appendix-d-other-engines.md`).

## Offline tests

`Tests/` (from `templates/tests/`) runs without the game:

```powershell
dotnet test Tests
```

- **LocalizationTests**: every LocalizationKey has an English line; every English line has a key; every translation covers English and keeps its `{0}` placeholders; nothing speaks a string literal.
- **ArchitectureTests**: only AccessibilityMgr (and ScreenReader and Main) talk to the screen reader; only AccessibleKey (and Main for F12) read raw keys.
- **GameCompatTests** (from PTCGL Access): parses the mod with Roslyn and resolves every game member the mod names in a string (Harmony targets, AccessTools lookups, ReflectionHelper calls, `GetField`/`GetMethod`) against the INSTALLED game's assemblies. The game is found through the `game` junction at the project root, the `GameDir` property in `Tests\Tests.csproj`, or the `GAME_DIR` environment variable. Without the game it prints SKIPPED instead of failing.

Run them after every change, and always first after a game update.

## The compatibility report

At startup Compat reports everything that did not resolve:

- The log has one "COMPAT:" line per problem (which hook or field, why).
- The count is spoken once: "Warning: 2 parts of the mod do not match this game version. Some screens may be silent."
- F1 repeats the warning, so the player can report it.

Players can tell you exactly what broke, and the mod keeps working everywhere else.

## Game update workflow

The HSA DevTools way: every update becomes a reviewable diff.

1. **New fingerprint**: read the new game version; open a new build fingerprint in `recon-records/` (G1). Old evidence is not reused until checked.
2. **Decompile into a new branch**:

```powershell
.\scripts\Decompile-Game.ps1 -Version 1.0.4
```

   It forks branch `1.0.4` from the current version's branch, decompiles, commits.
3. **What changed**:

```powershell
git -C decompiled diff 1.0.3 1.0.4 --stat
git -C decompiled diff 1.0.3 1.0.4 -- <path of a class the mod hooks>
```

   `docs/game-api.md` lists the hooked classes; check each one in the diff.
4. **Offline check before launching**: `dotnet test Tests`. GameCompatTests names each renamed or removed member with file and line.
5. **Fix**: update names, hooks and reflection to the new code; update `docs/game-api.md`.
6. **Build, deploy, start**: the startup compat count must be zero. Walk through the main slices with the screen reader.
7. **Records**: re-confirm the runtime claims the update could have touched (anything whose classes appear in the diff); everything else carries over with a note in the fingerprint.

**Never push, publish or share `decompiled/`.** It is the game's proprietary code. The same applies to `recon-records/` when it contains proprietary names, paths or hashes.

## Testing with a screen reader

- Test with a real screen reader (NVDA is free), not only the debug log.
- Listen for: too long, too much at once, missing state changes, wrong order, repeats.
- Every interactive element must be reachable by keyboard.
- Test with the screen off (or a sighted helper not looking) to catch assumed visual context.
- Rapid presses: hold arrows, press Enter twice quickly; every press answers once and correctly.
- Language: switch the game language and back; the mod follows within a second.
- Window focus: alt-tab away and back; speech stops and the current place is re-announced if something was missed.
- Get feedback from blind players whenever possible.

## Acceptance

The claim grades of `docs/02-reconnaissance.md` apply to reports too:

- "Builds", "tests pass", "the hook fired", "the screen reader bridge accepted the text" are progress, not acceptance.
- A feature is done when the user (or a blind tester) heard it and used it with the keyboard: `NVDA-MANUAL-CONFIRMED`. Until then it is listed under "Pending Tests" in `project_status.md`.
- Ask the user only for that experiential check and for decisions; collecting evidence, running checks and fixing clear local problems is Claude's job.
