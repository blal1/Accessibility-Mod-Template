# 06 Veröffentlichung

Deutsche Fassung von `docs/06-distribution.md`.

Wie du deine Barrierefreiheits-Mod verpackst, lizenzierst und veröffentlichst.

---

## Die Mod für ein Release vorbereiten

### Was Endbenutzer installieren müssen

Deine Mod braucht diese Komponenten auf dem Rechner des Benutzers:

1. **MelonLoader** - Der Mod-Loader (der Benutzer installiert ihn einmal)
   - Download: https://github.com/LavaGang/MelonLoader.Installer/releases
2. **Tolk-DLLs** - Kommunikation mit dem Screenreader (in deinem Release enthalten)
   - `Tolk.dll`
   - `nvdaControllerClient64.dll` oder `nvdaControllerClient32.dll` (passend zur Architektur des Spiels)
3. **Deine Mod-DLL** - Die eigentliche Mod-Datei

### Ein Release-Paket erstellen

Erstelle eine ZIP-Datei mit folgendem Inhalt:

```
YourModName-v1.0.0.zip
├── Mods/
│   └── YourModName.dll          (your compiled mod)
├── Tolk.dll                      (screen reader library)
├── nvdaControllerClient64.dll    (or 32-bit version)
├── README.txt                    (installation instructions)
└── LICENSE.txt                   (your license)
```

**Warum die Tolk-DLLs mitliefern?** Die meisten Benutzer haben Tolk nicht installiert. Wenn die DLLs dabei sind, wird die Installation viel einfacher - man kopiert einfach alles in den Spielordner.

### README-Vorlage für Endbenutzer

Schreib eine einfache README.txt (reiner Text, kein Markdown - für alle zugänglich):

```
[ModName] - Accessibility Mod for [GameName]
Version: 1.0.0
Author: [Your Name]

WHAT THIS MOD DOES
==================
Makes [GameName] playable with a screen reader (NVDA, JAWS).
- Keyboard navigation for all menus
- Screen reader announcements for game events
- [List key features]

REQUIREMENTS
============
- [GameName] (Steam version tested, others may work)
- MelonLoader (https://github.com/LavaGang/MelonLoader.Installer/releases)
- A screen reader (NVDA recommended, JAWS also works)

INSTALLATION
============
1. Install MelonLoader for your game (run the installer, select your game)
2. Start the game once to create the Mods folder, then close it
3. Copy ALL files from this ZIP into your game folder:
   - YourModName.dll goes into the Mods subfolder
   - Tolk.dll goes into the main game folder (where the .exe is)
   - nvdaControllerClient64.dll goes into the main game folder
4. Start the game - you should hear "Mod loaded" from your screen reader

CONTROLS
========
F1 - Help (shows all key bindings)
[List your key bindings here]

TROUBLESHOOTING
===============
- No sound from screen reader: Check that Tolk.dll is in the game folder
- Mod doesn't load: Check MelonLoader/Latest.log for errors
- Wrong architecture: If game is 32-bit, use nvdaControllerClient32.dll instead

KNOWN ISSUES
============
[List any known issues]

CONTACT
=======
[Your contact info, GitHub issues page, etc.]
```

---

## Versionierung

Verwende Semantic Versioning (SemVer): **MAJOR.MINOR.PATCH**

- **MAJOR** (1.0.0 → 2.0.0): Inkompatible Änderungen, großer Umbau
- **MINOR** (1.0.0 → 1.1.0): Neue Features, neue Menüs zugänglich
- **PATCH** (1.0.0 → 1.0.1): Fehlerbehebungen, verbesserte Ansagen

Aktualisiere die Version an diesen Stellen:
- `MelonInfo`-Attribut in Main.cs
- Dein Release/Tag auf GitHub
- README und Changelog

### Changelog

Führe eine CHANGELOG.md in deinem Projekt:

```
# Changelog

## 1.1.0 - 2025-03-15
- Added: Inventory navigation with arrow keys
- Added: Shop menu accessibility
- Fixed: Main menu skipping first item

## 1.0.0 - 2025-02-01
- Initial release
- Main menu navigation
- Basic status announcements (F2)
```

---

## Auf GitHub veröffentlichen

### Warum GitHub?

- Kostenloses Hosting für deinen Code und deine Releases
- Issue-Tracker für Fehlerberichte
- Mit Screenreadern zugänglich
- Spieleentwickler können deinen Code direkt prüfen
- Die Community kann Verbesserungen beitragen

### Dein Repository einrichten

Die Grundlagen von Git und GitHub findest du in `docs-de/appendix-f-git-github.md`.

Sobald dein Git-Repo initialisiert und zu GitHub gepusht ist:

