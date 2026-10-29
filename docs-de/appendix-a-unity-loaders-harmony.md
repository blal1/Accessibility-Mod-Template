# Anhang A: Unity-Loader, Harmony, Tolk

Kompakte Übersicht: MelonLoader, BepInEx, Harmony, Tolk und Unity-Eingabe. Die Architektur dahinter steht in `docs/03-architecture.md` (Englisch); die Vorlagen in `templates/melonloader/` und `templates/bepinex/` enthalten bereits alles hier Gezeigte.

---

## MelonLoader Grundlagen

### Projekt-Referenzen (csproj)

```xml
<Reference Include="MelonLoader">
    <HintPath>[Spielordner]\MelonLoader\net6\MelonLoader.dll</HintPath>
</Reference>
<Reference Include="UnityEngine.CoreModule">
    <HintPath>[Spielordner]\MelonLoader\Managed\UnityEngine.CoreModule.dll</HintPath>
</Reference>
<Reference Include="Assembly-CSharp">
    <HintPath>[Spielordner]\[Spiel]_Data\Managed\Assembly-CSharp.dll</HintPath>
</Reference>
```

### MelonInfo Attribut

```csharp
[assembly: MelonInfo(typeof(MyNamespace.Main), "ModName", "1.0.0", "Autor")]
[assembly: MelonGame("Entwickler", "Spielname")]
```

### Lebenszyklus

```csharp
public class Main : MelonMod
{
    public override void OnInitializeMelon() { }  // Einmalig beim Laden
    public override void OnUpdate() { }            // Jeden Frame
    public override void OnSceneWasLoaded(int buildIndex, string sceneName) { }
    public override void OnApplicationQuit() { }   // Beim Beenden
}
```

### KRITISCH: Zugriff auf Spielcode

**Jeder Zugriff auf Spielklassen vor dem vollständigen Laden des Spiels kann crashen.**

Das betrifft:
- Spielmanager-Singletons (z.B. `GameManager.i`, `AudioManager.instance`)
- `typeof(SpielKlasse)` - auch in Harmony-Attributen!
- Jede Referenz auf Spielklassen in Feldern oder frühen Methoden

**Erlaubt nach Zeitpunkt:**

- Assembly-Load: Nur eigene Klassen und Unity-Typen
- OnInitializeMelon: eigene Initialisierung und Patches anwenden (Compat.PatchAll); KEINE Aufrufe an Spielobjekte oder Singletons
- OnSceneWasLoaded: Alles erlaubt

**Wann ist das Spiel bereit?**

Erst in/nach `OnSceneWasLoaded()`. Sicherer Test: Ein zuverlässiges UI-Element prüfen:

```csharp
if (GameObject.Find("HauptUI") == null)
    return; // Spiel noch nicht bereit
```

**Fehler 1: zu frühes Patchen bei einem Spiel, das das nicht verträgt**

`typeof(SpielKlasse)` in einem `[HarmonyPatch]`-Attribut wird ausgewertet, wenn die Attribute gelesen werden, also wenn `Compat.PatchAll` läuft (nicht beim Laden der Mod-Assembly). Das Patchen lädt die Spieltypen, führt aber normalerweise keinen Spielcode aus. Bei den meisten Spielen ist `Compat.PatchAll` in `OnInitializeMelon` / `Awake` daher in Ordnung; so machen es die Vorlagen. `Compat.ScanStatics` führt die statischen Konstruktoren der Mod aus, die dürfen also keine Spiel-Singletons anfassen (`static readonly`-Felder nur für FieldInfo- und MethodInfo-Lookups).

Manche Spiele stürzen ab oder hängen, wenn ihre Typen vor der ersten Szene angefasst werden. Symptom: das Spiel stirbt direkt nachdem der Loader den Mod-Namen ausgibt. Dann die drei Compat-Aufrufe in den ersten Szenen-Load verschieben:

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

Die Hooks behalten ihre `[HarmonyPatch(typeof(SpielKlasse), "Methode")]`-Attribute. Nie zurück zu `harmony.PatchAll()` (ein kaputtes Ziel stoppt alle Patches) oder zu handgeschriebenen `_harmony.Patch(...)`-Aufrufen (die entgehen dem Offline-Kompatibilitätstest).

