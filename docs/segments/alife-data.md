# Segment: ALife data (C++)

## Rola
Przechowuje i liczy dane squad/NPC po stronie natywnej.

## Kluczowe pliki
- [src/alife/npc_data.h](../../src/alife/npc_data.h)
- [src/alife/npc_data.cpp](../../src/alife/npc_data.cpp)
- [src/alife/squad_data.h](../../src/alife/squad_data.h)
- [src/alife/squad_data.cpp](../../src/alife/squad_data.cpp)

## Co tu jest teraz
- Dane squadu (stan ruchu, cele, formacja, morale).
- Tick ruchu i obliczanie formacji po stronie C++.
- API bindowane do GDScript przez _bind_methods.

## Wejscia i wyjscia
- Wejscie: komendy i parametry z [project/scripts/squad_manager.gd](../../project/scripts/squad_manager.gd).
- Wyjscie: pozycje, statusy, flagi arrival i dane do debug snapshot.

## Na co uwazac
- Zmiany sygnatur metod wymagaja aktualizacji bind_method.
- Nie mieszac logiki scene tree z czysta logika danych.

## Szybkie debug checki
- Czy metoda widoczna w GDScript: sprawdz _bind_methods.
- Czy formacje sa poprawne: porownaj output w map/debug mode.
