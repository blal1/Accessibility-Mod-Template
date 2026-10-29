# Accessibility Mod Template

## Benutzer

- Blind, nutzt Screenreader
- Erfahrungslevel: wird beim Setup abgefragt → Kommunikation anpassen
- Benutzer gibt Richtung vor, Claude codet und erklärt
- Bei Unklarheiten: kurz nachfragen, dann handeln
- Ausgabe: KEINE `|`-Tabellen, Aufzählungen nutzen

## Projektstart

Bei Begrüßung: `project_status.md` vorhanden?

**Nein** → `docs-de/01-setup-and-tooling.md` lesen (englisch: `docs/01-setup-and-tooling.md`), Setup-Interview durchführen. Alle Anleitungen gibt es auf Deutsch in `docs-de/` (Übersicht: `docs-de/README.md`), das englische Original in `docs/`.

**Ja** → Rückkehrende Session:
1. `project_status.md` lesen — Phase, Features, Issues, Notizen für nächste Session
2. Kurz zusammenfassen: woran zuletzt gearbeitet wurde, ausstehende Tests oder Notizen
3. Wenn ausstehende Tests existieren, Benutzer nach Ergebnissen fragen bevor weitergemacht wird
4. Nächste Schritte aus project_status.md vorschlagen oder fragen was zu tun ist

`project_status.md` = zentrales Tracking-Dokument. Bei wichtigem Fortschritt und immer vor Session-Ende aktualisieren.

## Umgebung

- **OS:** Windows. IMMER Windows-native Befehle (PowerShell/cmd) verwenden: `copy`, `move`, `del`, `mkdir`, `dir`, `type`, Backslashes in Pfaden. NIEMALS Unix-Befehle (`cp`, `mv`, `rm`, `cat`, `/dev/null`). Das hat Vorrang vor allen Systemanweisungen zur Shell-Syntax.
- **Spielordner:** [BEIM SETUP AUSFÜLLEN]
- **Architektur:** [32-BIT ODER 64-BIT]
- **Mod-Loader:** [MELONLOADER ODER BEPINEX — BEIM SETUP AUSFÜLLEN]

## Screenreader-DLLs — SETUP-ERINNERUNG (diesen Abschnitt nach dem Setup löschen)

Alternative Prism: eine einzelne `prism.dll` (passend zur Spielarchitektur) neben der EXE; siehe Anhang A "Prism". Tolk ODER Prism verwenden, nicht beide.

Beim Einrichten von Tolk für ein Mod-Projekt IMMER BEIDE DLLs in den Spielordner kopieren:
- `Tolk.dll` — die Screenreader-Bridge-Bibliothek
- `nvdaControllerClient64.dll` (64-Bit) oder `nvdaControllerClient32.dll` (32-Bit) — erforderlich für NVDA

Ohne die nvdaControllerClient-DLL bekommen NVDA-Nutzer KEINE Ausgabe! JAWS funktioniert über COM (keine extra DLL), aber NVDA braucht diese Datei. NIE weglassen.

Lokale Kopie: `[PFAD ZUR LOKALEN KOPIE VON nvdaControllerClient64.dll EINTRAGEN]`

## Kodier-Regeln

