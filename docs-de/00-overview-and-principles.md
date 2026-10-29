# 00 Überblick und Grundsätze

Deutsche Fassung von `docs/00-overview-and-principles.md`.

Dieses Template ist ein Referenz-Leitfaden, um jedes Spiel mit einem Screenreader spielbar zu machen, so wie Hearthstone Access (HSA) es macht: ein kleiner, strenger Kern (eine fokussierte Komponente, deklarierte Tasten, lokalisierte Sprachausgabe, abgesicherte Hooks) und eine barrierefreie Klasse pro Spielbildschirm, Slice für Slice aus geprüften Belegen gebaut.

Es ist für einen blinden Entwickler geschrieben, der mit Claude Code arbeitet, und für Claude Code selbst. Jede Anleitung verwendet Überschriften und Listen, niemals Tabellen.

## Der Weg durch die Anleitungen

Lies sie beim ersten Mal der Reihe nach. Später springst du direkt zu der, die zu deiner aktuellen Aufgabe passt.

1. `docs-de/00-overview-and-principles.md` (diese Datei): Ziele, Grundsätze der Sprachausgabe, die Architektur auf einer Seite, Gebote und Verbote.
2. `docs-de/01-setup-and-tooling.md`: Setup-Interview, Werkzeuge, Loader, Tolk, Dekompilierung in ein privates, versioniertes Repository, Build- und Deploy-Skripte, das Offline-Testprojekt.
3. `docs-de/02-reconnaissance.md`: wie du herausfindest, was das Spiel tut, BEVOR du Code schreibst. Die Projekt-Grundlage (Tier 1), dann der Slice-Ablauf (G0 bis G7), mit dem jedes Feature beginnt, und die Grep-Kataloge.
4. `docs-de/03-architecture.md`: die HSA-Architektur im Detail: Fokus-Modell, Komponenten und Elemente, Hooks, Tasten, Sprachausgabe, Lokalisierung, Kompatibilität. Enthält "Den Kern erstellen" und die Migration einer älteren, Handler-basierten Mod.
5. `docs-de/04-building-screens.md`: wie aus einer Oberfläche eine barrierefreie Klasse wird: Menüs, Listen, Einträge, Popups, Spielbretter, Texteingabe, leere Zustände und die Checkliste pro Bildschirm.
6. `docs-de/05-quality-and-updates.md`: Absicherung gegen Exceptions, Fehlerbehandlung, Performance, Offline-Tests, der Kompatibilitätsbericht, Spiel-Updates mit git diff, Abnahme mit dem Screenreader.
7. `docs-de/06-distribution.md`: Packen, Releases, Veröffentlichen.

Anhänge (Besonderheiten von Engines und Loadern):

- `docs-de/appendix-a-unity-loaders-harmony.md`: MelonLoader, BepInEx, Harmony, Tolk, Unity-Input-Backends.
- `docs-de/appendix-b-unity-reflection.md`: private Felder in Unity-Spielen, ReflectionHelper.
- `docs-de/appendix-c-legacy-unity.md`: Unity 5.x und älter.
- `docs-de/appendix-d-other-engines.md`: Godot, Unreal, eigene Engines: wie sich dieselbe Architektur überträgt.
- `docs-de/appendix-e-known-issues.md`: Kompatibilitätswarnungen, die beim Setup geprüft werden.
- `docs-de/appendix-f-git-github.md`: Git und GitHub für Einsteiger.

Weitere Teile des Templates:

- `templates/shared/`: die Kern-Klassen (AccessibilityMgr, AccessibleComponent, AccessibleKey, AccessibleMenu, AccessibleItem, AccessibleListOfItems, Compat, ReflectionHelper, Lokalisierung) und das Bildschirm-Beispiel AccessibleFEATURENAME.
- `templates/melonloader/`, `templates/bepinex/`: Loader-spezifische Main, ScreenReader, DebugLogger, ModConfig, csproj.
- `templates/tests/`: das Offline-Testprojekt (Lokalisierung, Architektur und Prüfungen der Spielkompatibilität).
- `recon/`: der Recon-Ablauf und sein Validator `uar` (Drittanbieter, MIT, siehe `THIRD-PARTY-NOTICES.md`).
- `scripts/`: Build, Deploy, Dekompilieren und Setup-Prüfungen.

## Woher die Ideen stammen

