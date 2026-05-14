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
- [project/scripts/world/zone_manager.gd](../../project/scripts/world/zone_manager.gd)
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

## Flow
1. Editor: Open main.tscn → WorldEditorTool generates/loads world_layout.tres → 3D visuals appear.
2. Editor: Modify locations via world_builder_dock → Save → EditorTool reloads visuals (including Bezier curves if path_points set).
3. Runtime: zone_manager._ready() calls _bootstrap_zone_data() → _try_load_all_from_file() → zones loaded from persistence.
4. Zone manager builds and maintains active zone.
5. World graph holds relations with adaptive pathfinding:
   - **Default**: Euclidean distance (straight-line) if no path_points.
   - **Faza 3 (Bezier)**: Polyline distance through control points if path_points defined.
   - **Pathfinding**: Dijkstra uses these edge weights for globally optimal routes.
   - **Faza 5 (Squad Pathfollowing):** Squads interpolate along curves, but are not rigidly bound to them.
   - Curves serve as *guidance paths*, not rails — squads can deviate for tactical reasons (combat, avoidance, rally).
6. Gameplay and ALife query graph for location id and neighbors.

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
- Czy squady się odchylają od ścieżek (Faza 5): This is expected and by design. Curves are guidance, not constraints. Combat, avoidance, and tactical regrouping override curve alignment.
