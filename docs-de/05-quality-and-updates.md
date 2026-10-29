# 05 Qualität und Updates

Deutsche Fassung von `docs/05-quality-and-updates.md`.

Wie die Mod robust und schnell bleibt und Spiel-Updates überlebt.

## Niemals das Spiel kaputt machen

Mod-Code läuft innerhalb des Spiels. Das Schlimmste, was eine Barrierefreiheits-Mod tun kann, ist das Spiel abstürzen oder einfrieren zu lassen, und zwar für genau den Spieler, der auf sie angewiesen ist.

- Jeder Aufruf vom Spiel in die Mod ist abgesichert. AccessibilityMgr umschließt bereits jeden Aufruf von `HandleInput`, `GetHelp`, `OnGainedFocus` und jedem Poller. Hooks packen ihren Rumpf in `AccessibilityMgr.Guard("Where", () => ...)`. Dasselbe gilt für Event-Handler des Spiels und für Coroutinen, die die Mod startet.
- Echter Fall: Eine Exception aus dem Öffnen-Hook eines Modal-Dialogs hat die Coroutine beendet, die ein Online-Match steuerte, und das Spiel komplett einfrieren lassen. Ein abgesicherter Hook loggt den Fehler und kehrt zurück; das Spiel läuft weiter, und im schlimmsten Fall bleibt ein Bildschirm stumm.
- Guard loggt jeden einzelnen Fehler nur einmal (nicht 60 Mal pro Sekunde aus HandleInput).
- Hooks werden mit Compat.PatchAll gepatcht, eine Klasse nach der anderen, sodass ein umbenanntes Ziel nur seinen eigenen Hook deaktiviert.

## Fehlerbehandlung

### Regeln

1. **Null-Sicherheit mit Logging, niemals stillschweigend.** Wenn etwas null ist, logge es UND sag dem Spieler etwas Nützliches.
2. **try-catch nur dort, wo ein Fehlschlag zu erwarten ist**: Reflection (Namen können sich mit Updates ändern), Tolk und andere externe Bibliotheken, Spiel-APIs, die Exceptions werfen können. Normaler Code nutzt Null-Prüfungen. Die oben beschriebenen Guards sind das Sicherheitsnetz für alles andere; sie ersetzen nicht das Nachdenken über Nullwerte.
3. **Log-Level**: `DebugLogger.Log(category, ...)` für Diagnosen (nur im Debug-Modus, F12, sonst ohne Kosten). `DebugLogger.Info/Warn/Error` für Dinge, die immer im Log stehen müssen (Tolk fehlt, Initialisierung fehlgeschlagen, Kompatibilitätsprobleme).

### Defensive Programmierung

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

Für Reflection fängt ReflectionHelper Fehler bereits ab, meldet sie einmal an Compat und gibt null oder den Standardwert zurück: Prüfe das Ergebnis.

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

### Kontrollierter Funktionsabbau (Graceful Degradation)

Wenn etwas fehlschlägt, stürze nicht ab, sondern gib nützliches Feedback:

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

Ohne Null-Prüfungen stürzt die Mod bei fehlender UI ab; ohne Logging erfährst du nie, warum etwas nicht funktioniert.

## Live-Daten und Caching

**Cache Objektreferenzen, niemals Werte.** Ein sehender Spieler sieht, wenn sich der Bildschirm aktualisiert. Ein blinder Spieler vertraut dem, was gesprochen wird. Ein gecachter Wert, der nach einem fehlgeschlagenen Live-Lesen angezeigt wird, ist eine falsche Information, die der Spieler nicht bemerken kann: stiller Funktionsverlust, das schlimmste Ergebnis für eine Barrierefreiheits-Mod.

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

Die Element-Klassen sind genau so gebaut: Beschriftungen von AccessibleMenu können `Func<string>` sein, AccessibleListOfItems ruft `getItems` bei jedem Tastendruck auf, AccessibleItem baut seine Zeilen bei jedem Lesen neu auf. Eine Komponente, die den Fokus zurückerhält, liest in `OnGainedFocus` alles neu.

