# Segment: Weapon runtime

## Rola
Logika strzalu, pociskow, attachmentow i stats broni.

## Kluczowe pliki
- [src/weapon/weapon_base.h](../../src/weapon/weapon_base.h)
- [src/weapon/weapon_base.cpp](../../src/weapon/weapon_base.cpp)
- [src/weapon/bullet_3d.h](../../src/weapon/bullet_3d.h)
- [src/weapon/bullet_3d.cpp](../../src/weapon/bullet_3d.cpp)
- [src/weapon/weapon_stats.h](../../src/weapon/weapon_stats.h)
- [src/weapon/weapon_stats.cpp](../../src/weapon/weapon_stats.cpp)
- [src/weapon/weapon_attachment_slot.h](../../src/weapon/weapon_attachment_slot.h)
- [src/weapon/weapon_attachment_slot.cpp](../../src/weapon/weapon_attachment_slot.cpp)
- [project/scripts/attachment_manager.gd](../../project/scripts/attachment_manager.gd)

## Flow
1. Main scene podpina bron pod playera.
2. WeaponBase emituje fired/bullet_hit/reloaded.
3. Attachment manager i HUD aktualizuja warstwe gracza.

## Szybkie debug checki
- Czy sygnaly broni docieraja do HUD.
- Czy durability/jam flow nie rozchodzi sie miedzy C++ i GDScript.