**Fehler 2: Singleton-Zugriff zu früh**

```csharp
// FALSCH - Singleton kann blockieren oder crashen
public override void OnUpdate()
{
    var manager = GameManager.i;
}
```

```csharp
// RICHTIG - Erst prüfen, dann cachen
private GameManager _cachedManager = null;

private GameManager GetManagerSafe()
{
    if (_cachedManager != null) return _cachedManager;

    if (GameObject.Find("HauptUI") == null)
        return null; // Spiel noch nicht bereit

    _cachedManager = GameManager.i;
    return _cachedManager;
}
```

### Logging

```csharp
MelonLogger.Msg("Info");
MelonLogger.Warning("Warnung");
MelonLogger.Error("Fehler");
```

### Tasteneingaben

Features lesen Tasten nie direkt: sie deklarieren einen `AccessibleKey` und prüfen `IsPressed()` (`docs/03-architecture.md`, "Keys"). Nur AccessibleKey (und Main für F12) ruft Unitys Input auf; siehe "Input System vs. Legacy Input" weiter unten.

---

## BepInEx Grundlagen

### Projekt-Referenzen (csproj)

```xml
<Reference Include="BepInEx">
    <HintPath>[Spielordner]\BepInEx\core\BepInEx.dll</HintPath>
</Reference>
<Reference Include="0Harmony">
    <HintPath>[Spielordner]\BepInEx\core\0Harmony.dll</HintPath>
</Reference>
<Reference Include="UnityEngine">
    <HintPath>[Spielordner]\[Spiel]_Data\Managed\UnityEngine.dll</HintPath>
</Reference>
<Reference Include="UnityEngine.CoreModule">
    <HintPath>[Spielordner]\[Spiel]_Data\Managed\UnityEngine.CoreModule.dll</HintPath>
</Reference>
<Reference Include="Assembly-CSharp">
    <HintPath>[Spielordner]\[Spiel]_Data\Managed\Assembly-CSharp.dll</HintPath>
</Reference>
```

### BepInPlugin Attribut

```csharp
[BepInPlugin("com.autor.modname", "ModName", "1.0.0")]
```

- Erster Parameter: Eindeutige GUID (umgekehrte Domain-Notation)
- Im Gegensatz zu MelonLoader werden diese Werte frei gewählt (nicht aus einer Log-Datei)
- Die GUID muss einzigartig unter allen Mods für dieses Spiel sein

### Lebenszyklus

```csharp
using BepInEx;
using UnityEngine;

[BepInPlugin("com.autor.modname", "ModName", "1.0.0")]
public class Main : BaseUnityPlugin
{
    void Awake() { }     // Einmalig beim Laden (wie OnInitializeMelon)
    void Update() { }    // Jeden Frame (wie OnUpdate)
    void OnDestroy() { } // Beim Beenden (wie OnApplicationQuit)
}
```

**Hauptunterschiede zu MelonLoader:**

- `BaseUnityPlugin` erbt von `MonoBehaviour` — nutzt Unity-Lifecycle-Methoden
- Kein `OnSceneWasLoaded`-Äquivalent eingebaut. Stattdessen `SceneManager.sceneLoaded`-Event nutzen:

```csharp
using UnityEngine.SceneManagement;

void Awake()
{
    SceneManager.sceneLoaded += OnSceneLoaded;
}

private void OnSceneLoaded(Scene scene, LoadSceneMode mode)
{
    Logger.LogInfo($"Scene geladen: {scene.name}");
}
```

### KRITISCH: Zugriff auf Spielcode (BepInEx)

Die gleichen Timing-Regeln gelten wie bei MelonLoader:

- **Awake()**: eigene Initialisierung und Patches anwenden (Compat.PatchAll); KEINE Aufrufe an Spielobjekte oder Singletons
- **Nach Scene-Load**: Alles erlaubt

```csharp
private bool _gameReady = false;

void Update()
{
    if (!_gameReady)
    {
        // Auf Spiel-Singletons prüfen — ans Spiel anpassen!
        // if (GameManager.instance != null)
        //     _gameReady = true;
        // else
        //     return;
        return;
    }

    // Spiellogik hier
}
```

