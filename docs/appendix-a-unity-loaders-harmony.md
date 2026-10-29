# Appendix A: Unity Loaders, Harmony, Tolk, Prism

Compact overview: MelonLoader, BepInEx, Harmony, Tolk, and Unity input. The architecture these serve is in `docs/03-architecture.md`; the templates in `templates/melonloader/` and `templates/bepinex/` already contain everything shown here.

---

## MelonLoader Basics

### Project References (csproj)

```xml
<Reference Include="MelonLoader">
    <HintPath>[GameDirectory]\MelonLoader\net6\MelonLoader.dll</HintPath>
</Reference>
<Reference Include="UnityEngine.CoreModule">
    <HintPath>[GameDirectory]\MelonLoader\Managed\UnityEngine.CoreModule.dll</HintPath>
</Reference>
<Reference Include="Assembly-CSharp">
    <HintPath>[GameDirectory]\[Game]_Data\Managed\Assembly-CSharp.dll</HintPath>
</Reference>
```

### MelonInfo Attribute

```csharp
[assembly: MelonInfo(typeof(MyNamespace.Main), "ModName", "1.0.0", "Author")]
[assembly: MelonGame("Developer", "GameName")]
```

### Lifecycle

```csharp
public class Main : MelonMod
{
    public override void OnInitializeMelon() { }  // Once on load
    public override void OnUpdate() { }            // Every frame
    public override void OnSceneWasLoaded(int buildIndex, string sceneName) { }
    public override void OnApplicationQuit() { }   // On exit
}
```

### CRITICAL: Accessing Game Code

**Any access to game classes before the game is fully loaded can crash.**

This affects:
- Game manager singletons (e.g., `GameManager.i`, `AudioManager.instance`)
- `typeof(GameClass)` - even in Harmony attributes!
- Any reference to game classes in fields or early methods

**Allowed by timing:**

- Assembly load: Only own classes and Unity types
- OnInitializeMelon: own initialization and applying patches (Compat.PatchAll); NO calls into game objects or singletons
- OnSceneWasLoaded: Everything allowed

**When is the game ready?**

Only in/after `OnSceneWasLoaded()`. Safe test: Check a reliable UI element:

```csharp
if (GameObject.Find("MainUI") == null)
    return; // Game not ready yet
```

**Error 1: patching too early in a game that does not allow it**

`typeof(GameClass)` in a `[HarmonyPatch]` attribute is resolved when the attributes are read, which is when `Compat.PatchAll` runs (not when the mod assembly loads). Patching itself loads the game's types but normally does not run game code, so for most games `Compat.PatchAll` in `OnInitializeMelon` / `Awake` is fine; this is what the templates do. `Compat.ScanStatics` runs the mod's own static constructors, so those must not touch game singletons (keep `static readonly` fields to FieldInfo and MethodInfo lookups).

Some games crash or hang when their types are touched before the first scene (static constructors that need the engine running, IL2CPP interop not ready). Symptom: the game dies right after the loader prints the mod's name. Then move the three Compat calls to the first scene load:

```csharp
private bool _patched;

public override void OnSceneWasLoaded(int buildIndex, string sceneName)
{
    if (_patched) return;
    _patched = true;
    var asm = typeof(Main).Assembly;
    Compat.PatchAll(_harmony, asm);
    Compat.ScanStatics(asm);
    Compat.ReportStartup();
}
```

Hooks keep their `[HarmonyPatch(typeof(GameClass), "Method")]` attributes either way; never fall back to `harmony.PatchAll()` (one broken target would stop all patches) or to hand-written `_harmony.Patch(...)` calls (they escape the offline compatibility test).

**Error 2: Singleton access too early**

```csharp
// WRONG - Singleton can block or crash
public override void OnUpdate()
{
    var manager = GameManager.i;
}
```

```csharp
// CORRECT - Check first, then cache
private GameManager _cachedManager = null;

private GameManager GetManagerSafe()
{
    if (_cachedManager != null) return _cachedManager;

    if (GameObject.Find("MainUI") == null)
        return null; // Game not ready yet

    _cachedManager = GameManager.i;
    return _cachedManager;
}
```

### Logging

