# 04 Building Screens

Turning one game surface into one accessible class. Prerequisites: the core exists (`docs/03-architecture.md`, "Creating the core") and the slice has the verdict `READY FOR SLICE IMPLEMENTATION` (`docs/02-reconnaissance.md`).

## Before each feature (Phase 3)

1. Consult `docs/game-api.md`:
   - game key bindings (no conflicts),
   - already documented classes, methods and hook targets,
   - the UI access pattern for this kind of screen (do not re-analyze what is documented).
2. Check the feature plan entry: are its dependencies done?
3. Check the slice records: the surface lifecycle rows, the native input matrix, the open gaps.
4. For UI with private fields: ReflectionHelper (`docs/appendix-b-unity-reflection.md`).
5. Work through the checklist at the end of this file.

Why game-api.md first: no key conflicts, no duplicate searching, the same patterns everywhere, and UI access problems that are already solved stay solved.

Build features in the order a player meets them:

1. Main menu (first contact, basic navigation).
2. Settings menu, if reachable from the main menu.
3. General status announcements (health, money, time).
4. Tutorial or starting area.
5. Core gameplay (the most frequent actions).
6. Inventory and in-game menus (pause menu, map).
7. Special features (crafting, trading, dialogue).
8. Endgame and optional (achievements, statistics).

## The shape of every screen

Start from `templates/shared/AccessibleFEATURENAME.cs.template`:

1. One file per surface: `Accessibility/Screens/<Area>/Accessible<Name>.cs`, sealed, one static instance.
2. `AccessibleScreen` for a base screen, `AccessibleUI` for a popup or overlay (then `ShowUI`/`HideUI` instead of `SetScreen`/`ClearScreen`).
3. Nested `[HarmonyPatch]` hook classes on the game's open and close methods, each body inside `AccessibilityMgr.Guard`.
4. On open: keep the game instance, build the menu or lists, hand the component to AccessibilityMgr. On close: check it is the same instance, release it.
5. `OnGainedFocus()`: title and current element. `GetHelp()`: the keys that work now. `HandleInput()`: elements first, then feature keys.
6. Every text from LocalizationUtils or from the game; keys in `LocalizationKey.<Feature>.cs` and `Localization/*/<Feature>.txt`; feature keys in `AccessibleKey.<Feature>.cs`.
7. Actions through the game's own path. Live data on every key.

A minimal options popup:

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

## Menu item types

Each control type has its own announcement and keys. The label always comes first.

**Button**
- Activation: Enter or Space invokes the game's own click (`button.onClick.Invoke()`).
- Announcement: the label. "New Game, 1 of 5".
- Not interactable right now: still listed, "Continue, unavailable".

**Slider**
- Left and Right decrease and increase (feature keys, or a menu option with its own HandleInput).
- Announcement: label, "slider", value, hint. "Master Volume, slider, 75 percent, left and right to adjust".
- Step: the game's own increment, else about 5 to 10 percent of the range. Announce the new value after each step.

