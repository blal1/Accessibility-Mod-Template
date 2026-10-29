# Anhang E: Bekannte Probleme und Kompatibilitätswarnungen

Deutsche Fassung von `docs/appendix-e-known-issues.md`.

Diese Datei wird beim Projekt-Setup (Schritt 4) automatisch geprüft. Sobald die Engine des Spiels, die Unity-Version oder der Mod-Loader feststeht, geht Claude diese Liste durch und warnt den Benutzer vor passenden Problemen.

**Wie man Einträge hinzufügt:** Füge unter der passenden Kategorie einen neuen Punkt hinzu. Gib die betroffene Version/Komponente an, eine kurze Beschreibung und einen Workaround, falls es einen gibt.

---

## Unity + MelonLoader

- **Unity 6000.2.2f1**: MelonLoader startet nicht. Wirft während der Loader-Initialisierung Null-Reference-Fehler. Kein Workaround bekannt — verwende stattdessen BepInEx oder warte auf ein MelonLoader-Update.
- **Unity 2022.3.62f2**: Crash beim Start während der IL2CPP-Initialisierung. BepInEx 6 Bleeding Edge crasht ebenfalls. Kein Fix bekannt. ([GitHub Issue #1063](https://github.com/LavaGang/MelonLoader/issues/1063))
- **Unity 2022.3.58**: Der Download der UnityDependencies schlägt fehl. **Fix:** MelonLoader auf die neueste Version aktualisieren — die fehlende Version wurde im Dependency-Repo nachgetragen. ([GitHub Issue #936](https://github.com/LavaGang/MelonLoader/issues/936))
- **Unity 5.x**: MelonLoader unterstützt Unity 5 im Allgemeinen nicht. Verwende stattdessen BepInEx 5.x. Siehe `docs-de/appendix-c-legacy-unity.md`.
- **Unity 4.x und älter**: Weder MelonLoader noch BepInEx funktionieren. Nur Assembly-Patching ist möglich. Siehe `docs-de/appendix-c-legacy-unity.md`.

## Unity + BepInEx

- **Unity 6000+**: BepInEx 5.x unterstützt Unity 6 nicht. BepInEx 6 (Bleeding Edge) kann funktionieren, ist aber nicht stabil. Prüfe vor dem Weitermachen den aktuellen Stand auf dem GitHub von BepInEx.

## Engine-spezifische Probleme

_(Füge hier Einträge hinzu, sobald Engine-spezifische Kompatibilitätsprobleme bestätigt sind.)_

## Spielspezifische Probleme

_(Füge hier Einträge hinzu, wenn ein bestimmtes Spiel bekannte Modding-Hürden hat, die von den Kategorien oben nicht abgedeckt werden.)_

---

## Wie Claude diese Datei verwendet

Beim Setup (Schritt 4), nachdem Engine und Version erkannt wurden:

1. Diese Datei lesen
2. Prüfen, ob ein Eintrag zur erkannten Konfiguration passt
3. Bei einem Treffer: den Benutzer sofort warnen, das Problem erklären und den dokumentierten Workaround vorschlagen
4. Die Warnung in `project_status.md` festhalten, damit sie nicht vergessen wird