```csharp
MelonLogger.Msg("Info");
MelonLogger.Warning("Warning");
MelonLogger.Error("Error");
```

### Key Input

Features never read keys directly: they declare an `AccessibleKey` and test `IsPressed()` (`docs/03-architecture.md`, "Keys"). Only AccessibleKey (and Main for F12) calls Unity input; see "Input System vs legacy Input" below.

---

## BepInEx Basics

### Project References (csproj)

```xml
<Reference Include="BepInEx">
    <HintPath>[GameDirectory]\BepInEx\core\BepInEx.dll</HintPath>
</Reference>
<Reference Include="0Harmony">
    <HintPath>[GameDirectory]\BepInEx\core\0Harmony.dll</HintPath>
</Reference>
<Reference Include="UnityEngine">
    <HintPath>[GameDirectory]\[Game]_Data\Managed\UnityEngine.dll</HintPath>
</Reference>
<Reference Include="UnityEngine.CoreModule">
    <HintPath>[GameDirectory]\[Game]_Data\Managed\UnityEngine.CoreModule.dll</HintPath>
</Reference>
<Reference Include="Assembly-CSharp">
    <HintPath>[GameDirectory]\[Game]_Data\Managed\Assembly-CSharp.dll</HintPath>
</Reference>
```

### BepInPlugin Attribute

```csharp
[BepInPlugin("com.author.modname", "ModName", "1.0.0")]
```

- First parameter: Unique GUID (reverse domain notation)
- Unlike MelonLoader, these values are freely chosen (not from a log file)
- The GUID must be unique across all mods for this game

### Lifecycle

```csharp
using BepInEx;
using UnityEngine;

[BepInPlugin("com.author.modname", "ModName", "1.0.0")]
public class Main : BaseUnityPlugin
{
    void Awake() { }    // Once on load (like OnInitializeMelon)
    void Update() { }   // Every frame (like OnUpdate)
    void OnDestroy() { } // On exit (like OnApplicationQuit)
}
```

**Key differences from MelonLoader:**

- `BaseUnityPlugin` inherits from `MonoBehaviour` — uses Unity lifecycle methods
- No `OnSceneWasLoaded` equivalent built-in. Use `SceneManager.sceneLoaded` event instead:

```csharp
using UnityEngine.SceneManagement;

void Awake()
{
    SceneManager.sceneLoaded += OnSceneLoaded;
}

private void OnSceneLoaded(Scene scene, LoadSceneMode mode)
{
    Logger.LogInfo($"Scene loaded: {scene.name}");
}
```

### CRITICAL: Accessing Game Code (BepInEx)

The same timing rules apply as with MelonLoader:

- **Awake()**: own initialization and applying patches (Compat.PatchAll); NO calls into game objects or singletons
- **After scene load**: Everything allowed

```csharp
private bool _gameReady = false;

void Update()
{
    if (!_gameReady)
    {
        // Check for game singletons — adjust to your game!
        // if (GameManager.instance != null)
        //     _gameReady = true;
        // else
        //     return;
        return;
    }

    // Game logic here
}
```

### Logging

```csharp
Logger.LogInfo("Info");      // Instance logger (within plugin class)
Logger.LogWarning("Warning");
Logger.LogError("Error");
```

### Key Input

Same as MelonLoader: AccessibleKey reads Unity's input; see "Input System vs legacy Input" below.

### Mod Output Directory

Built DLL goes into `BepInEx/plugins/` (not `Mods/` like MelonLoader).

---

## Harmony Patching

Harmony is included in both MelonLoader and BepInEx - no extra import needed.

### Setup in Main

Both loaders: create one Harmony instance and apply every patch class through Compat (as in the Main templates), never `harmony.PatchAll()`:

```csharp
_harmony = new HarmonyLib.Harmony("com.author.modname");
var asm = typeof(Main).Assembly;
Compat.PatchAll(_harmony, asm);   // each [HarmonyPatch] class separately; failures reported, not fatal
Compat.ScanStatics(asm);          // static readonly FieldInfo/MethodInfo that resolved to null
Compat.ReportStartup();           // log + spoken count if anything did not match this game version
```

