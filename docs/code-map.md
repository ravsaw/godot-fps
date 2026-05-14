# Code Map

## Punkty wejscia
- Rejestracja klas C++: [src/register_types.cpp](../src/register_types.cpp)
- Bootstrap sceny i menedzerow: [project/scripts/main.gd](../project/scripts/main.gd)
- Status roadmapy: [plan-summary.md](plan-summary.md)

## Segmenty C++
- Core i init: [segments/core-bootstrap.md](segments/core-bootstrap.md)
- ALife data: [segments/alife-data.md](segments/alife-data.md)
- World i strefy: [segments/world-zones.md](segments/world-zones.md)
- NPC runtime: [segments/npc-runtime.md](segments/npc-runtime.md)
- Player: [segments/player-runtime.md](segments/player-runtime.md)
- Weapon: [segments/weapon-runtime.md](segments/weapon-runtime.md)

## Segmenty GDScript
- Orchestracja i gameplay flow: [segments/gdscript-orchestration.md](segments/gdscript-orchestration.md)
- Event system i consequence loop: [segments/event-system.md](segments/event-system.md)
- UI i debug tools: [segments/ui-debug.md](segments/ui-debug.md)

## Szybki routing
- "Gdzie podpiac nowa klase C++?" -> [src/register_types.cpp](../src/register_types.cpp)
- "Gdzie startuje tryb mapy/testu?" -> [project/scripts/main.gd](../project/scripts/main.gd)
- "Gdzie idzie symulacja squadow?" -> [project/scripts/squad_manager.gd](../project/scripts/squad_manager.gd) i [src/alife/squad_data.cpp](../src/alife/squad_data.cpp)
- "Gdzie event bus i handlery consequence?" -> [project/scripts/alife_event_bus.gd](../project/scripts/alife_event_bus.gd), [project/scripts/alife_consequence_registry.gd](../project/scripts/alife_consequence_registry.gd), [project/scripts/alife_manager.gd](../project/scripts/alife_manager.gd)
