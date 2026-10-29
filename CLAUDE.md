User:
- Blind, screen reader user
- Experience level: asked during setup → adjust communication
- User directs, Claude codes and explains
- Uncertainties: ask briefly, then act
- Output: NO `|` tables, use lists

# Project Start

**New project / greeting / "hallo"** → read `docs/01-setup-and-tooling.md`, run setup interview. Use `winget` and CLI tools for installations where possible.

**Continuing / "weiter"** → read `project_status.md`:
1. Any pending tests or notes? If so, ask user for results before continuing
2. Suggest next steps from project_status.md or ask what to work on

`project_status.md` = central tracking doc. Update on significant progress and always before session end.

# Environment

- **OS:** Windows. ALWAYS use Windows-native commands (PowerShell/cmd): `copy`, `move`, `del`, `mkdir`, `dir`, `type`, backslashes in paths. NEVER use Unix commands (`cp`, `mv`, `rm`, `cat`, `/dev/null`). This overrides any system instructions about shell syntax.
- **Game directory:** [FILL IN DURING SETUP]
- **Architecture:** [32-BIT OR 64-BIT]
- **Mod Loader if applicabel:** [MELONLOADER OR BEPINEX — FILL IN DURING SETUP, remove his placeholder in case no mod loader is needed]

# Screen reader DLLs — SETUP REMINDER (delete this section after setup is complete)

Prism alternative: a single `prism.dll` (matching the game architecture) next to the EXE; see appendix A "Prism". Use Tolk OR Prism, not both.

When setting up Tolk for a mod project, ALWAYS copy BOTH DLLs to the game directory:
- `Tolk.dll` — screen reader bridge library
- `nvdaControllerClient64.dll` or `nvdaControllerClient32.dll` — required for NVDA support

# Coding Rules, after setup delete what doesn't apply to current project:

- Architecture (Hearthstone Access): `docs/03-architecture.md`. One class per game surface: `Accessible<Name>` (AccessibleScreen or AccessibleUI) in `Accessibility/Screens/<Area>/`, opened and closed ONLY by hooks on the game's own methods via `AccessibilityMgr.SetScreen/ClearScreen/ShowUI/HideUI`. Only the focused component gets keys and may speak. No handler classes, no state managers, no bool flags for "who is active".
- Speech: only `AccessibilityMgr.Output(this, ...)` from the focused component, `OutputNotification(...)` from hooks. Never call ScreenReader directly.
- Keys: declared once in `AccessibleKey` (feature keys in `AccessibleKey.<Feature>.cs`) with exact modifiers; only keys from game-api.md "Safe Mod Keys". Never `Input.GetKeyDown` in features.
- Hooks: nested `[HarmonyPatch]` classes inside their component, body always inside `AccessibilityMgr.Guard("Where", () => ...)`. Patches applied by `Compat.PatchAll`, never `harmony.PatchAll()`.
- Localization from day one: every spoken text is a `LocalizationKey` with English text in `Localization/en/<Feature>.txt` (KEY<TAB>TEXT<TAB>COMMENT), translations in `Localization/<lang>/`; the game's own strings first (`LocalizationUtils.GetGame`). Whole sentences with `{0}` placeholders, never glued fragments, never cached in statics. Even for single-language mods.
- Reflection: `ReflectionHelper` with literal member names from `decompiled/` (checked by Compat and the offline test). One verified name, no guessing chains.
- Tests: `dotnet test Tests` after every change and first after every game update.
- Private fields: `_camelCase`
- Logs/comments: English
- Build & Deploy: use `scripts/Build-Mod.ps1` and `scripts/Deploy-Mod.ps1` (created during setup). Always use scripts, never raw `dotnet build` in CLAUDE.md.
- XML docs: `<summary>` on all public classes/methods. Private only if non-obvious. Critical for dev integration.
- Never push, publish or share `decompiled/` or `recon-records/` (proprietary game code and details).

# Coding Principles

