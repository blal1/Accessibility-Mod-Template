# 02 Recon

Deutsche Fassung von `docs/02-reconnaissance.md`.

Wie du herausfindest, was das Spiel wirklich tut, bevor du Code schreibst. Zwei Ebenen:

1. **Projekt-Grundlage (Phase 1, Tier 1)**: einmal erledigt, bevor der Kern erstellt wird. Struktur, Eingabe, UI-System, Fokus-Modell, Sprachsystem. Ohne sie lässt sich nichts sicher bauen.
2. **Der Slice-Ablauf (G0 bis G7)**: für JEDES Feature. Immer ein kleines Spielerziel auf einmal, Belege nach ihrer Stärke eingestuft, ein ausdrückliches Urteil über die Bereitschaft vor der Implementierung. So beginnt jedes Feature.

Werkzeuge: der dekompilierte Code in `decompiled/` (erstellt mit `scripts/Decompile-Game.ps1`, siehe `docs-de/01-setup-and-tooling.md`), der Validator `uar` in `recon/` und das laufende Spiel mit dem Debug-Modus der Mod.

## Niemals raten, immer prüfen

**Bevor du eine Komponente schreibst, eine Spielmechanik verwendest oder ein UI-Element benennst, durchsuche den dekompilierten Quellcode in `decompiled/`.** Geratene Klassennamen, Methodennamen oder Mechaniken führen immer zu Bugs.

Warum das wichtig ist:

- Spiele verwenden unerwartete Namen (`CardZone` statt `Hand`, `UIManager` statt `GameUI`).
- Interne Mechaniken funktionieren selten so, wie sie von außen aussehen.
- Falsche Annahmen erzeugen Code, der kompiliert, aber nichts tut, und das ist schwer zu debuggen.
- Reflection auf ein Feld, das nicht existiert, scheitert stillschweigend (ReflectionHelper und Compat des Templates melden es wenigstens).

Was du VOR jeder Implementierung prüfst:

- Für einen neuen Bildschirm oder ein Popup: den exakten Klassennamen; seine Methoden zum Öffnen, Anzeigen, Schließen und Verstecken; seine Eltern- und Kind-Struktur; Events und Callbacks, die er auslöst.
- Für eine Spielmechanik: die relevanten Klassen (`InventoryManager`, `PlayerInventory`, `ItemStorage`?); öffentliche Properties und Felder; Singleton-Instanzen und wie man sie erreicht; die Methoden, die den Zustand ändern.
- Für UI-Elemente: exakte Komponententypen (Text, TextMeshProUGUI, Button, ...), Feldnamen, Verschachtelung.
- Für Tasten: wie das Spiel Eingaben liest (Legacy Input, Input System, eine eigene Schicht); welche Tasten belegt sind; ob es Eingabe-Blocker oder ein Fokus-System gibt.

Typische Suchmuster:

```
UI screens:
- "class.*Menu" or "class.*Screen" or "class.*Panel"
- "public static.*Instance" (singletons)
- "void Show" or "void Open" or "void Display"

Game mechanics:
- "class.*Manager" or "class.*Controller"
- "public.*List<" or "public.*Dictionary<" (collections)
- "static.*Current" or "static.*Active" (active state)

Specific features:
- the English word for the mechanic
- a text that is visible in the game (it leads to the localization id, and the id leads to the code)
- variable names that seem logical
```

Checkliste, bevor du Code schreibst:

- [ ] Relevante Klassen in `decompiled/` gefunden
- [ ] Exakte Namen notiert (Groß- und Kleinschreibung beachten!)
- [ ] Zugriffsweg verstanden (Singleton, FindObjectOfType, Referenz aus dem `__instance` eines Hooks)
- [ ] Öffentliche API der Klasse bekannt (Methoden, Properties)
- [ ] Erkenntnisse in `docs/game-api.md` eingetragen

Falsch gegen richtig:

```csharp
// WRONG (guessing): "the inventory is surely called InventoryPanel..."
var inventory = GameObject.Find("InventoryPanel");
// Does nothing: the real name is UI_Inventory_Main
```

```
RIGHT (researching):
1. Grep decompiled/ for "Inventory"
2. Found: class UI_Inventory_Main : MonoBehaviour
3. Its Show() and Hide() methods are the hook targets
4. Code: [HarmonyPatch(typeof(UI_Inventory_Main), "Show")]
```

Erneut recherchieren:

- für JEDEN neuen Bildschirm und jede neue Mechanik,
- immer wenn Code unerwartet nichts tut,
- immer wenn Reflection oder ein Hook als fehlend gemeldet wird,
- nach Spiel-Updates (Namen ändern sich; `git -C decompiled diff` zeigt genau, welche).

## Projekt-Grundlage (Phase 1)

**VORAUSSETZUNG: Der dekompilierte Quellcode MUSS in `decompiled/` liegen.** Phase 1 arbeitet ausschließlich mit dem dekompilierten Code, nicht mit Internet-Recherche, Wikis oder Vermutungen. Wenn `decompiled/` leer ist, geh zurück zu Schritt 7 von `docs-de/01-setup-and-tooling.md`. Alle Grep-Befehle unten zielen auf `decompiled/`.

