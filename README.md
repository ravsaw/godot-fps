# 🎮 godot-fps

> **FPS zbudowany w Godot 4 + GDExtension (C++) — low-poly 3D, dynamiczna symulacja świata oparta na eventach**

Projekt zakłada stworzenie strzelca pierwszoosobowego (FPS) z żyjącym, niezależnym od gracza światem. Silnik Godot 4 dostarcza renderer i fizykę, natomiast logika symulacji świata (frakcje, NPC off-screen, łańcuchy zdarzeń) jest zaimplementowana jako natywna wtyczka C++ przez GDExtension. Wszystkie zasoby 3D to modele low-poly — bez tekstur PBR, z flat shadingiem.

---

## 🗺️ Plan projektu — 11 faz (0–10)

### Legenda trudności

| Symbol | Poziom | Opis |
|--------|--------|------|
| 🟢 | Łatwe | Standardowe API Godot, gotowe rozwiązania |
| 🟡 | Średnie | Wymaga eksperymentów, kilku iteracji |
| 🔴 | Trudne | Niestandardowe podejście, ryzyko refactoru |

---

### Tabela faz

| Faza | Opis | Trudność | Szacowany czas |
|------|------|----------|----------------|
| [**0 — Fundament**](docs/FAZA_00_fundament.md) | Działające środowisko, konwencje, pipeline | 🟢 | ~1 tydzień |
| [**1 — Renderer**](docs/FAZA_01_renderer.md) | Grywalny świat 3D: geometria, teren, oświetlenie | 🟡 | 2–3 tygodnie |
| [**2 — Gracz**](docs/FAZA_02_gracz.md) | Ruch FPS, kamera, interakcje | 🟢🟡 | 2–3 tygodnie |
| [**3 — Model NPC**](docs/FAZA_03_npc_model.md) | Low-poly model, animacje, eksport | 🟡 | 4–6 tygodni |
| [**4 — Węzeł NPC**](docs/FAZA_04_wezel_npc.md) | Scena NPC, NavMesh, synchronizacja animacji | 🟡 | 2–3 tygodnie |
| [**5 — System broni**](docs/FAZA_05_system_broni.md) | Broń FPS — feel, animacje, dźwięk, recoil | 🟡🔴 | 4–6 tygodni |
| [**6 — AI bazowa**](docs/FAZA_06_ai_bazowa.md) | NPC widzi, słyszy, reaguje — state machine | 🟡🔴 | 4–6 tygodni |
| [**7 — Symulacja świata**](docs/FAZA_07_symulacja_swiata.md) | Event bus C++, frakcje, symulacja off-screen | 🔴 | 6–10 tygodni |
| [**8 — POI i regiony**](docs/FAZA_08_poi_regiony.md) | Podział świata na strefy, dynamiczne spawny, cykl dobowy | 🟡🔴 | 3–4 tygodnie |
| [**9 — Ekwipunek i HUD**](docs/FAZA_09_ekwipunek_hud.md) | Interfejs minimalistyczny, zarządzanie przedmiotami | 🟡 | 2–3 tygodnie |
| [**10 — Optymalizacja**](docs/FAZA_10_optymalizacja.md) | Profiling, LOD, testy długich sesji, save/load | 🟡🔴 | 4–6 tygodni |

---

## 📅 Harmonogram miesięczny

| Miesiąc | Fazy | Kamień milowy |
|---------|------|---------------|
| 1 | 0, 1 | Grywalny świat 3D, gracz chodzi po terenie |
| 2 | 2, 3 | Pełny kontroler gracza + model NPC z animacjami |
| 3 | 4, 5 | NPC poruszają się po NavMesh + działająca broń |
| 4–5 | 6, 7 | AI reaguje na gracza + symulacja świata w tle |
| 6 | 8, 9 | Regiony, POI, ekwipunek, HUD |
| 7–8 | 10 | Optymalizacja, save/load, testy długich sesji |

---

## 📁 Struktura dokumentacji

```
docs/
├── FAZA_00_fundament.md       — środowisko, git, struktura projektu
├── FAZA_01_renderer.md        — świat 3D, teren, oświetlenie
├── FAZA_02_gracz.md           — kontroler gracza FPS
├── FAZA_03_npc_model.md       — model i animacje NPC
├── FAZA_04_wezel_npc.md       — węzeł NPC w Godot
├── FAZA_05_system_broni.md    — system broni
├── FAZA_06_ai_bazowa.md       — AI: percepcja, state machine
├── FAZA_07_symulacja_swiata.md — dynamiczna symulacja świata
├── FAZA_08_poi_regiony.md     — regiony, POI, cykl dobowy
├── FAZA_09_ekwipunek_hud.md   — ekwipunek i HUD
└── FAZA_10_optymalizacja.md   — optymalizacja i testy
```

---

## 🔧 Stos technologiczny

- **Silnik:** Godot 4.x
- **Język skryptowy:** GDScript (gameplay), C++ / GDExtension (symulacja świata)
- **Grafika:** Low-poly 3D, flat shading, brak PBR
- **Modelowanie:** Blender → GLTF → Godot
- **System zdarzeń:** Własny event bus zaimplementowany w C++
- **Nawigacja:** Godot NavigationServer3D + NavigationAgent3D
- **Fizyka:** Godot Physics (CharacterBody3D, RigidBody3D)