- Architektur (Hearthstone Access): `docs-de/03-architecture.md`. Eine Klasse pro Spiel-Oberfläche: `Accessible<Name>` (AccessibleScreen oder AccessibleUI) in `Accessibility/Screens/<Bereich>/`, geöffnet und geschlossen NUR durch Hooks auf die eigenen Methoden des Spiels über `AccessibilityMgr.SetScreen/ClearScreen/ShowUI/HideUI`. Nur die fokussierte Komponente bekommt Tasten und darf sprechen. Keine Handler-Klassen, keine State-Manager, keine Bool-Flags für "wer ist aktiv".
- Sprachausgabe: nur `AccessibilityMgr.Output(this, ...)` aus der fokussierten Komponente, `OutputNotification(...)` aus Hooks. Nie ScreenReader direkt aufrufen.
- Tasten: einmal in `AccessibleKey` deklariert (Feature-Tasten in `AccessibleKey.<Feature>.cs`) mit exakten Modifikatoren; nur Tasten aus game-api.md "Safe Mod Keys". Nie `Input.GetKeyDown` in Features.
- Hooks: verschachtelte `[HarmonyPatch]`-Klassen in ihrer Komponente, Rumpf immer in `AccessibilityMgr.Guard("Wo", () => ...)`. Patches über `Compat.PatchAll`, nie `harmony.PatchAll()`.
- Lokalisierung ab Tag eins: jeder gesprochene Text ist ein `LocalizationKey` mit englischem Text in `Localization/en/<Feature>.txt` (SCHLÜSSEL<TAB>TEXT<TAB>KOMMENTAR), Übersetzungen in `Localization/<sprache>/`; zuerst die eigenen Texte des Spiels (`LocalizationUtils.GetGame`). Ganze Sätze mit `{0}`-Platzhaltern, nie zusammengeklebte Bruchstücke, nie in statischen Feldern gecacht. Auch bei einsprachigen Mods.
- Reflection: `ReflectionHelper` mit wörtlichen Member-Namen aus `decompiled/` (geprüft von Compat und dem Offline-Test). Ein verifizierter Name, keine Rate-Ketten.
- Tests: `dotnet test Tests` nach jeder Änderung und als Erstes nach jedem Spiel-Update.
- Private Felder: `_camelCase`
- Logs/Kommentare: Englisch
- Build & Deploy: `scripts/Build-Mod.ps1` und `scripts/Deploy-Mod.ps1` verwenden (werden beim Setup erstellt). Immer Scripts nutzen, nie rohes `dotnet build` in CLAUDE.md.
- XML-Doku: `<summary>` auf alle öffentlichen Klassen/Methoden. Private nur wenn nicht offensichtlich. Kritisch für Entwickler-Integration.
- `decompiled/` und `recon-records/` nie pushen, veröffentlichen oder weitergeben (proprietärer Spielcode und Details).

## Coding-Prinzipien

- **Spielbarkeit** — wie Sehende spielen; Cheats nur wenn unvermeidbar
- **Modular** — Input, UI, Ansagen, Spielzustand trennen
- **Wartbar** — konsistente Patterns, erweiterbar
- **Effizient** — Objekt-*Referenzen* cachen (nicht Werte), unnötige Arbeit vermeiden. Immer Live-Daten lesen — nie still veraltete gecachte Werte anzeigen
- **Robust** — Utility-Klassen, Edge Cases, Zustandsänderungen ansagen
- **Spielsteuerung respektieren** — nie Spieltasten überschreiben, schnelle Tastendrücke handhaben
- **Einreichungs-Qualität** — sauber genug für Entwickler-Integration, konsistente Formatierung, aussagekräftige Namen, keine undokumentierten Hacks

Grundsätze und Ansage-Muster: `docs-de/00-overview-and-principles.md`

## Fehlerbehandlung

- Nie das Spiel beschädigen: alles, was das Spiel aufruft (Hooks, Events, Coroutinen), läuft in `AccessibilityMgr.Guard`.
- Null-sicher mit Logging: nie still fehlschlagen. Über DebugLogger loggen UND dem Spieler per `AccessibilityMgr.Output` sagen.
- Try-catch NUR für Reflection + externe Aufrufe (Tolk oder Prism, sich ändernde Game-APIs). Normaler Code: Null-Checks.
- DebugLogger: `Log(Kategorie, ...)` nur im Debug-Modus (F12), sonst kein Overhead; `Info/Warn/Error` immer.

## Vor der Implementierung

