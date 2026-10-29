# 04 Screens bauen

Deutsche Fassung von `docs/04-building-screens.md`.

Wie aus einer Spieloberfläche eine barrierefreie Klasse wird. Voraussetzungen: Der Kern existiert (`docs-de/03-architecture.md`, "Den Kern erstellen"), und der Slice hat das Urteil `READY FOR SLICE IMPLEMENTATION` (`docs-de/02-reconnaissance.md`).

## Vor jedem Feature (Phase 3)

1. Lies in `docs/game-api.md` nach:
   - Tastenbelegungen des Spiels (keine Konflikte),
   - bereits dokumentierte Klassen, Methoden und Hook-Ziele,
   - das UI-Zugriffsmuster für diese Art von Screen (analysiere nicht erneut, was schon dokumentiert ist).
2. Prüfe den Eintrag im Feature-Plan: Sind seine Abhängigkeiten erledigt?
3. Prüfe die Slice-Records: die Zeilen zum Surface-Lifecycle, die Native-Input-Matrix, die offenen Lücken.
4. Für UI mit privaten Feldern: ReflectionHelper (`docs-de/appendix-b-unity-reflection.md`).
5. Arbeite die Checkliste am Ende dieser Datei durch.

Warum zuerst game-api.md: keine Tastenkonflikte, kein doppeltes Suchen, überall dieselben Muster, und UI-Zugriffsprobleme, die schon gelöst sind, bleiben gelöst.

Baue Features in der Reihenfolge, in der ein Spieler ihnen begegnet:

1. Hauptmenü (erster Kontakt, grundlegende Navigation).
2. Einstellungsmenü, falls vom Hauptmenü aus erreichbar.
3. Allgemeine Statusansagen (Gesundheit, Geld, Zeit).
4. Tutorial oder Startgebiet.
5. Kern-Gameplay (die häufigsten Aktionen).
6. Inventar und Menüs im Spiel (Pausenmenü, Karte).
7. Besondere Features (Crafting, Handel, Dialoge).
8. Endgame und Optionales (Achievements, Statistiken).

## Die Form jedes Screens

Beginne mit `templates/shared/AccessibleFEATURENAME.cs.template`:

1. Eine Datei pro Oberfläche: `Accessibility/Screens/<Area>/Accessible<Name>.cs`, sealed, eine statische Instanz.
2. `AccessibleScreen` für einen Basis-Screen, `AccessibleUI` für ein Popup oder Overlay (dann `ShowUI`/`HideUI` statt `SetScreen`/`ClearScreen`).
3. Verschachtelte `[HarmonyPatch]`-Hook-Klassen auf den Öffnen- und Schließen-Methoden des Spiels, jeder Body innerhalb von `AccessibilityMgr.Guard`.
4. Beim Öffnen: die Spielinstanz behalten, das Menü oder die Listen aufbauen, die Komponente an AccessibilityMgr übergeben. Beim Schließen: prüfen, dass es dieselbe Instanz ist, und sie freigeben.
5. `OnGainedFocus()`: Titel und aktuelles Element. `GetHelp()`: die Tasten, die jetzt funktionieren. `HandleInput()`: zuerst die Elemente, dann die Feature-Tasten.
6. Jeder Text aus LocalizationUtils oder aus dem Spiel; Keys in `LocalizationKey.<Feature>.cs` und `Localization/*/<Feature>.txt`; Feature-Tasten in `AccessibleKey.<Feature>.cs`.
7. Aktionen über den eigenen Weg des Spiels. Live-Daten bei jedem Tastendruck.

Ein minimales Options-Popup:

```csharp
public sealed class AccessibleOptionsPopup : AccessibleUI
{
    private static readonly AccessibleOptionsPopup _instance = new AccessibleOptionsPopup();
    private OptionsPopup _game;
    private AccessibleMenu _menu;

    public void HandleInput() => _menu?.HandleInput();
    public string GetHelp() => _menu?.GetHelp() ?? LocalizationUtils.Get(LocalizationKey.GLOBAL_PLEASE_WAIT);
    public void OnGainedFocus() => _menu?.StartReading();

    private void OnOpened(OptionsPopup game)
    {
        _game = game;
        _menu = new AccessibleMenu(this, LocalizationUtils.Get(LocalizationKey.OPTIONS_TITLE), () => _game.Close());
        var music = ReflectionHelper.GetPrivateField<Toggle>(game, "musicToggle");
        _menu.AddOption(() => ToggleLabel(LocalizationKey.OPTIONS_MUSIC, music), () => { music.isOn = !music.isOn; AccessibilityMgr.Output(this, OnOff(music.isOn)); });
        AccessibilityMgr.ShowUI(this);
    }

    private void OnClosed(OptionsPopup game)
    {
        if (game != _game) return;
        AccessibilityMgr.HideUI(this);
        _game = null;
        _menu = null;
    }

    // ToggleLabel, OnOff: small helpers over LocalizationUtils; hooks as in the template.
}
```

## Typen von Menüeinträgen

Jeder Steuerelementtyp hat seine eigene Ansage und seine eigenen Tasten. Die Beschriftung kommt immer zuerst.

**Button**
- Aktivierung: Enter oder Leertaste löst den eigenen Klick des Spiels aus (`button.onClick.Invoke()`).
- Ansage: die Beschriftung. "Neues Spiel, 1 von 5".
- Gerade nicht bedienbar: trotzdem aufgelistet, "Fortsetzen, nicht verfügbar".

**Slider**
- Links und Rechts verringern und erhöhen (Feature-Tasten oder eine Menüoption mit eigenem HandleInput).
- Ansage: Beschriftung, "Schieberegler", Wert, Hinweis. "Gesamtlautstärke, Schieberegler, 75 Prozent, Links und Rechts zum Einstellen".
- Schrittweite: die eigene Schrittweite des Spiels, sonst etwa 5 bis 10 Prozent des Bereichs. Sage nach jedem Schritt den neuen Wert an.

**Toggle oder Checkbox**
- Enter oder Leertaste schaltet um (über den Toggle des Spiels, damit seine Listener laufen).
- Ansage: Beschriftung, "Kontrollkästchen", Zustand. "Tutorials aktivieren, Kontrollkästchen, aktiviert".
- Nach der Änderung: der neue Zustand.

**Dropdown oder Auswahl**
- Links und Rechts wechseln durch die Optionen, oder Enter öffnet ein Untermenü (ein AccessibleUI) mit allen Optionen.
- Ansage: Beschriftung, "Dropdown", aktueller Wert. "Sprache, Dropdown, Englisch".
- Nach der Änderung: der neue Wert.

**Tab**
- Tab und Umschalt+Tab wechseln die Tabs (`AccessibleKey.NEXT_SECTION`/`PREV_SECTION`), oder die Tabs sind die erste Ebene eines zweistufigen Menüs.
- Ansage: Beschriftung, "Tab". "Audio, Tab". Danach das erste Element des Tab-Inhalts.

**Textfeld**
- Siehe "Texteingabe" weiter unten.

Die Typbezeichnungen ("Schieberegler", "Kontrollkästchen", "Tab") sind ebenfalls LocalizationKeys.

## Beschriftungen ermitteln

Wenn ein Element keine offensichtliche lesbare Beschriftung hat, nutze diese Reihenfolge:

1. **Die Lokalisierung des Spiels**: eine Komponente für lokalisierten Text mit einem Key, oder ein Text, der mit einer Lokalisierungsmarkierung beginnt (`%`, `#`, `@`): Löse ihn über den Lokalisierer des Spiels auf (`LocalizationUtils.GetGame`).
2. **Der eigene sichtbare Text des Elements**: das Text oder TMP_Text in seinen Kindern (`GetComponentInChildren<TMP_Text>()`).
3. **Das Parent**: Oft hält der Wrapper die Beschriftung (das Feld Title, Label oder Text einer Optionszeile), nicht das Steuerelement selbst.
4. **Tooltip-Text**: muss eventuell geparst werden (zum Beispiel "Category:Key").
5. **Eine Zuordnung bekannter Namen**: interne Namen zu lesbaren Beschriftungen ("SelectAll" zu "Alle auswählen", "EndTurn" zu "Zug beenden", "BtnOK" zu "OK"), gespeichert als LocalizationKeys, damit sie übersetzt werden.
6. **Der bereinigte Objektname**: Präfixe und Suffixe entfernen (`btn_`, `_button`), Leerzeichen vor Großbuchstaben einfügen. Letzter Ausweg, nicht lokalisiert; logge ihn im Debug-Modus, damit er später eine echte Beschriftung bekommt.