## Performance

### Was pro Frame nichts kostet

- `AccessibleKey.X.IsPressed()` (ein `GetKeyDown` und Modifier-Prüfungen).
- Der Vergleich eines bool, int oder float.
- Null-Prüfungen.
- Eine Eigenschaft einer gecachten Referenz (`_panel.activeInHierarchy`).

Selbst viele davon pro Frame sind nicht messbar neben dem, was das Spiel tut (Rendering, Physik, KI). Nur das `HandleInput` der fokussierten Komponente läuft, daher wachsen die Kosten nicht mit der Anzahl der Bildschirme.

### Was nicht in jedem Frame passieren darf

- `GameObject.Find`, `FindObjectOfType`, `GetComponentsInChildren`: Suchen in der Hierarchie.
- Reflection-Lookups (ReflectionHelper cacht die FieldInfo; den Wert bei einem Tastendruck zu lesen ist in Ordnung).
- Strings zusammenbauen und formatieren (Druck auf die Garbage Collection).
- Sprechen: Ein Screenreader kann ohnehin keine 60 Meldungen pro Sekunde verarbeiten.

### Pro Frame prüfen, bei Änderung handeln

Für Poller (Oberflächen ohne Hook) und Status-Beobachter:

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

### Drosselung (Throttling)

Für mäßig teure Prüfungen ohne Event, an das man sich hängen kann (z.B. eine Liste durchlaufen):

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

### Hooks vor Polling

Wenn das Spiel eine Methode hat, die läuft, wenn etwas passiert, hooke sie:

- `OnMenuOpen()`, `OnMenuClose()` statt in jedem Frame `isOpen` zu prüfen,
- `OnItemSelected()`, `OnSelectionChanged()` statt einen Index mitzuverfolgen,
- `TakeDamage()`, `Heal()` statt die Gesundheit zu vergleichen.

Polling ist nur dann legitim, wenn das Spiel keine solche Methode anbietet. Die Architektur des Spiels entscheidet, und die Laufzeit-Probe des Slices zeigt, welche Methode feuert.

Die Beispiele verwenden Unity-APIs; andere Engines wenden dieselben Regeln mit ihren Entsprechungen an (`docs-de/appendix-d-other-engines.md`).

## Offline-Tests

`Tests/` (aus `templates/tests/`) läuft ohne das Spiel:

```powershell
dotnet test Tests
```

- **LocalizationTests**: Jeder LocalizationKey hat eine englische Zeile; jede englische Zeile hat einen Key; jede Übersetzung deckt das Englische ab und behält ihre `{0}`-Platzhalter; nichts spricht ein String-Literal.
- **ArchitectureTests**: Nur AccessibilityMgr (sowie ScreenReader und Main) sprechen mit dem Screenreader; nur AccessibleKey (und Main für F12) lesen rohe Tasten.
- **GameCompatTests** (aus PTCGL Access): parst die Mod mit Roslyn und löst jedes Spiel-Member, das die Mod in einem String benennt (Harmony-Ziele, AccessTools-Lookups, ReflectionHelper-Aufrufe, `GetField`/`GetMethod`), gegen die Assemblies des INSTALLIERTEN Spiels auf. Das Spiel wird über die `game`-Junction im Projektstamm, die Eigenschaft `GameDir` in `Tests\Tests.csproj` oder die Umgebungsvariable `GAME_DIR` gefunden. Ohne das Spiel gibt es SKIPPED aus, statt fehlzuschlagen.

Führe sie nach jeder Änderung aus, und nach einem Spiel-Update immer als Erstes.

## Der Kompatibilitätsbericht

Beim Start meldet Compat alles, was nicht aufgelöst werden konnte:

- Das Log enthält pro Problem eine "COMPAT:"-Zeile (welcher Hook oder welches Feld, und warum).
- Die Anzahl wird einmal gesprochen: "Warning: 2 parts of the mod do not match this game version. Some screens may be silent."
- F1 wiederholt die Warnung, damit der Spieler sie melden kann.