MelonLoader: in `OnInitializeMelon`. BepInEx: in `Awake`. See "Accessing Game Code" above if the game needs it later.

### Where patches live

Patch classes are nested inside the component they serve (`docs/03-architecture.md`, "Hooks"), and every body runs inside `AccessibilityMgr.Guard`, because hooks run in the game's call stack and an escaping exception can break the game.

### Postfix (after original method)

```csharp
[HarmonyPatch(typeof(InventoryUI), "Show")]
private static class ShowHook
{
    private static void Postfix(InventoryUI __instance) =>
        AccessibilityMgr.Guard("AccessibleInventory.ShowHook", () => _instance.OnOpened(__instance));
}
```

### Postfix with return value

```csharp
[HarmonyPatch(typeof(Player), "GetHealth")]
public class HealthPatch
{
    [HarmonyPostfix]
    public static void Postfix(ref int __result)
    {
        MelonLogger.Msg($"Health: {__result}");
    }
}
```

### Prefix (before original method)

```csharp
[HarmonyPatch(typeof(Player), "TakeDamage")]
public class DamagePatch
{
    [HarmonyPrefix]
    public static void Prefix(Player __instance, int damage)
    {
        // Prefix: capture state the original method is about to change
        AccessibilityMgr.Guard("DamagePatch", () =>
            AccessibilityMgr.OutputNotification(LocalizationUtils.Format(LocalizationKey.STATUS_DAMAGE_TAKEN, damage)));
    }

    // Return false to skip original:
    // public static bool Prefix() { return false; }
}
```

### Special Parameters

- `__instance` - The object instance
- `__result` - Return value (Postfix only)
- `___fieldName` - Private fields (3 underscores!)

---

## Prism (Screen Reader, alternative to Tolk)

