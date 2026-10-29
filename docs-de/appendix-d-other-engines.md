# Anhang D: Andere Engines

Deutsche Fassung von `docs/appendix-d-other-engines.md`.

Die Architektur aus `docs-de/03-architecture.md` ist Engine-neutral; die Vorlagen sind für Unity mit MelonLoader oder BepInEx geschrieben. Dieser Anhang überträgt die einzelnen Bausteine auf andere Engines. Reconnaissance für Spiele, die nicht auf Unity basieren: `docs-de/02-reconnaissance.md`, Abschnitt "Engine-neutrales Minimum".

## Was überall gleich bleibt

- Ein AccessibilityMgr mit einem aktuellen Screen und einem Stapel von UIs; nur die fokussierte Komponente bekommt Tasten und darf sprechen.
- Eine zugängliche Klasse pro Spieloberfläche, geöffnet und geschlossen durch die eigenen Events des Spiels.
- Tasten werden einmal deklariert, mit exakten Modifiern.
- Jeder gesprochene Text ist lokalisiert, die eigenen Strings des Spiels zuerst, Englisch als Fallback, Textdateien mit Tabulator-Trennung.
- Jeder Aufruf vom Spiel in die Mod ist abgesichert; fehlende Spiel-Member werden gemeldet, sind aber nicht fatal.
- Dekompilierter oder extrahierter Spielcode in einem privaten Git-Repository, ein Branch pro Spielversion.
- Tolk (oder das Gegenstück der Plattform) für die Sprachausgabe.

## Was sich je nach Engine ändert

Für jede Engine: wie der Mod-Code hineinkommt, was ein "Hook" ist, wie man Tasten liest und wie man die Sprache erkennt.

### Unity (Mono oder IL2CPP)

- Code hinein: MelonLoader oder BepInEx (`docs-de/appendix-a-unity-loaders-harmony.md`). IL2CPP: Interop-Assemblies, die vom Loader erzeugt werden; diese dekompilieren (`docs-de/01-setup-and-tooling.md`, Schritt 7).
- Hooks: Harmony-Prefix und -Postfix.
- Tasten: `UnityEngine.Input` oder das Input-System-Paket (Anhang A).
- Sprache: der eigene Lokalisierungsmanager des Spiels; `Application.systemLanguage` nur als letzter Ausweg.

```csharp
string lang = Language.getAlias();                         // a game's own class (example)
string lang = PlayerPrefs.GetString("language", "en");     // stored preference
SystemLanguage sys = Application.systemLanguage;           // last resort
```

- Wann initialisieren: in der Init des Loaders, oder beim ersten Laden einer Szene, falls ein früher Zugriff zum Absturz führt (Anhang A).

### Andere .NET-Spiele (XNA, FNA, MonoGame, eigene C#-Engines)

- Code hinein: BepInEx (es unterstützt mehrere .NET-Runtimes außerhalb von Unity), ein eigener Loader oder eine gepatchte Einstiegs-Assembly. Schau zuerst bei der Modding-Community des Spiels nach.
- Hooks: Harmony funktioniert auf jeder .NET-Runtime, die der Loader unterstützt.
- Tasten: der Tastaturzustand des Frameworks (`Keyboard.GetState().IsKeyDown(Keys.F1)` in XNA/MonoGame); AccessibleKey vergleicht mit dem Zustand des vorherigen Frames, um "in diesem Frame gedrückt" zu erhalten.
- Dekompilieren mit ilspycmd wie bei Unity; `scripts/Decompile-Game.ps1 -GamePath <folder with the DLLs>`.

### Godot

- Godot 4 mit C# (.NET): Mod-Code kann von einigen Community-Loadern als zusätzliche Assembly geladen werden; Harmony funktioniert dann auf dem C#-Code des Spiels. GDScript-Spiele: Mods sind Skripte, die über die eigene Mod-Unterstützung des Spiels oder einen PCK-Patch geladen werden; "Hooks" sind Signale, mit denen sich die Mod verbindet, oder ersetzte Skripte.
- Extrahieren: PCK-Dateien mit einem Godot-RE-Tool (GDRE Tools), um Szenen und Skripte zu bekommen.
- Screens: Godot-Szenen und `Control`-Nodes; verbinde dich mit `visibility_changed`, `tree_entered`, `tree_exiting` der Panel-Nodes als Öffnen- und Schließen-Events.
- Tasten: `Input.IsActionJustPressed` oder `_UnhandledInput` mit `InputEventKey`.
- Sprache:

```csharp
string locale = TranslationServer.GetLocale();   // "en_US"
string lang = locale.Substring(0, 2);            // "en"
```

