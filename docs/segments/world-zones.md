# Segment: World i strefy

## Rola
Modeluje lokacje, graf swiata, persystencję topologii map i przejscia miedzy strefami.

## Kluczowe pliki
- [src/world/smart_location.h](../../src/world/smart_location.h)
- [src/world/smart_location.cpp](../../src/world/smart_location.cpp)
- [src/world/world_graph.h](../../src/world/world_graph.h)
- [src/world/world_graph.cpp](../../src/world/world_graph.cpp)
- [src/world/zone_manager.h](../../src/world/zone_manager.h)
- [src/world/zone_manager.cpp](../../src/world/zone_manager.cpp)
- [src/alife/squad_data.h](../../src/alife/squad_data.h) — **Faza 5**: Squad path_points interpolation
- [src/alife/squad_data.cpp](../../src/alife/squad_data.cpp) — **Faza 5**: evaluate_bezier_curve() method
- [project/scripts/world/zone_manager.gd](../../project/scripts/world/zone_manager.gd)
- [project/scripts/world/world_layout_data.gd](../../project/scripts/world/world_layout_data.gd)
- [project/scripts/world/world_editor_tool.gd](../../project/scripts/world/world_editor_tool.gd)
- [project/addons/world_builder/world_builder_dock.gd](../../project/addons/world_builder/world_builder_dock.gd)

## Persistence Architecture (Faza 1+2+3)
1. **world_layout_data.gd**: Resource container for world topology (zones[], locations[], zone_connections[]).
2. **world_editor_tool.gd** (@tool script in main.tscn):
   - Generates initial `res://data/world_layout.tres` from hardcoded zones on first editor run.
   - Visualizes SmartLocations + edges in 3D viewport (color-coded by type).
   - **Faza 3**: Visualizes Bezier curves as yellow polylines through control points (darker yellow markers).
   - Reloads on file changes (detects mtime).
3. **world_builder_dock.gd** (editor addon):
   - Save/load UI for topology editing.
   - Generates procedural chains and seeds zones.
   - Can now include path_points[] for each SmartLocation edge.
4. **zone_manager.gd** (_try_load_all_from_file):
   - Loads world_layout.tres at startup.
   - Falls back to hardcoded zones if file missing.
   - Populates _zone_locations_by_id[zone_id] → Array[SmartLocation].
5. **SmartLocation** (Faza 3 - Bezier curves):
   - Added `path_points: PackedVector3Array` field for Bezier waypoints.
   - Each location can define intermediate waypoints to next neighbor.
   - Empty array = straight-line pathfinding (backward compatible).
6. **SquadData** (Faza 5 - Squad movement along curves):
   - Added `path_points: PackedVector3Array` field (copied per movement leg).
   - tick_movement() calls evaluate_bezier_curve(t) if path_points defined.
   - Squads interpolate position along curved path instead of straight line.
   - Design: Curves are *guidance paths*, not rigid rails — squads retain tactical autonomy.

## Flow
1. Editor: Open main.tscn → WorldEditorTool generates/loads world_layout.tres → 3D visuals appear.
2. Editor: Modify locations via world_builder_dock → Add path_points for edges → Save → EditorTool reloads visuals (including Bezier curves).
3. Runtime: zone_manager._ready() calls _bootstrap_zone_data() → _try_load_all_from_file() → zones loaded from persistence.
4. Zone manager builds and maintains active zone.
5. World graph holds relations with adaptive pathfinding:
   - **Default**: Euclidean distance (straight-line) if no path_points.
   - **Faza 3 (Bezier pathfinding)**: Polyline distance through control points if path_points defined.
   - **Dijkstra**: Uses these edge weights for globally optimal routes.
6. Squad movement (Faza 5):
   - When squad receives path between locations, it gets target location's path_points (if any).
   - tick_movement() sets squad.path_points from location data.
   - Squad.evaluate_bezier_curve(t) interpolates along curved path during travel.
   - Curves are guidance, not constraints: squads can deviate for combat, avoidance, or tactical rally.
   - Design constraint: "Squady będą starały się poruszać po krzywej, ale nie muszą idealnie jej się trzymać" (squads try to follow curves but retain tactical autonomy).
7. Gameplay and ALife query graph for location id and neighbors.

## Konwencja ID
- Uzywany format referencji: zone_id:local_id.
- W dokumentach i logach trzymaj ten sam format, zeby latwo korelowac zdarzenia.
- World graph id = zone_graph_index * GRAPH_ZONE_STRIDE + local_location_id (see zone_manager.gd).

## Szybkie debug checki
- Czy graf jest spojny: sprawdz walidacje grafu przy starcie (_validate_world_graph output).
- Czy persystencja dzialala: uruchom edytor, sprawdz Console czy "WorldEditorTool: generated initial layout" się pojawił.
- Czy edytor wizualizuje: w 3D viewport powinnien zobaczyć kolorowe sferki (lokacje) i linie (krawędzie).
- Czy runtime wczytuje: w headless mode, sprawdz Console czy "ZoneManager: loaded X zones from res://data/world_layout.tres".
- **Faza 3 — Bezier curves**: Żółte linie z ciemnożółtymi markerami = zdefiniowane control points. Szare linie = proste połączenia.
- **Faza 3 — Pathfinding**: Sprawdz WorldGraph edge distances — powinny uwzględniać path_points (nie tylko 3D odległość).
- **Faza 5 — Squad movement**: Squads should follow curved paths when path_points exist; verify by placing path points and watching squad travel in headless or editor.
  - Expected: Squad's interpolation follows curve segments instead of straight line.
  - Tactical deviation: If squad takes damage (morale < 0.3), it retreats to resting location (may deviate from curve).
  - This behavior is intentional per design: "curves are guidance, not rails".
