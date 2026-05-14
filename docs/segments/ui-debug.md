# Segment: UI i debug tools

## Rola
HUD, overlay i narzedzia debug do obserwacji runtime.

## Kluczowe pliki
- [project/scripts/hud.gd](../../project/scripts/hud.gd)
- [project/scripts/debug_overlay_composer.gd](../../project/scripts/debug_overlay_composer.gd)
- [project/scripts/world_debug.gd](../../project/scripts/world_debug.gd)
- [project/scripts/map_command_controller.gd](../../project/scripts/map_command_controller.gd)
- [project/scripts/main.gd](../../project/scripts/main.gd)

## Flow
1. main.gd buduje menu debug i HUD.
2. Overlay composer sklada informacje z managerow.
3. Map command controller przeklada wejscie gracza na command API squadow.

## Szybkie debug checki
- Czy debug text odswieza sie po kazdym _process.
- Czy selekcja i goal marker wskazuja ten sam squad co status.
- Czy UI nie omija command API (brak bezposrednich write do runtime internals).
