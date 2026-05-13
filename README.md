# godot-fps
FPS game built with Godot 4 + GDExtension (C++) — low-poly 3D, event-driven world simulation

## Sprint 1 Release Note (May 2026)

### Scope completed
- Unified location key contract in runtime flow (`zone_id:local_id`) and normalized strategic ownership messages.
- Added world graph validation diagnostics (orphan/missing/one-way/bad-cost) with stronger connection guards.
- Refactored squad goals from single target to a lightweight stack model (explicit goals + low-priority fallback).
- Added safe fallback for unreachable squad goals to prevent movement stalls.
- Added public squad command API for map/debug command path decoupling.
- Refactored transition spawning with per-tick activation budget, pending queue, and throttled position sync.
- Extracted map input handling into dedicated controller and HUD/debug text composition into separate composer.
- Simplified main scene input path and reduced coupling between UI and simulation internals.

### Verification status
- Godot headless smoke start passes.
- Main scene loads correctly.
- Zone graph validation reports OK (33 nodes).
- GDExtension bootstrap instantiation confirmed.
- Parser check on edited scripts: no errors.

### Regression checklist (quick)
- Map mode: select squad, assign single move, assign all move with Shift+LMB.
- Squad controls: Tab cycling and clear-goal behavior (C / Shift+C).
- Attachment menu flow: toggle, navigate, confirm.
- Transition behavior near player radius under multiple active squads.
- HUD/debug overlay consistency between FPS and MAP views.
