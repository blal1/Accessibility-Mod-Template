# 01 — Setup und Werkzeuge

Deutsche Fassung von `docs/01-setup-and-tooling.md`.

Schritt 1 des Weges (siehe `docs-de/00-overview-and-principles.md`). Dieses Kapitel behandelt das Setup-Interview, die Werkzeug-Pipeline (Spiel-Link, privates Repository mit dem dekompilierten Code und einem Branch pro Spielversion, Recon-Werkzeuge, Offline-Tests), den ersten Build und die Build-/Deploy-Skripte. Es wird nur zu Projektbeginn gebraucht und wenn sich die Werkzeuge ändern.

Weiter: `docs-de/02-reconnaissance.md`.

---

## Setup-Interview

Wenn der Benutzer zum ersten Mal mit Claude in diesem Ordner spricht (z.B. "Hallo", "Neues Projekt", "Los geht's"), führe dieses Interview durch.

**Stelle diese Fragen EINZELN. Warte nach JEDER Frage auf die Antwort.**

### Schritt 1: Erfahrungslevel

Frage: Wie viel Erfahrung hast du mit Programmieren und Modding? (Wenig/Keine oder Viel)

- Merke dir die Antwort für den Rest des Interviews
- Bei "Wenig/Keine": Erkläre Konzepte kontextabhängig bei den folgenden Schritten (siehe Hinweise "Für Anfänger")
- Bei "Viel": Knappe, technische Kommunikation ohne ausführliche Erklärungen

### Schritt 2: Spielname

Frage: Wie heißt das Spiel, das du barrierefrei machen möchtest?

### Schritt 2b: Spielkenntnis

Frage: Wie gut kennst du dieses Spiel? (Sehr gut / Etwas / Gar nicht)

- **"Sehr gut"**: Der Benutzer kann bei der Priorisierung der Features mitreden und Mechaniken erklären. Notiere das in project_status.md.
- **"Etwas"**: Der Benutzer hat Grundwissen, braucht aber eventuell Hilfe beim Verständnis der Spielsysteme. Für später notieren.
- **"Gar nicht"**: Für die Extraktion der Tutorial-Texte nach der Dekompilierung vormerken (siehe Schritt 7b). Bei der Feature-Planung sollte Claude die gefundenen Spielmechaniken ausführlicher erklären.

Merke dir die Antwort — sie beeinflusst Schritt 7b und Phase 1.5 (Feature-Planung).

### Schritt 2c: Open-Source-Prüfung

Sobald der Spielname bekannt ist, suche **automatisch** nach öffentlich verfügbarem Quellcode:

**Durchzuführende Suchen:**
- Websuche: "[Spielname] source code site:github.com"
- Websuche: "[Spielname] open source game"
- Websuche: "[Spielname] gitlab source"

**Falls das Spiel öffentlich verfügbaren Quellcode hat:**

Sag dem Benutzer:

> Gute Nachricht! [Spielname] scheint Open Source zu sein. Der Quellcode ist unter [URL] verfügbar. Das ist ein großer Vorteil für Accessibility-Modding:
>
> - Wir haben den echten Quellcode mit richtigen Variablennamen, Kommentaren und Dokumentation — viel einfacher zu bearbeiten als dekompilierter Code
> - Wir können unsere Accessibility-Features eventuell direkt per Pull Request ins Spiel einbringen
> - Keine Dekompilierung nötig — der Code ist leichter zu lesen und zu verstehen
> - Wir können das Spiel selbst bauen und testen

**Frage:** "Möchtest du direkt mit dem Quellcode arbeiten (empfohlen) oder einen separaten Mod erstellen?"

#### Option A: Direkte Änderung am Quellcode (empfohlen)

**Vorteile:**
- Echter Quellcode mit Kommentaren und Dokumentation
- Accessibility-Features können als PR beim Originalprojekt eingereicht werden
- Kein Dekompiler, kein MelonLoader/BepInEx nötig
- Bessere Integration, weniger Kompatibilitätsprobleme bei Spiel-Updates
- Die Entwickler schauen sich deinen Code vielleicht an und helfen ihn zu verbessern

**Was sich am Ablauf ändert:**
- Das Repository klonen statt dekompilieren
- Die Build-Umgebung nach der Build-Anleitung des Projekts einrichten
- Schritte 5-7 überspringen (Mod-Loader, Tolk-Setup, Dekompilierung) — je nach Architektur des Spiels bei Bedarf darauf zurückkommen
- Die Screenreader-Anbindung hängt von der Audio-/UI-Architektur des Spiels ab
- Die Analyse in Phase 1 ist mit echtem Quellcode viel einfacher
- Der Ordner `decompiled/` wird nicht gebraucht — direkt den geklonten Quellcode verwenden

**Wichtig: Lizenz prüfen!**

Lies die LICENSE-Datei des Repositorys, bevor du anfängst. Häufige Lizenzen:
- **MIT, Apache, BSD:** Freizügig — darf frei verändert werden, die Originallizenz muss beiliegen
- **GPL:** Änderungen müssen unter derselben Lizenz geteilt werden (für Accessibility-Mods kein Problem — die sollten ohnehin offen sein)
- **Eigene Lizenz / "source available":** Genau lesen — kann Änderungen oder Weitergabe einschränken

Ist die Lizenz unklar, notiere das in `project_status.md` und schlage dem Benutzer vor, bei den Entwicklern nachzufragen.

**Angepasste Setup-Schritte für die Arbeit direkt am Quellcode:**
1. Das Repository in einen lokalen Ordner klonen
2. Der README/Build-Anleitung des Projekts folgen, um die Entwicklungsumgebung einzurichten
3. Prüfen, dass du das Spiel aus dem Quellcode bauen und starten kannst
4. Herausfinden, wie das Spiel Audioausgabe und UI handhabt (ersetzt die Analyse des dekompilierten Codes)
5. Einen Branch für die Accessibility-Arbeit anlegen
6. Mit der Analyse in Phase 1 weitermachen (mit echtem Quellcode viel einfacher)

#### Option B: Separater Mod (falls das Spiel ein Plugin-/Mod-System hat)

Manchmal auch bei Open-Source-Spielen sinnvoll:
- Das Spiel hat bereits eine Mod-/Plugin-API
- Einfacher zu verteilen (Benutzer installieren einen Mod, statt das Spiel zu bauen)
- Man muss keinen Fork über Spiel-Updates hinweg pflegen

Wählt der Benutzer das: mit dem normalen Setup weitermachen (Schritt 3+), aber für die Analyse den Quellcode statt Dekompilierung verwenden.

**Falls das Spiel NICHT Open Source ist:** Normal mit Schritt 3 weitermachen. Nichts weiter zu tun.

Für Anfänger: "Open Source" heißt, dass die Entwickler den Quellcode des Programms öffentlich gemacht haben. Stell es dir vor, als bekämst du das Rezept statt nur das fertige Gericht — wir sehen genau, wie alles funktioniert, und das macht das Einbauen von Accessibility-Features viel einfacher. Manche Entwickler nehmen auch Beiträge aus der Community an, sodass unsere Accessibility-Arbeit im offiziellen Spiel landen könnte, wovon alle profitieren.

---

### WICHTIG: Internet-Recherche während des Setups begrenzen!

Sobald der Spielname bekannt ist, **recherchiere KEINE Spiel-Interna online** (UI-Systeme, Spielmechaniken, Code-Struktur, wie bestimmte Features funktionieren). Ein grobes Verständnis von Genre und Überblick ist in Ordnung ("rundenbasiertes RPG", "Städtebauspiel"), aber eine genaue Analyse der Spielsysteme **MUSS auf den dekompilierten Quellcode warten** (Phase 1).

**Erlaubte Internet-Recherche während des Setups:**
- Ist das Spiel Open Source? (Schritt 2c)
- Welche Engine benutzt es? (Schritt 4)
- Welchen Mod-Loader benutzt die Community? (Schritt 4b/4e)
- Ist Modding bei Nicht-Unity-Engines machbar? (Schritt 4d)

**NICHT erlaubt vor der Dekompilierung:**
- Wie das UI-/Menüsystem des Spiels funktioniert
- Welche Klassen oder Systeme das Spiel intern benutzt
- Spielarchitektur, Zustandsverwaltung, Event-Systeme
- Alles, was in die Analyse in Phase 1 gehört

**Warum?** Informationen aus dem Internet über Spiel-Interna sind unzuverlässig — sie können veraltet oder falsch sein oder eine andere Version beschreiben. Der dekompilierte Quellcode ist die einzige vertrauenswürdige Quelle. Vorschnelle Recherche verschwendet Tokens und kann zu falschen Annahmen führen, die man später schwer wieder loswird.

---

### Schritt 3: Installationspfad

Frage: Wo ist das Spiel installiert? (z.B. `C:\Program Files (x86)\Steam\steamapps\common\GameName`)

### Schritt 4: Automatische Prüfung anbieten

Nachdem der Spielpfad bekannt ist, biete an:

Frage: Soll ich den Spielordner automatisch prüfen? Ich kann die Game-Engine, die Architektur (32/64-Bit) und vorhandene Modding-Infrastruktur erkennen.

**Falls ja:**

Führe diese Prüfungen durch und sammle die Ergebnisse:

1. **Game-Engine erkennen:**
   - Prüfe ob `UnityPlayer.dll` existiert → Unity-Spiel
   - Prüfe ob der Ordner `[GameName]_Data\Managed` existiert → Unity-Spiel
   - Prüfe auf `.pak`-Dateien oder `UnrealEngine`/`UE4` in Dateinamen → Unreal Engine
   - Prüfe auf `libgodot`- oder `.pck`-Dateien → Godot
   - Prüfe auf `data.win`- oder `audiogroup`-Dateien → GameMaker
   - Falls unklar: Als "Unbekannte Engine" notieren

2. **Architektur erkennen:**
   - Ordner `MonoBleedingEdge` vorhanden → 64-Bit
   - Ordner `Mono` (ohne "BleedingEdge") → 32-Bit
   - Dateien mit "x64" im Namen → 64-Bit
   - Auch die Eigenschaften der `.exe`-Datei können die Architektur verraten

3. **Vorhandene Modding-Infrastruktur prüfen:**
   - Ordner `MelonLoader` → MelonLoader installiert (Unity)
   - Ordner `BepInEx` → BepInEx installiert (Unity)
   - Ordner `Mods` oder `plugins` → Mögliche Mod-Unterstützung
   - `UE4SS` o.ä. → Unreal-Modding-Werkzeuge
   - Workshop-Ordner oder Steam-Workshop-Integration

4. **Bei Unity mit Mod-Loader - Log auslesen (falls vorhanden):**
   - **MelonLoader** (`MelonLoader/Latest.log`): Game Name, Developer, Runtime Type (net35/net6), Unity Version extrahieren
   - **BepInEx** (`BepInEx/LogOutput.log`): Erfolgreiche Initialisierung, Unity-Version, eventuelle Fehler prüfen

4b. **Falls kein Mod-Loader installiert ist — Community-Konsens recherchieren:**
   - Websuche: "[Spielname] mods"
   - Websuche: "[Spielname] MelonLoader OR BepInEx"
   - Nexus Mods, Thunderstore oder spielspezifische Mod-Seiten prüfen
   - Notieren, welchen Mod-Loader andere Mods für dieses Spiel nutzen
   - Falls keine Mods gefunden werden, das notieren — die Wahl des Mod-Loaders basiert dann auf Heuristiken (siehe Schritt 4e)