Mach nicht alles auf einmal:

- **Tier 1 (unverzichtbar, vor JEGLICHEM Code):** 1.1 bis 1.5: Struktur, Eingabe, UI, Zuordnung zum Fokus-Modell, Lokalisierungssystem.
- **Tier 2 (genau dann, wenn es gebraucht wird, im Slice des Features, das es braucht):** 1.6 bis 1.8: Mechaniken, Status, Events. Analysiere das Inventar direkt bevor du AccessibleInventory baust, nicht Monate im Voraus.
- **Tier 3 (wenn relevant):** 1.9 und 1.10: Dokumentation, Tutorial.

### 1.1 Strukturüberblick (Tier 1)

Bestandsaufnahme der Namespaces:

```
Grep pattern: ^namespace\s+
```

Ordne sie ein in UI/Menüs, Gameplay, Audio, Eingabe, Speichern/Laden, Netzwerk, Sonstiges.

Singletons (die wichtigsten Zugangspunkte ins Spiel):

```
Grep pattern: static.*instance
Grep pattern: \.instance\.
Grep pattern: static.*Get\(\)
```

Liste jeden mit Klassenname, was er verwaltet und wichtigen Properties auf.

### 1.2 Eingabe-System (Tier 1, KRITISCH)

Alle Tastenbelegungen:

```
Grep pattern: KeyCode\.
Grep pattern: Input\.GetKey
Grep pattern: Input\.GetKeyDown
Grep pattern: Input\.GetKeyUp
Grep pattern: Keyboard\.current
Grep pattern: InputAction
```

Für JEDEN Treffer: Datei und Zeile, Taste, was passiert, in welchem Kontext.

Mauseingabe:

```
Grep pattern: Input\.GetMouseButton
Grep pattern: OnClick
Grep pattern: OnPointerClick
Grep pattern: OnPointerEnter
```

Eingabe-Controller:

```
Grep pattern: class.*Input.*Controller
Grep pattern: class.*InputManager
```

Notiere auch, WELCHES Input-Backend das Spiel verwendet: das alte `UnityEngine.Input`, das Input-System-Paket (`Keyboard.current`, `InputAction`) oder beides. AccessibleKey muss dasselbe Backend lesen (`docs-de/appendix-a-unity-loaders-harmony.md`, "Input System vs. Legacy Input").

Ergebnis: die Liste der Tasten, die das Spiel NICHT verwendet = sichere Mod-Tasten.

**PFLICHT-AUSGABE, jetzt, nicht später:**

1. Trage ALLE Tastenbelegungen des Spiels in `docs/game-api.md` ein, Abschnitt "Game Key Bindings".
2. Trage die sicheren Mod-Tasten in `docs/game-api.md` ein, Abschnitt "Safe Mod Keys".
3. Hake die Eingabe-Punkte in `project_status.md` ab.

Mach nicht mit 1.3 weiter, bevor beide Abschnitte existieren. Tastenkonflikte sind der häufigste Mod-Bug, und genau dieser Schritt wird am häufigsten übersprungen.

### 1.3 UI-System (Tier 1, KRITISCH)

UI-Systeme sind das Herz einer Barrierefreiheits-Mod. Wie das Spiel seine Bildschirme aufbaut und öffnet, entscheidet, wohin jeder Hook kommt.

UI-Basisklassen:

```
Grep pattern: class.*Form.*:
Grep pattern: class.*Panel.*:
Grep pattern: class.*Window.*:
Grep pattern: class.*Dialog.*:
Grep pattern: class.*Popup.*:
Grep pattern: class.*Menu.*:
Grep pattern: class.*Screen.*:
Grep pattern: class.*Canvas.*:
```

Finde heraus: Gibt es eine gemeinsame Basisklasse? Wie werden Fenster geöffnet und geschlossen (ein zentraler Manager mit einem Stapel, oder jedes Panel für sich)? Gibt es einen "aktuellen Bildschirm" oder einen "Szenenmodus"?

Textanzeige:

```
Grep pattern: \.text\s*=
Grep pattern: SetText\(
Grep pattern: TextMeshPro
```

Tooltips:

```
Grep pattern: Tooltip
Grep pattern: hover
Grep pattern: description
```

Private serialisierte Felder (in Unity sehr häufig):

```csharp
[SerializeField]
private TextMeshProUGUI title;
```

Der Text ist dann nicht über öffentliche Properties erreichbar. Suche:

```
Grep pattern: \[SerializeField\]
Grep pattern: private.*Text
Grep pattern: private.*TMP
Grep pattern: private.*Button
```

Viele Treffer bedeuten, dass ReflectionHelper oft zum Einsatz kommt (`docs-de/appendix-b-unity-reflection.md`).

Dokumentiere in `docs/game-api.md`:

- UI-Basisklassen und ihre Hierarchie, jeweils mit dem Zugriffsweg auf den Text.
- Welche Felder privat sind, und die Namenskonvention (`m_PascalCase` oder `camelCase`).
- Beispiel-Snippets für häufige Zugriffsmuster.

