# Segment: Core i bootstrap

## Rola
Laduje GDExtension, rejestruje klasy i uruchamia glowny flow sceny.

## Kluczowe pliki
- [src/init.cpp](../../src/init.cpp)
- [src/register_types.cpp](../../src/register_types.cpp)
- [src/register_types.h](../../src/register_types.h)
- [src/core/game_bootstrap.cpp](../../src/core/game_bootstrap.cpp)
- [project/scripts/main.gd](../../project/scripts/main.gd)

## Flow
1. Godot laduje extension przez init.
2. Rejestracja klas leci przez ClassDB w register_types.
3. Main scene uruchamia manager-y i debug mode.

## Na co uwazac
- Kazda nowa klasa C++ musi byc zarejestrowana.
- Brak rejestracji zwykle konczy sie tym, ze ClassDB.instantiate zwraca null.
- Zachowuj Godot 4 API only.

## Szybkie debug checki
- Czy klasa istnieje: sprawdz ClassDB.class_exists po nazwie.
- Czy extension sie laduje: sprawdz log z [project/scripts/main.gd](../../project/scripts/main.gd).
