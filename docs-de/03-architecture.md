# 03 Architektur

Deutsche Fassung von `docs/03-architecture.md`.

Die Architektur von Hearthstone Access (HSA), so wie sie die Templates in `templates/shared/` umsetzen. Dies ist die Referenz dafür, wie jeder Teil des Mods aufgebaut ist. `docs-de/04-building-screens.md` wendet sie auf konkrete Screens an.

## Projektstruktur

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

## Das Focus-Modell

AccessibilityMgr verwaltet:

- **einen aktuellen Screen** (`AccessibleScreen`): die Grundfläche, die das Spiel gerade zeigt (Titel, Hub, Spielwelt, Kampf),
- **einen Stapel von UIs** (`AccessibleUI`): Popups, Overlays, Dialoge und Untermenüs über dem Screen.

**Fokussiert** ist das oberste UI, falls eines offen ist, sonst der Screen. Nur die fokussierte Komponente:

- bekommt in jedem Frame `HandleInput()` aufgerufen,
- wird gehört, wenn sie `AccessibilityMgr.Output(this, text)` aufruft: Sprachausgabe von allen anderen wird verworfen.

Alles ergibt sich aus dieser einen Regel:

- Ein Popup, das sich über dem Shop öffnet, bringt den Shop zum Schweigen und übernimmt die Tasten. Kein Flag muss gesetzt werden.
- Wenn das Popup sich schließt, bekommt der Shop wieder den Focus, und `OnGainedFocus()` sagt erneut an, wo der Spieler ist.
- Ein Screen, der wechselt, während ein Popup offen ist, wartet still darunter und meldet sich, wenn das letzte UI geschlossen wird.
- `HideUI` funktioniert von jeder Stelle im Stapel aus: Das Spiel schließt Dinge, wann es will, auch unter einem anderen Popup. Ein totes UI, das vergraben liegen bleibt, würde später wieder auftauchen und die Tastatur besitzen, ohne dass es etwas zu steuern gibt.
- Wird ein UI angezeigt, das schon im Stapel liegt, wandert es nach oben, statt doppelt hinzugefügt zu werden.
- Wenn das Spielfenster den Focus verliert, verstummt die Sprachausgabe; wurde in der Zwischenzeit etwas verworfen, sagt sich die fokussierte Komponente erneut an, sobald das Fenster zurückkommt.

### Warum das State-Manager und Handler-Flags ersetzt

Ältere Versionen dieses Templates hatten `[Feature]Handler`-Klassen, die jeweils in jedem Frame abfragten "bin ich offen?", dazu einen AccessStateManager oder boolesche Flags, die entschieden, wer auf Enter reagieren darf. Dieses Design erzeugt die klassischen Bugs: ein Enter-Druck, der im selben Frame zwei Handler auslöst, ein geschlossenes Menü, das das dahinterliegende aktiviert, veraltete Listen nach der Rückkehr aus einem Overlay. Dafür brauchte es Hilfsfunktionen zum Verbrauchen von Eingaben, Regeln für die Update-Reihenfolge und Events zum Leeren von Caches.

Mit einer einzigen fokussierten Komponente gibt es nichts davon: Nur eine Komponente wird je nach Eingaben gefragt, verdeckte Komponenten können nicht sprechen, und jede Komponente liest Live-Daten, wenn sie den Focus bekommt. Die einzige verbleibende Koordination sind die Öffnen- und Schließen-Events des Spiels selbst, die die Hooks weiterreichen.

## Komponenten

Eine Komponente implementiert `AccessibleScreen` oder `AccessibleUI`; beide sind `AccessibleComponent`:

```csharp
void HandleInput();     // every frame while focused; read keys with AccessibleKey.X.IsPressed()
string GetHelp();       // F1: the keys that work RIGHT NOW, localized
void OnGainedFocus();   // shown, a UI above closed, window came back: say where the player is
```

Regeln:

- **Eine Klasse pro Spieloberfläche**, `Accessible<Name>`, sealed, in `Accessibility/Screens/<Area>/`. Sie entsteht aus einer Zeile der Surface-Lifecycle-Matrix (`docs-de/02-reconnaissance.md`, "Von den Aufzeichnungen zum Code").
- **Eine Instanz**, gehalten in einem statischen Feld; die Hooks rufen sie auf.
- Sie hält eine **Referenz** auf das Spielobjekt, das sie umhüllt (das `__instance` des Hooks), gültig zwischen ihrem Öffnen- und ihrem Schließen-Hook.
- `OnGainedFocus()` sagt den Titel und das aktuelle Element; mehr nicht. Hilfe und Hinweise kommen auf F1 oder werden in die Warteschlange gestellt.
- `GetHelp()` beschreibt nur, was jetzt funktioniert, in der Sprache des Spielers, mit Tastennamen aus AccessibleKey (lokalisiert).
- Komponenten rufen nie ScreenReader auf, lesen nie direkt `Input` und sprechen nie, wenn sie nicht fokussiert sind. Die Architekturtests in `Tests/` erzwingen die ersten beiden Punkte.

Screen oder UI?

- `AccessibleScreen`, wenn die Oberfläche die vorherige ersetzt (modale Tiefe 0). Immer nur einer zur Zeit: `SetScreen` / `ClearScreen`.
- `AccessibleUI`, wenn die Oberfläche über etwas erscheint und beim Schließen dorthin zurückkehrt (modale Tiefe 1 oder mehr): `ShowUI` / `HideUI`.

## Elemente

Wiederverwendbare Bausteine, die einer Komponente gehören. Sie sprechen ÜBER ihr Parent (`Output` prüft den Focus des Parents), daher verstummen sie mit ihm. Jedes `HandleInput()` gibt true zurück, wenn die Taste für das Element bestimmt war, sodass die Komponente sie verketten kann:

```csharp
public void HandleInput()
{
    if (_menu.HandleInput()) return;
    if (AccessibleKey.SHOP_READ_GOLD.IsPressed()) AccessibilityMgr.Output(this, ReadGold());
}
```

- **AccessibleMenu**: eine vertikale Liste von Optionen (Text oder Live-Text, plus eine Aktion). Pfeil hoch und runter lesen vor, Pos1 und Ende springen, Zifferntasten springen zur N-ten Option, Enter oder Leertaste wählen aus, Backspace oder Escape gehen zurück (falls eine Zurück-Aktion angegeben wurde). Spricht "Spielen, 1 von 4". Hält an seinen Rändern an: kein Wraparound, der Rand ist still und der Spieler bleibt, wo er ist; Pos1, Ende und Ziffern machen ein Umlaufen überflüssig. (Ältere Anleitungen nutzten Wraparound mit "erstes Element" / "letztes Element"; das Anhalten am Rand bei HSA hat sich als leichter zur Orientierung erwiesen. Wenn die eigenen Listen eines Spiels umlaufen, folge dem Spiel.)
- **AccessibleListOfItems&lt;T&gt;**: eine horizontale Reihe von Items (eine Hand Karten, eine Gruppe, eine Inventarreihe). Links und Rechts bewegen, Pos1 und Ende springen, Ziffern springen; das fokussierte Item behandelt Hoch und Runter selbst. Die Items werden bei jedem Tastendruck LIVE geholt, sodass die Liste dem Spiel folgt. Nimmt einen Leer-Text entgegen: niemals Stille. Mehrere Listen auf einem Screen sind getrennte Instanzen; Tab und Umschalt+Tab wechseln zwischen ihnen.
- **AccessibleItem**: etwas, das Zeile für Zeile gelesen wird (eine Karte, ein Gegenstand, eine Quest). `GetLines()` wird bei jedem Lesen aus Live-Daten neu aufgebaut; leere Zeilen werden weggelassen. Runter und Hoch gehen Zeile für Zeile, Umschalt+Hoch wiederholt die aktuelle Zeile, Umschalt+Runter liest bis zum Ende. Die erste Zeile ist die Kurzform, die gesprochen wird, wenn das Item den Focus bekommt.

Füge eigene Elemente für wiederkehrende Muster deines Spiels hinzu (ein Raster, eine Schieberegler-Zeile, ein Spielbrett): leite von `AccessibleElement` ab, nimm das Parent im Konstruktor entgegen und nutze `Output`.

## Hooks

Das Spiel teilt dem Mod mit, wann sich eine Oberfläche öffnet und schließt. Hooks sind verschachtelte `[HarmonyPatch]`-Klassen innerhalb der Komponente, der sie dienen, sodass die Komponente und ihre Auslöser in einer Datei leben:

```csharp
[HarmonyPatch(typeof(ShopScreen), "Open")]
private static class OpenHook
{
    private static void Postfix(ShopScreen __instance) =>
        AccessibilityMgr.Guard("AccessibleShop.OpenHook", () => _instance.OnOpened(__instance));
}
```

Regeln:

- **Jeder Hook-Body läuft innerhalb von `AccessibilityMgr.Guard(where, action)`.** Hooks laufen im eigenen Call Stack des Spiels. Eine Exception, die aus dem Mod-Code entweicht, kann die Spielmethode oder Coroutine töten, die ihn aufgerufen hat; in einem echten Mod hat eine Exception aus dem Öffnen-Hook eines Modals die Coroutine getötet, die ein Online-Match steuerte, und das Spiel komplett einfrieren lassen. Guard loggt jeden einzelnen Fehler einmal und kehrt zurück; das Spiel läuft weiter.
- Hooks übergeben die Komponente nur an AccessibilityMgr (`SetScreen`, `ClearScreen`, `ShowUI`, `HideUI`), rufen die eigenen Methoden der Komponente auf oder senden eine Benachrichtigung. Kein Sprechen, keine Logik.
- Zielnamen kommen aus `decompiled/` und aus dem Runtime-Probe des Slice, niemals aus dem Gedächtnis.
- Bevorzuge Postfix: Das Spiel hat die Oberfläche dann fertig aufgebaut. Nutze Prefix nur, um einen Zustand festzuhalten, den die Methode zerstört.
- Ein Schließen-Hook prüft, dass er dieselbe Instanz schließt, die er geöffnet hat (`if (game != _game) return;`).
- Patches werden von `Compat.PatchAll(harmony, assembly)` angewendet, eine Klasse nach der anderen: Ein Hook, dessen Ziel durch ein Update umbenannt wurde, wird gemeldet, und der Rest funktioniert weiter. Rufe niemals `harmony.PatchAll()` auf.
- HSA patcht den Quellcode des Spiels direkt (es ist in den Build des Spiels integriert); ein Loader-Mod erreicht dasselbe mit Harmony. Die Regel ist dieselbe: Der Hook-Punkt ist dort, wo das SPIEL entscheidet, dass die Oberfläche offen ist, nicht eine Vermutung aus Polling.

Oberflächen ohne hookbare Methode (nur am Zustand erkennbar) nutzen einen Poller: eine statische, parameterlose Methode mit `[AccessibilityPoller]`, die AccessibilityMgr in jedem Frame ausführt, egal wer den Focus hat, und die wie ein Hook abgesichert ist. Halte sie bei einer billigen Prüfung (das `activeInHierarchy` einer gecachten Referenz) und bevorzuge jeden Hook. Das Mod-Einstellungsmenü nutzt einen solchen Poller, um auf seine eigene Öffnen-Taste zu achten.

## Integration ins Spiel

**Nutze für Aktionen immer die eigenen Methoden des Spiels.** Aufheben, Kaufen, Auswählen, Bestätigen: Rufe die Methode oder den Button auf, die das Spiel verwendet.

Warum:

- Das Spiel erfasst Statistiken, Achievements und Fortschritt.
- Sounds und visuelles Feedback werden abgespielt (sehende Helfer und sehbehinderte Spieler verlassen sich darauf).
- Andere Systeme werden benachrichtigt (Quests, Tutorials, Netzwerk).
- Keine Desyncs oder kaputten Zustände.

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

Manipuliere Daten nur dann direkt, wenn es keine Alternative gibt, und halte den Grund in `docs/game-api.md` fest.

## Tasten

`AccessibleKey` deklariert jede Taste, auf die der Mod reagiert, EINMAL, mit ihren EXAKTEN Modifiern:

- Umschalt+Hoch ist nie zugleich Hoch; Strg+Enter ist nie zugleich Enter. Eine Taste mit Modifiern löst nur aus, wenn genau diese gehalten werden (außer bei Tasten, die mit `anyModifiers` deklariert sind, wie F1).
- Features rufen nie `Input.GetKeyDown` auf: Sie deklarieren `AccessibleKey.<NAME>` in ihrer eigenen partial-Datei (`AccessibleKey.Shop.cs`) und prüfen `KEY.IsPressed()`. So bleibt die gesamte Tastenbelegung per grep durchsuchbar, und zwei Features können nicht unbemerkt dieselbe Kombination belegen. Der Architekturtest erzwingt das.
- Nutze die gemeinsamen Tasten wieder (CONFIRM, BACK, Pfeiltasten, Pos1 und Ende, Ziffern, Tab), damit sich jeder Screen gleich anfühlt.
- Nur Tasten aus "Safe Mod Keys" in `docs/game-api.md`. Belege niemals eine Spieltaste.
- `ToString()` ist der lokalisierte gesprochene Name der Taste, daher lauten Hilfetexte `Format(KEY_HELP, AccessibleKey.SHOP_READ_GOLD)` und bleiben korrekt, wenn sich Tasten oder Sprachen ändern.
- `TryGetPressedNumber()` liefert 1 bis 9 (und 0 als 10) für Ziffernsprünge; `IsHoldingShift/Ctrl/Alt` für Mengen-Multiplikatoren.
- Input-Backend: Das Template liest das alte `UnityEngine.Input`. Für ein Spiel, das nur das Input-System-Package nutzt, tausche die beiden Low-Level-Methoden aus und löse Buchstaben über das Zeichen auf, das sie tippen (layoutabhängig), siehe `docs-de/appendix-a-unity-loaders-harmony.md`, "Input System vs. Legacy Input".

Globale Tasten, die AccessibilityMgr vor jeder Komponente behandelt: F8 (Mod an oder aus), F1 (Hilfe: fokussierte Komponente, dann globale Tasten, dann gegebenenfalls die Kompatibilitätswarnung). Main behandelt F12 (Debug-Log) selbst, damit es auch funktioniert, wenn der Mod kaputt ist. AccessibleModSettings öffnet sich mit Strg+F11.

Spieltasten und Mod-Tasten: Eine Taste, die der Mod nutzt, wird oft im selben Frame auch vom Spiel gelesen. Möglichkeiten, in der Reihenfolge der Präferenz:

1. Nutze nur Tasten, die das Spiel auf diesem Screen ignoriert (die Liste der sicheren Tasten).
2. Lass das Spiel handeln und beschreibe das Ergebnis (das Enter des Spiels auf einem fokussierten Button ist oft genau richtig; die Komponente spricht dann nur).
3. Blockiere die Eingabe des Spiels für diese Taste mit einem Prefix auf der Input-Methode des Spiels, nur solange die Komponente fokussiert ist (siehe `docs-de/04-building-screens.md`, "Key Capture").

## Sprachausgabe

- Komponenten: `AccessibilityMgr.Output(this, text, interrupt)`. Interrupt (Standard) für die Antwort auf einen Tastendruck; `interrupt: false` für nachfolgende Ansagen in der Warteschlange.
- Spielereignisse, die überall wichtig sind, wo der Spieler gerade ist: `AccessibilityMgr.OutputNotification(text)`, standardmäßig in der Warteschlange.
- Elemente: `Output(text)` über ihr Parent.
- Sonst spricht nichts. ScreenReader wird nur von AccessibilityMgr aufgerufen (und von Main für die Lademeldung), erzwungen durch den Architekturtest.
- Sprachausgabe wird verworfen, solange der Mod aus ist (F8) oder das Spielfenster im Hintergrund liegt.

Muster, Unterbrechen gegenüber Warteschlange, und Prioritäten: `docs-de/00-overview-and-principles.md`, "Grundsätze der Sprachausgabe".

## Lokalisierung

Der Mod spricht vom ersten Tag an die Sprache des Spiels.

- **Zuerst der eigene Text des Spiels.** Button-Beschriftungen, Gegenstandsnamen, Kartentexte, Beschreibungen: Lies sie aus dem Spiel (aus seinem UI-Text oder seiner Lokalisierungsabfrage), damit sie offiziell sind und in jeder Sprache vorliegen, die das Spiel mitbringt. `LocalizationUtils.GetGame("game_string_id", LocalizationKey.FALLBACK)` fragt das Spiel und fällt auf den Text des Mods zurück.
- **Die eigenen Worte des Mods** sind `LocalizationKey`s:
  - deklariert als `public static readonly LocalizationKey X = new LocalizationKey(nameof(X));` in `LocalizationKey.cs` (global) oder `LocalizationKey.<Feature>.cs`,
  - mit einer Zeile in `Localization/en/<Feature>.txt`: drei durch Tabs getrennte Spalten `KEY`, `TEXT`, `COMMENT` (dasselbe Format wie HSAs ACCESSIBILITY.txt, sodass Übersetzer in einer Tabellenkalkulation arbeiten können),
  - und dieselben Keys in jedem anderen Sprachordner (`Localization/de/<Feature>.txt`).