Nach diesem Schritt weißt du:

1. wie du an den Text jedes UI-Elements kommst (Property, Methode oder privates Feld),
2. wie Auswahl und Fokus im Spiel funktionieren (Fokus-System? Highlight-Events?),
3. welche Methoden Bildschirme und Popups öffnen und schließen (die künftigen Hook-Ziele).

### 1.4 Zuordnung zum Fokus-Modell (Tier 1)

Das ersetzt die alte "State-Manager-Entscheidung". Mit der HSA-Architektur gibt es bei der Koordination nichts zu entscheiden: AccessibilityMgr gibt Tasten und Stimme an genau eine Komponente (siehe `docs-de/03-architecture.md`, "Das Focus-Modell"). Was du hier entscheidest, ist, wie die Oberflächen des Spiels darauf abgebildet werden:

- **Basis-Bildschirme** (immer nur einer): Titel, Hauptmenü, Hub, Welt, Kampf, Sammlung. Jeder wird ein `AccessibleScreen`. Welche Spielmethode oder welches Event markiert den Wechsel des Basis-Bildschirms? (Laden einer Szene, ein Moduswechsel eines Szenen-Managers, das Show eines Bildschirm-Controllers)
- **Overlays** (über einem Bildschirm gestapelt): Popups, Bestätigungsdialoge, Belohnungsbildschirme, Einstellungen, Untermenüs. Jedes wird eine `AccessibleUI`. Welche Methoden öffnen und schließen sie? Können mehrere gleichzeitig offen sein? Kann eines schließen, während ein anderes es verdeckt?
- **Benachrichtigungen**: Dinge, die passieren, egal wo der Spieler gerade ist (Toasts, Aktionen des Gegners, Timer). Sie werden zu `AccessibilityMgr.OutputNotification(...)` aus einem Hook.
- **Textfelder**: wo der Spieler tippt (Namen, Suche, Chat). Ihre Komponenten rufen `AllowTextInput()` / `DisallowTextInput()` auf.
- **Oberflächen ohne Öffnen- oder Schließen-Methode** (nur über den Zustand erkennbar): Kandidaten für einen `[AccessibilityPoller]`. Notiere sie; bevorzuge jede Methode, an die man einen Hook hängen kann.

Schreibe das Ergebnis in `project_status.md`, "Architecture Decisions": die Liste der Screens und UIs, die du erwartest, mit ihren Öffnen- und Schließen-Methoden. Es ist ein erster Entwurf; jeder Slice verfeinert ihn.

### 1.5 Lokalisierungssystem (Tier 1)

Die Mod spricht vom ersten Tag an die Sprache des Spiels (`docs-de/03-architecture.md`, "Lokalisierung"). Selbst eine Mod, die nur Englisch ausliefert, braucht die Spracherkennung des Spiels, damit Übersetzungen später ohne Codeänderung hinzukommen können, und die spieleigene Textsuche, damit die Mod offizielle Namen wiederverwenden kann.

```
Grep pattern: Locali
Grep pattern: Language
Grep pattern: Translate
Grep pattern: GetString
Grep pattern: currentLanguage
Grep pattern: getAlias
Grep pattern: SystemLanguage
```

Finde:

- Wie das Spiel seine aktuelle Sprache speichert und erkennt (ein Singleton oder eine statische Property wie `LocalizationManager.CurrentLanguage`, ein Optionswert, PlayerPrefs).
- Das Format der Sprachcodes ("en", "de-DE", "English", ein Enum) und wie man daraus ein Kürzel wie "en" oder "de" macht.
- Die spieleigene Textsuche (`Localization.Get(id)`, `I2.Loc`, ein Tabellen-Asset) und was sie für eine unbekannte ID zurückgibt (oft die ID selbst oder eine Markierung).
- Wo die Übersetzungsdateien des Spiels liegen.

Dokumentiere das in `docs/game-api.md`, Abschnitt "Lokalisierung". Diese Antworten füllen in Phase 2 `LocalizationUtils.GetGameLanguageTag()` und `LocalizationUtils.GetGame()`. Andere Engines: `docs-de/appendix-d-other-engines.md`.

### Tier-1-Abschluss-Gate

**STOPP. Vor dem Kern (Phase 2) und vor dem ersten Slice muss ALLES davon erledigt sein:**

1. `docs/game-api.md` hat einen vollständigen Abschnitt "Game Key Bindings".
2. `docs/game-api.md` hat einen Abschnitt "Safe Mod Keys".
3. `docs/game-api.md` dokumentiert die UI-Basisklassen und die Zugriffsmuster auf Texte.
4. `docs/game-api.md` dokumentiert die Spracherkennung und die Textsuche des Spiels.
5. In `project_status.md` sind alle Tier-1-Kästchen abgehakt und "Game Key Bindings (Original)" ist ausgefüllt.
6. `project_status.md` "Architecture Decisions" listet die erwarteten Screens und UIs mit ihren Öffnen- und Schließen-Methoden auf (1.4).
7. Der Build-Fingerabdruck existiert (`recon-records/build-fingerprint.json`, Gate G1 unten): Jeder spätere Beleg nennt diesen Build.