1. **Schreib eine gute Repository-Beschreibung:**
   - "[GameName] accessibility mod - makes the game playable with screen readers (NVDA/JAWS)"

2. **Erstelle eine README.md für GitHub** (anders als die README für Endbenutzer):
   - Was die Mod tut
   - Aktueller Stand (welche Features funktionieren)
   - Wie man sie installiert
   - Wie man sie aus dem Quellcode baut
   - Wie man beitragen kann
   - Lizenzinformationen

3. **Erstelle ein Release:**
   - Geh zu deinem Repository auf GitHub
   - Klicke auf "Releases" (rechte Seite, oder über `gh release create`)
   - Klicke auf "Create a new release"
   - Tag: `v1.0.0` (immer mit v davor)
   - Titel: `v1.0.0 - Initial Release`
   - Beschreibung: Kopiere die passenden Changelog-Einträge
   - Hänge deine ZIP-Datei an (das Release-Paket von oben)
   - Klicke auf "Publish release"

   Oder über die Kommandozeile:
   ```
   gh release create v1.0.0 YourModName-v1.0.0.zip --title "v1.0.0 - Initial Release" --notes "Initial release with main menu navigation and status announcements"
   ```

### Andere Plattformen zum Veröffentlichen

- **audiogames.net-Forum** - Poste im passenden Spieleforum. Die Community blinder Spieler ist hier aktiv. Verlinke dein GitHub-Release.
- **NexusMods** - Beliebte Mod-Hosting-Seite. Erstelle ein Konto und lade deine Mod hoch. Gut für die Sichtbarkeit in der allgemeinen Modding-Community.
- **Spielspezifische Foren/Discord** - Viele Spiele haben Modding-Communities. Poste auch dort.

---

## Lizenzierung

### Warum eine Lizenz wichtig ist

Ohne Lizenz ist dein Code technisch gesehen "alle Rechte vorbehalten" - niemand darf ihn rechtlich gesehen benutzen, verändern oder weitergeben. Eine Lizenz sagt den Leuten, was sie tun dürfen.

Das ist besonders wichtig, wenn:
- du möchtest, dass Spieleentwickler deinen Code integrieren können
- du möchtest, dass andere die Mod verbessern und pflegen
- du Code aus anderen Projekten verwendest (du musst deren Lizenz respektieren)

### Lizenzoptionen

#### MIT-Lizenz (für die meisten Mods empfohlen)

**Was sie sagt:** "Mach mit diesem Code, was du willst, behalte nur den Copyright-Hinweis bei."

Vorteile:
- Sehr einfach und kurz
- Maximale Freiheit für alle
- Spieleentwickler können integrieren, ohne rechtliche Bedenken
- Mit fast jeder anderen Lizenz kompatibel
- Die beliebteste Lizenz auf GitHub

Nachteile:
- Andere können Closed-Source-Versionen erstellen (falls dich das stört)
- Keine "Weitergabe unter gleichen Bedingungen"-Pflicht

**Am besten für:** Mods, bei denen du maximale Verbreitung und eine einfache Integration durch Spieleentwickler willst.

#### GNU GPL v3 (Copyleft)

**Was sie sagt:** "Du darfst das benutzen und verändern, aber jedes weitergegebene abgeleitete Werk muss ebenfalls unter der GPL stehen."

Vorteile:
- Stellt sicher, dass Änderungen Open Source bleiben
- Starker Schutz für die Community

Nachteile:
- Spieleentwickler können GPL-Code oft nicht in proprietäre Spiele integrieren
- Schwerer zu verstehen
- Kann manche Mitwirkende abschrecken

**Am besten für:** Große Projekte, bei denen du sicherstellen willst, dass alle Verbesserungen zurückfließen.

#### Apache License 2.0

**Was sie sagt:** Wie MIT, enthält aber zusätzlich eine Patentlizenz.

Vorteile:
- Klarer Patentschutz
- Unternehmensfreundlich
- Freizügig wie MIT

Nachteile:
- Längerer und komplexerer Text
- Für kleine Mods überdimensioniert

#### Creative Commons (CC BY 4.0)

**Für Code nicht empfohlen** - gedacht für kreative Werke (Kunst, Dokumentation, Text). Wird manchmal für die Nicht-Code-Teile eines Projekts verwendet.

### Meine Empfehlung

**Für Barrierefreiheits-Mods: Nimm MIT.** Der ganze Sinn ist es, Spiele zugänglich zu machen. Du willst, dass Spieleentwickler sich deinen Code ansehen und denken: "Das können wir integrieren." MIT macht das rechtlich so einfach wie möglich.

### Eine Lizenz anwenden