- **Hearthstone Access** (HSA): die umfassendste Screenreader-Mod eines kommerziellen Spiels, über Jahre von Spiel-Updates hinweg gepflegt. Die Architektur (AccessibilityMgr mit einem Bildschirm und einem UI-Stapel, AccessibleComponent, AccessibleKey, AccessibleMenu, LocalizationKey mit tabulatorgetrennten Textdateien, der DevTools-Ablauf mit Dekompilierung pro Version) folgt ihr. Der Code von HSA wird nicht in dieses Template kopiert; die Muster werden beschrieben und neu implementiert.
- **PTCGL Access** (MIT, Copyright (c) 2026 RealAmethyst): die Unity/MelonLoader-Portierung derselben Architektur auf Pokemon TCG Live. Der Kompatibilitätsprüfer (Compat), der Offline-Test der Spielkompatibilität und die Absicherung gegen Exceptions stammen von dort.
- **unity-accessibility-recon** (MIT, Copyright (c) 2026 Sheldon): der belegbasierte Slice-Ablauf in `recon/` und `docs-de/02-reconnaissance.md`.

## Kerngrundsatz: Spielbarkeit, nicht Vereinfachung

**Das Ziel ist, das Spiel für blinde Spieler so spielbar zu machen, wie sehende Spieler es erleben.** Barrierefreiheit bedeutet gleichen Zugang zum Gameplay, keine vereinfachte Version.

- **Keine Cheats ohne Nachfrage:** Schlage Cheats oder Vereinfachungen nur vor, wenn es absolut keinen anderen Weg gibt, eine Mechanik zugänglich zu machen.
- **Nie automatisch einbauen:** Implementiere Cheats oder Abkürzungen nie, ohne vorher zu fragen.
- **Volles Spielerlebnis:** Alle Mechaniken, Herausforderungen und Entscheidungen bleiben beim Spieler. Die Mod wählt niemals stillschweigend Dialoge, Ziele, Routen, Käufe oder andere bedeutsame Ergebnisse.
- **Die Wege des Spiels nutzen:** Jede Aktion läuft über die Methode oder den Button, den das Spiel selbst verwendet (siehe "Integration ins Spiel" in `docs-de/03-architecture.md`).

## Technische Ziele

- Sprachausgabe über eine Screenreader-Brücke (Tolk unter Windows: NVDA, JAWS, SAPI als Fallback).
- Vollständig per Tastatur spielbar; nirgends ist eine Maus nötig.
- Linearer, gut strukturierter Text: keine Tabellen, keine Grafiken, keine räumlichen Layouts.
- Die Mod spricht die Sprache des Spiels.
- Die Mod übersteht Spiel-Updates: Kaputte Teile werden gemeldet und bringen das Spiel nie zum Absturz.

## Die Architektur auf einer Seite

Details in `docs-de/03-architecture.md`. Die Kurzfassung:

- **AccessibilityMgr** hält EINEN aktuellen Bildschirm und einen STAPEL von Popups (UIs) darüber. Nur die fokussierte Komponente (die oberste UI, sonst der Bildschirm) bekommt Tasten und darf sprechen. Alles andere schweigt. Es gibt keine State-Machine, die synchron gehalten werden muss: Der Fokus ist der Zustand.
- **AccessibleScreen / AccessibleUI**: eine Klasse pro Spiel-Oberfläche (Titelbildschirm, Shop, Kampf, ein Bestätigungs-Popup), benannt `Accessible<Name>`. Sie implementiert drei Methoden: `HandleInput()`, `GetHelp()`, `OnGainedFocus()`.
- **Elemente** (AccessibleMenu, AccessibleListOfItems, AccessibleItem) sind wiederverwendbare Bausteine, die einer Komponente gehören; sie sprechen über sie und verstummen deshalb mit ihr.
- **Hooks**: verschachtelte Harmony-Patches auf die eigenen Öffnen- und Schließen-Methoden des Spiels rufen `SetScreen`, `ClearScreen`, `ShowUI`, `HideUI` auf, immer innerhalb von `AccessibilityMgr.Guard(...)`, damit ein Mod-Fehler niemals das Spiel kaputt machen kann.
- **AccessibleKey**: Jede Taste, die die Mod verwendet, wird einmal mit ihren exakten Modifikatoren deklariert. Features lesen nie rohe Tasten.
- **Lokalisierung**: Jeder gesprochene Text ist ein `LocalizationKey` mit englischem Text in `Localization/en/*.txt` (tabulatorgetrennt), Übersetzungen daneben, und die eigenen Texte des Spiels werden bevorzugt, wo es sie gibt.
- **Compat**: Jede Hook-Klasse wird einzeln angewendet; ein Hook, dessen Ziel durch ein Update umbenannt wurde, wird gemeldet (Log, F1, Ansage beim Start), und der Rest der Mod funktioniert weiter. Der Offline-Test prüft jeden Namen gegen das installierte Spiel, noch bevor du es überhaupt startest.

## Grundsätze der Sprachausgabe

### Was angesagt wird

