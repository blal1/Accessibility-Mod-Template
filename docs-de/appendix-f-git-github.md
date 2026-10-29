# Anhang F: Git und GitHub für Einsteiger

Deutsche Fassung von `docs/appendix-f-git-github.md`.

Diese Anleitung erklärt Git und GitHub von Grund auf. Vorwissen ist nicht nötig.

---

## Was ist Git?

Git ist eine "Versionsgeschichte" für dein Projekt. Stell dir vor, du schreibst ein Dokument:
- Du machst den ganzen Tag über Änderungen
- An bestimmten Punkten speicherst du einen Schnappschuss: "Menu navigation working"
- Wenn später etwas kaputtgeht, kannst du zu jedem beliebigen Schnappschuss zurückkehren
- Du kannst genau sehen, was sich zwischen zwei beliebigen Schnappschüssen geändert hat

Diese Schnappschüsse heißen **Commits**. Git speichert sie alle lokal auf deinem Computer.

**Warum ist das beim Modding nützlich?**
- Du hast gerade das Inventar zum Laufen gebracht und machst es dann beim Einbauen des Shops kaputt. Mit Git kannst du zurück zu "Inventar funktioniert".
- Du kannst sehen, was du seit der letzten funktionierenden Version geändert hast.
- Wenn du deine Mod teilen willst, brauchst du Git, um sie zu GitHub hochzuladen.

## Was ist GitHub?

GitHub ist eine Website, auf der du dein Git-Projekt online speicherst. Stell es dir so vor:
- Ein Backup deines Projekts in der Cloud
- Ein Ort, an dem andere deine Mod herunterladen können
- Ein Ort, an dem Leute Fehler melden können (Issues)
- Ein Ort, an dem du Releases veröffentlichst (ZIP-Dateien deiner Mod)

Git arbeitet lokal auf deinem Computer. GitHub ist die Online-Kopie.

---

## Git einrichten

### Git installieren

Git ist wahrscheinlich schon installiert, wenn du der Setup-Anleitung in der README gefolgt bist. Prüfe es mit:
```
git --version
```

Falls es nicht installiert ist, lade es hier herunter: https://git-scm.com/downloads

### Git konfigurieren (einmalig)

Sag Git, wer du bist (das erscheint in deinen Commits):
```
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

**Tipp:** Verwende dieselbe E-Mail-Adresse wie bei GitHub.

### Ein GitHub-Konto erstellen

1. Geh auf https://github.com und registriere dich
2. Wähle einen Benutzernamen (er ist öffentlich sichtbar)
3. Bestätige deine E-Mail-Adresse

### GitHub CLI installieren (optional, aber empfohlen)

Mit der GitHub CLI (`gh`) kannst du GitHub-Aufgaben über die Kommandozeile erledigen:
```
winget install GitHub.cli
```

Dann meldest du dich an:
```
gh auth login
```

Folge den Anweisungen. Das ist eine einmalige Einrichtung.

---

## Versionsverwaltung für deine Mod starten

### Git in deinem Projekt initialisieren

Öffne PowerShell in deinem Mod-Projektordner und führe aus:
```
git init
```

Das legt einen versteckten `.git`-Ordner an, der die gesamte Versionsgeschichte speichert.

### Eine .gitignore-Datei anlegen

Lege vor deinem ersten Commit im Stammverzeichnis deines Projekts eine Datei namens `.gitignore` an. Sie sagt Git, welche Dateien es NICHT verfolgen soll:

```
# Build output
bin/
obj/

# Decompiled game code: PROPRIETARY, never publish (own private git repo)
decompiled/

# Junction to the game installation
game/

# Reconnaissance records (may contain proprietary names, paths, hashes)
recon-records/

# Offline test build output
Tests/bin/
Tests/obj/

# Visual Studio
.vs/
*.user
*.suo

# OS files
Thumbs.db
Desktop.ini

