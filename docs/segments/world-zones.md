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

## Persistence Architecture (Faza 1+2)
1. **world_layout_data.gd**: Resource container for world topology (zones[], locations[], zone_connections[]).
2. **world_editor_tool.gd** (@tool script in main.tscn):
   - Generates initial `res://data/world_layout.tres` from hardcoded zones on first editor run.
   - Visualizes SmartLocations + edges in 3D viewport (color-coded by type).
   - Reloads on file changes (detects mtime).
3. **world_builder_dock.gd** (editor addon):
   - Save/load UI for topology editing.
   - Generates procedural chains and seeds zones.
4. **zone_manager.gd** (_try_load_all_from_file):
   - Loads world_layout.tres at startup.
   - Falls back to hardcoded zones if file missing.
   - Populates _zone_locations_by_id[zone_id] → Array[SmartLocation].

## Flow
1. Editor: Open main.tscn → WorldEditorTool generates/loads world_layout.tres → 3D visuals appear.
2. Editor: Modify locations via world_builder_dock → Save → EditorTool reloads visuals.
3. Runtime: zone_manager._ready() calls _bootstrap_zone_data() → _try_load_all_from_file() → zones loaded from persistence.
4. Zone manager builds and maintains active zone.
5. World graph holds relations between locations (Dijkstra pathfinding; Faza 3 will add Bezier curves).
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
