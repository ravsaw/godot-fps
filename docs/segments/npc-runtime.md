# Segment: NPC runtime

## Rola
Obsluga jednostek NPC w runtime 3D: ruch, combat, hitbox.

## Kluczowe pliki
- [src/npc/npc_agent_3d.h](../../src/npc/npc_agent_3d.h)
- [src/npc/npc_agent_3d.cpp](../../src/npc/npc_agent_3d.cpp)
- [src/npc/hitbox_component.h](../../src/npc/hitbox_component.h)
- [src/npc/hitbox_component.cpp](../../src/npc/hitbox_component.cpp)
- [project/scripts/npc_manager.gd](../../project/scripts/npc_manager.gd)

## Flow
1. NPC manager tworzy i podlacza NPC w scenie.
2. NpcAgent3D realizuje logike zachowania i walki.
3. Hitbox przeklada trafienia na damage routing.

## Szybkie debug checki
- Czy NPC spawnuje sie poprawnie: sprawdz npc_manager.
- Czy trafienia sa widoczne: sprawdz hitbox + sygnaly dmg.