5. **Unity-Version prüfen (bei Unity-Spielen):**
   - Unity-Version 4.x oder älter (3.x, 2.x): **Kritische Warnung** - MelonLoader und BepInEx funktionieren NICHT, nur Assembly-Patching ist möglich. So alte Spiele sind selten, aber es gibt sie.
   - Unity-Version 5.x: **Warnung** - MelonLoader funktioniert eventuell nicht, zuerst BepInEx 5.x probieren
   - Unity-Version 2017-2018: Funktioniert meistens, braucht eventuell eine ältere MelonLoader-Version
   - Unity-Version 2019+: Volle Unterstützung, keine Probleme zu erwarten
   - Details zu älteren Unity-Versionen: `docs-de/appendix-c-legacy-unity.md`

5b. **Bekannte Probleme prüfen (`docs-de/appendix-e-known-issues.md`):**
   - `docs-de/appendix-e-known-issues.md` lesen und ALLE Kategorien mit der erkannten Konfiguration (Engine, Version, Mod-Loader) abgleichen
   - Passt ein Eintrag: **den Benutzer sofort warnen**, mit Beschreibung des Problems und Workaround
   - Jede zutreffende Warnung in `project_status.md` im Abschnitt "Known Issues" festhalten
   - Gibt es für einen Treffer keinen Workaround, mit dem Benutzer Alternativen besprechen, bevor das Setup weitergeht

6. **Tolk-DLLs prüfen:**
   - Bei 64-Bit: Prüfe ob `Tolk.dll` und `nvdaControllerClient64.dll` im Spielordner liegen
   - Bei 32-Bit: Prüfe ob `Tolk.dll` und `nvdaControllerClient32.dll` im Spielordner liegen

**Ergebnisse zusammenfassen:**

Zeige eine Zusammenfassung dessen, was erkannt wurde:
- Game-Engine: Unity / Unreal / Godot / GameMaker / Unbekannt
- Architektur: 64-Bit / 32-Bit / Unbekannt
- Mod-Loader: MelonLoader / BepInEx / Keiner installiert (+ Community-Empfehlung, falls recherchiert)
- Infos aus dem Mod-Loader-Log: Game Name, Developer, Runtime, Unity-Version (falls vorhanden)
- Tolk-DLLs: Vorhanden / Fehlen

Frage: Stimmt das so? (Bestätigung abwarten)

**Die nächsten Schritte hängen von der Engine ab - siehe Schritt 4d unten.**

**Falls nein (manuelle Prüfung gewünscht):**

Fahre mit den manuellen Schritten 4a-4c fort.

---

### Schritt 4d: Engine-spezifische nächste Schritte

Je nach erkannter Engine unterschiedlich vorgehen:

#### Falls Unity-Spiel

Weiter mit Schritt 4e (Mod-Loader). Unity-Spiele haben die beste Modding-Unterstützung für Accessibility-Mods.

#### Falls KEIN Unity-Spiel

**Nicht sofort aufgeben!** Aber ehrlich einschätzen, was realistisch ist. Die Machbarkeit hängt stark von der Engine ab und davon, ob es für genau dieses Spiel eine aktive Modding-Community gibt.

**Zuerst immer diese allgemeinen Prüfungen:**

1. **Nach offizieller Mod-Unterstützung suchen:**
   - Hat das Spiel eine Steam-Workshop-Integration?
   - Hat der Entwickler Modding-Tools oder ein SDK veröffentlicht?
   - Gibt es einen `Mods`-Ordner o.ä. im Spielordner?

2. **Nach Modding-Ressourcen der Community suchen:**
   - Websuche: "[Spielname] modding guide"
   - Websuche: "[Spielname] mod loader"
   - Nexus Mods, Thunderstore, ModDB nach vorhandenen Mods durchsuchen
   - Nach spielspezifischen Discord-Servern oder Foren suchen

3. **Prüfen, in welcher Sprache der Spielcode geschrieben ist:**
   - C# / .NET / Mono → Sehr gut moddbar (siehe .NET-Spiele unten)
   - Java → Mit Java-spezifischen Werkzeugen moddbar
   - Lua-Skripte im Spielordner → Durch Bearbeiten der Skripte moddbar
   - Python-Skripte im Spielordner → Durch Bearbeiten der Skripte moddbar
   - Nur C++ → Schwierig (siehe Abschnitte unten)

Für Anfänger: Verschiedene Spiele nutzen verschiedene "Engines" (die zugrunde liegende Technik). Jede Engine braucht andere Werkzeuge zum Modden. Spiele in C# oder mit Skriptsprachen (Lua, Python) sind im Allgemeinen viel leichter zu modden als reine C++-Spiele.

**Dann je nach erkannter Engine vorgehen:**

---

##### Unreal Engine (UE4 / UE5)

**HINWEIS: Die Informationen in diesem Abschnitt basieren auf Recherche, nicht auf erprobter Accessibility-Modding-Erfahrung. Es gibt noch kein etabliertes Muster für Screenreader-Accessibility-Mods in Unreal-Spielen. Nutze dies als Ausgangspunkt für die Untersuchung, nicht als garantierten Ablauf.**

**Erkennung:** `.pak`-Dateien, `UE4` oder `UE5` in Dateinamen, Ordnerstruktur `Engine/Binaries`.

**Was es gibt:**
- **UE4SS** (RE-UE4SS) ist das Standard-Modding-Framework der Community für Unreal-Spiele. Es injiziert sich ins Spiel und bietet eine Lua-Skriptschicht und eine C++-Mod-API. Von der Rolle her vergleichbar mit MelonLoader/BepInEx, aber für Unreal.
- UE4SS kann reflektierte Spielfunktionen hooken (ähnliches Konzept wie Harmony, aber nur für Funktionen, die im Reflection-System der Engine als UFUNCTION markiert sind — nicht für beliebige C++-Funktionen).
- Lua-Mods können Eigenschaften von Spielobjekten lesen/schreiben, die Ausführung von Funktionen hooken und auf Spiel-Events reagieren.
- C++-Mods, als DLLs kompiliert, könnten theoretisch Tolk für die Screenreader-Ausgabe aufrufen.

**Analyse-Werkzeuge:**
- UE4SS erzeugt SDK-/Header-Dumps mit Klassennamen, Properties und Funktionssignaturen — das kommt der Unity-Dekompilierung am nächsten, liefert aber nur die API-Struktur, keinen Implementierungscode.
- FModel extrahiert und durchsucht Spiel-Assets aus .pak-Dateien.
- KismetKompiler kann Blueprint-Bytecode dekompilieren (für Blueprint-lastige Spiele).

**Accessibility-Barrieren für blinde Modder:**
- FModel und der UE4SS Live Property Viewer sind visuelle GUI-Werkzeuge — **mit Screenreader nicht bedienbar**.
- Die Ausgabe der SDK-/Header-Dumps ist textbasiert und lässt sich mit CLI-Werkzeugen durchsuchen — dieser Teil ist zugänglich.
- Es gibt **keine existierenden Screenreader-Accessibility-Mods** für irgendein Unreal-Spiel, von denen man lernen könnte. Das wäre Neuland.
- Die Analyse des Spielcodes ist schwieriger als bei Unity, weil man nur API-Signaturen bekommt, keinen vollständigen Quellcode.

