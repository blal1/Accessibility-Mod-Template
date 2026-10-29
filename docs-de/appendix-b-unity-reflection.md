# Anhang B: Unity-Reflection

Deutsche Fassung von `docs/appendix-b-unity-reflection.md`.

Diese Anleitung beschreibt Muster und bewährte Vorgehensweisen, um in Unity-Spielen per Reflection auf private Felder zuzugreifen - ein zentrales Thema bei der Entwicklung von Barrierefreiheits-Mods.

## Das Problem

Unity-Entwickler verwenden häufig dieses Muster:

```csharp
[SerializeField]
private TextMeshProUGUI title;
```

**Warum machen Entwickler das?**
- Das Feld ist im Unity Editor sichtbar und bearbeitbar
- Das Feld bleibt im Code privat (gute Kapselung)
- Es verhindert versehentlichen Zugriff aus anderen Klassen

**Warum ist das für Mods problematisch?**
- Es gibt keinen öffentlichen Getter
- Die Daten lassen sich nur per Reflection lesen
- UI-Pfade (transform.Find) funktionieren oft NICHT, weil das Feld direkt an der Komponente hängt

## Häufig betroffene Bereiche

### UI-Komponenten (am häufigsten)

Fast alle UI-Klassen haben wichtige Daten in privaten Feldern:
- Textfelder für Titel/Beschreibung
- Button-Referenzen
- Icon-/Sprite-Referenzen
- Aktiv-/Ausgewählt-Zustand

Achte auf Muster wie:
- `private TextMeshProUGUI title`
- `private Text m_Label`
- `private Button m_Button`
- `private Image icon`

### Manager-Klassen

Singleton-Manager haben oft privaten Zustand:
- `m_CurrentlyOpen` - aktuell geöffnetes Overlay/Menü
- `m_IsGamepadInUse` - Eingabemodus
- `m_CurrentDialogue` - aktiver Dialog

### Spiellogik

Spielobjekte verbergen oft ihren Zustand:
- Enums für aktuelle Phase/Zustand
- Interne Sammlungen (Listen von Gegenständen, Einheiten usw.)
- Gecachte Referenzen

## Namenskonventionen

Die meisten Unity-Projekte folgen einem von zwei Mustern:

1. **m_PascalCase** (häufiger in älteren Projekten):
   - m_ActiveTab
   - m_CurrentlyOpen
   - m_IsGamepadInUse

2. **camelCase** (häufiger in neueren Projekten):
   - title
   - description
   - button

**Tipp:** Prüfe beim Dekompilieren immer beide Varianten!

## Die Lösung: ReflectionHelper

Der Kern enthält einen zentralen Helfer (`templates/shared/ReflectionHelper.cs.template`, wird in Phase 2 zusammen mit dem Kern angelegt). Er cacht jeden Lookup, findet private Felder, die in Basisklassen deklariert sind, und meldet einen Namen, der in diesem Spiel-Build nicht existiert, einmal an Compat (Log, Warnung beim Start, F1), statt stillschweigend zu scheitern. Übergib Feldnamen als String-Literale, damit die Offline-GameCompatTests sie gegen das installierte Spiel prüfen können:

```csharp
// Read a class field (e.g., TextMeshProUGUI)
var tmp = ReflectionHelper.GetPrivateField<TextMeshProUGUI>(component, "title");
string text = tmp?.text;

// Read a value type (e.g., int, bool, enum)
int tabIndex = ReflectionHelper.GetPrivateFieldValue<int>(controller, "m_ActiveTab", 0);

// Shortcut for text fields
string title = ReflectionHelper.GetTextFromPrivateField(uiCard, "title");

// Set a field
ReflectionHelper.SetPrivateField(manager, "m_IsGamepadInUse", true);
```

## Bewährte Vorgehensweisen

### 1. Immer zuerst den dekompilierten Code prüfen

**Falsch:** Annehmen, dass die Daten über UI-Pfade erreichbar sind
```csharp
// Often DOESN'T work!
var title = transform.Find("Card/Title")?.GetComponent<TextMeshProUGUI>();
```

**Richtig:** Zuerst die Klasse im dekompilierten Code ansehen
```csharp
// From decompiled/SomeUIClass.cs:
// [SerializeField] private TextMeshProUGUI title;

var title = ReflectionHelper.GetTextFromPrivateField(uiComponent, "title");
```

### 2. Gecachte Lookups

ReflectionHelper cacht jede FieldInfo pro Typ und Name, daher ist ein Aufruf bei jedem Tastendruck günstig. Für ein Feld, das in jedem Frame gelesen wird (ein Poller), kannst du die FieldInfo auch selbst in einem `static readonly`-Feld halten; `Compat.ScanStatics` meldet es beim Start, falls es zu null aufgelöst wurde:

