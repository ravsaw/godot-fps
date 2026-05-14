# Segment: Player runtime

## Rola
Sterowanie graczem i stan zdrowia postaci.

## Kluczowe pliki
- [src/player/player_controller.h](../../src/player/player_controller.h)
- [src/player/player_controller.cpp](../../src/player/player_controller.cpp)
- [src/player/health_component.h](../../src/player/health_component.h)
- [src/player/health_component.cpp](../../src/player/health_component.cpp)
- [project/scenes/main.tscn](../../project/scenes/main.tscn)

## Flow
1. Main scene spawnuje playera.
2. PlayerController zbiera input i wykonuje ruch.
3. HealthComponent obsluguje damage/death eventy.

## Szybkie debug checki
- Czy InputMap jest podpiety pod akcje sterowania.
- Czy player_died jest emitowany i obslugiwany w main.gd.