**Realistische Einschätzung:**
- **Machbar, wenn:** Das Spiel eine aktive UE4SS-Modding-Community mit dokumentierten Hooks und APIs hat. Andere Mods existieren, die zeigen, wie man an die Spieldaten kommt. Ein sehender Helfer bei der ersten Analyse mit den visuellen Werkzeugen unterstützen könnte.
- **Nicht machbar, wenn:** Keine Modding-Community existiert, das Spiel nicht mit UE4SS funktioniert oder wichtige Spiellogik in nicht-reflektierten nativen C++-Funktionen liegt.
- **Unser Template ist NICHT direkt anwendbar.** Die Mod-Sprache ist Lua oder C++ (nicht C#), das Patching-System ist anders und die Projektstruktur ist komplett verschieden. Die Accessibility-Muster (Handler-Klassen, ScreenReader-Wrapper, Lokalisierungssystem) lassen sich konzeptionell übertragen, aber der Code müsste neu geschrieben werden.

**Falls es weitergeht:** Zuerst die UE4SS-Kompatibilität für genau dieses Spiel recherchieren. Den UE4SS-Discord und die Dokumentation prüfen. Erkenntnisse in `docs/game-api.md` festhalten.

---

##### Godot Engine

**HINWEIS: Die Informationen in diesem Abschnitt basieren auf Recherche, nicht auf erprobter Accessibility-Modding-Erfahrung. Nutze dies als Ausgangspunkt, nicht als garantierten Ablauf.**

**Erkennung:** `.pck`-Dateien, `libgodot`-Dateien, Godot-Splashscreen.

**Was es gibt:**
- **Godot Mod Loader** ist das wichtigste Modding-Framework — aber er **muss vom Spielentwickler eingebaut werden**. Er lässt sich nicht von außen injizieren (anders als MelonLoader/BepInEx). Enthält das Spiel ihn nicht, ist Modding auf Skriptebene sehr eingeschränkt.
- Ohne den Mod Loader: Mods funktionieren, indem Spieldateien über PCK-Pakete ersetzt werden. Spielskripte dekompilieren, ändern, wieder als PCK verpacken. Das ist fragil und geht bei Spiel-Updates kaputt.
- **Godot 4.5+** (erschienen im September 2025) hat eingebaute AccessKit-Screenreader-Unterstützung. Nutzt das Spiel Godot 4.5+ und Standard-UI-Nodes, ist die UI eventuell schon ohne jedes Modding teilweise für Screenreader zugänglich.
- Godot ist vollständig Open Source (MIT-Lizenz), die Engine-Interna sind also dokumentiert.

**Analyse-Werkzeuge:**
- **gdsdecomp / GDRE Tools** kann GDScript-Bytecode wieder in lesbaren Quellcode dekompilieren — ähnlich wie dnSpy für .NET. Es ist ein CLI-Werkzeug und sollte mit Screenreader bedienbar sein.
- **GdTool** ist ein CLI-Werkzeug zum Kompilieren/Dekompilieren von GDScript und zum Verwalten von PCK-Dateien.

**Accessibility-Barrieren für blinde Modder:**
- Fehlt dem Spiel der Godot Mod Loader: nur das Ersetzen von PCK-Dateien funktioniert, was aufwendig und fragil ist.
- Die Mod-Sprache ist GDScript (nicht C#), man muss also eine neue Sprache lernen.
- Für Godot-Spiele sind noch keine Accessibility-Mods bekannt.

**Realistische Einschätzung:**
- **Bester Fall:** Das Spiel nutzt Godot 4.5+ (AccessKit ist eventuell eingebaut) UND hat den Godot Mod Loader integriert. Dann sind GDScript-Mods mit TTS-Aufrufen möglich.
- **Mittlerer Fall:** Das Spiel lässt sich mit gdsdecomp dekompilieren, Skripte ändern und neu verpacken. Funktioniert, ist aber fragil.
- **Schlechtester Fall:** Das Spiel nutzt Godot 3.x ohne Mod Loader. Beschränkt auf das Ersetzen von Skripten, keine eingebaute Accessibility-Unterstützung.
- **Unser Template ist NICHT direkt anwendbar** (andere Sprache, andere Mod-Struktur), aber die Accessibility-Muster (modulare Handler, Lokalisierung, Screenreader-Wrapper) lassen sich konzeptionell übertragen.

---

##### .NET-Spiele (XNA, MonoGame, FNA, andere .NET-Frameworks)

**Erkennung:** Die Spiel-DLLs lassen sich mit dnSpy/ILSpy öffnen und zeigen lesbaren C#-Code. Suche nach `MonoGame.Framework.dll`, `FNA.dll`, `Microsoft.Xna.Framework.dll` oder anderen .NET-Assemblies im Spielordner.

**Gute Nachricht: Diese Spiele lassen sich mit denselben Werkzeugen modden wie Unity-Spiele.**

- **BepInEx** unterstützt ausdrücklich auch .NET-Framework-Spiele jenseits von Unity, einschließlich XNA-, MonoGame- und FNA-Spielen.
- **Harmony**-Patching funktioniert genauso wie bei Unity — IL-Patching beliebiger .NET-Methoden zur Laufzeit.
- **dnSpy / ILSpy** dekompilieren den Spielcode zu lesbarem C#, genau wie bei Unity.
- Die **Tolk**-Anbindung funktioniert identisch.

**Erprobte Beispiele:**
- Stardew Valley (MonoGame) hat SMAPI, einen eigenen Mod-Loader mit tausenden Mods
- Celeste (MonoGame) hat den Mod-Loader Everest

**Realistische Einschätzung:**
- **Unser Template ist weitgehend anwendbar.** Die Accessibility-Architektur (AccessibilityMgr, Komponenten, Tasten, Lokalisierung), der ScreenReader-Wrapper und die Offline-Tests funktionieren alle. Die Hauptunterschiede liegen im Projekt-Setup (andere DLL-Referenzen, kein MelonLoader-/Unity-spezifischer Lebenszyklus) und eventuell in anderen Einstiegspunkten.
- **Die Machbarkeit ist ähnlich wie bei Unity** — wenn sich die DLLs dekompilieren lassen und BepInEx funktioniert, gilt der komplette Ablauf.

**Falls es weitergeht:** Zuerst BepInEx probieren. Den Spielcode mit dnSpy analysieren. Die Main.cs des Templates auf das `BaseUnityPlugin`-Muster von BepInEx anpassen (oder auf die passende Basisklasse des jeweiligen .NET-Frameworks). Der Rest des Templates (der Kern aus `templates/shared/`, ScreenReader) braucht nur minimale Änderungen; siehe `docs-de/appendix-d-other-engines.md`.

---

##### Java-Spiele

**HINWEIS: Modding von Java-Spielen ist gut etabliert (Minecraft hat die größte Modding-Community im Gaming), nutzt aber völlig andere Werkzeuge als unser C#-basiertes Template.**

**Erkennung:** `.jar`-Dateien, Java Runtime erforderlich, Ordner `jre` oder `jdk`.

**Was es gibt:**
- Java-Bytecode behält Metadaten (Klassennamen, Methodennamen) ähnlich wie .NET — Dekompilierung liefert lesbaren Code.
- **Minecraft** hat ausgereifte Mod-Loader: Fabric (schlank, nutzt Mixin für Bytecode-Injektion) und NeoForge (umfassende APIs). Das Mixin-System ist konzeptionell mit Harmony vergleichbar.
- Andere Java-Spiele haben vielleicht keine etablierten Mod-Loader, aber es gibt Java-Dekompiler (JD-GUI, Fernflower, CFR) und Bibliotheken zur Bytecode-Manipulation.

**Accessibility-Barrieren:**
- Unser Template (C#, .NET, Tolk) ist nicht anwendbar — Java nutzt ein anderes Ökosystem.
- Tolk hat keine Java-Bindings (man bräuchte JNI oder JNA, um die native DLL aufzurufen).
- Entwicklungsablauf, Build-Werkzeuge und Projektstruktur sind komplett anders.

**Realistische Einschätzung:**
- **Machbar für Minecraft** und andere Java-Spiele mit etablierten Mod-Loadern — erfordert aber Java-Entwicklungskenntnisse und spielspezifische Werkzeuge.
- **Unser Template ist beim Code NICHT anwendbar**, aber die Accessibility-Konzepte (modulare Handler, Screenreader-Anbindung, Lokalisierung) lassen sich auf jede Sprache übertragen.
- Wollte jemand ein Accessibility-Modding-Template für Java erstellen, wäre das ein eigenes Projekt.

---

##### Spiele mit eingebettetem Lua-Scripting

**Erkennung:** Suche nach `lua51.dll`, `lua52.dll`, `lua53.dll`, `lua54.dll` oder `luajit.dll` im Spielordner. Achte auch auf `.lua`- oder `.luac`-Dateien.

**Was es gibt:**
- Viele eigene Engines betten Lua als Skriptschicht ein. Lädt das Spiel Lua-Skripte aus Dateien, lassen sich diese ändern oder erweitern.
- Spiele mit umfassenden Lua-APIs sind z.B.: World of Warcraft (UI-Addons), Factorio (vollständige Gameplay-Mods), Don't Starve, Garry's Mod.
- Das FFI (Foreign Function Interface) von LuaJIT kann native DLLs aufrufen — Tolk ließe sich also möglicherweise aus Lua-Mods aufrufen.

**Realistische Einschätzung:**
- **Stark spielabhängig.** Manche per Lua geskripteten Spiele haben reichhaltige APIs und aktive Communities (Factorio, WoW). Andere nutzen Lua nur für interne Konfiguration, ohne Angriffsfläche fürs Modding.
- **Wenn die Lua-Skripte bearbeitbar und dokumentiert sind:** Das kann ein gangbarer Weg sein. Der Mod würde in Lua statt C# geschrieben, und Tolk ließe sich über FFI aufrufen.
- **Wenn der Lua-Bytecode kompiliert ist (nur `.luac`-Dateien):** Dekompilierung ist möglich, aber weniger zuverlässig als bei GDScript oder .NET.
- **Unser Template ist NICHT direkt anwendbar** (andere Sprache), aber die Muster lassen sich übertragen.

---

##### Spiele mit eingebettetem Python

**Erkennung:** Suche nach `python*.dll` im Spielordner oder nach `.py`- / `.pyc`-Dateien.

**Was es gibt:**
- **Ren'Py** (Visual-Novel-Engine): Basiert auf Python, Open Source, leicht zu modden durch Bearbeiten der `.rpy`-Skriptdateien. Hat eine Community.
- Manche eigene Engines betten Python fürs Scripting ein.
- Die Python-Bibliothek `ctypes` kann native DLLs aufrufen — die Tolk-Anbindung ist aus Python heraus einfach.
- `.pyc`-Dateien (kompilierter Python-Bytecode) lassen sich mit Werkzeugen wie `uncompyle6` oder `decompyle3` dekompilieren.

**Realistische Einschätzung:**
- **Ren'Py-Spiele:** Relativ leicht zu modden. Die Skripte werden oft als lesbare `.rpy`-Dateien ausgeliefert. Accessibility-Mods könnten TTS-Aufrufe ergänzen.
- **Andere per Python geskriptete Spiele:** Hängt davon ab, wie viel der Spiellogik in Python liegt und ob die Skripte zugänglich sind.
- **Unser Template ist NICHT direkt anwendbar** (andere Sprache), aber die Muster lassen sich übertragen.

---

##### Eigene oder proprietäre Engines

**HINWEIS: Dieser Abschnitt beschreibt das allgemeine Vorgehen, wenn ein Spiel eine unbekannte, selbst entwickelte oder proprietäre Engine nutzt. Ziel ist, systematisch einzuschätzen, ob Accessibility-Modding machbar ist, bevor viel Zeit investiert wird.**

**Erkennung:** Das Spiel passt zu keiner der bekannten Engines oben (keine UnityPlayer.dll, keine .pak-Dateien, keine Godot-Merkmale, keine .NET-Assemblies, kein Java). Das Spiel nutzt vielleicht eine weniger bekannte Open-Source-Engine (Torque, OGRE, Irrlicht usw.), eine stark veränderte Version einer bekannten Engine oder etwas komplett Selbstgebautes.

**Schritt 1: Die Engine identifizieren**

Systematisch suchen:
- Websuche: "[Spielname] game engine"
- Websuche: "[Spielname] what engine"
- Websuche: "[Spielname] technology" oder "[Spielname] made with"
- PCGamingWiki prüfen (nennt oft die Engine)
- Den Wikipedia-Artikel zum Spiel prüfen
- Entwickler-Interviews oder Devblogs prüfen
- Die DLL-Dateien im Spielordner auf engine-spezifische Namen ansehen

**Schritt 2: Prüfen, ob die Engine Open Source ist**

Wenn du den Namen der Engine gefunden hast:
- Websuche: "[Engine-Name] open source"
- Websuche: "[Engine-Name] github"
- Die Lizenz der Engine prüfen (MIT, GPL, proprietär?)

**Wichtige Unterscheidung:** Eine Open-Source-Engine heißt NICHT, dass das Spiel Open Source ist. Das Spiel kann ein kommerzielles Produkt auf Basis einer Open-Source-Engine sein. Der Engine-Quellcode hilft, die Interna zu verstehen, aber an den spielspezifischen Quellcode kommst du trotzdem nicht, solange der Entwickler ihn nicht teilt.

**Schritt 3: Die Skriptschicht untersuchen**

Das ist die wichtigste Frage für Accessibility-Modding. Suche nach:
- Websuche: "[Engine-Name] scripting language"
- Websuche: "[Spielname] modding scripting"
- Im Spielordner nach Skriptdateien schauen (.lua, .py, .cs, .js, .gd, .sq, .nut oder engine-spezifische Endungen)
- Prüfen, ob die Skripte Klartext (lesbar) oder kompilierter Bytecode sind

**Kernfrage: Kann die Skriptsprache externe DLLs (wie Tolk) aufrufen?**

- **Ja, nativ** (z.B. Lua mit FFI, Python mit ctypes): Screenreader-Anbindung ist aus Mods heraus möglich
- **Kein natives FFI**: Screenreader-Ausgabe erfordert entweder eine Änderung an der Engine (auf C++-Ebene) oder Umwege (über Dateien, über die Zwischenablage) — beides fragil oder nur mit sehender Hilfe machbar
- **Gar keine Skriptschicht**: Fällt in die Kategorie "Reine C++-Spiele" unten

**Schritt 4: Nach vorhandener Mod-Unterstützung suchen**

- Websuche: "[Spielname] modding support"
- Websuche: "[Spielname] mods"
- Nexus Mods, ModDB, Steam Workshop prüfen
- Prüfen, ob der Entwickler Modding-Werkzeuge oder Dokumentation veröffentlicht hat
- Im Spielordner nach einem `mods/`-Ordner o.ä. suchen

**Schritt 5: Die Modding-Angriffsfläche einschätzen**

Wenn es Modding gibt, bestimmen, was sich ändern lässt:
- **Nur Inhalte** (Texturen, Level, Übersetzungen): Reicht für Accessibility-Mods nicht
- **Spiellogik über Skripte** (Kampf, KI, Events, Dialoge): Nützlich, braucht aber eine Brücke zum Screenreader
- **UI/GUI lässt sich ändern**: Entscheidend für die Zugänglichkeit von Menüs
- **Laden von Plugins/DLLs**: Bester Fall — es könnte eine native DLL mit Tolk geladen werden

**Schritt 6: Die Machbarkeit für Accessibility bewerten**

Die Lage ehrlich einschätzen:

**Machbar (mit Vorsicht weitermachen):**
- Das Spiel erlaubt Modding auf Skriptebene UND die Skriptsprache kann native DLLs (Tolk) aufrufen
- ODER: Das Spiel lädt native Plugins/DLLs, die sich in Spiel-Events einhängen können
- Aktive Modding-Community mit Dokumentation

**Teilweise machbar (deutliche Einschränkungen):**
- Modding auf Skriptebene existiert, aber Tolk lässt sich aus Skripten nicht aufrufen
- Umwege sind möglich (TTS-Brücke über Dateien, Überwachung der Zwischenablage), bringen aber Verzögerung und Fragilität
- Die Engine ist Open Source, Tolk ließe sich also theoretisch auf Engine-Ebene einbauen, aber das erfordert C++-Kompilierung und wahrscheinlich sehende Hilfe
- UI/Spiellogik lässt sich ändern, aber die Screenreader-Ausgabe braucht externe Werkzeuge

**Nicht machbar (sei ehrlich zum Benutzer):**
- Keine Mod-Unterstützung und keine Möglichkeit, Code einzuschleusen
- Die Engine ist Closed-Source-C++ ohne Skriptschicht
- Das einzige "Modding" ist das Ersetzen von Assets (Texturen, Sounds)

**Bei teilweiser Machbarkeit die Optionen mit dem Benutzer besprechen:**

> Dieses Spiel nutzt [Engine-Name], das [Skript-/Mod-Unterstützung] hat, aber es gibt keinen direkten Weg, aus einem Mod heraus Text an deinen Screenreader zu schicken. Das sind die realistischen Optionen:
>
> 1. **Den Entwickler kontaktieren** — Fragen, ob er Screenreader-Unterstützung einbaut oder seinen Engine-Build teilt, damit wir die Tolk-Anbindung ergänzen können. Das ist der nachhaltigste Weg.
> 2. **Externes Brücken-Werkzeug** — Wir schreiben ein kleines Begleitprogramm, das eine Datei oder die Zwischenablage auf Text vom Mod überwacht und ihn über den Screenreader ausgibt. Das funktioniert, bringt aber Verzögerung und Komplexität.
> 3. **Änderung an der Engine** (falls Open Source) — Der Skriptsprache der Engine eine native Funktion hinzufügen, die Tolk aufruft. Erfordert C++-Entwicklung und jemanden, der die Engine kompilieren kann.
> 4. **Hilfe aus der Community** — Prüfen, ob sehende Modder oder Entwickler beim Teil der Screenreader-Anbindung mitarbeiten würden.

**Unser Template ist für eigene Engines NICHT direkt anwendbar** (andere Sprache, andere Architektur), aber die Accessibility-Muster (modulare Handler, das Konzept des Screenreader-Wrappers, Lokalisierung, Zustandsverfolgung) lassen sich konzeptionell auf jede Sprache übertragen.

---

##### Reine C++-Spiele (keine Skriptschicht)

Ist das Spiel rein in C++ geschrieben, ohne jede Skriptschicht (Lua, Python, C#), sag es dem Benutzer offen:

> **Wichtiger Hinweis:** Reine C++-Spiele sind für Accessibility-Modding extrem schwierig — besonders für blinde Modder. Und zwar aus diesem Grund:
>
> Die Werkzeuge, die sehende Reverse Engineers nutzen (Cheat Engine, ReClass, Frida, x64dbg), sind grundsätzlich **mit Screenreader nicht bedienbar**. Sie erfordern, das Spiel visuell zu steuern, Speicherlayouts auf dem Bildschirm zu untersuchen und den sichtbaren Spielzustand mit Speicheradressen abzugleichen. Ein blinder Benutzer kann diese Schritte nicht selbstständig durchführen.
>
> Selbst wenn jemand Sehendes beim Finden von Speicheradressen hilft, sind die Ergebnisse **unzuverlässig**: Adressen ändern sich zwischen Spielsitzungen, Spiel-Updates und Systemkonfigurationen. Stabile Accessibility-Features auf wechselnden Speicheradressen aufzubauen, ist keine tragfähige Grundlage.
>
> **Realistisch ist ein reines C++-Spiel nur dann für Accessibility moddbar, wenn:**
>
> 1. **Eine etablierte Modding-Community existiert** mit dokumentierten Werkzeugen und APIs. Gibt es andere Mods, können wir deren Ansatz studieren und auf erprobten Methoden aufbauen.
> 2. **Das Spiel offizielle Mod-Unterstützung hat** — ein SDK, eine Plugin-API oder eine Skriptschnittstelle, die stabilen, benannten Zugriff auf die Spieldaten bietet.
> 3. **Das Spiel Daten in zugänglichen Formaten speichert** — lesbare Konfigurationsdateien, Spielstände oder APIs, die sich von außen auswerten lassen.
>
> **Falls nichts davon zutrifft:**
>
> Sei ehrlich: Dieses Spiel ist derzeit für einen blinden Modder nicht für Accessibility moddbar. Das ist keine Frage des Könnens — es ist eine Barriere bei Werkzeugen und Zugang.
>
> Alternativen vorschlagen:
> - Den Spielentwickler direkt kontaktieren und um Accessibility-Features oder eine Accessibility-API bitten
> - Prüfen, ob es schon ein Accessibility-Projekt der Community gibt (manchmal leiten sehende Freiwillige solche Projekte)
> - Nach einem anderen Spiel mit ähnlichem Gameplay suchen, das eine moddbare Engine nutzt
> - Prüfen, ob der Entwickler Open-Source-freundlich ist — schon teilweiser Zugang (Spieldatendateien, Dokumentation) kann helfen

---

##### Spiele mit offiziellem Modding-SDK

Manche Spiele liefern unabhängig von der Engine offizielle Modding-Werkzeuge mit. Hat die automatische Prüfung oder die Community-Suche ein SDK, einen Mod-Editor oder eine dokumentierte Mod-API gefunden:

- **Das ist immer der bevorzugte Weg.** Offizielle Werkzeuge sind stabiler und besser dokumentiert als Reverse Engineering.
- Prüfen, was das SDK erlaubt: nur Inhalts-/Asset-Mods oder auch Code-/Logik-Mods?
- Für Accessibility brauchen wir Zugriff auf Code-Ebene (um Screenreader-Aufrufe einzubauen). SDKs nur für Assets (Level-Editoren, Texturtausch) reichen nicht.
- Bietet das SDK eine Skriptschnittstelle (Lua, Python, C#), können Accessibility-Mods machbar sein. Von Fall zu Fall bewerten.

---

##### Falls kein Modding-Weg gefunden wird

Sei ehrlich zum Benutzer — manche Spiele lassen sich nicht modden. Faktoren, die Modding schwierig oder unmöglich machen:
- Keine etablierte Modding-Community und keine Werkzeuge für genau dieses Spiel
- Starkes DRM oder Anti-Cheat (blockiert DLL-Injektion und Speicherzugriff)
- Vollständig kompiliertes C++ ohne Skriptschicht oder Modding-API
- Reine Online-Spiele mit serverseitiger Logik
- Sehr obskure oder proprietäre Engines

**Wichtig:** Keine Ansätze vorschlagen, die für Screenreader-Benutzer unzugängliche Werkzeuge erfordern (Cheat Engine, Memory-Scanner, visuelle Debugger), ohne diese Einschränkung klar zu benennen. Unzugängliche Werkzeuge zu empfehlen kostet Zeit und erzeugt Frust.

**Haftungsausschluss:** Die engine-spezifischen Informationen oben basieren auf Recherche und können unvollständig oder veraltet sein. Modding-Ökosysteme entwickeln sich schnell. Prüfe immer die aktuelle Kompatibilität für das jeweilige Spiel.

---

### Manuelle Schritte (nur falls die automatische Prüfung abgelehnt wurde)

#### Schritt 4a: Game-Engine (manuell)

Frage: Weißt du, welche Game-Engine das Spiel verwendet?

- Hinweise zum Erkennen von Unity: `UnityPlayer.dll` im Spielordner oder ein Ordner `[GameName]_Data\Managed`
- Hinweise für Unreal Engine: `UnrealEngine` oder `UE4` in Dateinamen, `.pak`-Dateien
- Hinweise für Godot: `libgodot`-Dateien oder `.pck`-Dateien
- Hinweise für GameMaker: Datei `data.win`
- Falls unklar: Der Benutzer kann im Spielordner nachschauen, oder du hilfst beim Identifizieren

**Falls KEIN Unity-Spiel:** Siehe Schritt 4d oben zum weiteren Vorgehen.

#### Schritt 4b: Architektur (manuell)

Frage: Weißt du, ob das Spiel 32-Bit oder 64-Bit ist?

Hinweise zum Herausfinden:
- Ordner `MonoBleedingEdge` = meist 64-Bit
- Ordner `Mono` = meist 32-Bit
- Dateien mit "x64" im Namen = 64-Bit

**WICHTIG:** Die Architektur bestimmt, welche Tolk-DLLs benötigt werden!

#### Schritt 4c: Mod-Loader (manuell, nur Unity)

Frage: Ist schon ein Mod-Loader (MelonLoader oder BepInEx) installiert?

Hinweise zum Herausfinden:
- Ordner `MelonLoader` im Spielverzeichnis → MelonLoader ist installiert
- Ordner `BepInEx` im Spielverzeichnis → BepInEx ist installiert
- Keiner von beiden → Einer muss installiert werden (siehe Schritt 4e)

Für Anfänger: Ein Mod-Loader ist ein Programm, das unseren Mod-Code ins Spiel lädt. Sowohl MelonLoader als auch BepInEx bringen "Harmony" mit, eine Bibliothek zum Einhaken in Spielfunktionen. Harmony müssen wir deshalb nicht extra herunterladen.

---

### Schritt 4e: Auswahl des Mod-Loaders (nur Unity)

**Ziel:** Bestimmen, welcher Mod-Loader für dieses Spiel verwendet wird. Das ist entscheidend — mit dem falschen Mod-Loader funktioniert der Mod möglicherweise gar nicht.

**Falls bereits ein Mod-Loader erkannt wurde (automatische Prüfung oder manuell):**

Nimm den, der installiert ist. Sind beide installiert, frag, welchen der Benutzer bevorzugt (normalerweise bei dem bleiben, den die Modding-Community des Spiels nutzt).

**Falls noch kein Mod-Loader installiert ist:**

1. **Community-Konsens recherchieren:**
   - Websuche: "[Spielname] mods"
   - Websuche: "[Spielname] modding guide"
   - Nexus Mods, Thunderstore oder spielspezifische Mod-Seiten prüfen
   - Schauen, was andere Mods für dieses Spiel verwenden

2. **Ergebnisse auswerten:**
   - Die Community nutzt **MelonLoader**: MelonLoader verwenden
   - Die Community nutzt **BepInEx**: BepInEx verwenden
   - **Beide** werden genutzt: Beide funktionieren — den Benutzer fragen oder empfehlen, was die Mehrheit nutzt
   - Für das Spiel gibt es **keine Mods**: Siehe Hinweise unten

3. **Allgemeine Heuristiken (wenn es keine Empfehlung aus der Community gibt):**
   - Il2Cpp-Spiele (kein Ordner `[Game]_Data\Managed`, oder das MelonLoader-Log sagt "Il2Cpp"): **MelonLoader** ist im Allgemeinen zuverlässiger
   - Mono-Spiele (klassischer Ordner `[Game]_Data\Managed` mit `Assembly-CSharp.dll`): Beide funktionieren, BepInEx hat mehr Community-Ressourcen
   - Sehr alte Unity-Versionen (5.x): Zuerst **BepInEx 5.x** probieren, MelonLoader unterstützt sie eventuell nicht

**Die wichtigsten Unterschiede für den Benutzer:**

- **MelonLoader:** Wird über eine Installer-EXE installiert. Mods kommen in den Ordner `Mods/`. Hat eine eigene Logdatei (`MelonLoader/Latest.log`).
- **BepInEx:** Wird installiert, indem man eine ZIP in den Spielordner entpackt. Mods (Plugins) kommen in den Ordner `BepInEx/plugins/`. Hat eine eigene Logdatei (`BepInEx/LogOutput.log`).
- **Beide:** Enthalten Harmony fürs Patching. Beide unterstützen Tolk für die Screenreader-Ausgabe. Der Kern des Mod-Codes (AccessibilityMgr, Screens und UIs, Tasten, Lokalisierung) ist identisch; nur Main, DebugLogger, ModConfig und die csproj unterscheiden sich.

Für Anfänger: Stell dir Mod-Loader wie Netzteile verschiedener Marken vor — beide liefern Strom (laden deinen Mod), nur mit leicht unterschiedlichen Steckern (Setup und Struktur). Der wichtige Teil — die eigentlichen Features deines Mods — funktioniert mit beiden gleich.

**Falls es für das Spiel überhaupt keine Mods gibt:**

Das ist nicht unbedingt ein Hindernis, bedeutet aber:
- Niemand hat bestätigt, dass ein Mod-Loader mit diesem Spiel funktioniert
- Es kann Anti-Cheat, DRM oder andere Hürden geben
- Die Installation braucht eventuell Fehlersuche

Schlag vor, den Mod-Loader zu probieren, der zur Runtime des Spiels passt (MelonLoader für Il2Cpp, beide für Mono). Funktioniert er nicht, den anderen versuchen. Die Ergebnisse dokumentieren.

**Installationsanleitungen:**

**MelonLoader:**
- Download: https://github.com/LavaGang/MelonLoader.Installer/releases
- Den Installer starten und auf die EXE des Spiels zeigen lassen
- Nach der Installation sollte es im Spielverzeichnis einen Ordner `MelonLoader` geben
- Das Spiel einmal starten, damit die Ordnerstruktur angelegt und die Logdatei erzeugt wird

**BepInEx:**
- Download: https://github.com/BepInEx/BepInEx/releases
- Für Unity-Mono-Spiele: Den passenden Build herunterladen (x64 oder x86, passend zur Architektur des Spiels)
- Für Unity-Il2Cpp-Spiele: Den Il2Cpp-Build herunterladen (für Il2Cpp ist MelonLoader aber meist besser)
- Den Inhalt der ZIP ins Spielverzeichnis entpacken (dorthin, wo die EXE des Spiels liegt)
- Das Spiel einmal starten, damit die Ordnerstruktur angelegt wird (`BepInEx/plugins/`, `BepInEx/config/` usw.)

**Nach der Installation:** Weiter mit Schritt 5 (Tolk).

**Halte den gewählten Mod-Loader** in `project_status.md` fest — er beeinflusst Projektstruktur, Build-Konfiguration und Code-Templates.

**Auswahl der Templates nach Mod-Loader:**

Die Templates sind auf diese Ordner verteilt:
- `templates/melonloader/` — MelonLoader-spezifische Dateien (Main.cs, DebugLogger.cs, ModConfig.cs, ScreenReader.cs, csproj)
- `templates/bepinex/` — BepInEx-spezifische Dateien (derselbe Satz, angepasst an die BepInEx-APIs)
- `templates/shared/` — Der vom Mod-Loader unabhängige Kern (AccessibilityMgr, AccessibleComponent, AccessibleKey, AccessibleMenu, AccessibleItem, AccessibleListOfItems, Compat, ReflectionHelper, LocalizationKey/Table/Utils, Localization/<language>/Global.txt, AccessibleModSettings, das Screen-Beispiel AccessibleFEATURENAME, project_status.md, game-api.md)
- `templates/tests/` — Projekt für die Offline-Tests (Prüfungen für Lokalisierung, Architektur und Spielkompatibilität)

Wenn du später die Projektdateien anlegst, **nimm immer die Templates, die zum gewählten Mod-Loader passen**, plus alle gemeinsamen Templates. Die wichtigsten Unterschiede:
- **MelonLoader:** Basisklasse `MelonMod`, `MelonLogger`, `MelonPreferences`, Ausgabe nach `Mods/`
- **BepInEx:** Basisklasse `BaseUnityPlugin`, `ManualLogSource`, `ConfigFile`, Ausgabe nach `BepInEx/plugins/`

---

### Schritt 5: Tolk (falls bei der automatischen Prüfung als fehlend gemeldet)

Falls die Tolk-DLLs fehlen, erkläre:
- Download: https://github.com/ndarilek/tolk/releases
- **WICHTIG: Es werden BEIDE DLLs benötigt — nicht nur Tolk.dll!**
- Für 64-Bit: `Tolk.dll` + `nvdaControllerClient64.dll` aus dem x64-Ordner
- Für 32-Bit: `Tolk.dll` + `nvdaControllerClient32.dll` aus dem x86-Ordner
- BEIDE DLLs in den Spielordner kopieren (dorthin, wo die .exe liegt)
- Ohne `nvdaControllerClient*.dll` bekommt NVDA keine Ausgabe! (JAWS funktioniert über COM, braucht keine zusätzliche DLL)

Für Anfänger: Tolk ist eine Bibliothek, die mit verschiedenen Screenreadern (NVDA, JAWS usw.) sprechen kann. Unser Mod nutzt Tolk, um Text an deinen Screenreader zu schicken. Tolk.dll ist die Brücke, und nvdaControllerClient*.dll wird speziell gebraucht, damit NVDA den Text empfangen kann.

### Schritt 6: .NET SDK

Frage: Hast du das .NET SDK bereits installiert?

Prüfen mit: `dotnet --version` in PowerShell.

Falls nein, per WinGet installieren (bevorzugt — Claude Code kann das automatisch ausführen):

```powershell
winget install Microsoft.DotNet.SDK.8
```

Nach der Installation **das Terminal neu starten**, damit der Befehl `dotnet` verfügbar ist.

Ist WinGet nicht verfügbar, manueller Download: https://dotnet.microsoft.com/download (empfohlen: .NET 8 SDK oder neuer).

Für Anfänger: Das .NET SDK ist ein Entwicklungswerkzeug von Microsoft. Wir brauchen es, um unseren C#-Code in eine DLL-Datei zu kompilieren, die der Mod-Loader (MelonLoader oder BepInEx) dann laden kann.

### Schritt 7: Dekompilierung

Frage: Hast du ein Dekompilier-Werkzeug (dnSpy oder ILSpy) installiert?

Falls nein, erkläre die Möglichkeiten:

**ILSpy (empfohlen):**

Das Kommandozeilen-Werkzeug per dotnet installieren (bevorzugt — Claude Code kann das automatisch ausführen):

```powershell
dotnet tool install ilspycmd -g
```

Nach der Installation **das Terminal neu starten**, damit der Befehl `ilspycmd` verfügbar ist.

- **Vorteil:** Komplett über die Kommandozeile steuerbar, Claude Code kann die gesamte Dekompilierung automatisieren
- **Über das Skript benutzen, nicht von Hand:** `.\scripts\Decompile-Game.ps1 -GamePath "C:\Path\to\Game" -Version <game version>`. Das Skript dekompiliert jede Assembly des Spiels (nicht nur Assembly-CSharp: viele Spiele verteilen ihren Code auf mehrere DLLs) nach `decompiled\` und macht diesen Ordner zu einem privaten Git-Repository mit einem Branch pro Spielversion. Dadurch wird ein künftiges Spiel-Update zu einem lesbaren `git diff` (siehe "Werkzeug-Pipeline" unten).
- Falls nötig auch git installieren: `winget install Git.Git`

**IL2CPP-Spiele** haben keine Managed-DLLs zum Dekompilieren: MelonLoader erzeugt beim ersten Start Proxy-Assemblies (`MelonLoader\Il2CppAssemblies`), und Il2CppDumper / Cpp2IL erzeugen Dummy-DLLs mit Namen und Signaturen, aber ohne Methodenrümpfe. Richte `-GamePath` auf den Ordner, der diese enthält (siehe `docs-de/appendix-a-unity-loaders-harmony.md`); rechne damit, dich bei der Recherche stärker auf Beobachtung zur Laufzeit zu stützen.

Optional auch die GUI-Version per WinGet installieren:

```powershell
winget install icsharpcode.ILSpy
```

Ist weder WinGet noch dotnet tool verfügbar, manueller Download: https://github.com/icsharpcode/ILSpy/releases

**dnSpy (Alternative):**
- Download: https://github.com/dnSpy/dnSpy/releases
- Nicht über WinGet verfügbar (eingestelltes Projekt)
- GUI-basiertes Werkzeug mit manuellem Ablauf
- Damit `Assembly-CSharp.dll` aus `[Game]_Data\Managed\` dekompilieren
- Der dekompilierte Code sollte nach `decompiled/` in diesem Projektordner kopiert werden
- Manuelle Exporte verlieren die Historie pro Version. Wenn du dnSpy benutzt, committe trotzdem jeden Export in `decompiled\` als eigenen Git-Branch, benannt nach der Spielversion (`git -C decompiled checkout -b <version>` vor dem Kopieren, danach committen).

**Screenreader-Anleitung für dnSpy:**
1. DnSpy.exe öffnen
2. Mit Strg+O die DLL auswählen (z.B. Assembly-CSharp.dll)
3. Im Menü "Datei" den Punkt "Exportieren in Projekt" wählen
4. Einmal Tab drücken - du landest auf einem unbeschrifteten Schalter für die Auswahl des Zielordners
5. Dort den Zielordner auswählen (am besten vorher einen Unterordner "decompiled" in diesem Projektordner anlegen, damit Claude Code den Quellcode leicht findet)
6. Nach dem Bestätigen der Ordnerauswahl so oft Tab drücken, bis du beim Schalter "Exportieren" bist
7. Der Export dauert etwa eine halbe Minute
8. Danach dnSpy schließen

Für Anfänger: Spiele werden in einer Programmiersprache geschrieben und dann "kompiliert" (in Maschinencode übersetzt). Dekompilieren macht das rückgängig - wir bekommen lesbaren Code. Den brauchen wir, um zu verstehen, wie das Spiel funktioniert und wo wir unsere Accessibility-Features einhängen können.

### Schritt 7b: Tutorial-Texte extrahieren (falls der Benutzer das Spiel nicht kennt)

Falls der Benutzer in Schritt 2b angegeben hat, dass er das Spiel nicht gut kennt ("Etwas" oder "Gar nicht"):

**Anbieten:** "Ich kann den dekompilierten Code und die Spieldateien nach Tutorial-Texten, Hilfetexten und Spielanleitungen durchsuchen. Ich schreibe sie in eine Datei, damit du dich vor oder während des Moddens in die Spielmechaniken einlesen kannst. Soll ich das machen?"

**Falls ja:**

1. **Den dekompilierten Code nach Tutorial-/Hilfetexten durchsuchen:**
   ```
   Grep pattern: Tutorial
   Grep pattern: [Hh]elp[Tt]ext
   Grep pattern: [Ii]nstruction
   Grep pattern: [Hh]ow[Tt]o
   Grep pattern: [Tt]ip[Ss]
   Grep pattern: [Hh]int
   Grep pattern: [Gg]uide
   ```

2. **Nach Lokalisierungs-/Ressourcendateien suchen:**
   - In `[Game]_Data/StreamingAssets/` nach JSON-, XML-, CSV- oder TXT-Dateien schauen
   - In `[Game]_Data/Resources/` nach Text-Assets schauen
   - Nach Dateien suchen, die "tutorial", "help" oder "tips" im Namen haben
   - Lokalisierungsdateien nach Schlüsseln mit diesen Begriffen durchsuchen

3. **Bevorzugte Sprache:**
   - Zuerst versuchen, Texte in der Sprache des Benutzers zu finden
   - Auf Englisch zurückfallen, wenn die Sprache des Benutzers nicht vorhanden ist
   - Gibt es mehrere Sprachen, die Sprache des Benutzers + Englisch extrahieren

4. **Ergebnisse in `docs/tutorial-texts.md` schreiben:**
   - Wo möglich nach Thema/Spielmechanik ordnen
   - Den Kontext angeben (aus welcher Klasse/Datei der Text stammt)
   - Unklare oder bruchstückhafte Texte als solche kennzeichnen
   - Einen Hinweis ergänzen, dass es extrahierte Spieltexte sind, keine Mod-Dokumentation

5. **Für den Benutzer zusammenfassen:**
   - Kurzer Überblick über das Gefundene
   - Welche Spielmechaniken abgedeckt sind
   - Eventuelle Lücken (Mechaniken, die es offenbar gibt, aber ohne Tutorial-Text)

**Falls nein:** Weiter mit Schritt 8. Der Benutzer kann das jederzeit später anfordern.

Für Anfänger: Spiel-Tutorials erklären die Grundmechaniken Schritt für Schritt. Diese Texte zu lesen hilft dir zu verstehen, was das Spiel macht — nützlich, um zu entscheiden, welche Features zuerst Accessibility-Unterstützung brauchen.

### Schritt 8: Sprachen

**WICHTIG: Lokalisierung ist NICHT optional.** Alles, was der Mod in eigenen Worten sagt, MUSS vom allerersten Feature an ein `LocalizationKey` mit einer Zeile in `Localization\<language>\<Feature>.txt` sein, gelesen mit `LocalizationUtils.Get/Format`; Texte, die das Spiel schon hat, werden aus dem Spiel gelesen (`LocalizationUtils.GetGame`). Die Lokalisierungsklassen gehören zum Kern, der in Phase 2 angelegt wird, und ein Offline-Test schlägt fehl, wenn irgendwo ein String-Literal gesprochen wird. Darüber wird nicht verhandelt, weil:
- Lokalisierung später nachzurüsten bedeutet, jeden einzelnen Bildschirm anzufassen - eine riesige Zeitverschwendung
- Auch ein "einsprachiger" Mod davon profitiert, alle Strings an einem Ort zu haben
- Eine neue Sprache später hinzuzufügen trivial ist, wenn das System schon steht

Frage: Welche Sprachen soll der Mod unterstützen? Empfehlung: mit 1-3 anfangen:

1. **Englisch** (immer - dient als Rückfallsprache und erreicht die meisten Benutzer)
2. **Deine Muttersprache** (falls nicht Englisch)
3. **Optional:** Eine weitere Sprache, falls du oder jemand, den du kennst, übersetzen kann

**Rat für den Benutzer:**
- Mit 1-2 Sprachen anfangen. Weitere kannst du jederzeit später ergänzen.
- Eine neue Sprache hinzuzufügen ist einfach: den Ordner `Localization\en\` nach `Localization\<tag>\` kopieren und die Spalte TEXT übersetzen. Die Dateien sind tabulatorgetrennt im Format `KEY<TAB>TEXT<TAB>COMMENT` (das Format, das die Community-Übersetzer von Hearthstone Access benutzen), ein Übersetzer fasst also nie Code an; die Spalte COMMENT sagt ihm, wofür `{0}` steht und wo die Zeile gesprochen wird.
- Konzentriere dich zuerst darauf, dass der Mod funktioniert. Verbring nicht Wochen mit Übersetzen, bevor die Features fertig sind.
- Hat das Spiel ein eigenes Übersetzungssystem, nutze für spielspezifische Begriffe (Gegenstandsnamen, Menübeschriftungen) wo möglich die Übersetzungen des Spiels. Übersetze nur deine eigenen Mod-Strings.
- 5+ Sprachen bedeuten viel Pflegeaufwand. Erst daran denken, wenn der Mod stabil ist und du Übersetzer hast, die helfen wollen.

In jedem Fall (auch bei nur einer Sprache, weil die eigenen Strings des Spiels darüber gelesen werden):
- Das Sprachsystem des Spiels wird bei der Recherche analysiert (`docs-de/02-reconnaissance.md`, "Localization system")
- Suche nach: `Language`, `Localization`, `I18n`, `currentLanguage`, `getAlias()`
- Das vollständige System steht in `docs-de/03-architecture.md`, "Lokalisierung"

Starte mit `templates/shared/LocalizationKey.cs.template`, `LocalizationTable.cs.template`, `LocalizationUtils.cs.template` und `templates/shared/Localization/<language>/Global.txt.template` (immer, unabhängig von der Zahl der Sprachen).

### Schritt 9: Projektordner einrichten

Nach dem Interview:
- **Mod-Namen festlegen:** `[GameName]Access` - bei 3+ Wörtern abkürzen (z.B. "PetIdleAccess", "DsaAccess" für "Das Schwarze Auge")
- `project_status.md` aus `templates/shared/project_status.md.template` erstellen - alle gesammelten Informationen eintragen und die erledigten Setup-Schritte abhaken. **Das ist das zentrale Dokument zur Verfolgung des ganzen Projekts.** Aktualisiere es bei jedem wichtigen Meilenstein: fertige Features, gefundene Bugs, Architekturentscheidungen, Notizen für die nächste Session.
- `docs/game-api.md` aus `templates/shared/game-api.md.template` als Platzhalter für Erkenntnisse über das Spiel erstellen
- Die konkreten Pfade in CLAUDE.md unter "Environment" eintragen

#### CLAUDE.md nach dem Setup kürzen

Sobald `project_status.md` erstellt ist, kürze CLAUDE.md, um für den Rest des Projekts Tokens zu sparen:

1. **Den Abschnitt "Project Start" ersetzen** durch:
   ```
   ## Session Start
   On greeting:
   1. Read `project_status.md` — summarize phase, last work, pending tests, notes
   2. If pending tests exist, ask user for results before continuing
   3. Suggest next steps or ask what to work on
   Update `project_status.md` on significant progress and before session end.
   ```

2. **Aus den Referenzen entfernen:**
   - `docs-de/01-setup-and-tooling.md` — nur die Teile "Werkzeug-Pipeline" und "Phase 2.5" im Hinterkopf behalten; das Interview wird nicht mehr gebraucht
   - `docs-de/appendix-c-legacy-unity.md` — entfernen, wenn dieses Spiel KEINE alte Unity-Version (5.x oder älter) ist
   - `docs-de/appendix-d-other-engines.md` — bei Unity-Spielen entfernen

Das spart bei jeder Nachricht Tokens, über die gesamte Laufzeit des Projekts.

---

## Checkliste für den Benutzer (zum Vorlesen)

Nach dem Interview diese Checkliste vorlesen:

- Architektur des Spiels bekannt (32-Bit oder 64-Bit)
- Mod-Loader installiert und getestet: MelonLoader (Spiel startet mit MelonLoader-Konsole) oder BepInEx (BepInEx-Logdatei wurde erstellt)
- Tolk-DLLs im Spielordner (passend zur Architektur!)
- Dekompilier-Werkzeug bereit (ilspycmd) und git installiert
- Spiel mit `scripts\Decompile-Game.ps1` in das private Repository `decompiled\` dekompiliert (Branch = Spielversion)
- Recon-Werkzeuge installiert (`cd recon`, `uv sync --dev`, `uv run pytest -q` läuft durch)

**Tipp:** Das Validierungsskript prüft alle Punkte automatisch:
```powershell
.\scripts\Test-ModSetup.ps1 -GamePath "C:\Path\to\Game" -Architecture x64
```

---

## Token-Verbrauch und Unterhaltungen

**Erkläre das dem Benutzer früh (während oder nach dem Setup):**

Claude Code liest bei jeder Nachricht, die du schickst, die gesamte Unterhaltung neu. Lange Unterhaltungen kosten also immer mehr Tokens. Um effizient zu bleiben:

- **Starte eine neue Unterhaltung**, wann immer du ein Feature oder eine abgeschlossene Aufgabe fertig hast. Mach nicht stundenlang in derselben Unterhaltung weiter.
- **Ungefähr 30-40 Nachrichten** sind ein guter Punkt, um über einen Neustart nachzudenken.
- **Bevor eine neue Unterhaltung beginnt:** Claude sollte immer `project_status.md` aktualisieren, damit die nächste Unterhaltung genau weiß, wo die Dinge stehen.
- **Wenn du zurückkommst:** Sag einfach "Hallo" oder "Lass uns weitermachen" - Claude liest `project_status.md` und macht dort weiter, wo du aufgehört hast.

Das ist keine Einschränkung, sondern ein Vorteil im Ablauf: Frische Unterhaltungen haben einen klaren Kontext und machen weniger Fehler.

---

## Ablauf ab der zweiten Session

**Erkläre das dem Benutzer am Ende der ersten Session (oder wenn er nach dem Ablauf fragt):**

### Was du tun musst

- **Eine Session beginnen:** Sag einfach "Hallo", "Lass uns weitermachen" oder steig direkt ein mit "Ich habe das Menü getestet, Folgendes ist passiert: ..."
- **Du musst nicht wiederholen**, wie das Spiel heißt, wie das Projekt eingerichtet ist, was vorher gemacht wurde oder technische Details. Claude liest `project_status.md` und weiß das alles.
- **Testergebnisse melden:** Beschreib einfach ganz normal, was passiert ist. "Das Menü funktioniert, aber Punkt 3 wird übersprungen" oder "Wenn ich F2 drücke, passiert nichts" reicht. Claude fragt nach, wenn nötig.
- **Features anfordern:** "Machen wir als Nächstes das Inventar" oder "Können wir Ansagen für die Lebenspunkte einbauen?" — Claude schaut in den Feature-Plan und legt los.
- **Wenn sich etwas falsch anfühlt:** "Ich glaube, X ist seit dem letzten Mal kaputt" — Claude untersucht das.

### Was Claude automatisch macht

1. Liest `project_status.md` — kennt die aktuelle Phase, alle Features, Probleme und Notizen aus der letzten Session
2. Fragt dich nach den Ergebnissen, falls Tests ausstehen
3. Schlägt vor, woran als Nächstes gearbeitet wird (oder fragt)
4. Aktualisiert vor dem Ende der Session `project_status.md` mit allem, was passiert ist

### Der Kreislauf

```
Session start → Claude reads project_status.md → summarizes → asks what to do
  → You say what to work on (or Claude suggests)
  → Claude codes → builds → you test in game → report results
  → Repeat until feature is done
  → Claude updates project_status.md → suggests new session
```

### Wenn zwischen den Sessions etwas schiefgeht

- **Spiel wurde aktualisiert und der Mod ist kaputt:** Sag es Claude, es prüft, was sich geändert hat
- **Du hast vergessen, was geplant war:** Sag einfach "Hallo" — Claude sagt es dir
- **Du willst die Richtung ändern:** Sag es einfach, Claude passt den Plan an
- **Deine Testnotizen sind weg:** Claude kann den Kontext aus `project_status.md` und dem Code wiederherstellen

---

## Nächste Schritte

Nach Abschluss des Setups in dieser Reihenfolge vorgehen:

0. **`docs-de/00-overview-and-principles.md` und `docs-de/03-architecture.md` vollständig lesen.** Sie legen die Grundsätze und die eine Architektur fest, die im ganzen Projekt verwendet wird (das Hearthstone-Access-Modell).

0b. **Bei älteren Unity-Versionen (5.x oder älter):** `docs-de/appendix-c-legacy-unity.md` lesen; dort stehen wichtige Informationen zu Kompatibilitätsproblemen, alternativen Mod-Loadern und Assembly-Patching als Ausweg. Behalte das bei der Analyse im Hinterkopf - manche Muster müssen eventuell angepasst werden.

1. **Die Werkzeug-Pipeline einrichten** ("Werkzeug-Pipeline" unten): Spiel-Link, Repository mit dem dekompilierten Code, Recon-Werkzeuge
2. **Recherche der Projekt-Grundlage** (`docs-de/02-reconnaissance.md`) - Tier 1 ist Pflicht vor jedem Coden
3. **Tutorial suchen/analysieren** (`docs-de/02-reconnaissance.md`, "Tutorial") - Mechaniken verstehen, oft hohe Priorität
4. **Den Feature-Plan als geordnete Slices erstellen** (`docs-de/02-reconnaissance.md`, "Feature plan")
5. **game-api.md befüllen** - Erkenntnisse aus der Analyse dokumentieren (fortlaufend, aber die Ergebnisse von Tier 1 MÜSSEN vor Phase 2 drinstehen)
6. **Phase 2** (unten): den Kern und die Offline-Tests anlegen, erster Build

---

## KRITISCH: Vor dem ersten Build - Log prüfen!

**Diese Werte MÜSSEN aus dem Log des Mod-Loaders gelesen werden, NIEMALS raten!**

### Für MelonLoader

#### Automatisch mit Skript (empfohlen)

```powershell
.\scripts\Get-MelonLoaderInfo.ps1 -GamePath "C:\Path\to\Game"
```

Das Skript extrahiert alle Werte und zeigt das fertige MelonGame-Attribut an.

#### Manuell (falls das Skript nicht verfügbar ist)

**Schritt 1:** Das Spiel einmal mit MelonLoader starten (erstellt das Log).

**Schritt 2:** Pfad des Logs: `[Spielordner]\MelonLoader\Latest.log`

Suche nach diesen Zeilen und notiere die EXAKTEN Werte:

```
Game Name: [COPY EXACTLY]
Game Developer: [COPY EXACTLY]
Runtime Type: [net35 or net6]
```

#### Werte in Code/Projekt eintragen (MelonLoader)

**MelonGame-Attribut (Main.cs):**
```csharp
[assembly: MelonGame("DEVELOPER_FROM_LOG", "GAME_NAME_FROM_LOG")]
```
- Groß-/Kleinschreibung MUSS exakt stimmen
- Leerzeichen MÜSSEN exakt stimmen
- Mit falschem Namen wird der Mod geladen, aber NICHT initialisiert!

**TargetFramework (csproj):**
- Steht im Log `Runtime Type: net35` → `<TargetFramework>net472</TargetFramework>` verwenden
- Steht im Log `Runtime Type: net6` → `<TargetFramework>net6.0</TargetFramework>` verwenden
- Die MelonLoader-DLLs aus dem passenden Unterordner referenzieren (net35/ oder net6/)

**ACHTUNG:** Für net35-Spiele NICHT `netstandard2.0` verwenden!
netstandard2.0 ist nur eine API-Spezifikation, keine Runtime. Mono hat damit Kompatibilitätsprobleme - der Mod wird geladen, aber nicht initialisiert (keine Fehlermeldung, einfach Stille).

**Warum ist das so wichtig?**
1. **Entwicklername falsch** = Der Mod wird geladen, aber OnInitializeMelon() wird nie aufgerufen. Kein Fehler im Log, einfach Stille.
2. **Framework falsch** = Der Mod wird geladen, kann aber nicht ausgeführt werden. Kein Fehler im Log, einfach Stille.

**Bei Abstürzen oder stillem Versagen:** `docs-de/appendix-a-unity-loaders-harmony.md` lesen, Abschnitt "KRITISCH: Zugriff auf Spielcode".

### Für BepInEx

#### Log und Konfiguration

**Schritt 1:** Das Spiel einmal mit BepInEx starten (erstellt Config- und Logdateien).

**Schritt 2:** Pfad des Logs: `[Spielordner]\BepInEx\LogOutput.log`

Prüfe das Log auf:
- Erfolgreiche Initialisierung von BepInEx
- Unity-Version
- Fehler oder Warnungen

#### Werte in Code/Projekt eintragen (BepInEx)

**BepInPlugin-Attribut (Main.cs):**
```csharp
[BepInPlugin("com.author.modname", "ModName", "1.0.0")]
```
- Der erste Parameter (GUID) ist eine eindeutige Kennung — verwende die umgekehrte Domain-Schreibweise
- Dafür braucht es KEINE Werte aus dem Log — die wählst du selbst
- Die GUID muss aber unter allen Mods für dieses Spiel eindeutig sein

**TargetFramework (csproj):**
- Die meisten BepInEx-Mono-Spiele: `<TargetFramework>net472</TargetFramework>` oder `<TargetFramework>net35</TargetFramework>`
- Prüfen, was andere BepInEx-Mods für dieses Spiel verwenden, oder die DLLs in `BepInEx/core/` ansehen
- BepInEx-DLLs referenzieren: `BepInEx/core/BepInEx.dll` und die relevanten Unity-DLLs aus `[Game]_Data/Managed/`

**Projekt-Referenzen (csproj) für BepInEx:**
```xml
<Reference Include="BepInEx">
    <HintPath>[GameDirectory]\BepInEx\core\BepInEx.dll</HintPath>
</Reference>
<Reference Include="0Harmony">
    <HintPath>[GameDirectory]\BepInEx\core\0Harmony.dll</HintPath>
</Reference>
<Reference Include="UnityEngine">
    <HintPath>[GameDirectory]\[Game]_Data\Managed\UnityEngine.dll</HintPath>
</Reference>
<Reference Include="UnityEngine.CoreModule">
    <HintPath>[GameDirectory]\[Game]_Data\Managed\UnityEngine.CoreModule.dll</HintPath>
</Reference>
<Reference Include="Assembly-CSharp">
    <HintPath>[GameDirectory]\[Game]_Data\Managed\Assembly-CSharp.dll</HintPath>
</Reference>
```

**Ausgabeordner:** Die gebaute DLL kommt nach `BepInEx/plugins/` (nicht nach `Mods/`).

### Gemeinsam für beide Mod-Loader

**Ordner decompiled ausschließen (csproj):**
Die csproj MUSS diese Zeilen enthalten, sonst werden die dekompilierten Dateien mitkompiliert (hunderte Fehler!):
```xml
<ItemGroup>
  <Compile Remove="decompiled\**" />
  <Compile Remove="templates\**" />
</ItemGroup>
```

**Build-Befehl - IMMER mit Projektdatei!**
```
dotnet build [ModName].csproj
```
NICHT einfach `dotnet build` verwenden! Der Ordner `decompiled/` enthält oft eine eigene `.csproj`-Datei aus dem dekompilierten Spiel. Findet MSBuild mehrere Projektdateien, bricht es ab.

---

## Werkzeug-Pipeline (im Stil der Hearthstone Access DevTools)

Hearthstone Access wird mit ein paar kleinen Werkzeugen gepflegt, die jedes Spiel-Update zu einem prüfbaren Diff machen statt zu einem Ratespiel. Dieses Template bildet diese Pipeline mit Skripten nach. Richte sie einmal ein, während des Setups; spätestens beim ersten Spiel-Update zahlt sie sich aus.

### 1. Die Spielinstallation verlinken (optional, empfohlen)

Leg im Hauptordner des Projekts eine Junction namens `game` an, die auf die Installation zeigt. Skripte, die csproj und die Offline-Tests können dann `game\...` statt eines langen Pfads benutzen, und wenn die Installation umzieht, muss nur neu verlinkt werden:

```powershell
New-Item -ItemType Junction -Path game -Target "C:\Path\to\Game"
```

Eine Junction braucht keine Administratorrechte. `game/` steht in `.gitignore`. MelonLoader kann nicht aus einem Pfad mit Nicht-ASCII-Zeichen laden: Enthält der echte Pfad welche, leg die Junction auf einem ASCII-Pfad an und installiere den Loader über diesen.

### 2. In ein privates Git-Repository dekompilieren, ein Branch pro Spielversion

```powershell
.\scripts\Decompile-Game.ps1 -GamePath game -Version 1.0.3
```

- `decompiled\` wird ein eigenes lokales Git-Repository (vom Mod-Repository ignoriert).
- Jeder Lauf legt einen Branch mit dem Namen der Spielversion an, abgezweigt von dem Branch, auf dem du gerade bist (der vorherigen Version), dekompiliert jede Assembly des Spiels hinein (Engine- und Fremd-Assemblies werden übersprungen) und committet.
- Nach einem Spiel-Update erneut mit der neuen Version ausführen. Dann listet `git -C decompiled diff 1.0.3 1.0.4 --stat` jede Datei auf, die das Update geändert hat, und `git -C decompiled diff 1.0.3 1.0.4 -- <file of a class we hook>` zeigt genau, was sich darin geändert hat. Siehe `docs-de/05-quality-and-updates.md`, "Ablauf bei einem Spiel-Update".
- **`decompiled\` niemals pushen, veröffentlichen oder weitergeben.** Es enthält den proprietären Code des Spiels. Die Entwickler von Hearthstone Access arbeiten nach derselben Regel.

Der Versionsname muss die echte Spielversion sein (Titelbildschirm, Launcher, Steam-Build-ID, Loader-Log). Nie eine erfinden: Belege aus zwei Builds dürfen nie vermischt werden (das ist auch Gate G1 des Recherche-Ablaufs).

### 3. Recon-Werkzeuge (recon/)

`recon/` enthält den Slice-basierten Recherche-Ablauf und seinen Validator `uar` (Python). Einmal installieren:

```powershell
winget install astral-sh.uv
cd recon
uv sync --dev
uv run pytest -q
```

Wie man ihn benutzt, steht in `docs-de/02-reconnaissance.md`. Die Aufzeichnungen für dieses Spiel (Build-Fingerabdruck, Ledger, Readiness) kommen in `recon-records\` im Hauptordner des Projekts, der von git ignoriert wird, wenn sie sich auf proprietäre Daten beziehen.

### 4. Offline-Tests (werden in Phase 2 mit dem Kern angelegt)

Aus `templates/tests/` wird `Tests\` im Hauptordner des Projekts. `dotnet test Tests` führt aus, ohne das Spiel zu starten:

- Prüfungen der Lokalisierung (jeder Schlüssel hat einen englischen Text, Übersetzungen behalten ihre `{0}`-Platzhalter, nichts spricht ein String-Literal),
- Prüfungen der Architektur (nur AccessibilityMgr spricht, nur AccessibleKey liest rohe Tasten),
- die Prüfung der Spielkompatibilität: Jeder Spiel-Member, den der Mod in einem String nennt (Harmony-Ziele, private Felder), wird mit Roslyn gegen den INSTALLIERTEN Build des Spiels aufgelöst.

Führe sie nach jeder Änderung aus und immer, bevor du eine neue Spielversion startest. Details: `docs-de/05-quality-and-updates.md`.

---

## Phase 2: Grundgerüst

**VORAUSSETZUNG: Der erste Recherche-Slice hat sein Gate bestanden** (`docs-de/02-reconnaissance.md`, "Project baseline" und "Tier-1-Abschluss-Gate").

1. Das C#-Projekt aus der **csproj-Vorlage des jeweiligen Mod-Loaders** erstellen (`templates/melonloader/csproj.template` oder `templates/bepinex/csproj.template`)
2. Main.cs, ScreenReader.cs, DebugLogger.cs, ModConfig.cs aus den passenden Mod-Loader-Templates erstellen
3. Den Kern aus `templates/shared/` genau so anlegen, wie in `docs-de/03-architecture.md`, "Den Kern erstellen", beschrieben: AccessibilityMgr, AccessibleComponent, AccessibleKey, AccessibleMenu, AccessibleItem, AccessibleListOfItems, Compat, ReflectionHelper, LocalizationKey, LocalizationTable, LocalizationUtils, AccessibleModSettings und `Localization\en\Global.txt` (+ ein Ordner pro in Schritt 8 gewählter Sprache). Lokalisierung gehört zum Kern, sie ist KEINE spätere Ergänzung.
4. `LocalizationUtils.GetGameLanguageTag()` und `GetGame()` mit dem Sprachsystem des Spiels füllen, das bei der Recherche gefunden wurde.
5. `Tests\` aus `templates/tests/` anlegen und `dotnet test Tests` ausführen.
6. Bauen und das Spiel starten: Der Mod muss "MODNAME loaded" sagen, F1 muss antworten, F8 muss den Mod ein- und ausschalten.
7. Dann der erste Feature-Slice: ein AccessibleScreen aus `templates/shared/AccessibleFEATURENAME.cs.template` (`docs-de/04-building-screens.md`).

#### Build-Test-Ablauf

**WICHTIG: Erkläre dem Benutzer diesen Ablauf beim ersten Build-Test-Durchlauf (typischerweise in Phase 2, wenn die Grundansage "Mod loaded" getestet wird). Das ist der grundlegende Kreislauf, der sich im Laufe des Projekts hunderte Male wiederholt.**

Der Entwicklungsablauf zum Testen von Mod-Änderungen:

1. **Code schreiben/ändern** - Claude schreibt oder ändert den Quellcode des Mods
2. **Build** - `dotnet build [ModName].csproj` ausführen, um den Mod zu einer DLL zu kompilieren
3. **Automatisches Kopieren** - Die DLL wird automatisch in den Mod-Ordner des Spiels kopiert: `Mods/` bei MelonLoader oder `BepInEx/plugins/` bei BepInEx (falls das Target CopyToMods in der csproj eingerichtet ist)
4. **Spiel starten** - Das Spiel normal starten (der Mod-Loader lädt den Mod automatisch)
5. **Testen** - Prüfen, ob das neue Feature wie erwartet funktioniert
6. **Spiel schließen** - **Das Spiel vor dem nächsten Build immer vollständig schließen!** Die DLL-Datei ist gesperrt, solange das Spiel läuft.
7. **Rückmeldung geben** - Sag Claude, was funktioniert hat und was nicht. Sei konkret: "Es sagt X, sollte aber Y sagen" oder "Wenn ich F2 drücke, passiert nichts"
8. **Wiederholen** - Claude behebt die Probleme anhand deiner Rückmeldung, dann wieder bauen und testen

**Wichtige Hinweise für den Benutzer:**
- Bei jeder Code-Änderung musst du das Spiel schließen und neu starten - es gibt kein "Hot Reload"
- Scheint der Mod gar nicht zu laden, im Log nach Fehlern schauen: `MelonLoader/Latest.log` (MelonLoader) oder `BepInEx/LogOutput.log` (BepInEx)
- Hörst du nichts vom Screenreader, obwohl das Log zeigt, dass der Mod geladen wurde: Prüfen, ob die Tolk-DLLs am richtigen Ort liegen und zur Architektur passen
- Build-Fehler (Kompilierfehler) werden im Terminal angezeigt - Claude kann sie direkt lesen und beheben
- Laufzeitfehler (Abstürze während des Spielens) erscheinen im MelonLoader-Log

Für Anfänger: Stell es dir vor wie ein Dokument bearbeiten und ausdrucken. Du machst Änderungen, "druckst" (Build) und prüfst dann den Ausdruck (Test im Spiel). Stimmt etwas nicht, gehst du zurück und bearbeitest weiter.

**Hinweis:** Der erste Build nutzt `dotnet build` direkt. Nach Phase 2.5 gibt es Build-/Deploy-Skripte — ab dann immer die Skripte benutzen.

### Phase 2.5: Build-/Deploy-Skripte und CLAUDE.md aktualisieren (nach dem ersten erfolgreichen Build)

Erstelle nach dem ersten erfolgreichen manuellen Build PowerShell-Skripte, damit Build und Deploy immer nur einen Befehl entfernt sind. Aktualisiere dann CLAUDE.md, damit es auf diese Skripte verweist.

#### Schritt 1: Build-/Deploy-Skripte erstellen

Erstelle diese Skripte im Ordner `scripts/`:

**`scripts/Build-Mod.ps1`** — Baut den Mod:
- Führt `dotnet build [ModName].csproj` aus
- Meldet Erfolg/Fehlschlag klar
- Zeigt den Pfad der erzeugten DLL

**`scripts/Deploy-Mod.ps1`** — Baut und kopiert ins Spielverzeichnis:
- Ruft `Build-Mod.ps1` auf
- Kopiert die erzeugte DLL in den Mod-Ordner des Spiels (`Mods/` bei MelonLoader, `BepInEx/plugins/` bei BepInEx)
- Kopiert optional weitere Dateien (z.B. Lokalisierungsdateien, Konfigurationsdateien)
- Meldet, was wohin kopiert wurde

**Anforderungen an die Skripte:**
- Parameter für Pfade verwenden, damit die Skripte ohne fest eingetragene Werte funktionieren (z.B. `-GamePath`, `-Configuration Debug/Release`)
- Die Standardwerte sollten zum Projekt-Setup passen, damit der Benutzer einfach `.\scripts\Deploy-Mod.ps1` ohne Argumente ausführen kann
- Fehlerbehandlung einbauen: Schlägt der Build fehl, nicht kopieren. Existiert das Spielverzeichnis nicht, deutlich warnen.
- Die Skripte einfach halten — kein Over-Engineering. Das sind bequeme Hüllen.

**Beispielaufbau für Deploy-Mod.ps1:**
```powershell
param(
    [string]$Configuration = "Debug",
    [string]$GamePath = "C:\Path\to\Game"  # Fill in during setup
)

# Build
& "$PSScriptRoot\Build-Mod.ps1" -Configuration $Configuration
if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed."
    exit 1
}

# Copy DLL to game
$dllPath = "bin\$Configuration\net472\ModName.dll"
$targetDir = "$GamePath\Mods"  # Adjust for BepInEx: BepInEx\plugins

Copy-Item $dllPath $targetDir -Force
Write-Host "Deployed to $targetDir"
```

#### Schritt 2: CLAUDE.md aktualisieren

Den Abschnitt "Environment" ergänzen um:
- Pfad des Spielverzeichnisses
- Architektur (32-Bit/64-Bit)
- Mod-Loader (MelonLoader oder BepInEx)

**Den Platzhalter `Build` im Abschnitt Coding Rules** durch einen Verweis auf die Skripte ersetzen:

```markdown
## Build & Deploy

- Build: `.\scripts\Build-Mod.ps1`
- Build + copy to game: `.\scripts\Deploy-Mod.ps1`
- Offline checks (before every launch): `dotnet test Tests`
- After a game update: `.\scripts\Decompile-Game.ps1 -Version <new>`, then `git -C decompiled diff <old> <new> --stat`, then `dotnet test Tests`
```

**KEINE rohen `dotnet build`-Befehle in CLAUDE.md schreiben.** Immer die Skripte benutzen — sie sind die einzige verbindliche Quelle dafür, wie gebaut und deployt wird.

Projektspezifische Hinweise ergänzen:
- Engine-Version (z.B. Unity 2021.3)
- Besonderheiten dieses Spiels
- Abweichungen von den Mustern des Templates
- Bekannte Eigenheiten oder Workarounds

**CLAUDE.md kurz und knapp halten** - sie ist nur für Claude Code da, keine Dokumentation.

Beispiel für eine Ergänzung:
```markdown
## Build & Deploy

- Build: `.\scripts\Build-Mod.ps1`
- Build + copy to game: `.\scripts\Deploy-Mod.ps1`

## Notes

- Unity 2021.3.5f1
- Uses legacy Input system
- MainMenu has no base class, access via MainMenuManager.instance
```

## Hilfsskripte

### Decompile-Game.ps1

Dekompiliert jede Assembly des Spiels in das private Git-Repository `decompiled\`, auf einen neuen Branch mit dem Namen der Spielversion (abgezweigt von der vorherigen Version), und committet. Siehe "Werkzeug-Pipeline" oben und `docs-de/05-quality-and-updates.md`.

**Verwendung:**
```powershell
.\scripts\Decompile-Game.ps1 -GamePath "C:\Path\to\Game" -Version 1.0.3
.\scripts\Decompile-Game.ps1 -GamePath "C:\Path\to\Game" -Version 1.0.3 -Only Assembly-CSharp.dll
```

Benötigt `ilspycmd` und `git`. `decompiled\` niemals pushen oder weitergeben.

### Get-MelonLoaderInfo.ps1

Liest `MelonLoader\Latest.log` und extrahiert die Werte, die das Projekt braucht:
- Game Name und Game Developer (für das MelonGame-Attribut)
- Runtime Type (net35 oder net6: TargetFramework und der MelonLoader-DLL-Ordner `RUNTIME_ORDNER` in der csproj)
- Game Type (Mono oder Il2Cpp), Game Arch, Unity-Version und MelonLoader-Version, sofern das Log sie enthält

Außerdem warnt es vor sehr alten Unity-Versionen (siehe `docs-de/appendix-c-legacy-unity.md`) und vor einem Spielpfad mit Nicht-ASCII-Zeichen.

**Verwendung:**
```powershell
.\scripts\Get-MelonLoaderInfo.ps1 -GamePath "C:\Path\to\Game"
```

Ohne `-GamePath` liest es das Log über die Junction `game`, falls es eine gibt.

**Ausgabe:** Das fertige MelonGame-Attribut und die csproj-Werte zum Kopieren.

### Test-ModSetup.ps1

Prüft das ganze Projekt gegen dieses Template, in acht Gruppen:
1. Spielordner: existiert, EXE des Spiels, Architektur (aus dem Header der EXE gelesen), Unity Mono oder Il2Cpp, die optionale Junction `game`.
2. Mod-Loader: erkennt MelonLoader oder BepInEx, prüft dessen DLL, Log und Mod-Ordner; bei MelonLoader außerdem, dass der Spielpfad reines ASCII ist.
3. Sprach-DLL: Prism oder Tolk (mit `nvdaControllerClient64.dll` oder `nvdaControllerClient32.dll`) neben der EXE, jeweils mit der Architektur des Spiels, plus jede DLL, die `ScreenReader.cs` importiert.
4. Projektdateien: csproj (Platzhalter ersetzt, TargetFramework nicht netstandard2.0, `decompiled`, `templates`, `Tests` und `recon` ausgeschlossen, Lokalisierung eingebettet, Loader-Referenz, Kopier-Target), Main.cs mit MelonGame oder BepInPlugin, ScreenReader.cs, DebugLogger.cs, ModConfig.cs.
5. Accessibility-Kern: AccessibilityMgr, Komponenten, AccessibleKey, Menüs, Compat, ReflectionHelper und die Lokalisierungsklassen; warnt vor Resten der alten Handler-Architektur.
6. Lokalisierung: `Localization\en\*.txt` existiert, und jeder in `LocalizationKey*.cs` deklarierte Schlüssel hat eine englische Zeile (eine schnelle Prüfung; die vollständige ist `dotnet test Tests`).
7. Das Projekt `Tests`.
8. `decompiled\`: ein eigenes Git-Repository mit einem Branch pro Spielversion und ohne Remote; `decompiled/` und `recon-records/` stehen in .gitignore.

**Verwendung:**
```powershell
.\scripts\Test-ModSetup.ps1 -GamePath "C:\Path\to\Game"
```

`-ProjectPath` ist standardmäßig der aktuelle Ordner, `-GamePath` die Junction `game`, `-Architecture` (`x64` oder `x86`) das, was die EXE des Spiels angibt.

**Ausgabe:** Eine Zeile pro Prüfung, beginnend mit OK, WARNING oder ERROR, zu jedem Problem eine Zeile "Fix:". Exit-Code 1, wenn es Fehler gibt.

---

## Wichtige Links

- MelonLoader GitHub: https://github.com/LavaGang/MelonLoader
- MelonLoader Installer: https://github.com/LavaGang/MelonLoader.Installer/releases
- BepInEx GitHub: https://github.com/BepInEx/BepInEx
- BepInEx Releases: https://github.com/BepInEx/BepInEx/releases
- Tolk (Screenreader): https://github.com/ndarilek/tolk/releases
- dnSpy (Dekompiler): https://github.com/dnSpy/dnSpy/releases
- .NET SDK: https://dotnet.microsoft.com/download