```csharp
private string ResolveLabel(GameObject obj)
{
    var loc = obj.GetComponent<LocalizedText>();                       // 1. game localization (names from decompiled/)
    if (loc != null && !string.IsNullOrEmpty(loc.Key))
        return LocalizationUtils.GetGame(loc.Key, LocalizationKey.GLOBAL_NOT_READABLE);

    var text = obj.GetComponentInChildren<TMPro.TMP_Text>();         // 2. own visible text
    if (text != null && !string.IsNullOrWhiteSpace(text.text)) return text.text;

    var row = obj.GetComponentInParent<OptionRow>();                    // 3. parent
    if (row != null && !string.IsNullOrEmpty(row.Title)) return row.Title;

    if (KnownNames.TryGetValue(obj.name, out var key))                  // 5. known names
        return LocalizationUtils.Get(key);

    DebugLogger.Log(LogCategory.Component, $"Unlabeled element: {obj.name}");
    return CleanObjectName(obj.name);                                   // 6. last resort
}
```

Das statische UI-Ledger des Slice sagt meistens schon, woher jede Beschriftung kommt; nutze das.

## Elemente sammeln

Baue das Menü wann immer möglich aus den eigenen Referenzen des Spiels auf (Felder der Screen-Klasse, die im statischen Ledger gefunden wurden). Nur wenn ein Screen dynamisch zusammengesetzt wird, sammle aus der Hierarchie:

Sammeln:

- Buttons mit echten Klick-Handlern (nicht dekorativ),
- Slider, Toggles und Dropdowns mit Change-Handlern,
- Tab-Buttons.

Überspringen:

- Steuerelemente ohne Handler,
- inaktive Objekte, unsichtbare Steuerelemente, Steuerelemente, deren übergeordnetes Panel ausgeblendet ist,
- interne Container (Namen mit "Area", "Panel", "Container", "Group"),
- dekorative Elemente (Hintergründe, Trennlinien).

Sortiere nach visueller Position, damit die Reihenfolge dem entspricht, was sehende Spieler sehen:

1. Zuerst Prioritätseinträge, falls das Spiel eine natürliche Hauptaktion hat ("Neues Spiel" vor "Beenden").
2. Dann von oben nach unten (in Unity UI bedeutet ein höheres Y weiter oben auf dem Bildschirm).
3. Bei horizontalen Reihen (Tabs): von links nach rechts.

```csharp
items.Sort((a, b) =>
{
    int prio = GetPriority(b) - GetPriority(a);
    if (prio != 0) return prio;
    return b.transform.position.y.CompareTo(a.transform.position.y);
});
```

Sammle, wenn sich die Komponente öffnet, und bei Inhalten, die sich ändern, erneut bei jedem Lesen (Live-Getter) statt nur einmal.

## Listen und Items

- Vertikale Auswahlen (Menüs, Einstellungen, eine Liste von Spielständen): AccessibleMenu.
- Reihen von Dingen mit Details (Karten auf der Hand, Gruppenmitglieder, Inventarreihe, Belohnungen): AccessibleListOfItems mit einer AccessibleItem-Unterklasse, deren `GetLines()` das Spielobjekt live liest:

```csharp
private sealed class InventorySlotItem : AccessibleItem
{
    private readonly InventorySlot _slot;
    public InventorySlotItem(AccessibleComponent parent, InventorySlot slot) : base(parent) => _slot = slot;

    protected internal override List<string> GetLines() => new List<string>
    {
        LocalizationUtils.Format(LocalizationKey.INVENTORY_SLOT_NAME, _slot.Item.DisplayName, _slot.Count),
        _slot.Item.Description,
        _slot.Item.IsEquipped ? LocalizationUtils.Get(LocalizationKey.INVENTORY_EQUIPPED) : "",
    };
}
```