```csharp
private static readonly FieldInfo ActiveTabField = ReflectionHelper.GetFieldInfo(typeof(UITabController), "m_ActiveTab");

int tab = ActiveTabField != null ? (int)ActiveTabField.GetValue(controller) : 0;
```

### 3. Ein verifizierter Name, keine Rateketten

Probiere NICHT mehrere Namen hintereinander ("title", dann "m_Title", dann ein Transform-Pfad), um Updates zu überstehen. Das verschleiert, welcher Name richtig ist, und der Fallback liest stillschweigend das Falsche. Verwende den einen Namen aus `decompiled/`. Wenn ein Update ihn umbenennt, meldet Compat das beim Start und `dotnet test Tests` nennt Datei und Zeile; behebe es einmal, mithilfe von `git -C decompiled diff` zwischen den beiden Versions-Branches (`docs-de/05-quality-and-updates.md`, "Ablauf bei einem Spiel-Update").

### 4. Fehlerbehandlung

ReflectionHelper fängt Reflection-Fehler selbst ab, meldet sie und gibt null (oder den angegebenen Standardwert) zurück. Prüfe immer das Ergebnis und sag dem Spieler, wenn etwas nicht gelesen werden konnte:

```csharp
var title = ReflectionHelper.GetTextFromPrivateField(card, "title");
if (title == null)
{
    AccessibilityMgr.Output(this, LocalizationUtils.Get(LocalizationKey.GLOBAL_NOT_READABLE));
    return;
}
```

## Checkliste für neue Komponenten

Wenn du eine neue zugängliche Komponente erstellst:

1. Identifiziere die relevanten Spielklassen
2. Öffne die dekompilierten .cs-Dateien
3. Suche nach `[SerializeField] private`-Feldern
4. Notiere die Feldnamen (m_Name oder camelCase?)
5. Verwende ReflectionHelper statt transform.Find()
6. Teste mit verschiedenen Spielzuständen

## Harmony-Patches als Alternative

Manchmal ist ein Harmony-Patch besser als Reflection:

```csharp
[HarmonyPatch(typeof(SomeUIClass), "Init")]
public static class SomeUIClassPatch
{
    public static void Postfix(SomeUIClass __instance, ItemData item)
    {
        // Here we have direct access to the item parameter
        string title = item.GetTitle();
    }
}
```

**Vorteile:**
- Keine Reflection nötig
- Zugriff auf Methodenparameter
- Wird automatisch aufgerufen

**Nachteile:**
- Schwieriger zu debuggen
- Kann mit anderen Mods in Konflikt geraten
- Manche Methoden lassen sich schwer patchen (virtual/override)

## Wann welcher Ansatz

**Verwende ReflectionHelper für:**
- Einmaligen Zugriff auf private Daten
- Das Lesen von UI-Text, der sich selten ändert
- Den Zugriff auf den Zustand von Managern

**Verwende eine gecachte FieldInfo für:**
- Felder, auf die häufig zugegriffen wird (jeden Frame)
- Performance-kritischen Code

**Verwende einen Harmony-Postfix für:**
- Das Abfangen von Daten, wenn eine Methode aufgerufen wird
- Fälle, in denen du Methodenparameter brauchst
- Das Reagieren auf Spiel-Events

**Verwende SetPrivateField für:**
- Das Erzwingen eines Spielzustands (z.B. Gamepad-Modus)
- Testen/Debuggen
- Seltene Fälle, in denen du internen Zustand ändern musst

## Dokumentiere deine Erkenntnisse

Lege in `docs/game-api.md` einen Abschnitt für UI-Zugriffsmuster an:

```markdown
## UI Text Access

### MenuButton
- Field: `title` (camelCase)
- Type: TextMeshProUGUI
- Access: `ReflectionHelper.GetTextFromPrivateField(button, "title")`

### InventorySlot
- Field: `m_ItemName` (m_PascalCase)
- Type: Text
- Access: `ReflectionHelper.GetTextFromPrivateField(slot, "m_ItemName")`
```

Diese Dokumentation spart Zeit bei der Umsetzung neuer Features - du musst nicht jede UI-Klasse neu analysieren.

## Referenzen

- `templates/shared/ReflectionHelper.cs.template` - Vorlage für die Helferklasse
- `decompiled/` - Dekompilierter Spielcode zum Nachschlagen
- `templates/shared/Compat.cs.template` - Meldet Namen, die im aktuellen Spiel-Build fehlen
- `templates/tests/GameCompatTests.cs.template` - Prüft offline jeden literalen Namen gegen das installierte Spiel
- `docs-de/03-architecture.md` - Architektur, Abschnitt "Kompatibilität und Reflection"