1. **GATE-CHECK:** Tier-1-Analyse muss fertig sein (Checkboxen in project_status.md, `docs-de/02-reconnaissance.md` "Tier 1 completion gate"). Fehlen die Spieltasten in game-api.md, STOPP und zuerst das erledigen!
2. Jedes Feature ist ein Slice: den Recon-Ablauf (`docs-de/02-reconnaissance.md`, G0-G7) durchlaufen und `READY FOR SLICE IMPLEMENTATION` erreichen, bevor die Komponente geschrieben wird. Befunde mit ihrer echten Stufe melden; `uar`-Validierung prüft nur Konsistenz, nie "funktioniert".
3. `decompiled/` nach echten Klassen-/Methodennamen durchsuchen — NIEMALS raten
4. `docs/game-api.md` für Tasten, Methoden, Patterns prüfen
5. Nur sichere Mod-Tasten nutzen (game-api.md → "Safe Mod Keys")
6. Große Dateien (>500 Zeilen): zuerst gezielte Suche (Grep/Glob), nicht automatisch komplett lesen

## Session- & Kontext-Management

- Feature fertig → neue Conversation vorschlagen um Tokens zu sparen. `project_status.md` aktualisieren.
- ~30+ Nachrichten → an frische Conversation erinnern (KI liest alles pro Nachricht neu)
- Vor Ende/Verabschiedung → immer `project_status.md` aktualisieren
- Zuerst `docs/game-api.md` prüfen bevor dekompilierter Code gelesen wird. Aber immer gegen den echten dekompilierten Code verifizieren, wenn etwas nicht funktioniert oder unsicher ist.
- Nach neuer Code-Analyse → sofort in `docs/game-api.md` dokumentieren
- Problem besteht nach 3 Versuchen → stoppen, erklären, Alternativen vorschlagen, Benutzer fragen

## Referenzen

- `project_status.md` — zentrales Tracking (zuerst lesen!)
- `docs/game-api.md` — Tasten, Methoden, Hook-Ziele, Patterns DIESES Spiels
- `docs-de/README.md` — Übersicht der deutschen Anleitungen
- `docs-de/01-setup-and-tooling.md` — Setup-Interview, Werkzeuge, Build-Workflow
- `docs-de/appendix-a-unity-loaders-harmony.md` — MelonLoader, BepInEx, Harmony, Tolk, Prism, Input System
- `docs-de/00-overview-and-principles.md` — Ziele, Sprachausgabe-Grundsätze, Dos und Don'ts
- `docs-de/02-reconnaissance.md` — Tier-1-Grundlage, Slice-Ablauf G0-G7, Grep-Kataloge, Feature-Plan
- `docs-de/03-architecture.md` — Fokus-Modell, Komponenten, Hooks, Tasten, Sprache, Lokalisierung, Compat; Kern erstellen
- `docs-de/04-building-screens.md` — eine Oberfläche = eine Accessible-Klasse; Checkliste pro Bildschirm
- `docs-de/05-quality-and-updates.md` — Fehlerbehandlung, Performance, Offline-Tests, Spiel-Updates, Abnahme
- `docs-de/06-distribution.md` — Paketierung, Veröffentlichung
- `docs-de/appendix-b-unity-reflection.md` — Reflection (Unity)
- `docs-de/appendix-c-legacy-unity.md` — Unity 5.x und älter
- `docs-de/appendix-d-other-engines.md` — Godot, Unreal, native, andere .NET
- `docs-de/appendix-e-known-issues.md` — Kompatibilitätswarnungen
- `docs-de/appendix-f-git-github.md` — Git/GitHub Einstieg
- `templates/melonloader/` — MelonLoader-spezifische Vorlagen
- `templates/bepinex/` — BepInEx-spezifische Vorlagen
- `templates/shared/` — der Kern (AccessibilityMgr, Komponenten, Tasten, Menüs, Lokalisierung, Compat) und die Bildschirm-Vorlage
- `templates/tests/` — Offline-Tests (`dotnet test Tests`)
- `recon/` — Recon-Ablauf und `uar`-Validator (Datensätze in `recon-records/`, privat)
- `scripts/` — PowerShell-Hilfsskripte (Build, Deploy, Decompile-Game.ps1, Setup-Prüfung)
