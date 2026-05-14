# Segment: World i strefy

## Rola
Modeluje lokacje, graf swiata i przejscia miedzy strefami.

## Kluczowe pliki
- [src/world/smart_location.h](../../src/world/smart_location.h)
- [src/world/smart_location.cpp](../../src/world/smart_location.cpp)
- [src/world/world_graph.h](../../src/world/world_graph.h)
- [src/world/world_graph.cpp](../../src/world/world_graph.cpp)
- [src/world/zone_manager.h](../../src/world/zone_manager.h)
- [src/world/zone_manager.cpp](../../src/world/zone_manager.cpp)
- [project/scripts/world/zone_manager.gd](../../project/scripts/world/zone_manager.gd)

## Flow
1. Zone manager buduje i utrzymuje aktualna strefe.
2. World graph trzyma relacje miedzy lokacjami.
3. Gameplay i ALife pytaja o graph location id oraz sasiedztwo.

## Konwencja ID
- Uzywany format referencji: zone_id:local_id.
- W dokumentach i logach trzymaj ten sam format, zeby latwo korelowac zdarzenia.

## Szybkie debug checki
- Czy graf jest spojny: sprawdz walidacje grafu przy starcie.
- Czy przejscia dzialaja: uruchom zone transition debug mode.