```gdscript
var locale = TranslationServer.get_locale()
```

- Die eigenen Strings des Spiels: `Tr("KEY")` / `tr("KEY")`.
- Wann initialisieren: in `_Ready()` des Haupt-Nodes der Mod.
- Sprachausgabe: Tolk über P/Invoke aus C#, oder eine GDExtension für reine GDScript-Spiele.

### Unreal Engine

- Code hinein: UE4SS (Lua- und C++-Mods) oder eine Proxy-DLL; reine Blueprint-Spiele über UE4SS-Blueprint-Mods.
- Extrahieren: FModel oder UModel für Assets; UE4SS gibt die Klassen- und Eigenschaftsstruktur aus (SDK-Header, "Live View").
- Hooks: UE4SS `RegisterHook("/Script/Module.Class:Function", ...)` auf UFunctions (Öffnen und Schließen von UMG-Widgets: `Construct`, `Destruct`, `AddToViewport`, `RemoveFromParent`, die eigenen Show- und Hide-Funktionen des Spiels).
- Screens: UMG-Widgets; Text aus `TextBlock`-Eigenschaften lesen.
- Tasten: die Eingabe des Player Controllers hooken, oder UE4SS `RegisterKeyBind`.
- Sprache:

```cpp
FString Culture = FInternationalization::Get().GetCurrentCulture()->GetName();   // "de-DE"
```

  oder `UKismetInternationalizationLibrary::GetCurrentLanguage()`.
- Wann initialisieren: nachdem das Spielmodul hochgefahren ist (Start der UE4SS-Mod, oder `PostInitializeComponents` eines gehookten Actors).
- Sprachausgabe: Tolk, aus der C++-Mod geladen, oder eine kleine native Brücke, die aus Lua aufgerufen wird.

### Eigene native Engines (C++)

- Code hinein: DLL-Injection oder eine Proxy-DLL (`dinput8.dll`, `version.dll`), mit einer Hooking-Bibliothek (MinHook, Detours).
- Extrahieren: Ghidra oder IDA; Strings und Symbolnamen führen zum UI-Code. Die Reconnaissance ist viel langsamer; der Slice-Workflow hält sie in Grenzen.
- Hooks: Funktions-Detours auf die Öffnen-, Schließen- und Text-Zeichnen-Funktionen der UI.
- Text: Oft ist die zuverlässigste Quelle die Textzeichen- oder Lokalisierungs-Lookup-Funktion des Spiels; hooke sie, um zu erfahren, welche Strings zu welchem Screen gehören.
- Sprachausgabe: Tolk direkt (es ist eine C-Bibliothek).

### Webbasierte Spiele (Electron, Browser)

- Viele stellen bereits HTML bereit; prüfe vor dem Modding, ob das DOM des Spiels für den Screenreader erreichbar ist.
- Code hinein: ein Preload-Skript oder ein injiziertes Userscript.
- Hooks: DOM-Mutation-Observer auf den Panels des Spiels, oder das Umhüllen der JavaScript-Funktionen des Spiels.
- Sprachausgabe: ARIA-Live-Regionen, die der Screenreader selbst vorliest, statt Tolk.

## Die Kernklassen übertragen

- **AccessibilityMgr**: dieselbe Klasse in der Sprache der Engine (C#, Lua, GDScript, C++). Sie braucht ein Update pro Frame (den Tick der Engine, einen Lua-Loop-Hook, `_Process`).
- **AccessibleComponent**: dieselben drei Methoden.
- **Hooks**: was auch immer die Engine als "dieses Panel wurde vom Spiel geöffnet" anbietet: Harmony-Postfix, Signal, UFunction-Hook, Detour. Immer abgesichert (pcall in Lua, try-catch in C#/C++).
- **AccessibleKey**: umhüllt den Tastenzustand der Engine; dieselbe Regel der exakten Modifier.
- **LocalizationUtils**: dieselben Dateien mit Tabulator-Trennung; lies sie aus dem Mod-Ordner, wenn die Engine keine Ressourcen einbetten kann.
- **Compat**: melde jeden Hook, der nicht installiert werden konnte, und jeden fehlgeschlagenen Member-Lookup; sprich die Anzahl beim Start.
- **Tests**: Die Lokalisierungsprüfungen parsen nur die Textdateien und die Key-Deklarationen, daher lassen sie sich leicht an eine Mod in einer anderen Sprache anpassen (ändere den regulären Ausdruck, der die Keys findet); der Spielkompatibilitätstest ist nur für .NET, daher führen andere Engines eine Liste der Hook-Ziele in `docs/game-api.md` und prüfen sie gegen jede neue dekompilierte oder gedumpte Version erneut.