Falls etwas fehlt, erledige es jetzt. Jeder je gemeldete Tastenkonflikt-Bug hätte durch dieses Gate verhindert werden können.

### 1.6 Spielmechaniken (Tier 2, pro Slice)

Spieler:

```
Grep pattern: class.*Player
Grep pattern: class.*Character
Grep pattern: class.*Controller.*:.*MonoBehaviour
```

Inventar:

```
Grep pattern: class.*Inventory
Grep pattern: class.*Item
Grep pattern: class.*Slot
```

Interaktion:

```
Grep pattern: Interact
Grep pattern: OnUse
Grep pattern: IInteractable
```

Weitere Systeme, je nach Spiel:

- Quests: `class.*Quest`, `class.*Mission`
- Dialoge: `class.*Dialog`, `class.*Conversation`, `class.*NPC`
- Kampf: `class.*Combat`, `class.*Attack`, `class.*Health`
- Crafting: `class.*Craft`, `class.*Recipe`
- Ressourcen: `class.*Currency`, `Gold`, `Coins`

### 1.7 Status und Rückmeldungen (Tier 2, pro Slice)

```
Grep pattern: Health
Grep pattern: Stamina
Grep pattern: Mana
Grep pattern: Energy
```

Benachrichtigungen:

```
Grep pattern: Notification
Grep pattern: Message
Grep pattern: Toast
Grep pattern: Popup
```

### 1.8 Events und Hook-Punkte (Tier 2, pro Slice)

Events:

```
Grep pattern: delegate\s+
Grep pattern: event\s+
Grep pattern: Action<
Grep pattern: UnityEvent
Grep pattern: \.Invoke\(
```

Gute Hook-Ziele:

```
Grep pattern: OnOpen
Grep pattern: OnClose
Grep pattern: OnShow
Grep pattern: OnHide
Grep pattern: OnSelect
Grep pattern: OnEnable
Grep pattern: OnDisable
```

Bevorzuge eine Methode, die genau einmal pro Öffnen oder Schließen läuft und die Instanz übergeben bekommt. `OnEnable`/`OnDisable` des eigenen MonoBehaviours des Panels sind verlässliche Ausweichlösungen. Vermeide Methoden, die in jedem Frame laufen (`Update`), als Hook-Ziele.

### 1.9 Ergebnisse dokumentieren (fortlaufend)

`docs/game-api.md` sollte enthalten:

1. Überblick: Beschreibung des Spiels, Engine-Version, Backend (Mono oder IL2CPP), Spielversion.
2. Singleton-Zugangspunkte.
3. Tastenbelegungen des Spiels (ALLE).
4. Sichere Mod-Tasten.
5. UI-System, im Detail: Basisklassen und Hierarchie, Textzugriff pro Klasse, Namenskonvention, Beispiel-Snippets, welche Klassen ReflectionHelper brauchen.
6. Lokalisierung: Spracherkennung, Textsuche.
7. Spielmechaniken, Statussysteme.
8. Hook-Ziele pro Bildschirm (Methode, was `__instance` ist, wann sie ausgelöst wird).

Jeder Bildschirm wird UI-Text lesen müssen. Einmal dokumentiert, wird das Zugriffsmuster überall wiederverwendet.

### 1.10 Tutorial (Tier 3, wenn es geplant wird)

Warum das Tutorial wichtig ist:

- Es erklärt Mechaniken Schritt für Schritt: genau das, was barrierefrei werden muss.
- Es ist oft einfacher aufgebaut: ein guter früher Slice.
- Nur wenn das Tutorial barrierefrei ist, können blinde Spieler das Spiel überhaupt lernen.
- Sein Code zeigt, welche UI-Elemente und Interaktionen es gibt.
- Tutorials schränken oft ein, welche Aktionen erlaubt sind; HSA bildet das mit einer Tasten-Whitelist und einem überschriebenen F1-Text nach (`docs-de/03-architecture.md`, "Forced keys and tutorials").

Suche im Code:

```
Grep pattern: Tutorial
Grep pattern: class.*Tutorial
Grep pattern: FirstTime
Grep pattern: Introduction
Grep pattern: HowToPlay
Grep pattern: Onboarding
```

Durchsuche das Spielverzeichnis nach Dateien mit "tutorial", "intro", "howto" im Namen (oft eigene Szenen oder Level).

Fragen:

1. Gibt es ein Tutorial, und wie startet es?
2. Welche Mechaniken führt es ein?
3. Wie werden Anweisungen gezeigt (Text, Popups, Sprachausgabe)?
4. Welche interaktiven Elemente müssen barrierefrei werden?
5. Kann man es überspringen?

Ergebnis: die Startmethode des Tutorials in `docs/game-api.md`; das Tutorial im Feature-Plan (meist hohe Priorität).

## Feature-Plan (Phase 1.5)

