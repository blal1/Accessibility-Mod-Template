# Appendix C: Legacy Unity (modding old Unity versions)

## Unity versions and mod loader compatibility

- **Unity 2019+**: MelonLoader, BepInEx, Doorstop - all work
- **Unity 2017-2018**: MelonLoader, BepInEx, Doorstop - all work
- **Unity 5.x**: MelonLoader in some games, BepInEx in some, possibly Doorstop, assembly patching as the fallback
- **Unity 4.x or older**: only assembly patching works

## Check before setup

### 1. Find the Unity version

The Unity version is in:
- `[Game]_Data/output_log.txt` (first line: "Initialize engine version: X.X.X")
- Or in the crash log
- Or in the MelonLoader log after the first start

### 2. Check the architecture

- `Mono/` folder = 32-bit, old Mono
- `MonoBleedingEdge/` folder = 64-bit, newer Mono
- Game in "Program Files (x86)" = often 32-bit

### 3. Community research

**Always check first:**
- Are there already mods for the game?
- Which framework does the community use?
- Is there an official mod system?

**Search terms:**
- "[Game name] modding guide"
- "[Game name] BepInEx"
- "[Game name] MelonLoader"
- "[Game name] dll mod"

**Where to search:**
- Steam discussions
- Nexus Mods
- ModDB
- GitHub
- The developer's official forums

## Try mod loaders in order of priority

### Unity 2017+

1. **MelonLoader** - the simplest option for Unity games
2. **BepInEx** - very widespread, good documentation
3. **Doorstop** - if the others do not work

### Unity 5.x

1. **BepInEx 5.x** with net35 compatibility
2. **Doorstop v3** (legacy branch)
3. **Assembly patching** as the fallback

### Unity 4.x or older

1. **Look for a community solution** - maybe someone has found a way
2. **Assembly patching** - usually the only option that works

## Assembly patching (always works)

### What it is

Inserting the mod code directly into the game DLL (`Assembly-CSharp.dll`).

### Advantages

- Works with every Unity version
- No external tools at runtime
- No proxy DLLs needed

### Disadvantages

- Changes original files (make a backup!)
- Has to be patched again after every game update
- Steam's integrity check detects the change

### Tools

- **dnSpy** - GUI based, can edit and save
- **ILSpy + Reflexil** - alternative

### Procedure

1. Back up `[Game]_Data/Managed/Assembly-CSharp.dll`
2. Open the DLL in dnSpy
3. Find a suitable place (e.g. MainMenu.Start or Awake)
4. Insert the code (edit a method or add a new class)
5. Save (Save Module)
6. Test

### Suitable entry points

- `Awake()` or `Start()` of a class that loads early
- The main menu class (always loaded)
- Singleton initialization

## Known problems

### "mono.dll Access Violation"

- Happens with Unity 4.x and BepInEx/Doorstop
- The Mono runtime is too old for modern tools
- Solution: assembly patching

### "Hooked into null"

- MelonLoader cannot hook in
- Unity version not supported
- Solution: another framework or assembly patching

### Game does not start (0xc0000142)

- Proxy DLL incompatible
- Solution: remove the proxy DLL, choose another approach

## UI analysis in old Unity versions

Older Unity versions can bring extra challenges:

- **Older UI systems:** Unity 4.x often still uses the old `OnGUI` system instead of uGUI/Canvas
- **Different component names:** `GUIText` instead of `Text`, `GUITexture` instead of `Image`
- **Missing features:** TextMeshPro may not exist
- **Reflection differences:** private fields may follow other naming conventions

### The OnGUI system (Unity 4.x and earlier)

The old OnGUI system works completely differently from modern Unity UI:

```csharp
void OnGUI() {
    if (GUI.Button(new Rect(10, 10, 100, 50), "Click me")) {
        // Button was clicked
    }
    GUI.Label(new Rect(10, 70, 100, 20), "Some text");
}
```

**Challenges:**
- The UI is redrawn every frame (immediate mode)
- No persistent GameObjects for UI elements
- Harder to hook than modern UI
- Text is often only known inside the OnGUI call

**Possible solutions:**
- Harmony patch on the OnGUI method
- Analyze GUI.skin and GUIStyle
- Own tracking logic for the UI state

## Checklist for old games

- [ ] Unity version found
- [ ] Architecture checked (32/64-bit)
- [ ] Community solutions researched
- [ ] Official mod system checked
- [ ] Mod loaders tried in order
- [ ] If they fail: assembly patching prepared
- [ ] Backup of the original DLLs made
