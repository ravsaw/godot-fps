# Faza 3 — Model NPC

> **Cel:** Low-poly model NPC gotowy do użycia w Godot 4.

---

## 📋 Zadania

| # | Zadanie | Trudność | Czas |
|---|---------|----------|------|
| 3.1 | Low-poly model NPC w Blenderze (500–1500 trójkątów, humanoid rig) | 🟡 | 1–2 tyg. |
| 3.2 | Animacje: idle, walk, run, combat_idle, shoot, reload, death | 🟡 | 1–2 tyg. |
| 3.3 | Eksport GLTF z animacjami → Godot 4 (AnimationLibrary) | 🟢 | 1–2 dni |
| 3.4 | AnimationTree + AnimationStateMachine — blending stanów | 🟡 | 3–5 dni |
| 3.5 | Foot IK — dopasowanie nóg do terenu (SkeletonIK3D) | 🔴 | 3–5 dni |
| 3.6 | Materiały low-poly — flat shading, bez PBR | 🟢 | 1–2 dni |

---

## 🔍 Opis zadań

### 3.1 — Model NPC w Blenderze

**Docelowe parametry:**
- Trójkąty: **500–1500** (LOD0 — blisko gracza)
- Rig: **humanoid** — minimum 20 kości (szkielet zgodny z Mixamo/Godot Humanoid)
- Proporcje: realistyczne lub lekko stylizowane — zgodne z resztą artstyle

**Konwencja nazewnictwa kości (Godot-friendly):**
```
Hips → Spine → Spine1 → Chest → Neck → Head
                       → LeftShoulder → LeftArm → LeftForeArm → LeftHand
                       → RightShoulder → RightArm → RightForeArm → RightHand
       → LeftUpLeg → LeftLeg → LeftFoot → LeftToeBase
       → RightUpLeg → RightLeg → RightFoot → RightToeBase
```

**Flat shading w Blenderze:**
1. Zaznacz cały mesh → `Object Data Properties` → `Normals` → `Auto Smooth: OFF`
2. Prawy klik na mesh → `Shade Flat`

---

### 3.2 — Animacje

Wymagane animacje (każda jako osobna akcja NLA w Blenderze):

| Animacja | Opis | Długość |
|----------|------|---------|
| `idle` | Oddychanie, drobne ruchy | 2–3 s (loop) |
| `walk` | Chód w miejscu | 1 s (loop) |
| `run` | Bieg w miejscu | 0.6 s (loop) |
| `combat_idle` | Gotowość bojowa | 2 s (loop) |
| `shoot` | Strzał z broni | 0.3 s |
| `reload` | Przeładowanie | 2–3 s |
| `death` | Śmierć — pada na ziemię | 1.5 s (no loop) |

**Wskazówka:** Animacje `walk` i `run` muszą być zsynchronizowane z prędkością — 1 pełny cykl = 1 krok lewą + 1 krok prawą nogą.

---

### 3.3 — Eksport GLTF z Blendera

**Ustawienia eksportu (File → Export → glTF 2.0):**

```
Format: glTF Binary (.glb)
Include:
  ☑ Selected Objects (lub All)
  ☑ Custom Properties
Transform:
  ☑ +Y Up
Geometry:
  ☑ Apply Modifiers
  ☑ UVs
  ☑ Normals
  ☑ Vertex Colors
Animation:
  ☑ Export
  ☑ Bake All Object Animations
  ☑ NLA Tracks
  ☑ All Bone Influences (do 4)
  ☐ Shape Keys (nie używamy)
```

**Import w Godot:**
```
Import As: Scene
Animation > Import: ✅
Animation > Storage: Files (.res)
Meshes > Lightmap UV: ☐ (NPC nie pieczemy)
```

Godot automatycznie tworzy `AnimationLibrary` z wszystkimi akcjami z Blendera.

---

### 3.4 — AnimationTree i AnimationStateMachine

Struktura `AnimationTree` dla NPC:

```
AnimationTree
└── AnimationNodeStateMachine (root)
    ├── idle          (AnimationNodeAnimation)
    ├── walk          (AnimationNodeAnimation)
    ├── run           (AnimationNodeAnimation)
    ├── combat_idle   (AnimationNodeAnimation)
    ├── shoot         (AnimationNodeAnimation — one-shot)
    ├── reload        (AnimationNodeAnimation — one-shot)
    └── death         (AnimationNodeAnimation — no loop)
```

**Przejścia (Transitions):**
- `idle → walk`: warunek `speed > 0.5`
- `walk → run`: warunek `speed > 4.0`
- `* → death`: warunek `is_dead == true` (priorytet: wysoki)
- `* → shoot`: warunek `is_shooting == true` (one-shot, powrót do poprzedniego)

Sterowanie z GDScript:
```gdscript
@onready var _anim_tree: AnimationTree = $AnimationTree
@onready var _state: AnimationNodeStateMachinePlayback = \
    _anim_tree.get("parameters/playback")

func set_movement_speed(speed: float) -> void:
    _anim_tree.set("parameters/walk_blend/blend_amount",
        clamp(speed / 5.0, 0.0, 1.0))

func play_state(state_name: String) -> void:
    _state.travel(state_name)
```

---

### 3.5 — Foot IK (SkeletonIK3D)

Foot IK dopasowuje stopy NPC do nierównego terenu, zapobiegając "pływaniu" nóg:

```gdscript
extends CharacterBody3D

@onready var _skeleton : Skeleton3D   = $MeshInstance3D/Skeleton3D
@onready var _ik_left  : SkeletonIK3D = $MeshInstance3D/Skeleton3D/IK_FootLeft
@onready var _ik_right : SkeletonIK3D = $MeshInstance3D/Skeleton3D/IK_FootRight

const RAY_LEN := 1.2   # długość raycastu w dół

func _process(delta: float) -> void:
    _update_foot_ik("LeftFoot",  _ik_left)
    _update_foot_ik("RightFoot", _ik_right)

func _update_foot_ik(bone_name: String, ik: SkeletonIK3D) -> void:
    var bone_idx  := _skeleton.find_bone(bone_name)
    var bone_pos  := _skeleton.get_bone_global_pose(bone_idx).origin
    var world_pos := _skeleton.global_transform * bone_pos

    var space_state := get_world_3d().direct_space_state
    var query := PhysicsRayQueryParameters3D.create(
        world_pos + Vector3.UP * 0.3,
        world_pos + Vector3.DOWN * RAY_LEN
    )
    var result := space_state.intersect_ray(query)

    if result:
        var target := Transform3D(Basis.IDENTITY, result["position"])
        target.basis = _align_to_normal(result["normal"])
        ik.target = _skeleton.global_transform.affine_inverse() * target
        ik.start()

func _align_to_normal(normal: Vector3) -> Basis:
    var up    := normal
    var fwd   := -transform.basis.z
    var right := fwd.cross(up).normalized()
    fwd = up.cross(right).normalized()
    return Basis(right, up, -fwd)
```

---

### 3.6 — Materiały low-poly (flat shading)

```gdscript
# Tworzenie materiału flat-shading przez kod:
var mat := StandardMaterial3D.new()
mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # pełny flat
# lub
mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL  # flat z oświetleniem
mat.albedo_color = Color(0.4, 0.5, 0.3)  # zielonoszary mundur

# Brak normalmap, brak roughness/metallic:
mat.normal_enabled   = false
mat.roughness        = 1.0
mat.metallic         = 0.0
```

---

## ✅ Rezultat fazy

- [ ] Model NPC z rigiem — widoczny w Godot bez artefaktów
- [ ] Animacje importowane jako `AnimationLibrary` — wszystkie 7 akcji
- [ ] `AnimationTree` z `StateMachine` przełącza stany poprawnie
- [ ] Foot IK — stopy leżą na terenie, nie przenikają ani nie unoszą się
- [ ] Materiały flat shading — brak PBR, brak normalmap
- [ ] Model LOD0 mieści się w 500–1500 trójkątach
