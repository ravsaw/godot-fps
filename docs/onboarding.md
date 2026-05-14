# Onboarding (szybki powrot do projektu)

## 1. Co odpalic najpierw
- Wejdz w [project/scripts/main.gd](../project/scripts/main.gd) i zobacz dostepne debug mode.
- Przejrzyj [code-map.md](code-map.md), zeby dobrac segment.

## 2. Jak myslec o architekturze
- C++: rdzen danych i logika wydajnosciowa.
- GDScript: orchestration, event chain, UI/debug.

## 3. Najczestsze miejsca zmian
- Squad logic: [project/scripts/squad_manager.gd](../project/scripts/squad_manager.gd), [src/alife/squad_data.cpp](../src/alife/squad_data.cpp)
- Event chain: [project/scripts/alife_manager.gd](../project/scripts/alife_manager.gd), [project/scripts/alife_event_bus.gd](../project/scripts/alife_event_bus.gd), [project/scripts/alife_consequence_registry.gd](../project/scripts/alife_consequence_registry.gd)
- Strefy i graf: [project/scripts/world/zone_manager.gd](../project/scripts/world/zone_manager.gd), [src/world/world_graph.cpp](../src/world/world_graph.cpp)

## 4. Definicja done dla zmian gameplay
- Build przechodzi.
- Headless smoke przechodzi.
- Brak nowych parser errors.
- Dokumentacja segmentu zaktualizowana.