Der Feature-Plan ist eine Liste von Slices: kleine Spielerziele, in der Reihenfolge, in der ein Spieler ihnen begegnet. Jeder Slice durchläuft später den Ablauf weiter unten.

Für die wichtigsten Slices dokumentierst du ausführlich:

```
Slice: Main menu
- Player goal: reach "Play" and "Options" from the title screen and start a match
- Surfaces in scope: title screen (AccessibleScreen), options popup (AccessibleUI)
- Out of scope: news panel, store (reason: not needed to start playing)
- Expected hooks: MainMenu.Show / MainMenu.Hide (to verify in G3)
- Keys: arrows, Enter (common keys), nothing new
- Dependencies: core created (Phase 2)
- Known challenge: buttons have no common text property
```

Für weniger wichtige grob:

```
Slice: Achievement announcements
- Brief: read achievement popups as notifications
- Complexity: simple
- Depends on: the notification hook of the toast system
```

Frag den Benutzer, mit welchem Slice er anfangen will. Leitgedanke: Was ein Spieler zuerst trifft, kommt zuerst, damit das Testen früh beginnt und das Spiel von Anfang an spielbar ist. Typische Reihenfolge (anpassen):

1. Popups beim Start und Titel- oder Hauptmenü (erster Kontakt).
2. Einstellungen, falls vom Hauptmenü aus erreichbar.
3. Grundlegende Statusansagen (Gesundheit, Ressourcen).
4. Tutorial oder Startgebiet.
5. Kern-Gameplay (die häufigsten Aktionen).
6. Inventar und Menüs im Spiel.
7. Besondere Features (Crafting, Handel, Dialoge).
8. Optionale Features (Achievements, Statistiken).

Manche Spiele starten direkt im Gameplay, manche erzwingen zuerst das Tutorial; Statusansagen können parallel laufen. Der Plan wird sich ändern; das ist so gewollt.

## Der Slice-Ablauf (G0 bis G7)

Damit beginnt JEDES Feature. Er stammt aus unity-accessibility-recon (`recon/`, MIT) und hält drei Versprechen:

- Untersucht werden nur die Abhängigkeiten des aktuellen Spielerziels: keine Bestandsaufnahme des ganzen Spiels, bevor nützliche Arbeit passiert.
- Jede Behauptung sagt, wie stark ihr Beleg ist. Ein Beleg aus Dateien wird nie als "funktioniert im Spiel" gemeldet.
- Der Slice bekommt vor der Implementierung ein ausdrückliches Urteil, und das Urteil gilt nur für diesen Slice.

Das vollständige Verfahren mit allen Feldern der Aufzeichnungen: `recon/skills/unity-accessibility-reconnaissance-en/SKILL.md` und seine Referenzen. Was folgt, beschreibt, wie dieses Template es verwendet.

### Rollen

- **Claude (der Agent)** sammelt die minimal nötigen Dateien, untersucht, führt die Aufzeichnungen, startet `uar`, behebt eindeutige lokale Probleme, schreibt den Code.
- **Der Benutzer** wählt Spielerziel und Umfang, genehmigt Änderungen am Umfang und alles Heikle (das Spiel starten, einen Loader installieren, Spielstände, Konten) und macht die abschließende Abnahme mit einem echten Screenreader und der Tastatur.
- Der blinde Benutzer wird nie gebeten, Bildschirme visuell aufzuzählen, Screenshots zu lesen, die Unity-Hierarchie zu erraten oder die Aufzeichnungen zu verwalten.

### Wo die Aufzeichnungen liegen

- `recon-records/` im Projektstammordner (leg es mit dem ersten Slice an). Es wird standardmäßig von git ignoriert: Aufzeichnungen können proprietäre Namen, Pfade und Hashes enthalten. Halte es privat wie `decompiled/`.
- Beginne jede Aufzeichnung mit einer Vorlage aus `recon/shared/templates/` (leere CSV-, JSON- und YAML-Dateien).
- Verträge (JSON Schema) liegen in `recon/shared/contracts/`. Phasen-IDs, Grade, Gates und Urteile: `recon/shared/phase-ids.yaml`.

### Die Gates

**G0 Autorisierung.** Einmal pro Projekt, bei Bedarf erweitert. Aufgezeichnet werden: das Produkt und wo es gekauft wurde, dass es dem Benutzer gehört, erlaubte Ordner nur zum Lesen (Spielordner, `decompiled/`), ausgeschlossene sensible Daten (Spielstände, Profile, Kontodaten, Logs mit persönlichen Daten) und welche Aktionen ein eigenes Ja brauchen (das Spiel starten, den Loader installieren, Eingaben einspeisen, Spielstände anfassen, pushen, veröffentlichen). Umkehrbare Schritte, die nur lesen und innerhalb des Umfangs liegen, brauchen keine neue Nachfrage.

