# godot-fps

FPS game built with Godot 4 + GDExtension (C++) — low-poly 3D, event-driven world simulation.

## Stack technologiczny

| Komponent | Technologia |
|---|---|
| Silnik | Godot 4 |
| Logika rozszerzeń | GDExtension (C++) |
| Modele i animacje | Blender → GLTF |
| Styl wizualny | Low-poly 3D, flat shading |
| Fizyka i kolizje | Godot Physics (CharacterBody3D) |
| Nawigacja NPC | NavigationMesh (Godot built-in) |
| Audio | Godot AudioServer (3D positional) |
| Levele | Blender/Trenchbroom → import |
| Symulacja świata | Event Bus (GDExtension C++) |

## Plan działania

| Faza | Nazwa | Trudność | Czas |
|---|---|---|---|
| 0 | Fundament projektu | 🟢 | ~1 tydzień |
| 1 | Renderer: Świat 3D | 🟡 | ~2–3 tygodnie |
| 2 | Gracz i sterowanie | 🟢 | ~2 tygodnie |
| 3 | Low-poly NPC (model + animacje) | 🟡 | ~3–4 tygodnie |
| 4 | Węzeł NPC | 🟡 | ~2–3 tygodnie |
| 5 | System broni | 🟡🔴 | ~4–6 tygodni |
| 6 | AI bazowa | 🔴 | ~4–6 tygodni |
| 7 | Symulacja świata (Event Bus) | 🔴 | ~6–10 tygodni |
| 8 | POI i regiony | 🟡 | ~3–4 tygodnie |
| 9 | Ekwipunek i HUD | 🟡 | ~3–4 tygodnie |
| 10 | Optymalizacja i stabilność | 🟡🔴 | ~3–4 tygodnie |

### Legenda trudności
- 🟢 Łatwe (podstawy Godot)
- 🟡 Średnie (wymaga doświadczenia)
- 🔴 Trudne (C++, shadery, architektura)

## Harmonogram

```
Miesiąc 1–2  │ FAZA 0 + 1 + 2   │ Środowisko, świat, gracz
Miesiąc 2–4  │ FAZA 3 + 4       │ Model NPC, animacje, węzeł NPC
Miesiąc 4–6  │ FAZA 5 + 6       │ Broń, AI bazowa
Miesiąc 6–9  │ FAZA 7 + 8       │ Symulacja świata, POI, regiony
Miesiąc 9–11 │ FAZA 9 + 10      │ Ekwipunek, optymalizacja
Miesiąc 12+  │ Iteracja, treść   │ Kolejne bronie, mapy, typy NPC
```

> ⚠️ **Zasada:** Każda faza kończy się działającym, grywalnym wycinkiem. Nie przechodź dalej dopóki poprzednia faza nie działa stabilnie.

## Dokumentacja

Szczegółowy opis każdego etapu znajduje się w folderze [`docs/`](docs/).