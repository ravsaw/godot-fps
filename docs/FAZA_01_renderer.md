# Faza 1 — Renderer

> **Cel:** Grywalny świat 3D z poprawną geometrią, terenem i oświetleniem.

---

## 📋 Zadania

| # | Zadanie | Trudność | Czas |
|---|---------|----------|------|
| 1.1 | Podstawowa scena 3D — kamera FPS, oświetlenie, skybox | 🟢 | 2–3 dni |
| 1.2 | Import statycznej geometrii z Blendera (GLTF → Godot) | 🟢 | 1–2 dni |
| 1.3 | Teren nieplanarny — HeightMapShape3D | 🟡 | 3–5 dni |
| 1.4 | Kolizje statyczne | 🟢 | 2–3 dni |
| 1.5 | Oświetlenie: światło kierunkowe + LightmapGI | 🟡 | 3–5 dni |
| 1.6 | Occlusion culling (OccluderInstance3D) | 🟡 | 2–3 dni |

---

## 🔍 Opis zadań

### 1.1 — Podstawowa scena 3D

Minimalna scena do testów renderingu:

```
World3D (Node3D)
├── DirectionalLight3D        — słońce (shadow_enabled = true)
├── WorldEnvironment          — skybox + ambient
├── Camera3D                  — tymczasowa, zastąpiona przez gracza w Fazie 2
└── StaticBody3D              — tymczasowa podłoga do testów
    └── CollisionShape3D (BoxShape3D)
```

Skybox: ustaw `WorldEnvironment.environment.sky` na `ProceduralSkyMaterial` — szybki start bez zasobów.

---

### 1.2 — Import GLTF z Blendera

**Ustawienia eksportu w Blenderze:**
- Format: `GLTF 2.0` (`.glb` — plik binarny, mniejszy)
- **Include:** Mesh Data, UVs, Normals, Vertex Colors
- **Transform:** `+Y Up` (Godot używa Y-up)
- **Geometry:** Apply Modifiers ✅, Triangulate Faces ✅
- Materiały: Principled BSDF z `Flat` shading (brak smooth normals)

**Ustawienia importu w Godot (`Import` panel):**
```
Import As: Scene
Meshes > Generate LODs: ✅ (opcjonalnie)
Animation > Import: ✅ (jeśli model ma animacje)
Materials > Storage: Files (.tres) — łatwiejszy edycja
Skins > Use Named Skins: ✅
```

**Wskazówka:** Dla geometrii statycznej (budynki, teren) użyj `Import As: Static Mesh` — szybszy render.

---

### 1.3 — Teren nieplanarny

Godot oferuje dwa podejścia:

**Opcja A — HeightMapShape3D (rekomendowana)**
```gdscript
# Generowanie terenu z heightmapy (obraz PNG/EXR)
var terrain = StaticBody3D.new()
var collision = CollisionShape3D.new()
var shape = HeightMapShape3D.new()

# map_data: PackedFloat32Array z wysokościami (width * depth wartości)
shape.map_width = 256
shape.map_depth = 256
shape.map_data = load_heightmap("res://assets/terrain/heightmap.png")
collision.shape = shape
terrain.add_child(collision)
```

**Opcja B — Mesh ręczny z MeshTool**
Bardziej elastyczna, ale wolniejsza. Używaj tylko dla małych, szczegółowych terenów.

---

### 1.4 — Kolizje statyczne

Dla każdego importowanego modelu GLTF:
- W Blenderze: dodaj `Custom Property` o nazwie `godot_collision_type` = `trimesh`
- W Godot przy imporcie: `Physics > Generate: Trimesh Static Body` ✅

Alternatywnie ręcznie:
```
MeshInstance3D
└── StaticBody3D (prawy klik → "Create Trimesh Static Body")
    └── CollisionShape3D (auto-generowana)
```

**Uwaga:** Trimesh collision kosztuje więcej CPU niż ConvexShape — używaj dla skomplikowanej geometrii.

---

### 1.5 — Oświetlenie i LightmapGI

**Światło kierunkowe (słońce):**
```
DirectionalLight3D
  energy: 1.5
  shadow_enabled: true
  shadow_blur: 0.5
  directional_shadow_mode: SHADOW_PARALLEL_4_SPLITS
```

**LightmapGI (pieczenie oświetlenia pośredniego):**
1. Dodaj węzeł `LightmapGI` do sceny
2. Ustaw `quality: Medium` na start (niskie = szybkie pieczenie)
3. Kliknij **Bake** w górnym pasku Godota
4. Zapisz lightmapy w `assets/lightmaps/`

**Optymalizacja:** Dla obiektów dynamicznych (NPC) użyj `LightmapProbe` zamiast lightmap.

---

### 1.6 — Occlusion Culling

```
OccluderInstance3D
  occluder: QuadOccluder3D   # dla ścian
  # lub
  occluder: BoxOccluder3D    # dla budynków
```

W Project Settings:
```
Rendering > Occlusion Culling > Use Occlusion Culling: ON
```

**Wskazówka:** Occludery dodawaj tylko do dużych, nieprzezroczystych obiektów (ściany, budynki, teren). Małe obiekty nie warto.

---

## ✅ Rezultat fazy

- [ ] Scena 3D ładuje się i renderuje bez błędów
- [ ] Geometria z Blendera wygląda poprawnie (normalne, flat shading)
- [ ] Teren nieplanarny — gracz (test capsule) nie wpada przez podłogę
- [ ] Kolizje statyczne działają
- [ ] Lightmapa upieczona i widoczna w edytorze
- [ ] Occlusion culling aktywny — widać poprawę FPS w scenie zamkniętej