- Kontextwechsel: Bildschirmwechsel, Popups, Wechsel von Modus und Phase.
- Das aktuell fokussierte Element, mit Position.
- Änderungen am Spielzustand, die der Spieler braucht (Gesundheit, Ressourcen, Zugwechsel).
- Ergebnisse von Aktionen und Fehler.
- Ereignisse von anderswo, die überall wichtig sind, wo der Spieler gerade ist (Zug des Gegners, Match gefunden): Das sind Benachrichtigungen.

### Wie angesagt wird

- Schlichter Text, optimiert für Screenreader.
- Knapp, aber vollständig. Details gehören in navigierbare Zeilen (ein Eintrag, der Zeile für Zeile gelesen wird), nicht in einen einzigen langen Satz.
- Das Wichtigste zuerst: der Name, dann der Zustand, dann die Details.
- Nur bei Änderung, nie in jedem Frame.
- Wiederholbar: Der Spieler kann sich den aktuellen Eintrag jederzeit noch einmal anhören und mit F1 die Tasten abrufen, die gerade funktionieren.

### Ansage-Muster

Verwende überall dasselbe Format. Alle Muster sind vollständige, lokalisierte Sätze mit Platzhaltern, niemals zusammengeklebte Fragmente.

Navigation in Menü oder Liste:

```
[Element], [Position] of [Total]
Example: "Health Potion, 3 of 12"
```

Öffnen eines Bildschirms oder Popups:

```
[Title], [first element]
Example: "Inventory, Health Potion, 1 of 12"
```

Statusänderung:

```
[What] [direction] [value] (optional: [context])
Example: "Health dropped to 45 of 100"
```

Bestätigung einer Aktion:

```
[Action] [object] (optional: [result])
Example: "Used Health Potion, health full"
```

Fehler oder Ablehnung:

```
[Reason]
Example: "Cannot do that: inventory full"
```

Deaktiviertes Element (aufgelistet, nicht versteckt):

```
[Label], disabled
Example: "Continue, disabled"
```

### Unterbrechende und eingereihte Sprachausgabe

- **Unterbrechend** (Standard für die Antwort auf einen Tastendruck): stoppt die vorherige Ausgabe und spricht sofort. Der Spieler hat eine Taste gedrückt und will die neue Antwort hören, nicht das Ende der alten.
- **Eingereiht**: wartet, bis die vorherige Ausgabe fertig ist. Verwende das für Nachträge nach einer Hauptansage: verfügbare Tasten, nachdem ein Popup aufgeht, Antwortmöglichkeiten nach einem Dialogtext, Hinweise nach einer Bestätigung.
- **Benachrichtigungen** (AccessibilityMgr.OutputNotification) werden standardmäßig eingereiht, damit sie nicht abschneiden, was der Spieler gerade liest.

```csharp
AccessibilityMgr.Output(this, LocalizationUtils.Format(LocalizationKey.QUEST_ACCEPTED, quest.Title));
AccessibilityMgr.Output(this, LocalizationUtils.Format(LocalizationKey.QUEST_LOG_HINT, AccessibleKey.OPEN_QUEST_LOG), interrupt: false);
```

### Priorität, wenn viel gleichzeitig passiert

Das ist spielspezifisch; als grobe Richtschnur:

- Meist unterbrechen: kritischer Zustand (Gesundheit kritisch, Game Over), Wechsel von Bildschirm oder Modus, Dialogtext und Auswahlmöglichkeiten, Fehler.
- Meist einreihen: Statusmeldungen, Hinweise, Tooltips, Tastenhinweise nach dem Öffnen eines Panels.
- Das Fokus-Modell beseitigt bereits die meisten Konflikte, weil verdeckte Bildschirme nicht sprechen können.
- Nur wenn ein Spiel den Spieler mit gleichzeitigen Ereignissen überflutet (Echtzeitstrategie, hektisches Action-RPG), kommt zusätzlich eine Filterung obendrauf: Unterdrückung von Duplikaten, Zusammenfassen ("3 enemies defeated"), eine Einstellung für die Ausführlichkeit. Fang ohne das an.
- Im Zweifel: mit einem Screenreader testen und zuhören. Geht wichtige Information unter: Priorität erhöhen. Geht Kontext verloren, weil alles unterbricht: mehr einreihen.

## Ausgabeformat für Screenreader

Das gilt für alles, was die Mod spricht, UND für alles, was Claude für den Benutzer schreibt (Dokumentation, Berichte, Chat).

Vermeide:

- Tabellen (Pipe-Zeichen werden einzeln vorgelesen).
- ASCII-Art oder Grafiken.
- Bedeutung, die über Position oder Spalten transportiert wird.

Bevorzuge:

- Überschriften und Aufzählungslisten.
- Einen Eintrag pro Zeile.
- Zusammengehörige Informationen unter einer klaren Bezeichnung gruppiert.
- Jedes Mal dieselbe Reihenfolge der Informationen.

Beispielformat statt einer Tabelle:

**Name des Eintrags**
- Eigenschaft: Wert
- Eigenschaft: Wert

## Tastatur-Design

- Belege nie eine Taste, die das Spiel verwendet. Die Liste der Spieltasten und der sicheren Mod-Tasten entsteht während der Recon (`docs/game-api.md`).
- Dieselbe Bedeutung auf jedem Bildschirm: Pfeiltasten navigieren, Enter bestätigt, Backspace geht zurück, Pos1 und Ende springen, F1 ist die Hilfe.
- Exakte Modifikatoren: Shift+Pfeil hoch ist nie zugleich Pfeil hoch.
- F1 ist kontextabhängig: zuerst die Tasten der fokussierten Komponente, dann die globalen Tasten.
- F8 schaltet die Mod aus und ein (für sehende Helfer und zum Debuggen), F12 schaltet das Debug-Logging um, Strg+F11 öffnet die Mod-Einstellungen. Ändere sie, falls das Spiel sie verwendet.
- Massenaktionen mit Modifikatoren, wo das Spiel Mengen kennt (zum Beispiel Shift für 5, Strg für 10, Alt für 100), angesagt, wenn das Panel aufgeht.
- Schnelle Tastendrücke abfangen: Jeder Tastendruck liest den aktuellen Live-Zustand und antwortet genau einmal.

## Gebote und Verbote

Gebote:

- Prüfe jeden Klassen-, Methoden- und Feldnamen in `decompiled/`, bevor du ihn verwendest. Niemals raten.
- Bevorzuge die eigenen Texte und die Lokalisierung des Spiels vor allem, was die Mod selbst schreibt.
- Lies Spieldaten bei jedem Tastendruck live; cache nur Objekt-Referenzen, niemals Werte.
- Gib jedem Bildschirm eine `GetHelp()`-Antwort für F1.
- Sage leere Zustände ausdrücklich an ("No items").
- Teste mit einem echten Screenreader.

Verbote:

- Keine langen Ansagen, die den Screenreader blockieren.
- Keine Tabellen oder ASCII-Art in der Ausgabe.
- Keine redundanten Ansagen (dasselbe zweimal).
- **Niemals Spieltasten überschreiben.**
- **Niemals stillschweigend auf einen gecachten Wert zurückfallen**, wenn ein Live-Lesen fehlschlägt: logge es, sag es an, scheitere sichtbar. Ein blinder Spieler kann nicht sehen, dass die Information veraltet ist.
- **Niemals Spielmethoden umgehen** (Einträge direkt zu einer Liste hinzuzufügen, statt die Aufheben-Methode aufzurufen, macht Achievements, Sounds, Statistiken und Synchronisierung kaputt).
- Lass niemals eine Exception aus einem Hook ins Spiel entkommen.
- Sprich niemals von irgendwo anders als aus der fokussierten Komponente (oder als Benachrichtigung).

## Häufige Fallstricke

- Zu viel auf einmal ansagen oder in jedem Frame ansagen.
- Wichtige Zustandsänderungen nicht ansagen.
- Unterschiedliche Tasten oder unterschiedliche Formulierungen für dieselbe Aktion auf verschiedenen Bildschirmen.
- Visuellen Kontext voraussetzen, der nie gesprochen wurde.
- Ein generischer Cursor nach dem Motto "lies vor, was gerade ausgewählt ist" statt einer Klasse pro Oberfläche: Er liest auf der Hälfte der Bildschirme das Falsche vor und auf dem Rest gar nichts.
- Mit einer Karte des ganzen Spiels anfangen statt mit dem nächsten kleinen Slice.
- "Es kompiliert" oder "die Methode wurde aufgerufen" mit "es funktioniert für den Spieler" verwechseln. Beweisen kann das nur der Spieler, der es hört und danach handelt.

## Kurzreferenz: Best Practices

1. Bei Änderung ansagen, nie in jedem Frame.
2. In Listen immer die Position angeben ("3 of 12").
3. Leere Zustände ausdrücklich ansagen: niemals Stille.
4. Aktionen bestätigen: was getan wurde und der neue Zustand.
5. Tastenhinweise, wenn ein Panel aufgeht, eingereiht.
6. Gleiche Aktionen, gleiche Ansagen, überall.
7. Logging immer verfügbar (Debug-Modus, F12).
8. Eine barrierefreie Klasse pro Oberfläche, geöffnet und geschlossen durch die eigenen Methoden des Spiels.