# MelonLoader output (don't commit game DLLs)
*.dll
!templates/**

# Local IDE settings
.idea/
.vscode/
```

**Warum `decompiled/` ignorieren?** Es ist der proprietäre Code des Spieleentwicklers: Ihn zu veröffentlichen ist nicht erlaubt, deshalb darf er niemals auf GitHub landen. Außerdem sind es Tausende von Dateien. `scripts/Decompile-Game.ps1` führt ihn als eigenes privates lokales Git-Repository mit einem Branch pro Spielversion; so siehst du, was ein Spiel-Update geändert hat (`docs-de/05-quality-and-updates.md`). Füge ihm niemals ein Remote hinzu und pushe es niemals.

### Dein erster Commit

Ein Commit ist ein Schnappschuss. So erstellst du einen:

```
git add .gitignore
git add CLAUDE.md
git add docs/
git add templates/
git add scripts/
git add Main.cs
git add ScreenReader.cs
git add Accessibility/
git add Localization/
git add Tests/
git add YourMod.csproj
```

Dann committen (den Schnappschuss speichern):
```
git commit -m "Initial project setup with basic framework"
```

**Wichtig:** Füge nur Dateien hinzu, die du wirklich verfolgen willst. Füge niemals hinzu:
- `.dll`-Dateien (binär, werden beim Bauen neu erzeugt)
- den Ordner `decompiled/` (proprietärer Spielcode, niemals veröffentlichen)
- `recon-records/` (kann proprietäre Details enthalten)
- Zugangsdaten oder persönliche Daten

---

## Der tägliche Git-Ablauf

### Der grundlegende Zyklus

1. **Arbeite an deinem Code** (mit Hilfe von Claude Code)
2. **Wenn etwas funktioniert:** Mach einen Commit
3. **Arbeite weiter** an der nächsten Sache
4. **Wenn du online sichern willst:** Push zu GitHub

### Commits erstellen

Prüfe, was sich geändert hat:
```
git status
```

Das zeigt:
- **Modified files:** Dateien, die du geändert hast
- **Untracked files:** Neue Dateien, die Git noch nicht kennt

Füge die Dateien hinzu, die du committen willst:
```
git add Main.cs
git add Accessibility/Screens/Inventory/AccessibleInventory.cs
```

Oder füge alle geänderten/neuen Dateien auf einmal hinzu:
```
git add -A
```

Committe mit einer Nachricht, die beschreibt, was du getan hast:
```
git commit -m "Add inventory navigation with arrow keys"
```

**Gute Commit-Nachrichten:**
- "Add main menu keyboard navigation"
- "Fix shop prices not being announced"
- "Add German localization for inventory"

**Schlechte Commit-Nachrichten:**
- "stuff" (welches Zeug?)
- "fix" (was wurde behoben?)
- "asdf" (überhaupt nicht hilfreich)

### Wann committen

Committe:
- wenn ein Feature funktioniert (auch nur teilweise)
- bevor du mit einer größeren Änderung anfängst (Sicherheitsnetz!)
- bevor du für den Tag aufhörst
- bevor du etwas Riskantes ausprobierst

**Faustregel:** Wenn es dich ärgern würde, die Änderungen seit dem letzten Commit zu verlieren, ist es Zeit für einen Commit.

---

## Zu GitHub hochladen

### Ein Repository auf GitHub erstellen

Mit der GitHub CLI:
```
gh repo create YourModName --public --description "Accessibility mod for GameName"
```

Oder auf der Website:
1. Geh auf https://github.com
2. Klicke auf den "+"-Button (oben rechts) und wähle "New repository"
3. Name: Der Name deiner Mod
4. Description: Eine kurze Beschreibung
5. Public (damit Leute deine Mod finden und nutzen können)
6. Keine README/gitignore hinzufügen (die hast du schon)
7. Klicke auf "Create repository"

### Dein lokales Projekt mit GitHub verbinden

Nachdem du das Repository erstellt hast, verbinde es:
```
git remote add origin https://github.com/YourUsername/YourModName.git
```

### Deine Commits pushen (hochladen)

```
git push -u origin master
```

Das `-u origin master` ist nur beim ersten Mal nötig. Danach reicht:
```
git push
```

### Änderungen holen (wenn du auf einem anderen Computer arbeitest)

```
git pull
```

---

## Releases auf GitHub erstellen

Wenn deine Mod bereit ist, von anderen benutzt zu werden:

1. **Bau deine Mod** und erstelle das Release-ZIP (siehe docs-de/06-distribution.md)

2. **Erstelle ein Release:**
   ```
   gh release create v1.0.0 YourMod-v1.0.0.zip --title "v1.0.0 - Initial Release" --notes "First release with main menu and inventory navigation"
   ```

3. **Teile den Link** - Die URL der Release-Seite ist das, was du mit Benutzern teilst

---

## Nützliche Befehle zum Nachschlagen

Status prüfen:
```
git status
```

Änderungen im Detail sehen:
```
git diff
```

Commit-Verlauf ansehen:
```
git log --oneline
```

Änderungen an einer Datei rückgängig machen (zurück zum letzten Commit):
```
git checkout -- filename.cs
```

**Sei vorsichtig mit diesem Befehl - er verwirft deine Änderungen an dieser Datei endgültig!**

---

## Fehlerbehebung

**"fatal: not a git repository"**
Du bist nicht in einem Ordner, in dem Git initialisiert ist. Führe zuerst `git init` aus oder wechsle in den richtigen Ordner.

**"error: failed to push some refs"**
Jemand (oder du auf einem anderen Computer) hat Änderungen gepusht, die du nicht hast. Führe zuerst `git pull` aus, dann `git push`.

**"Changes not staged for commit"**
Du hast Dateien geändert, sie aber noch nicht mit `git add` hinzugefügt. Füge sie hinzu und committe dann.

**Versehentlich etwas committet, das nicht hineingehört?**
Sag es Claude Code - es kann dir helfen, Dateien aus der Git-Geschichte zu entfernen.

---

## Zusammenfassung: Minimaler Ablauf

Wenn dir alles andere zu viel ist, mach einfach das:

1. `git init` (einmal, zu Projektbeginn)
2. `.gitignore` anlegen (einmal)
3. `git add -A && git commit -m "description"` (immer, wenn etwas funktioniert)
4. `gh repo create` und `git push` (wenn du bereit zum Teilen bist)

Das war's. Alles andere ist optional und kann bei Bedarf gelernt werden.