1. Erstelle eine `LICENSE`-Datei im Stammverzeichnis deines Projekts
2. Kopiere den vollständigen Lizenztext hinein (suche nach "MIT license text")
3. Trage deinen Namen und das Jahr ein
4. Füge in deiner README ein Lizenz-Badge oder einen Hinweis hinzu

Vorlage für die MIT-Lizenz:
```
MIT License

Copyright (c) [YEAR] [YOUR NAME]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### Andere Lizenzen respektieren

Deine Mod verwendet Komponenten von Drittanbietern:
- **MelonLoader**: Apache 2.0 - in deiner README vermerken
- **Harmony** (in MelonLoader enthalten): MIT
- **Tolk**: LGPL 2.1 - du darfst die DLLs zusammen mit deiner Mod weitergeben
- **Das Spiel selbst**: Du moddest es, du verbreitest es nicht. Deine Mod sollte niemals Spielcode oder Spiel-Assets enthalten.

---

## Umgang mit Spiel-Updates

Spiele werden aktualisiert, und Updates können Mods kaputt machen. So gehst du damit um:

### Wenn ein Spiel-Update erscheint

Vollständiger Ablauf: `docs-de/05-quality-and-updates.md`, "Ablauf bei einem Spiel-Update". Kurz gefasst:

1. **Neu in einen neuen Branch dekompilieren** - `.\scripts\Decompile-Game.ps1 -Version <new version>`.
2. **Vergleichen** - `git -C decompiled diff <old> <new> --stat`, danach der Diff jeder Klasse, die die Mod hookt.
3. **Offline prüfen** - `dotnet test Tests` nennt jedes umbenannte oder entfernte Member, das die Mod verwendet.
4. **Im Spiel testen** - die Kompatibilitätswarnung beim Start muss verschwunden sein; andernfalls prüfe das Log ("COMPAT:"-Zeilen).
5. **Reparieren und veröffentlichen** - Aktualisiere deine Mod und erhöhe die PATCH-Version.

### Vorbeugende Maßnahmen

- **Ein verifizierter Name pro Member, geprüft von Compat und dem Offline-Test** (siehe `docs-de/appendix-b-unity-reflection.md`) - keine Ketten von geratenen Ersatznamen
- **Niemals dekompilierten Code ausliefern oder veröffentlichen** - nicht im Release-ZIP, nicht im Repository, nicht in Issues
- **Keine String-Konstanten aus dem Spiel fest einprogrammieren** - Verwende die eigenen Konstanten des Spiels
- **Nützliche Debug-Informationen loggen** - Damit du schnell erkennst, was sich geändert hat
- **Halte deine game-api.md aktuell** - Das macht es leichter, Änderungen zu finden

### Kommunikation mit Benutzern

Wenn ein Update deine Mod kaputt macht:
- Schreib in deinen GitHub Issues, dass du davon weißt
- Veröffentliche so schnell wie möglich eine Fehlerbehebung
- Wenn du es nicht sofort beheben kannst, veröffentliche einen Hinweis, welche Spielversion mit deiner aktuellen Mod-Version funktioniert

---

## Code bei Spieleentwicklern einreichen

Wenn du deine Barrierefreiheits-Features zur Integration ins Hauptspiel vorschlagen möchtest:

### Bevor du Entwickler ansprichst

- Stell sicher, dass dein Code **sauber und gut dokumentiert** ist (XML-Docs an jeder öffentlichen Methode)
- Halte dich so eng wie möglich an den bestehenden Code-Stil des Spiels
- Halte deine Änderungen **modular** - leicht zu prüfen und Stück für Stück zu integrieren
- Habe eine funktionierende Mod, die die Features vorführt
- Hol dir zuerst Feedback von blinden Spielern

### Wie du vorgehst

1. Prüfe, ob der Entwickler einen offiziellen Kanal für Mod-Einreichungen oder Feature-Wünsche hat
2. Beginne mit einer höflichen Nachricht, die erklärt, was deine Mod tut und warum sie wichtig ist
3. Biete Hilfe bei der Integration an
4. Verlinke dein GitHub-Repository, damit sie den Code prüfen können
5. Sei geduldig - Entwickler sind beschäftigt, und Integration braucht Zeit

### Worauf Entwickler achten

- Sauberer, einheitlicher Code-Stil
- Keine Hacks oder Workarounds (oder gut dokumentierte)
- Minimale Auswirkungen auf bestehenden Code
- Gute Performance (keine Frame-Einbrüche)
- Möglichst keine neuen Abhängigkeiten (Tolk ist eine kleine Abhängigkeit)
- Tests oder zumindest klare Testanweisungen