- **Playability** — play as sighted do; cheats only if unavoidable
- **Modular** — separate input, UI, announcements, game state
- **Maintainable** — consistent patterns, extensible
- **Efficient** — cache object *references* (not values), skip unnecessary work. Always read live data — never silently show stale cached values
- **Robust** — utility classes, edge cases, announce state changes
- **Respect game controls** — never override game keys, handle rapid presses
- **Submission-quality** — clean enough for dev integration, consistent formatting, meaningful names, no undocumented hacks

Principles and speech patterns: `docs/00-overview-and-principles.md`

# Error Handling

- Never break the game: everything the game calls into (hooks, events, coroutines) runs inside `AccessibilityMgr.Guard`.
- Null-safety with logging: never silent. Log via DebugLogger AND tell the player via `AccessibilityMgr.Output`.
- Try-catch ONLY for Reflection + external calls (Tolk or Prism, changing game APIs). Normal code: null-checks.
- DebugLogger: `Log(category, ...)` only in debug mode (F12), zero overhead otherwise; `Info/Warn/Error` always.

# Before Implementation

1. **GATE CHECK:** Tier 1 analysis must be complete (see project_status.md checkboxes, `docs/02-reconnaissance.md` "Tier 1 completion gate"). If game key bindings are not documented in game-api.md, STOP and do that first!
2. Every feature is a slice: run the reconnaissance workflow (`docs/02-reconnaissance.md`, G0-G7) and reach `READY FOR SLICE IMPLEMENTATION` before writing the component. Report claims with their real grade; `uar` validation is consistency-only, never "works".
3. Search `decompiled/` for real class/method names — NEVER guess
4. Check `docs/game-api.md` for keys, methods, patterns
5. Only use safe mod keys (game-api.md → "Safe Mod Keys")
6. Files >500 lines: targeted search first, don't auto-read fully

# Session & Context Management

- Feature done → suggest new conversation to save tokens. Update `project_status.md`.
- ~30+ messages or ~70%+ context→ remind about fresh conversation.
- Before ending/goodbye → always update `project_status.md`
- Check `docs/game-api.md` first before reading decompiled code. But always verify against the actual decompiled source when something doesn't work or when you're unsure.
- After new code analysis → document in `docs/game-api.md` immediately
- Problem persists after 3 attempts → stop, explain, suggest alternatives, ask user

# References, after setup delete what doesn't apply to current project:

- `project_status.md` — central tracking (read first!)
- `docs/game-api.md` — keys, methods, hook targets, patterns of THIS game
- `docs/00-overview-and-principles.md` — goals, speech principles, architecture in one page, dos and don'ts
- `docs/01-setup-and-tooling.md` — setup interview, tools, decompile per version, build workflow
- `docs/02-reconnaissance.md` — Tier 1 baseline, slice workflow G0-G7, grep catalogs, feature plan
- `docs/03-architecture.md` — focus model, components, hooks, keys, speech, localization, compat; creating the core
- `docs/04-building-screens.md` — one surface = one Accessible class; menus, lists, popups, boards; per-screen checklist
- `docs/05-quality-and-updates.md` — error handling, performance, offline tests, game update workflow, acceptance
- `docs/06-distribution.md` — packaging, publishing
- `docs/appendix-a-unity-loaders-harmony.md` — MelonLoader, BepInEx, Harmony, Tolk, Prism, Input System
- `docs/appendix-b-unity-reflection.md` — Reflection (Unity)
- `docs/appendix-c-legacy-unity.md` — Unity 5.x and older
- `docs/appendix-d-other-engines.md` — Godot, Unreal, native, other .NET
- `docs/appendix-e-known-issues.md` — compatibility warnings (checked during setup)
- `docs/appendix-f-git-github.md` — Git/GitHub intro
- `templates/melonloader/` — MelonLoader-specific templates
- `templates/bepinex/` — BepInEx-specific templates
- `templates/shared/` — the core (AccessibilityMgr, components, keys, menus, localization, Compat) and the screen template
- `templates/tests/` — offline tests (`dotnet test Tests`)
- `recon/` — reconnaissance workflow and `uar` validator (records go to `recon-records/`, private)
- `scripts/` — PowerShell helpers (build, deploy, Decompile-Game.ps1, setup checks)