- Mehrere Listen auf einem Screen (Hand, Spielbrett, Shop): getrennte Instanzen; Tab und Umschalt+Tab wechseln und sagen dabei den Namen der Liste und das aktuelle Item an.
- Positionen werden immer gesprochen ("3 von 12").
- Listen halten an ihren Rändern an (kein Wraparound). Pos1 und Ende springen, Ziffern springen zum N-ten Element.

## Zweistufige Navigation (Tabs und Kategorien)

Für Einstellungen mit Tabs oder kategorisierte Listen:

- Entweder sind die Tabs ein Menü, dessen Optionen den Tab-Inhalt als AccessibleUI öffnen (Backspace schließt ihn und kehrt zur Tab-Liste zurück, die sich erneut ansagt),
- oder die Komponente hält ein Menü pro Tab und wechselt mit Tab und Umschalt+Tab, wobei sie "Audio, Tab" und dann das erste Element ansagt.

Die erste Variante ist einfacher, wenn das Spiel selbst pro Tab ein Panel öffnet (hooke das); die zweite, wenn sich alle Tabs ein Panel teilen.

## Popups und modale Dialoge

- Jedes Popup ist ein eigenes AccessibleUI mit eigenen Öffnen- und Schließen-Hooks. Es übernimmt den Focus über allem, was darunter liegt; der Screen darunter verstummt automatisch.
- Kündige das Popup mit seinem Titel an, dann seinem Text, dann der ersten Option: "Kauf bestätigen. Schwert für 100 Gold kaufen? Ja, 1 von 2".
- Wenn es sich schließt, ist nichts zu tun: AccessibilityMgr sagt die fokussierte Komponente darunter erneut an.
- Eine generische Dialogklasse des Spiels, die für viele Zwecke genutzt wird (Bestätigung, Fehler, Info), ist eine einzige Komponente, die Titel und Text aus der Instanz liest.
- Benachrichtigungen des Spiels, die keine Eingabe annehmen (Toasts, Achievement-Banner), sind keine UIs: Der Hook ruft `AccessibilityMgr.OutputNotification(text)` auf.
- Blockierende Hinweise mit einem Schließen-Button: ein kleines AccessibleUI mit "Drücke Enter, um fortzufahren" (oder das Forced-Key-Muster, `docs-de/03-architecture.md`).

## Dynamische Inhalte

Wenn sich Inhalte ändern, während der Screen offen ist (Gegenstände verkauft, Karten gezogen, ein Timer):

- Live lesen: Menüs mit `Func<string>`-Beschriftungen, Listen mit `getItems`, die jedes Mal das Spiel abfragen.
- Wenn das Spiel bei einer Änderung ein Event auslöst oder eine Methode aufruft (`OnItemAdded`, `RefreshList`), hooke sie und kündige die Änderung an, wenn der Spieler davon wissen muss ("Schwert verkauft").
- Behalte die Auswahl, wenn das Element noch existiert; wurde das aktuelle entfernt, gehe zum nächstgelegenen gültigen und sage es an.
- Kündige niemals etwas aus einer veralteten Kopie an.

## Leere Zustände

Lass den Spieler niemals in Stille zurück:

- "Keine Gegenstände" (leere Liste oder leeres Menü).
- "Keine Auswahl" (nichts ausgewählt).
- "Inventar leer" (kein Inhalt).
- "Keine Ergebnisse" (Suche oder Filter hat nichts gefunden).

Zurück und Schließen funktionieren auch auf leeren Screens.

## Spielbretter und Gameplay-Screens

Kämpfe, Karten, Spielbretter und Spielwelten sind AccessibleScreens mit mehreren Elementen und vielen Feature-Tasten:

- Teile das Spielbrett in Zonen auf, zwischen denen der Spieler wechseln kann (deine Hand, dein Spielbrett, das Spielbrett des Gegners, der Shop), mit Tab oder eigenen Tasten; jede Zone ist ein AccessibleListOfItems.
- Separate "Lese"-Tasten (Status, Ressourcen, wer am Zug ist), deklariert in `AccessibleKey.<Feature>.cs`, die jeweils aus Live-Daten antworten.
- Aktionen von Gegnern und Umgebung sind Benachrichtigungen aus Hooks auf den eigenen Event-Methoden des Spiels (Karte gespielt, Schaden verursacht, Zug begonnen): in der Warteschlange, kurz, einheitlich.
- Zielauswahl (ein Ziel für einen Angriff oder Zauber wählen): ein AccessibleUI, das auf den Stapel gelegt wird, während das Spiel auf ein Ziel wartet; seine Liste enthält nur gültige Ziele, die das Spiel selbst anbietet; Bestätigen ruft den eigenen Zielauswahl-Aufruf des Spiels auf.
- Verlauf oder Log: ein AccessibleUI, das die letzten Ereignisse auflistet, damit eine verpasste Ansage erneut gelesen werden kann.
- Mengenaktionen: Modifier-Multiplikatoren (zum Beispiel Umschalt 5, Strg 10, Alt 100) mit `AccessibleKey.IsHoldingShift()` und Verwandten, angekündigt in der Hilfe des Screens.

## Texteingabe

Die Komponente, der ein Textfeld gehört:

- beim Focus: sagt die Beschriftung des Feldes und seinen aktuellen Inhalt an, ruft `AccessibilityMgr.AllowTextInput()` auf;
- beim Tippen: alle Tasten gehen an das Spiel; F1 und F8 funktionieren weiterhin;
- beim Abschicken oder Verlassen des Feldes (hooke das Submit oder Deselect des Spiels): `DisallowTextInput()`, sagt das Ergebnis an.

Lass die Texteingabe niemals erlaubt, nachdem das Feld verschwunden ist; Schließen-Hooks rufen ebenfalls `DisallowTextInput()` auf.

## Key Capture

Eine Mod-Taste, die auch das Spiel liest, würde beides auslösen. In der Reihenfolge der Präferenz:

1. Nutze eine Taste aus "Safe Mod Keys", die das Spiel auf diesem Screen ignoriert.
2. Lass das Spiel sie behandeln und beschreibe nur das Ergebnis (oft richtig für Enter auf dem fokussierten Button des Spiels).
3. Blockiere die Behandlung durch das Spiel nur, solange diese Komponente fokussiert ist, mit einem Prefix auf der Input-Methode des Spiels:

```csharp
[HarmonyPatch(typeof(GameInputHandler), "Update")]   // name from decompiled/
private static class BlockGameInputWhileFocused
{
    private static bool Prefix() => !AccessibilityMgr.IsFocused(_instance);   // false = skip the game's method
}
```

Blockiere so eng wie möglich (eine Methode, ein Screen), dokumentiere es in `docs/game-api.md` und blockiere niemals Tasten, die der Spieler für das Spiel selbst braucht.

## Zeitpunkt der Ansagen

- Screen oder Popup geöffnet: sein Name, dann das erste Element.
- Navigation: das aktuelle Element (mit Typ und Wert bei Nicht-Buttons) und die Position.
- Aktivierung: das Ergebnis ("Aktiviert", "Geändert zu Englisch", "75 Prozent").
- An einem Rand: Stille, und stehen bleiben (die Position hat dem Spieler schon gesagt, wo er ist).
- Leer: ein ausdrücklicher Leer-Text.
- Fehler: warum ("Aktivieren nicht möglich: nicht genug Gold").
- Tastenhinweise: in der Warteschlange nach der Öffnungsansage, oder nur auf F1.

## Debug-Modus

F12 schaltet den Debug-Modus um (Main). Wenn er an ist, gehen `DebugLogger.Log(...)` und jeder gesprochene Text ins Log des Loaders. Nutze ihn, um:

- Hook-Aufrufe sowie Wechsel von Screens und UIs zu loggen (AccessibilityMgr loggt diese bereits mit Info),
- gesammelte Elemente mit ihren ermittelten Beschriftungen zu loggen,
- Elemente ohne Beschriftung und Rückgriffe auf Ersatzbeschriftungen zu loggen,
- genau zu sehen, was in welcher Reihenfolge gesprochen wurde.

