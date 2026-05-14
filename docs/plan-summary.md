# Plan summary (maj 2026)

Zrodlo: [plan.md](../plan.md)

## Co dowiezione
- Stabilny fundament debug map i runtime (headless smoke green).
- Dzialajace strefy A / T_AB / B / T_BC / C z przejsciami opartymi o commit trigger.
- World graph i LOD regionow aktywne.
- Pathing squadow miedzy regionami naprawiony.
- Publiczne command API dla squadow wdrozone.
- Debug/UI odseparowane od runtime internals squadow.
- Stabilizacja transition 2D/3D pod obciazeniem (budget + throttling).
- Sprint 1 (ALife Core Hardening) oznaczony jako completed.
- Migracja krytycznego ticku ruchu/formacji squadow do C++ oznaczona jako completed.
- **Faza 1 (Integracja persystencji map): World layout persistence infrastructure complete.** zone_manager.gd now loads from world_layout.tres; fallback to hardcoded zones still active.
- **Faza 2 (3D preview skeleton): WorldEditorTool @tool script added.** Visualizes SmartLocations + edges in 3D editor viewport; generates initial layout.tres on first run.
- **Faza 3 (Bezier curves): Curve pathfinding implemented.** SmartLocation.path_points field added (C++); WorldGraph computes polyline distances; editor visualizes curves (yellow lines + control point markers).

## Co jest aktualnie priorytetem
- Faza 4: Path editor UI in world_builder_dock (add/edit/remove control points via UI).
- Faza 5: Squad interpolation along curves (SquadData::tick_movement uses Bezier, but can deviate for tactics).

## Ryzyka operacyjne
- Build i runtime sa stabilne, ale po zmianach C++ dalej wymagaja pelnej sekwencji: build + headless smoke.
- Editor @tool scripts may cause hot-reload issues; restart editor if visuals don't update.

## Minimalna checklista po zmianie gameplay
1. Build GDExtension przechodzi.
2. Headless smoke przechodzi.
3. Brak nowych parser errors.
4. Odpowiedni plik w docs/segments jest zaktualizowany.