**G1 Build-Fingerabdruck.** Einmal pro Spielversion. Produktversion, Engine-Version, Mono oder IL2CPP, Architektur, Loader-Kandidat, Hashes und Größen der Schlüsseldateien (der Haupt-Assemblies des Spiels), Digest des Quell-Manifests. Erstelle ihn vor dem Extrahieren. Die Version trägt denselben Namen wie der Branch in `decompiled/` (`scripts/Decompile-Game.ps1 -Version`). Belege aus zwei Builds werden nie gemischt: Nach einem Spiel-Update gibt es einen neuen Fingerabdruck und eine ausdrückliche Entscheidung, welche alten Belege noch gelten (das beantwortet der `git diff` zwischen den beiden dekompilierten Branches).

**G2 Extraktionsabdeckung.** Welche Quellfamilien der Slice braucht (Assemblies, Lokalisierungstabellen, Input-Assets, Szenen und Prefabs, ...) und wie jede extrahiert wurde: `extracted`, `partial`, `excluded-with-reason`, `unsupported`, `failed`, `not-present`. Ein Fehlschlag in einer Familie, die der Slice nicht braucht, blockiert ihn nicht. `DUMP-PARTIAL` ist ein ehrliches Ergebnis, wenn jede Lücke einen Verantwortlichen und einen Auslöser zum Wiederaufnehmen hat. Für die meisten Slices reichen die dekompilierten Assemblies plus die Lokalisierungsdateien des Spiels.

**G3 Statische UI-Erkundung.** Das statische UI-Verzeichnis (Static UI Ledger): die Klassen, Felder, Buttons, Texte, Lokalisierungs-IDs, Callbacks und Input-Actions, die diesen Slice berühren, jeweils mit ihrem Beleg im Quellcode. Nimm inaktive Vorlagen, gepoolte Objekte und dynamisch erzeugte Einträge mit auf, gekennzeichnet als Erkundungsbeleg (im Code vorhanden heißt nicht sichtbar oder benutzbar). Jeder Kandidat im Umfang endet als semantischer Kandidat, als ausdrücklicher Ausschluss oder als Lücke.

**G4 Lebenszyklus-Matrix der Oberflächen.** Eine Zeile pro Oberfläche im Umfang (`recon/shared/templates/surface-lifecycle-matrix.csv`): Eintritts- und Austrittsbedingungen, Kandidaten für den Besitzer, Modal-Tiefe, erforderliche und optionale Bedienelemente, anfänglicher Fokus, Übergänge zu Kind-Oberflächen, wie die Eltern-Oberfläche wiederhergestellt wird, Eingabe-Besitzer, Interaktionsmodell, Datenschutzklasse, bedingte Abhängigkeiten. Nicht zugehörige Oberflächen kommen mit Begründung auf eine kurze Liste außerhalb des Umfangs.

**G5 Laufzeitabdeckung.** Eigene Erlaubnis: Das Spiel läuft. Beobachte mit eingeschaltetem Debug-Modus (F12) den echten Besitzer jeder Oberfläche und ihre aktiven Bedienelemente, zuerst ohne Sprachausgabe. Achte auf Generationen von Oberflächen (ein Popup, das zerstört und neu erzeugt wird), inaktive Eltern hinter Modals und die Wiederherstellung des Fokus, wenn ein Kind schließt. Bring jede Oberfläche durch die Abdeckungs-Gates weiter unten voran.

**G6 Native Eingabe und Nachbedingungen.** Für jede Aktion des Slices: Vorbedingung, physische Taste, der spieleigene Weg, den sie nimmt (das onClick des Buttons, die Methode des Spiels), und der daraus folgende Spielzustand, genau einmal beobachtet. Eine aufrufbare Methode beweist nicht, dass der Spieler sie auslösen kann; eine Ansage der beabsichtigten Aktion beweist nicht, dass sie passiert ist. Nur wenn der native Weg fehlt oder unbrauchbar ist, kommt eine Ausweichlösung hinzu, die auf diese Oberfläche beschränkt ist.

**G7 Bereitschaft des Slices.** Die Bereitschafts-Aufzeichnung (`first-slice-readiness.yaml`, auch für jeden späteren Slice verwendet) nennt das Spielerziel, Oberflächen im und außerhalb des Umfangs, Behauptungen, Lücken, die Laufzeit-Probe und welche Behauptungen sie herausfordert, den Status der Code-QA und die Grenze der Autorisierung, und erklärt genau ein Urteil.

### Behauptungs-Grade (wie stark ist ein Befund)

Vom schwächsten zum stärksten; niemals ohne neuen Beleg hochstufen:

1. `SOURCE-IDENTIFIED`: exakte Quelle und Build-Identität aufgezeichnet.
2. `STATIC-CONFIRMED`: Code, Asset, Lokalisierungs-ID, Callback oder Binding existiert im extrahierten Build.
3. `RUNTIME-OBSERVED`: Besitzer, Zustand oder Übergang wurde im laufenden Spiel gesehen (sagt noch nichts über die Tastatur).
4. `PHYSICAL-INPUT-PROVEN`: Eine echte Taste ist über den vorgesehenen spieleigenen Weg gelaufen.
5. `POSTCONDITION-PROVEN`: Der vorgesehene Spielzustand hat sich genau einmal geändert.
6. `SPEECH-DISPATCH-PROVEN`: Die Screenreader-Brücke hat den exakten Text angenommen (kein Beweis, dass ihn jemand gehört hat).
7. `NVDA-MANUAL-CONFIRMED`: Der Benutzer hat es gehört und Sprachausgabe und Tastaturweg abgenommen.