### Logging

```csharp
Logger.LogInfo("Info");       // Instanz-Logger (innerhalb der Plugin-Klasse)
Logger.LogWarning("Warnung");
Logger.LogError("Fehler");
```

### Tasteneingaben

Gleich wie MelonLoader: AccessibleKey liest Unitys Input; siehe "Input System vs. Legacy Input" weiter unten.

### Mod-Ausgabeordner

Gebaute DLL kommt in `BepInEx/plugins/` (nicht `Mods/` wie bei MelonLoader).

---

## Harmony Patching

Harmony ist in MelonLoader und BepInEx enthalten - kein extra Import nötig.

### Setup in Main

Beide Loader: eine Harmony-Instanz erzeugen und jede Patch-Klasse über Compat anwenden (wie in den Main-Vorlagen), nie `harmony.PatchAll()`:

```csharp
_harmony = new HarmonyLib.Harmony("com.autor.modname");
var asm = typeof(Main).Assembly;
Compat.PatchAll(_harmony, asm);   // jede [HarmonyPatch]-Klasse einzeln; Fehler werden gemeldet, nicht fatal
Compat.ScanStatics(asm);          // static readonly FieldInfo/MethodInfo, die null ergaben
Compat.ReportStartup();           // Log + gesprochene Anzahl, falls etwas nicht zur Spielversion passt
```

MelonLoader: in `OnInitializeMelon`. BepInEx: in `Awake`. Falls das Spiel es erst später erlaubt, siehe "Zugriff auf Spielcode" oben.

### Wo Patches stehen

Patch-Klassen stehen verschachtelt in der Komponente, der sie dienen (`docs/03-architecture.md`, "Hooks"), und jeder Rumpf läuft in `AccessibilityMgr.Guard`, weil Hooks im Aufrufstapel des Spiels laufen und eine entkommene Exception das Spiel beschädigen kann.

### Postfix (nach Originalmethode)

```csharp
[HarmonyPatch(typeof(InventoryUI), "Show")]
private static class ShowHook
{
    private static void Postfix(InventoryUI __instance) =>
        AccessibilityMgr.Guard("AccessibleInventory.ShowHook", () => _instance.OnOpened(__instance));
}
```

### Postfix mit Rückgabewert

```csharp
[HarmonyPatch(typeof(Player), "GetHealth")]
public class HealthPatch
{
    [HarmonyPostfix]
    public static void Postfix(ref int __result)
    {
        MelonLogger.Msg($"Gesundheit: {__result}");
    }
}
```

### Prefix (vor Originalmethode)

```csharp
[HarmonyPatch(typeof(Player), "TakeDamage")]
public class DamagePatch
{
    [HarmonyPrefix]
    public static void Prefix(Player __instance, int damage)
    {
        // Prefix: Zustand erfassen, den die Originalmethode gleich ändert
        AccessibilityMgr.Guard("DamagePatch", () =>
            AccessibilityMgr.OutputNotification(LocalizationUtils.Format(LocalizationKey.STATUS_DAMAGE_TAKEN, damage)));
    }

    // Return false um Original zu überspringen:
    // public static bool Prefix() { return false; }
}
```

### Spezielle Parameter

- `__instance` - Die Objektinstanz
- `__result` - Rückgabewert (nur Postfix)
- `___fieldName` - Private Felder (3 Unterstriche!)

---

## Tolk (Screenreader)

### Benötigte DLLs im Spielordner

**BEIDE Dateien müssen im Spielordner liegen (wo die .exe ist):**
- `Tolk.dll` — die Screenreader-Bridge
- `nvdaControllerClient64.dll` (64-Bit-Spiele) oder `nvdaControllerClient32.dll` (32-Bit-Spiele) — erforderlich für NVDA

Ohne nvdaControllerClient bekommen NVDA-Nutzer keine Ausgabe. JAWS funktioniert über COM (keine extra DLL).

Download: https://github.com/ndarilek/tolk/releases

### DLL-Imports

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

### Einfacher Wrapper

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