[Prism](https://github.com/ethindp/prism) is a newer bridge with the same role as Tolk: one DLL that picks the best available output (NVDA, JAWS, SAPI, ...). Use either one, not both. Pokemon TCG Live Access uses Prism and is a working reference (MIT): its `Accessibility/Prism.cs` holds the P/Invoke declarations and `Accessibility/ScreenReader.cs` the wrapper.

### Getting the DLL

- Build it with CMake: `cmake -B build -A x64` then `cmake --build build --config Release` (use `-A Win32` for a 32-bit game).
- Copy `prism.dll` next to the game EXE. Its architecture must match the game's; `scripts/Test-ModSetup.ps1` checks it.

### Call sequence

1. `prism_init(NULL)` returns a context. Pass NULL for the config: the config struct grows between Prism versions, so mirroring it in C# breaks on every update.
2. `prism_registry_create_best(ctx)` returns the best backend for this machine.
3. `prism_backend_initialize(backend)`: accept `Ok` and `AlreadyInitialized`.
4. `prism_backend_output(backend, text, interrupt)` to speak (speech and braille), `prism_backend_stop(backend)` to silence.
5. On exit: `prism_backend_free(backend)`, then `prism_shutdown(ctx)`.

Every export uses the Cdecl calling convention. Catch `DllNotFoundException` when loading, log it and keep the mod running without speech: a missing DLL must never break the game. As with Tolk, only `AccessibilityMgr` talks to the wrapper.

## Tolk (Screen Reader)

### Required DLLs in Game Directory

**BOTH files must be present in the game folder (where the .exe is):**
- `Tolk.dll` — the screen reader bridge
- `nvdaControllerClient64.dll` (64-bit games) or `nvdaControllerClient32.dll` (32-bit games) — required for NVDA

Without nvdaControllerClient, NVDA users get no output. JAWS works via COM (no extra DLL).

Download: https://github.com/ndarilek/tolk/releases

### DLL Imports

```csharp
using System.Runtime.InteropServices;

[DllImport("Tolk.dll")]
private static extern void Tolk_Load();

[DllImport("Tolk.dll")]
private static extern void Tolk_Unload();

[DllImport("Tolk.dll")]
private static extern bool Tolk_IsLoaded();

[DllImport("Tolk.dll")]
private static extern bool Tolk_HasSpeech();

[DllImport("Tolk.dll", CharSet = CharSet.Unicode)]
private static extern bool Tolk_Output(string text, bool interrupt);

[DllImport("Tolk.dll")]
private static extern bool Tolk_Silence();
```

### Simple Wrapper

```csharp
public static class ScreenReader
{
    private static bool _available;

    public static void Initialize()
    {
        try
        {
            Tolk_Load();
            _available = Tolk_IsLoaded() && Tolk_HasSpeech();
        }
        catch
        {
            _available = false;
        }
    }

    public static void Say(string text, bool interrupt = true)
    {
        if (_available && !string.IsNullOrEmpty(text))
            Tolk_Output(text, interrupt);
    }

    public static void Stop()
    {
        if (_available) Tolk_Silence();
    }

    public static void Shutdown()
    {
        try { Tolk_Unload(); } catch { }
    }
}
```

### Usage

Main initializes and shuts it down; AccessibilityMgr is the only class that speaks through it (the architecture test enforces this):

**MelonLoader:**
```csharp
public override void OnInitializeMelon()
{
    ScreenReader.Initialize();
    ModConfig.Initialize();
    AccessibilityMgr.Initialize(typeof(Main).Assembly);   // speaks "MODNAME loaded"
}

public override void OnApplicationQuit()
{
    ScreenReader.Shutdown();
}
```

**BepInEx:**
```csharp
void Awake()
{
    ScreenReader.Initialize();
    ModConfig.Initialize(Config);
    AccessibilityMgr.Initialize(typeof(Main).Assembly);
}

void OnDestroy()
{
    ScreenReader.Shutdown();
}
```

---

## Unity Quick Reference

### Finding GameObjects

```csharp
var obj = GameObject.Find("Name");  // Slow!
var all = GameObject.FindObjectsOfType<Button>();
```

### Components

```csharp
var text = obj.GetComponent<Text>();
var text = obj.GetComponentInChildren<Text>();
var allTexts = obj.GetComponentsInChildren<Text>();
```

### Hierarchy

```csharp
var child = parent.transform.Find("ChildName");
foreach (Transform child in parent.transform) { }
```

### Active State

```csharp
bool isActive = obj.activeInHierarchy;
obj.SetActive(true);
```

---

## Common Accessibility Patterns

The patterns that used to live here (announce a menu opening, "3 of 12" navigation, status changes, avoiding duplicates) are now part of the core:

- UI opened and closed: open and close hooks call `AccessibilityMgr.ShowUI` / `HideUI`; the component announces itself in `OnGainedFocus` (`docs/04-building-screens.md`).
- Menu navigation with position: AccessibleMenu and AccessibleListOfItems ("Play, 1 of 4").
- Status changes: a hook on the game's change method, or a poller that compares with the last value (`docs/05-quality-and-updates.md`, "Check per frame, act on change").
- Duplicates: announce only on change; covered components cannot speak at all.

---

## Input System vs legacy Input

Unity has two input APIs. AccessibleKey must use the one the game has enabled (found in reconnaissance step 1.2):

- **Legacy Input Manager** (`UnityEngine.Input`): `Input.GetKeyDown(KeyCode.F1)`, `Input.GetKey(KeyCode.LeftShift)`. The template uses it. Most games, including many that also use the new package, keep it enabled.
- **Input System package** (`UnityEngine.InputSystem`): `Keyboard.current.f1Key.wasPressedThisFrame`. If the game's Player Settings set "Active Input Handling" to the new system ONLY, every legacy `Input` call throws `InvalidOperationException`. Symptom: the mod loads, then every frame logs that exception and no key works.

To switch AccessibleKey to the Input System, replace only its two low-level methods (`IsKeyDown`, `IsKeyHeld`) with lookups on `Keyboard.current` (reference `Unity.InputSystem.dll` in the csproj). Two details:

- `Keyboard.current` can be null (no keyboard yet, or during startup): treat as "not pressed".
- **Letters by character, not by position**: `Key.A` is the physical position of A on a US keyboard, which is Q on a French AZERTY keyboard. For letter keys, resolve the key that types the character on the player's layout: `Keyboard.current.FindKeyOnCurrentKeyboardLayout("a")`. Arrows, function keys, Enter and digits are layout-independent.

Main's F12 check uses the same backend as AccessibleKey.

---

## Cross-Platform: Linux and macOS

If the game runs on Linux or macOS, the mod can be ported. Here is what works, what needs changes, and how to approach it.

### What works without changes

- **All mod code** (AccessibilityMgr, components, localization, DebugLogger, Main) is pure C# — runs on any platform
- **Harmony patching** works everywhere Mono/.NET runs
- **Unity** is cross-platform, so game internals behave the same

### Mod Loader

- **BepInEx**: Has official Linux builds and works on macOS. Best choice for cross-platform mods.
- **MelonLoader**: Linux support exists but is less mature than BepInEx. macOS support is limited.
- If cross-platform is a goal, prefer BepInEx.

### The main challenge: Screen reader integration

**Tolk is Windows-only.** It uses Windows-specific DLLs (nvdaControllerClient, JAWS API, SAPI). On other platforms, different screen reader APIs exist:

- **Linux**: speech-dispatcher (libspeechd / `spd-say` command), AT-SPI
- **macOS**: VoiceOver via NSAccessibility API, or the `say` command

### How to implement cross-platform screen reader support

Replace the direct Tolk calls in `ScreenReader.cs` with a platform-aware abstraction:

```csharp
public static void Initialize()
{
    if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        _backend = new TolkBackend();       // Existing Tolk integration
    else if (RuntimeInformation.IsOSPlatform(OSPlatform.Linux))
        _backend = new SpeechDBackend();     // speech-dispatcher
    else if (RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
        _backend = new MacSayBackend();      // macOS say command
}
```

**Simple Linux backend (using spd-say process call):**

```csharp
public class SpeechDBackend : IScreenReaderBackend
{
    public bool IsAvailable()
    {
        // Check if spd-say exists
        try
        {
            var p = Process.Start(new ProcessStartInfo("which", "spd-say")
                { RedirectStandardOutput = true, UseShellExecute = false });
            p.WaitForExit();
            return p.ExitCode == 0;
        }
        catch { return false; }
    }

    public void Say(string text, bool interrupt)
    {
        if (interrupt) Silence();
        Process.Start("spd-say", $"\"{text}\"");
    }

    public void Silence()
    {
        try { Process.Start("spd-say", "--cancel"); } catch { }
    }
}
```

**Simple macOS backend (using say command):**

```csharp
public class MacSayBackend : IScreenReaderBackend
{
    public bool IsAvailable() => true; // say is always available on macOS

    public void Say(string text, bool interrupt)
    {
        if (interrupt) Silence();
        Process.Start("say", $"\"{text}\"");
    }

    public void Silence()
    {
        // Kill any running say process
        try { Process.Start("killall", "say"); } catch { }
    }
}
```

**Shared interface:**

```csharp
public interface IScreenReaderBackend
{
    bool IsAvailable();
    void Say(string text, bool interrupt);
    void Silence();
}
```

### Limitations of the simple approach

- **Process calls have slight latency** (~50-100ms) compared to Tolk's direct DLL calls
- **No queueing** — `spd-say` and `say` don't queue natively (would need custom queue)
- **`say` on macOS uses VoiceOver's voice but NOT the VoiceOver screen reader** — blind macOS users who use VoiceOver may hear double output

### Robust alternatives (more effort)

- **Linux**: P/Invoke directly to `libspeechd.so` for speech-dispatcher — similar to how Tolk works on Windows, no process overhead
- **macOS**: Use NSAccessibility APIs via P/Invoke or a native helper — integrates with VoiceOver properly
- **Cross-platform library**: [Tolk-rs](https://github.com/mush42/tolk-rs) (Rust) or [accessible-output](https://github.com/accessibleapps/accessible_output2) (Python) exist as references, but no maintained cross-platform C# screen reader library exists yet

### Effort estimate

- ScreenReader abstraction layer: Small (refactor existing ScreenReader.cs)
- Simple Linux backend (spd-say): Small
- Simple macOS backend (say): Small
- Robust Linux backend (libspeechd): Medium
- Robust macOS backend (NSAccessibility): Medium
- Everything else in the template: No changes needed
