# Segment: GDScript orchestration

## Rola
Skleja systemy runtime i debug mode w jednej scenie.

## Kluczowe pliki
- [project/scripts/main.gd](../../project/scripts/main.gd)
- [project/scripts/spawner.gd](../../project/scripts/spawner.gd)
- [project/scripts/transition_manager.gd](../../project/scripts/transition_manager.gd)
- [project/scripts/squad_manager.gd](../../project/scripts/squad_manager.gd)
- [project/scripts/alife_manager.gd](../../project/scripts/alife_manager.gd)

## Flow high level
1. main.gd tworzy manager-y i laczy sygnaly.
2. Wybor debug mode odpala dedykowany boot flow.
3. Manager-y dziela odpowiedzialnosci: NPC, squad, ALife, transitions, overlay.

## Co gdzie szukac
- Boot map: main.gd _boot_*.
- Publiczne command API squadow: squad_manager issue_*.
- Tick strategiczny: alife_manager _process.

## Szybkie debug checki
- Czy manager jest dodany do scene tree przed wywolaniami.
- Czy mapa komend korzysta z public API, nie z prywatnych pol runtime.