- `LocalizationUtils.Get(key)` und `Format(key, args)`. Platzhalter `{0}`, `{1}`.
- Die `.txt`-Dateien werden in die DLL eingebettet (csproj `EmbeddedResource` mit LogicalName `Localization/<lang>/<file>`). Keine losen Dateien zu installieren.
- Sprache: `GetGameLanguageTag()` fragt das Spiel einmal pro Sekunde, sodass ein Sprachwechsel in den Spieloptionen sofort wirkt. Fehlt eine Sprache oder eine Zeile, wird auf Englisch zurückgefallen; eine Übersetzung mit kaputten Platzhaltern fällt auf Englisch zurück, statt die Ansage zu verlieren.
- Die Kommentarspalte sagt, wo und wann der Text gesprochen wird und was jeder Platzhalter ist. Übersetzer brauchen das.

Regeln:

- **Ganze Sätze mit Platzhaltern, niemals zusammengeklebte Fragmente.** Grammatik und Wortstellung unterscheiden sich:

```csharp
// BAD: word order breaks in other languages
var text = LocalizationUtils.Get(LocalizationKey.YOU_HAVE) + " " + count + " " + LocalizationUtils.Get(LocalizationKey.ITEMS);

// GOOD: "You have {0} items" / "Du hast {0} Gegenstände"
var text = LocalizationUtils.Format(LocalizationKey.INVENTORY_COUNT, count);
```

- **Cache niemals einen übersetzten String in einem statischen Feld**: Er behält die Sprache, die beim ersten Lesen aktiv war. Lies `Get(...)` beim Sprechen.
- Key-Präfix = Feature (`GLOBAL_`, `MENU_`, `KEY_`, `SETTINGS_`, `SHOP_` ...), damit Dateien und Keys zusammenpassen.
- Keine String-Literale in der Sprachausgabe. Der Offline-Test schlägt fehl, wenn ein Key keine englische Zeile hat, eine Zeile keinen Key hat, eine Übersetzung einen Platzhalter verliert oder Code ein Literal spricht.
- Keine maschinelle Übersetzung ohne Prüfung durch einen Muttersprachler. Kurze, einheitliche Terminologie pro Sprache.

Eine Sprache hinzufügen: Lege `Localization/<tag>/` mit denselben Dateinamen und Keys an, übersetze die TEXT-Spalte und behalte den COMMENT. Am Code ändert sich nichts. `dotnet test Tests` meldet fehlende Zeilen und Platzhalter.

Spracherkennung bei anderen Engines (Godot `TranslationServer.GetLocale()`, Unreal `FInternationalization`): `docs-de/appendix-d-other-engines.md`.

## Kompatibilität und Reflection

Der Mod greift über Namen ins Spiel (Hook-Ziele, private Felder). Ein Spiel-Update, das einen davon umbenannte, ließ früher einen Screen ohne Erklärung verstummen. Hier ist jeder Bruch sichtbar:

- `Compat.PatchAll` wendet jede Hook-Klasse einzeln an und hält Fehlschläge fest.
- `Compat.ScanStatics` findet `static readonly`-Felder vom Typ FieldInfo, MethodInfo und PropertyInfo, die zu null aufgelöst wurden.
- `ReflectionHelper` (GetPrivateField, GetPrivateFieldValue, SetPrivateField, GetTextFromPrivateField) cacht jede Abfrage, durchläuft Basistypen und meldet einen fehlenden Namen einmal an Compat.
- `Compat.ReportStartup` loggt jedes Problem (Zeilen mit "COMPAT:") und spricht die Anzahl einmal aus; F1 wiederholt sie.
- Offline, noch bevor eine neue Spielversion überhaupt gestartet wird: `GameCompatTests` löst jeden Namen, den der Mod nutzt (Hook-Ziele und ReflectionHelper-Aufrufe mit literalen Namen), gegen die installierten Assemblies des Spiels auf.

Regeln:

- Übergib Member-Namen an ReflectionHelper als String-Literale (oder `nameof` auf einem öffentlichen Member), damit der Offline-Test sie finden und prüfen kann.
- Probiere niemals "mehrere Feldnamen nacheinander", um Updates zu überstehen: Das verschleiert, welcher der richtige ist. Ein verifizierter Name; wenn ein Update ihn umbenennt, melden Compat und der Test das, und du behebst es einmal.
- Details zu Unity-Reflection: `docs-de/appendix-b-unity-reflection.md`.

## Texteingabe

Wenn der Spieler in ein Textfeld des Spiels tippt (Namenseingabe, Suche, Chat), muss jede Taste das Feld erreichen. Die Komponente, der das Feld gehört, ruft `AccessibilityMgr.AllowTextInput()` auf, wenn das Feld den Focus bekommt, und `DisallowTextInput()`, wenn es abgeschickt oder verlassen wird. Solange das erlaubt ist, überspringt AccessibilityMgr das `HandleInput()` der fokussierten Komponente; F1 und F8 funktionieren weiterhin. Sage beim Focus die Beschriftung des Feldes und seinen aktuellen Inhalt an und auf Anfrage erneut den Inhalt.

## Erzwungene Tasten und Tutorials (HSA-Extras)

HSA hat rund um den Kern noch ein paar weitere Werkzeuge. Füge sie hinzu, wenn ein Spiel sie braucht; standardmäßig sind sie nicht im Template:

- **Forced Key**: "Drücke Enter, um fortzufahren". AccessibilityMgr wartet auf eine bestimmte Taste, führt eine Aktion aus und ignoriert alles andere; F1 antwortet "Press {0} to continue". Nützlich für Story-Texte, Tutorial-Schritte und Bildschirme am Ende eines Matches. Umsetzung: eine nullable Taste plus eine Aktion in AccessibilityMgr, geprüft vor der fokussierten Komponente.
- **Benachrichtigung mit Schließen-Button**: Wenn das Spiel einen blockierenden Hinweis mit einem einzigen Button zeigt, drückt Enter diesen Button, egal wo der Focus ist, und F1 sagt das an.
- **Tasten-Whitelist und -Blacklist**: Tutorials erlauben oft in jedem Schritt nur bestimmte Aktionen. HSA kann alle Tasten deaktivieren, eine Whitelist mit einem überschriebenen F1-Text für diesen Schritt aktivieren und bestimmte Tasten auf eine Blacklist setzen (zum Beispiel "Zug beenden" während des ersten Tutorials). Umsetzung: ein Enabled-Flag pro AccessibleKey, geprüft in `IsPressed()`.
- **Help Override**: ein schrittspezifischer F1-Text, der die Hilfe der Komponente ersetzt, bis er zurückgesetzt wird.
- **Erzählung und Warten**: einen Text sprechen und eine Aktion ausführen, wenn die Sprachausgabe voraussichtlich endet (geschätzt aus Länge und Sprechgeschwindigkeit), für geskriptete Abläufe. Jeder Tastendruck unterbricht die Erzählung.
- **Tasten für die Sprechgeschwindigkeit**: für SAPI-Nutzer Tasten zum Ändern der Geschwindigkeit; mit einem Screenreader gelten dessen eigene Einstellungen.
- **UIs im Übergang**: Während eines Szenenwechsels markiert HSA UIs als im Übergang befindlich, damit die Ansage des nächsten Screens nicht von den erneuten Ansagen der sich schließenden Popups abgeschnitten wird.
- **Dialog-Warteschlangen**: Wenn das Spiel Dialoge oder Popups in eine Warteschlange stellt, kündige den nächsten erst an, wenn das Spiel ihn tatsächlich zeigt (hooke die Show-Methode), niemals aus der Warteschlange selbst.

## Einstellungen

`AccessibleModSettings` ist ein AccessibleUI mit einem Menü über `ModConfig` (Strg+F11). ModConfig speichert nur Werte (MelonPreferences oder die BepInEx-Konfigurationsdatei); das Menü ändert und speichert sie. Eine Einstellung hinzufügen: eine Property in ModConfig, eine Option im Menü, ihre Text-Keys in `Global.txt` (oder in einer Settings-Feature-Datei).

## Den Kern erstellen

Phase 2 von `docs-de/01-setup-and-tooling.md`. Ersetze `NAMESPACE` und `MODNAME` in jedem Template.

