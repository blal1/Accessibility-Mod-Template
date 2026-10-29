# Third-Party Notices

This template contains or adapts work from the following projects.

## unity-accessibility-recon

- Location in this template: `recon/` (unchanged copy: workflow skills, contracts, templates, the `uar` validator and its tests).
- License: MIT. Copyright (c) 2026 Sheldon.
- Full license text: `recon/LICENSE`. The Python dependencies of `recon/` and their licenses: `recon/THIRD-PARTY-NOTICES.md`.
- Used by: `docs/02-reconnaissance.md` (the slice workflow, claim grades, coverage gates, readiness verdicts).

## PTCGL Access (Pokemon TCG Live accessibility mod)

- Adapted into: `templates/tests/GameCompatTests.cs.template` (offline game-compatibility check), `templates/shared/Compat.cs.template` (per-class patching and the startup compatibility report), the exception guard in `templates/shared/AccessibilityMgr.cs.template`, and the Unity/MelonLoader shape of the core classes.
- License: MIT. Copyright (c) 2026 RealAmethyst.

MIT License text (applies to both projects above, with their respective copyright lines):

```
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

## Hearthstone Access

- The architecture described in `docs/03-architecture.md` (AccessibilityMgr with one screen and a UI stack, AccessibleComponent, AccessibleKey, AccessibleMenu, AccessibleListOfItems, AccessibleItem, LocalizationKey with tab-separated text files) and the decompile-per-version workflow of `scripts/Decompile-Game.ps1` follow the design of Hearthstone Access and its DevTools.
- No Hearthstone Access source code is included. The patterns are described in the guides and re-implemented independently in the templates.