Und `OPEN / DYNAMIC-UNVERIFIED`: Beleg fehlt, ist bedingt, durch den Parser begrenzt oder stammt aus einem anderen Build.

Jede Behauptung, von der der Slice abhängt und die nur `SOURCE-IDENTIFIED`, `STATIC-CONFIRMED` oder `OPEN` ist, braucht einen kleinen Laufzeit-Gegentest: eine Live-Prüfung, die zeigen würde, dass die Annahme falsch ist.

### Abdeckungs-Gates (wie weit ist eine Oberfläche)

Jede Oberfläche im Umfang durchläuft der Reihe nach:

1. `STATIC-MAPPED`
2. `RUNTIME-OWNER-OBSERVED`
3. `ACTIVE-CONTROLS-INVENTORIED`
4. `SEMANTIC-MODELED`
5. `NATIVE-FOCUS-PROVEN`
6. `NATIVE-ACTION-POSTCONDITION-PROVEN`
7. `NVDA-MANUAL-CONFIRMED`
8. `COVERAGE-CLOSED`: Jedes derzeit bedeutsame Bedienelement hat einen gesprochenen Eintrag, einen ausdrücklichen Ausschluss oder eine reproduzierbare Lücke.

Behauptungs-Grade und Abdeckungs-Gates sind zwei getrennte Skalen. Rechne die eine nicht in die andere um.

### Urteile

Jedes gilt nur für den genannten Slice:

- `READY FOR RUNTIME PROBE`: Die Aufzeichnungen stimmen überein und der nächste Falsifikationstest ist festgelegt. Offline-Befunde sind noch keine Laufzeit-Wahrheit. Als Nächstes: die Probe ausführen (meist: eine minimale Komponente mit Hooks bauen, die im Debug-Modus nur loggen, das Spiel starten, die Oberfläche öffnen).
- `READY FOR SLICE IMPLEMENTATION`: Eine aufgezeichnete Laufzeit-Probe ist bestanden, jede herausgeforderte Behauptung ist `RUNTIME-OBSERVED` oder stärker, und jede teilt Belege mit dieser Probe. Als Nächstes: `docs-de/04-building-screens.md`.
- `BLOCKED FOR THIS SLICE`: gemischte Builds, ein Fehler bei der Sicherung, eine gescheiterte Probe, ein zutreffender Blocker oder widersprüchliche Aufzeichnungen. Als Nächstes: der kleinste Beleg, den das Lücken-Verzeichnis (Gap Ledger) nennt, oder ein kleinerer Slice.

### Den Validator ausführen

Aus `recon/` heraus (installiert mit `uv sync --dev`, siehe `docs-de/01-setup-and-tooling.md`):

```powershell
cd recon
uv run uar validate-foundation --build ..\recon-records\build-fingerprint.json --source ..\recon-records\source-manifest.json --coverage ..\recon-records\extraction-coverage.json
uv run uar validate-ledgers --build-id BUILD-ID --static-ui ..\recon-records\static-ui-ledger.json --lifecycle ..\recon-records\surface-lifecycle-matrix.csv --runtime-coverage ..\recon-records\static-to-runtime-coverage.csv --gaps ..\recon-records\gap-ledger.csv
uv run uar assess-readiness --build ..\recon-records\build-fingerprint.json --source ..\recon-records\source-manifest.json --coverage ..\recon-records\extraction-coverage.json --readiness ..\recon-records\slices\main-menu.yaml --static-ui ..\recon-records\static-ui-ledger.json --lifecycle ..\recon-records\surface-lifecycle-matrix.csv --runtime-coverage ..\recon-records\static-to-runtime-coverage.csv --gaps ..\recon-records\gap-ledger.csv
```

Ohne `--json` gibt `assess-readiness` das Spielerziel, die Offline-Befunde, die Laufzeit-Befunde, Unbekanntes, Grenzen und den nächsten Test aus: Gib diese Zusammenfassung in einfacher Sprache an den Benutzer weiter. Es endet nur bei `BLOCKED FOR THIS SLICE` mit einem Exit-Code ungleich null.

**Der Validator prüft nur die Konsistenz.** `VALIDATION_PASS` bedeutet, dass die Aufzeichnungen untereinander übereinstimmen, niemals, dass sich das Spiel so verhält. Melde es nie als "funktioniert".

Weitere Befehle: `uv run uar check-parity --root .` (die englischen und koreanischen Skills stimmen überein; nur für die Pflege von `recon/`), `uv run uar export-skills --destination <folder> --language en` (den Skill in eine andere Agenten-Umgebung kopieren).

### Der Phasenbericht an den Benutzer

Bei jedem Gate, kurz und screenreader-freundlich:

1. Das Spielerziel und die genaue Grenze des Slices.
2. Befunde aus Dateien, Befunde aus dem laufenden Spiel, Annahmen, Unbekanntes: als getrennte Gruppen.
3. Der nächste Test und was ein Fehlschlag bedeuten würde.
4. Ausgeführte Prüfungen, beschrieben als Konsistenzprüfungen.
5. Was automatisch behoben wurde.
6. Nur die kleinste Entscheidung, die der Benutzer wirklich treffen muss.
7. Was NICHT getan wurde (Spiel nicht gestartet, nichts gepusht, ...).

## Von den Aufzeichnungen zum Code

Die Aufzeichnungen sind keine Papierarbeit neben dem Code; jede Zeile wird zu einem bestimmten Stück davon (Details in `docs-de/03-architecture.md` und `docs-de/04-building-screens.md`):

- **Eine Zeile der Lebenszyklus-Matrix = eine Komponente**: `Accessible<Name>` in `Accessibility/Screens/<Area>/`, aus `templates/shared/AccessibleFEATURENAME.cs.template`.
- **modalDepth**: 0 (Basis-Bildschirm) = `AccessibleScreen`; 1 oder mehr (über etwas anderem) = `AccessibleUI`.
- **entryPredicate / exitPredicate**: die Methoden, die die Öffnen- und Schließen-Hooks patchen. Der Eintritt ruft `SetScreen` oder `ShowUI` auf; der Austritt ruft `ClearScreen` oder `HideUI` auf.
- **runtimeOwner**: die Klasse im `typeof(...)` des Hooks und die Instanz (`__instance`), auf die die Komponente eine Referenz behält.
- **initialFocus**: was `OnGainedFocus()` als Erstes ansagt und auswählt.
- **requiredControls / optionalControls**: die Optionen des AccessibleMenu oder die Einträge der AccessibleListOfItems; jede Beschriftung aus dem eigenen Text des Spiels, wo das statische Verzeichnis einen gefunden hat.
- **childTransitions / parentRestore**: welche UIs diese Oberfläche öffnet (jede ihre eigene Komponente) und dass ihr Schließen den Fokus hierher zurückgibt (AccessibilityMgr sagt den Bildschirm automatisch erneut an).
- **inputOwner, interactionModel**: ob die üblichen Menütasten reichen oder die Oberfläche eigene AccessibleKey-Einträge braucht (deklariert in `AccessibleKey.<Feature>.cs`, nur aus "Safe Mod Keys").
- **Ziel der Laufzeit-Probe**: das exakte Hook-Ziel. Eine Probe, die beobachtet hat, dass `Shop.Open` mit der Shop-Instanz ausgelöst wird, ist das, was `[HarmonyPatch(typeof(Shop), "Open")]` sicher schreibbar macht.
- **Native-Input-Matrix**: Der spieleigene Weg jeder Aktion ist genau das, was die Menüoption aufruft (`button.onClick.Invoke()`, `shop.Buy(item)`), niemals eine Neu-Implementierung.
- **privacyClass**: Sensible Felder (Kontonamen, Freundescodes) werden im Debug-Modus nicht geloggt.
- **Gap Ledger**: Offene Lücken werden zu Einträgen in `docs/game-api.md` oder `project_status.md` "Known Issues"; eine Lücke zu einem Member, der bei Updates verschwinden könnte, wird zu einer Compat-Prüfung (der Hook oder der ReflectionHelper-Aufruf meldet es, wenn er fehlt).
- **Abdeckungs-Gate `NVDA-MANUAL-CONFIRMED`**: der Eintrag unter "Pending Tests" in `project_status.md`, den der Benutzer bestätigt.

## Engine-neutrales Minimum

Die Recon-Verträge sind auf Unity zugeschnitten (`unityVersion`, `scriptingBackend` ist Pflicht und auf Mono oder IL2CPP beschränkt). Für Godot, Unreal, eine eigene Engine oder ein .NET-Spiel ohne Unity verwendest du den Ablauf ohne den Validator und hältst dieses Minimum in `recon-records/` als einfaches Markdown oder CSV fest:

- **G0**: dieselbe Autorisierungs-Aufzeichnung.
- **G1**: Produktversion, Engine und deren Version, Scripting-Laufzeit (C#, GDScript, C++, Lua...), Architektur, Mod- oder Injektionsmethode, Hashes der Haupt-Executable und der Code-Dateien. Gleiche Regel: Builds nie mischen.
- **G2**: was extrahiert wurde (dekompilierte Assemblies, entpackte PCK- oder PAK-Dateien, Skript-Dumps) und was fehlgeschlagen ist.
- **G3 und G4**: die Lebenszyklus-Matrix der Oberflächen mit denselben Spalten (sie sind engine-neutral; Spalten, die nur für Unity gelten, bleiben leer).
- **G5 und G6**: beobachteter Besitzer, Bedienelemente, nativer Aktionsweg, Nachbedingung, pro Oberfläche.
- **G7**: dieselben drei Urteile, nach denselben Regeln entschieden; Grade und Gates wie oben.

Wie sich die Architektur auf andere Engines überträgt: `docs-de/appendix-d-other-engines.md`.