### Verwendung

Main initialisiert und beendet ihn; AccessibilityMgr ist die einzige Klasse, die über ihn spricht (der Architektur-Test prüft das):

**MelonLoader:**
```csharp
public override void OnInitializeMelon()
{
    ScreenReader.Initialize();
    ModConfig.Initialize();
    AccessibilityMgr.Initialize(typeof(Main).Assembly);   // sagt "MODNAME loaded"
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

## Unity Kurzreferenz

### GameObjects finden

```csharp
var obj = GameObject.Find("Name");  // Langsam!
var all = GameObject.FindObjectsOfType<Button>();
```

### Komponenten

```csharp
var text = obj.GetComponent<Text>();
var text = obj.GetComponentInChildren<Text>();
var allTexts = obj.GetComponentsInChildren<Text>();
```

### Hierarchie

```csharp
var child = parent.transform.Find("ChildName");
foreach (Transform child in parent.transform) { }
```

### Aktiv-Status

```csharp
bool isActive = obj.activeInHierarchy;
obj.SetActive(true);
```

---

## Häufige Accessibility-Patterns

Die Muster, die früher hier standen (Menü geöffnet ansagen, "3 von 12", Statusänderungen, Duplikate vermeiden), sind jetzt Teil des Kerns:

- UI geöffnet und geschlossen: Öffnen- und Schließen-Hooks rufen `AccessibilityMgr.ShowUI` / `HideUI`; die Komponente sagt sich in `OnGainedFocus` selbst an (`docs/04-building-screens.md`).
- Menü-Navigation mit Position: AccessibleMenu und AccessibleListOfItems ("Spielen, 1 von 4").
- Statusänderungen: ein Hook auf die Änderungsmethode des Spiels oder ein Poller, der mit dem letzten Wert vergleicht (`docs/05-quality-and-updates.md`).
- Duplikate: nur bei Änderung ansagen; verdeckte Komponenten können gar nicht sprechen.

---

## Input System vs. Legacy Input

Unity hat zwei Eingabe-APIs. AccessibleKey muss die benutzen, die das Spiel aktiviert hat (Recherche-Schritt 1.2):

- **Legacy Input Manager** (`UnityEngine.Input`): `Input.GetKeyDown(KeyCode.F1)`, `Input.GetKey(KeyCode.LeftShift)`. Die Vorlage nutzt ihn. Die meisten Spiele lassen ihn aktiv, auch viele, die zusätzlich das neue Paket nutzen.
- **Input System Paket** (`UnityEngine.InputSystem`): `Keyboard.current.f1Key.wasPressedThisFrame`. Steht in den Player Settings "Active Input Handling" NUR auf dem neuen System, wirft jeder Legacy-`Input`-Aufruf `InvalidOperationException`. Symptom: die Mod lädt, dann loggt jeder Frame diese Exception und keine Taste geht.

Zum Umstellen nur die zwei Low-Level-Methoden von AccessibleKey (`IsKeyDown`, `IsKeyHeld`) durch Abfragen von `Keyboard.current` ersetzen (`Unity.InputSystem.dll` im csproj referenzieren). Zwei Details:

- `Keyboard.current` kann null sein (noch keine Tastatur, beim Start): als "nicht gedrückt" behandeln.
- **Buchstaben nach Zeichen, nicht nach Position**: `Key.A` ist die Position von A auf einer US-Tastatur, auf französischem AZERTY ist das Q. Für Buchstaben die Taste suchen, die auf dem Layout des Spielers das Zeichen tippt: `Keyboard.current.FindKeyOnCurrentKeyboardLayout("a")`. Pfeile, Funktionstasten, Enter und Ziffern sind layout-unabhängig.

Die F12-Abfrage in Main nutzt dasselbe Backend wie AccessibleKey.

---

## Cross-Platform: Linux und macOS

Wenn das Spiel auf Linux oder macOS läuft, kann der Mod portiert werden. Hier ist was funktioniert, was geändert werden muss, und wie man vorgeht.

### Was ohne Änderung funktioniert

- **Der gesamte Mod-Code** (AccessibilityMgr, Komponenten, Lokalisierung, DebugLogger, Main) ist reines C# — läuft auf jeder Plattform
- **Harmony-Patching** funktioniert überall wo Mono/.NET läuft
- **Unity** ist plattformübergreifend, Spiel-Interna verhalten sich gleich

### Mod Loader

- **BepInEx**: Hat offizielle Linux-Builds und funktioniert auf macOS. Beste Wahl für plattformübergreifende Mods.
- **MelonLoader**: Linux-Support existiert, ist aber weniger ausgereift als BepInEx. macOS-Support ist eingeschränkt.
- Wenn Plattformübergreifung ein Ziel ist, BepInEx bevorzugen.

### Die Hauptherausforderung: Screenreader-Integration

**Tolk ist rein Windows.** Es nutzt Windows-spezifische DLLs (nvdaControllerClient, JAWS API, SAPI). Auf anderen Plattformen gibt es andere Screenreader-APIs:

- **Linux**: speech-dispatcher (libspeechd / `spd-say`-Befehl), AT-SPI
- **macOS**: VoiceOver über NSAccessibility API, oder der `say`-Befehl

### Umsetzung: Plattformabhängige Screenreader-Unterstützung

Die direkten Tolk-Aufrufe in `ScreenReader.cs` durch eine plattformabhängige Abstraktion ersetzen:

```csharp
public static void Initialize()
{
    if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        _backend = new TolkBackend();       // Bestehende Tolk-Integration
    else if (RuntimeInformation.IsOSPlatform(OSPlatform.Linux))
        _backend = new SpeechDBackend();     // speech-dispatcher
    else if (RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
        _backend = new MacSayBackend();      // macOS say-Befehl
}
```

**Einfaches Linux-Backend (spd-say Prozessaufruf):**

```csharp
public class SpeechDBackend : IScreenReaderBackend
{
    public bool IsAvailable()
    {
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

**Einfaches macOS-Backend (say-Befehl):**

```csharp
public class MacSayBackend : IScreenReaderBackend
{
    public bool IsAvailable() => true; // say ist immer auf macOS verfügbar

    public void Say(string text, bool interrupt)
    {
        if (interrupt) Silence();
        Process.Start("say", $"\"{text}\"");
    }

    public void Silence()
    {
        try { Process.Start("killall", "say"); } catch { }
    }
}
```

**Gemeinsames Interface:**

```csharp
public interface IScreenReaderBackend
{
    bool IsAvailable();
    void Say(string text, bool interrupt);
    void Silence();
}
```

### Einschränkungen des einfachen Ansatzes

- **Prozessaufrufe haben leichte Latenz** (~50-100ms) im Vergleich zu Tolks direkten DLL-Aufrufen
- **Kein Queueing** — `spd-say` und `say` reihen nicht nativ ein (bräuchte eigene Queue)
- **`say` auf macOS nutzt VoiceOvers Stimme, aber NICHT den VoiceOver-Screenreader** — blinde macOS-Nutzer die VoiceOver verwenden könnten doppelte Ausgabe hören

### Robustere Alternativen (mehr Aufwand)

- **Linux**: Direkte P/Invoke-Anbindung an `libspeechd.so` für speech-dispatcher — ähnlich wie Tolk auf Windows funktioniert, kein Prozess-Overhead
- **macOS**: NSAccessibility APIs über P/Invoke oder einen nativen Helper nutzen — integriert sich korrekt mit VoiceOver
- **Plattformübergreifende Bibliothek**: [Tolk-rs](https://github.com/mush42/tolk-rs) (Rust) oder [accessible-output](https://github.com/accessibleapps/accessible_output2) (Python) existieren als Referenz, aber es gibt derzeit keine gepflegte plattformübergreifende C#-Screenreader-Bibliothek

### Aufwandsschätzung

- ScreenReader-Abstraktionsschicht: Klein (bestehende ScreenReader.cs umbauen)
- Einfaches Linux-Backend (spd-say): Klein
- Einfaches macOS-Backend (say): Klein
- Robustes Linux-Backend (libspeechd): Mittel
- Robustes macOS-Backend (NSAccessibility): Mittel
- Alles andere im Template: Keine Änderung nötig