1. Aus `templates/<loader>/`: `MODNAME.csproj` (csproj.template), `Main.cs`, `ScreenReader.cs`, `DebugLogger.cs`, `ModConfig.cs`.
2. Aus `templates/shared/` nach `Accessibility/`: `AccessibilityMgr.cs`, `AccessibleComponent.cs`, `AccessibleKey.cs`, `AccessibleMenu.cs`, `AccessibleItem.cs`, `AccessibleListOfItems.cs`, `AccessibleModSettings.cs`, `Compat.cs`, `ReflectionHelper.cs`.
3. Nach `Accessibility/Localization/`: `LocalizationKey.cs`, `LocalizationTable.cs`, `LocalizationUtils.cs`.
4. `Localization/en/Global.txt` aus `templates/shared/Localization/en/Global.txt.template`, und ein Ordner pro zusätzlicher Sprache (deutsches Template ist enthalten).
5. Fülle `LocalizationUtils.GetGameLanguageTag()` und `GetGame()` anhand von `docs/game-api.md`, "Lokalisierung".
6. Passe `AccessibleKey.cs` an die Liste der sicheren Tasten an (F8, Strg+F11 und die gemeinsamen Tasten dürfen nicht mit Spieltasten kollidieren).
7. `Tests/` aus `templates/tests/` (benenne `Tests.csproj.template` in `Tests.csproj` um, die anderen in `.cs`). Führe `dotnet test Tests` aus.
8. Das csproj referenziert `Unity.TextMeshPro.dll`, weil ReflectionHelper und das Screen-Template `TMPro.TMP_Text` lesen. Wenn das Spiel kein TextMeshPro hat, entferne die Referenz und diese Aufrufe.
9. Bauen, deployen, Spiel starten. Erwartet: "MODNAME loaded" wird gesprochen; F1 antwortet mit "Loading, please wait" und den globalen Tasten; F8 schaltet um; F12 schaltet das Debug-Logging um; Strg+F11 öffnet das Einstellungsmenü.
10. Der erste Slice: ein AccessibleScreen aus `AccessibleFEATURENAME.cs.template` (`docs-de/04-building-screens.md`).

## Einen bestehenden Handler-basierten Mod migrieren

Für einen Mod, der mit dem älteren Template gebaut wurde (`[Feature]Handler`-Klassen, AccessStateManager, `Loc.Get("key")`, `ScreenReader.Say` überall):

1. Erstelle den Kern neben dem alten Code (Schritte oben). Main ruft während der Migration sowohl die alten Handler als auch `AccessibilityMgr.Update()` auf.
2. Verschiebe einen Handler nach dem anderen, beginnend mit dem, dem Spieler zuerst begegnen:
   - Die Klasse wird zu `Accessible<Name> : AccessibleScreen` (oder `AccessibleUI` für Popups).
   - Ihr `IsOpen()`-Polling wird zu Öffnen- und Schließen-Hooks (suche nach den Methoden, die das setzen, was IsOpen geprüft hat). Gibt es wirklich keine, dann ein `[AccessibilityPoller]`, der bei einer Änderung SetScreen oder ShowUI aufruft.
   - Der Inhalt von `OnOpen()` kommt in `OnGainedFocus()`; `GetHelpText()` wird zu `GetHelp()`; Tastenprüfungen pro Frame kommen in `HandleInput()` mit AccessibleKey-Einträgen.
   - `ScreenReader.Say(x)` wird zu `AccessibilityMgr.Output(this, x)`; `ScreenReader.SayQueued(x)` wird zu `Output(this, x, interrupt: false)`.
   - Ihr AccessStateManager-Zustand und jeder Code zum Verbrauchen von Eingaben oder zum Entprellen wird gelöscht.
3. Lokalisierung: Jedes `Loc.Get("inventory_opened")` wird zu `LocalizationUtils.Get(LocalizationKey.INVENTORY_OPENED)`; die Strings aus den `Add(...)`-Aufrufen in `Loc.cs` kommen nach `Localization/<lang>/<Feature>.txt` (aus einer Spalte pro Sprache wird ein Ordner pro Sprache). Ein kleines Skript kann die Add-Aufrufe umwandeln; `dotnet test Tests` findet danach jeden Rest.
4. Entferne den Handler aus Main. Wenn keiner mehr übrig ist, lösche AccessStateManager, Loc und den Code zur Handler-Registrierung.
5. Nach jedem Schritt: bauen, `dotnet test Tests`, und den verschobenen Screen mit einem Screenreader testen.