Fehler und Kompatibilitätsprobleme werden immer geloggt, nicht nur im Debug-Modus. Logge niemals datenschutzrelevante Werte (Kontonamen, Freundescodes), auch nicht im Debug-Modus.

## Unity UI Kurzreferenz

Typische Hierarchie:

```
Canvas
  Panel (e.g. "InventoryPanel")
    Header (title)
    Content
      ScrollView
        Items (list)
    Buttons (actions)
```

Komponenten, nach denen du suchen solltest: `Text` / `TextMeshProUGUI` (Beschriftungen), `Button`, `Toggle`, `Slider`, `InputField` / `TMP_InputField`, `ScrollRect`, `Dropdown` / `TMP_Dropdown`.

```csharp
bool isOpen = panel != null && panel.activeInHierarchy;   // active?
bool canClick = button != null && button.interactable;    // usable?
var label = button.GetComponentInChildren<TMPro.TMP_Text>()?.text;
var child = parent.transform.Find("ChildName");
foreach (Transform c in parent.transform) { }
```

`GameObject.Find`, `FindObjectsOfType` und `GetComponentsInChildren` durchsuchen die Hierarchie: Rufe sie auf, wenn sich eine Komponente öffnet, nicht in jedem Frame; bevorzuge die Referenzen, die dir der Hook gibt (`__instance` und seine Felder).

## Checkliste pro Screen

Die Struktur verstehen:

- [ ] Layout bekannt: linear, Raster, hierarchisch oder mit Tabs.
- [ ] Elementtypen bekannt: Buttons, Slider, Toggles, Dropdowns, Tabs, Textfelder.
- [ ] Öffnen- und Schließen-Methoden verifiziert (Runtime-Probe bestanden), Screen oder UI entschieden.
- [ ] Modale Dialoge, die er öffnen kann, identifiziert (jeder eine eigene Komponente).

Interaktion:

- [ ] Für jedes Element wird der eigene Aktivierungsweg des Spiels genutzt (onClick, die Methode des Spiels); nichts nachgebaut.
- [ ] Vorhandene Focus- oder Barrierefreiheitssysteme des Spiels geprüft und, falls vorhanden, wiederverwendet.

Beschriftungen:

- [ ] Alle Beschriftungen aussagekräftig (nicht leer, nicht "item123").
- [ ] Beschriftungen wo möglich aus dem eigenen Text oder der Lokalisierung des Spiels.
- [ ] Ersatzreihenfolge für den Rest angewendet; jeder Mod-Text ist ein LocalizationKey mit englischem Text.

Tasten:

- [ ] Gemeinsame Tasten genutzt (Pfeiltasten, Enter, Backspace, Pos1 und Ende, Ziffern, Tab).
- [ ] Neue Tasten in `AccessibleKey.<Feature>.cs` deklariert, nur aus "Safe Mod Keys".
- [ ] Mod-Tasten lösen nicht zusätzlich das Spiel aus (oder die Blockierung ist eng und dokumentiert).

Sprachausgabe:

- [ ] Öffnen angesagt (Name, erstes Element).
- [ ] Navigation sagt das aktuelle Element mit Position an.
- [ ] Leere Zustände ausdrücklich.
- [ ] Aktionen mit dem neuen Zustand bestätigt.
- [ ] F1 antwortet mit den Tasten, die hier funktionieren.
- [ ] Schließen kehrt zur Komponente darunter zurück, die sich erneut ansagt.

Robustheit:

- [ ] Hooks innerhalb von Guard; Schließen-Hook prüft die Instanz.
- [ ] Live-Daten bei jedem Lesen, nur Referenzen gecacht.
- [ ] `dotnet test Tests` besteht (Lokalisierung, Architektur, Spielkompatibilität).

Testen:

- [ ] Nach jeder Änderung getestet, ein Elementtyp nach dem anderen.
- [ ] Debug-Log geprüft: gesammelte Elemente und Beschriftungen wie erwartet.
- [ ] Mit einem echten Screenreader getestet; der Benutzer hat es bestätigt (`NVDA-MANUAL-CONFIRMED` in den Slice-Records, "Pending Tests" in project_status.md).