Spieler können dir genau sagen, was kaputt ist, und die Mod funktioniert überall sonst weiter.

## Ablauf bei einem Spiel-Update

Der Weg der HSA DevTools: Jedes Update wird zu einem überprüfbaren Diff.

1. **Neuer Fingerabdruck**: Lies die neue Spielversion aus; lege in `recon-records/` einen neuen Build-Fingerabdruck an (G1). Alte Belege werden erst wiederverwendet, wenn sie geprüft sind.
2. **In einen neuen Branch dekompilieren**:

```powershell
.\scripts\Decompile-Game.ps1 -Version 1.0.4
```

   Das Skript zweigt den Branch `1.0.4` vom Branch der aktuellen Version ab, dekompiliert und committet.
3. **Was hat sich geändert**:

```powershell
git -C decompiled diff 1.0.3 1.0.4 --stat
git -C decompiled diff 1.0.3 1.0.4 -- <path of a class the mod hooks>
```

   `docs/game-api.md` listet die gehookten Klassen auf; prüfe jede einzelne im Diff.
4. **Offline-Prüfung vor dem Start**: `dotnet test Tests`. GameCompatTests nennt jedes umbenannte oder entfernte Member mit Datei und Zeile.
5. **Reparieren**: Passe Namen, Hooks und Reflection an den neuen Code an; aktualisiere `docs/game-api.md`.
6. **Bauen, deployen, starten**: Die Compat-Anzahl beim Start muss null sein. Geh die wichtigsten Slices mit dem Screenreader durch.
7. **Records**: Bestätige die Laufzeit-Aussagen erneut, die das Update betroffen haben könnte (alles, dessen Klassen im Diff auftauchen); alles andere wird mit einer Notiz im Fingerabdruck übernommen.

**`decompiled/` niemals pushen, veröffentlichen oder weitergeben.** Es ist der proprietäre Code des Spiels. Dasselbe gilt für `recon-records/`, wenn es proprietäre Namen, Pfade oder Hashes enthält.

## Testen mit einem Screenreader

- Teste mit einem echten Screenreader (NVDA ist kostenlos), nicht nur mit dem Debug-Log.
- Achte auf: zu lang, zu viel auf einmal, fehlende Zustandsänderungen, falsche Reihenfolge, Wiederholungen.
- Jedes interaktive Element muss per Tastatur erreichbar sein.
- Teste mit ausgeschaltetem Bildschirm (oder mit einem sehenden Helfer, der nicht hinschaut), um vorausgesetzten visuellen Kontext aufzuspüren.
- Schnelle Tastendrücke: Pfeiltasten gedrückt halten, zweimal schnell Enter drücken; jeder Druck wird genau einmal und korrekt beantwortet.
- Sprache: Stell die Spielsprache um und wieder zurück; die Mod folgt innerhalb einer Sekunde.
- Fensterfokus: Mit Alt+Tab weg- und zurückwechseln; die Sprachausgabe stoppt, und der aktuelle Ort wird erneut angesagt, falls etwas verpasst wurde.
- Hol dir, wann immer möglich, Feedback von blinden Spielern.

## Abnahme

Die Aussage-Grade aus `docs-de/02-reconnaissance.md` gelten auch für Berichte:

- "Baut", "Tests bestehen", "der Hook hat gefeuert", "die Screenreader-Brücke hat den Text angenommen" sind Fortschritt, keine Abnahme.
- Ein Feature ist fertig, wenn der Benutzer (oder ein blinder Tester) es gehört und mit der Tastatur benutzt hat: `NVDA-MANUAL-CONFIRMED`. Bis dahin steht es unter "Pending Tests" in `project_status.md`.
- Bitte den Benutzer nur um diese Prüfung aus eigener Erfahrung und um Entscheidungen; Belege sammeln, Prüfungen ausführen und klare lokale Probleme beheben ist Claudes Aufgabe.