**Toggle or checkbox**
- Enter or Space flips it (through the game's toggle so its listeners run).
- Announcement: label, "checkbox", state. "Enable Tutorials, checkbox, checked".
- After the change: the new state.

**Dropdown or selection**
- Left and Right cycle the options, or Enter opens a sub-menu (an AccessibleUI) with all options.
- Announcement: label, "dropdown", current value. "Language, dropdown, English".
- After the change: the new value.

**Tab**
- Tab and Shift+Tab switch tabs (`AccessibleKey.NEXT_SECTION`/`PREV_SECTION`), or the tabs are the first level of a two-level menu.
- Announcement: label, "tab". "Audio, tab". Then the first element of the tab's content.

**Text field**
- See "Text input" below.

The type words ("slider", "checkbox", "tab") are LocalizationKeys too.

## Label resolution

When an element has no obvious readable label, use this order:

1. **The game's localization**: a localized-text component with a key, or a text starting with a localization marker (`%`, `#`, `@`): resolve it through the game's localizer (`LocalizationUtils.GetGame`).
2. **The element's own visible text**: the Text or TMP_Text in its children (`GetComponentInChildren<TMP_Text>()`).
3. **The parent**: the wrapper often holds the label (an option row's Title, Label or Text field), not the control itself.
4. **Tooltip text**: may need parsing (for example "Category:Key").
5. **A known-name mapping**: internal names to readable labels ("SelectAll" to "Select All", "EndTurn" to "End Turn", "BtnOK" to "OK"), stored as LocalizationKeys so they are translated.
6. **The cleaned object name**: remove prefixes and suffixes (`btn_`, `_button`), add spaces before capitals. Last resort, not localized; log it in debug mode so it gets a real label later.

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

The static UI ledger of the slice usually already says where each label comes from; use that.

## Collecting elements

Build the menu from the game's own references (fields of the screen class found in the static ledger) whenever possible. Only when a screen is assembled dynamically, collect from the hierarchy:

Collect:

- buttons with real click handlers (not decorative),
- sliders, toggles, dropdowns with change handlers,
- tab buttons.

Skip:

- controls without handlers,
- inactive objects, invisible controls, controls whose parent panel is hidden,
- internal containers (names with "Area", "Panel", "Container", "Group"),
- decorative elements (backgrounds, separators).

Sort by visual position so the order matches what sighted players see:

1. Priority items first, if the game has a natural main action ("New Game" before "Exit").
2. Then top to bottom (in Unity UI, higher Y is higher on screen).
3. For horizontal rows (tabs): left to right.

```csharp
items.Sort((a, b) =>
{
    int prio = GetPriority(b) - GetPriority(a);
    if (prio != 0) return prio;
    return b.transform.position.y.CompareTo(a.transform.position.y);
});
```

Collect when the component opens and, for content that changes, again on every read (live getters) rather than once.

## Lists and items

- Vertical choices (menus, settings, a list of saves): AccessibleMenu.
- Rows of things with details (cards in hand, party members, inventory row, rewards): AccessibleListOfItems with an AccessibleItem subclass whose `GetLines()` reads the game object live:

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

- Several lists on one screen (hand, board, shop): separate instances; Tab and Shift+Tab switch, announcing the list name and the current item.
- Positions are always spoken ("3 of 12").
- Lists stop at their edges (no wraparound). Home and End jump, numbers jump to the Nth element.

## Two-level navigation (tabs and categories)

For tabbed settings or categorized lists:

- Either the tabs are a menu whose options open the tab content as an AccessibleUI (Backspace closes it and returns to the tab list, which re-announces itself),
- or the component keeps one menu per tab and switches with Tab and Shift+Tab, announcing "Audio, tab" and then the first element.

The first is simpler when the game itself opens a panel per tab (hook it); the second when all tabs share one panel.

## Popups and modal dialogs

- Every popup is its own AccessibleUI with its own open and close hooks. It takes focus over whatever is underneath; the screen below goes silent automatically.
- Announce the popup by its title, then its text, then the first option: "Confirm purchase. Buy Sword for 100 gold? Yes, 1 of 2".
- When it closes, nothing to do: AccessibilityMgr re-announces the focused component below.
- A generic game dialog class used for many purposes (confirm, error, info) is one component that reads its title and body from the instance.
- Game notifications that do not take input (toasts, achievement banners) are not UIs: the hook calls `AccessibilityMgr.OutputNotification(text)`.
- Blocking notices with one dismiss button: a small AccessibleUI with "Press Enter to continue" (or the forced-key pattern, `docs/03-architecture.md`).

## Dynamic content

When content changes while the screen is open (items sold, cards drawn, a timer):

- Read live: menus with `Func<string>` labels, lists with `getItems` that query the game each time.
- If the game fires an event or calls a method on change (`OnItemAdded`, `RefreshList`), hook it and announce the change if the player needs to know ("Sword sold").
- Keep the selection when the element still exists; if the current one was removed, move to the nearest valid one and say it.
- Never announce from a stale copy.

## Empty states

Never leave the player in silence:

- "No items" (empty list or menu).
- "No selection" (nothing selected).
- "Inventory empty" (no content).
- "No results" (search or filter found nothing).

Back and close still work on empty screens.

## Game boards and gameplay screens

Battles, maps, boards and worlds are AccessibleScreens with several elements and many feature keys:

- Split the board into zones the player can switch between (your hand, your board, the opponent's board, the shop) with Tab or dedicated keys; each zone an AccessibleListOfItems.
- Separate "read" keys (status, resources, whose turn) declared in `AccessibleKey.<Feature>.cs`, each answering from live data.
- Opponent and environment actions are notifications from hooks on the game's own event methods (card played, damage dealt, turn started): queued, short, consistent.
- Targeting (choose a target for an attack or a spell): an AccessibleUI pushed while the game waits for a target; its list contains only valid targets the game itself offers; confirm invokes the game's own targeting call.
- History or log: an AccessibleUI listing the last events, so a missed announcement can be re-read.
- Quantity actions: modifier multipliers (for example Shift 5, Ctrl 10, Alt 100) with `AccessibleKey.IsHoldingShift()` and friends, announced in the screen's help.

## Text input

The component owning a text field:

- on focus: announces the field's label and current content, calls `AccessibilityMgr.AllowTextInput()`;
- while typing: all keys go to the game; F1 and F8 still work;
- on submit or leaving the field (hook the game's submit or deselect): `DisallowTextInput()`, announces the result.

Never leave text input allowed after the field is gone; close hooks call `DisallowTextInput()` too.

## Key capture

A mod key the game also reads would trigger both. In order of preference:

1. Use a key from "Safe Mod Keys" that the game ignores on this screen.
2. Let the game handle it and only describe the result (often right for Enter on the game's focused button).
3. Block the game's handling only while this component is focused, with a Prefix on the game's input method:

```csharp
[HarmonyPatch(typeof(GameInputHandler), "Update")]   // name from decompiled/
private static class BlockGameInputWhileFocused
{
    private static bool Prefix() => !AccessibilityMgr.IsFocused(_instance);   // false = skip the game's method
}
```

Block as narrowly as possible (one method, one screen), document it in `docs/game-api.md`, and never block keys the player needs for the game itself.

## Announcement timing

- Screen or popup opened: its name, then the first element.
- Navigation: the current element (with type and value for non-buttons) and position.
- Activation: the result ("Enabled", "Changed to English", "75 percent").
- At an edge: silence and stay (the position already told the player where they are).
- Empty: an explicit empty text.
- Errors: why ("Cannot activate: not enough gold").
- Key hints: queued after the opening announcement, or only on F1.

## Debug mode

F12 toggles debug mode (Main). With it on, `DebugLogger.Log(...)` and every spoken text go to the loader log. Use it to:

- log hook calls and screen and UI changes (AccessibilityMgr logs these with Info already),
- log collected elements with their resolved labels,
- log unlabeled elements and label fallbacks,
- see exactly what was spoken, in order.

Errors and compatibility problems are logged always, not only in debug mode. Never log privacy-sensitive values (account names, friend codes) even in debug mode.

## Unity UI quick reference

Typical hierarchy:

```
Canvas
  Panel (e.g. "InventoryPanel")
    Header (title)
    Content
      ScrollView
        Items (list)
    Buttons (actions)
```

Components to look for: `Text` / `TextMeshProUGUI` (labels), `Button`, `Toggle`, `Slider`, `InputField` / `TMP_InputField`, `ScrollRect`, `Dropdown` / `TMP_Dropdown`.

```csharp
bool isOpen = panel != null && panel.activeInHierarchy;   // active?
bool canClick = button != null && button.interactable;    // usable?
var label = button.GetComponentInChildren<TMPro.TMP_Text>()?.text;
var child = parent.transform.Find("ChildName");
foreach (Transform c in parent.transform) { }
```

`GameObject.Find`, `FindObjectsOfType` and `GetComponentsInChildren` search the hierarchy: call them when a component opens, not every frame; prefer the references the hook gives you (`__instance` and its fields).

## Per-screen checklist

Understand the structure:

- [ ] Layout known: linear, grid, hierarchical or tabbed.
- [ ] Element types known: buttons, sliders, toggles, dropdowns, tabs, text fields.
- [ ] Open and close methods verified (runtime probe passed), screen or UI decided.
- [ ] Modal dialogs it can open identified (each its own component).

Interaction:

- [ ] For every element, the game's own activation path (onClick, the game's method) is used; nothing re-implemented.
- [ ] Existing game focus or accessibility systems checked and reused if present.

Labels:

- [ ] All labels meaningful (not empty, not "item123").
- [ ] Labels from the game's own text or localization where possible.
- [ ] Fallback order applied for the rest; every mod text is a LocalizationKey with English text.

Keys:

- [ ] Common keys used (arrows, Enter, Backspace, Home and End, numbers, Tab).
- [ ] New keys declared in `AccessibleKey.<Feature>.cs`, only from "Safe Mod Keys".
- [ ] Mod keys do not also trigger the game (or blocking is narrow and documented).

Speech:

- [ ] Opening announced (name, first element).
- [ ] Navigation announces the current element with position.
- [ ] Empty states explicit.
- [ ] Actions confirmed with the new state.
- [ ] F1 answers with the keys that work here.
- [ ] Closing returns to the component below, which re-announces itself.

Robustness:

- [ ] Hooks inside Guard; close hook checks the instance.
- [ ] Live data on every read, references only cached.
- [ ] `dotnet test Tests` passes (localization, architecture, game compatibility).

Testing:

- [ ] Tested after each change, one element type at a time.
- [ ] Debug log checked: collected elements and labels as expected.
- [ ] Tested with a real screen reader; the user confirmed it (`NVDA-MANUAL-CONFIRMED` in the slice records, "Pending Tests" in project_status.md).
