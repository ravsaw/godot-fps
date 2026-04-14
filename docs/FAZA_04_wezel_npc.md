# Faza 4 — Węzeł NPC

> **Cel:** Kompletny węzeł NPC łączący model, kolizję, animację i nawigację.

---

## 📋 Zadania

| # | Zadanie | Trudność | Czas |
|---|---------|----------|------|
| 4.1 | Struktura sceny NPC: CharacterBody3D + MeshInstance3D + CollisionShape3D + NavigationAgent3D | 🟢 | 1–2 dni |
| 4.2 | NavMesh — NavigationRegion3D, bake siatki, ruch NPC do celu | 🟡 | 3–4 dni |
| 4.3 | Nawigacja na nieplanarnym terenie | 🟡 | 3–5 dni |
| 4.4 | Synchronizacja AnimationTree z prędkością i stanem NPC | 🟢 | 2–3 dni |
| 4.5 | LOD system — uproszczony mesh z daleka (GeometryInstance3D LOD bias) | 🟡 | 2–3 dni |
| 4.6 | Test wydajności — 50–100 NPC jednocześnie, profiling | 🟡 | 3–4 dni |

---

## 🔍 Opis zadań

### 4.1 — Struktura sceny NPC

```
NPC (CharacterBody3D)               ← fizyka, ruch
├── CollisionShape3D                ← CapsuleShape3D (h:1.8m, r:0.3m)
├── MeshInstance3D                  ← model low-poly z Fazy 3
│   └── Skeleton3D
│       ├── IK_FootLeft  (SkeletonIK3D)
│       └── IK_FootRight (SkeletonIK3D)
├── AnimationTree                   ← z Fazy 3
├── NavigationAgent3D               ← pathfinding
├── SpotLight3D (opcjonalnie)       ← latarka nocna
└── Area3D (PerceptionArea)         ← zasięg słyszenia (Faza 6)
    └── CollisionShape3D (SphereShape3D, radius=20m)
```

---

### 4.2 — NavMesh i NavigationRegion3D

**Konfiguracja NavMesh:**
```
NavigationRegion3D
  NavigationMesh:
    agent_radius: 0.4          ← musi pasować do kolizji NPC
    agent_height: 1.9
    agent_max_climb: 0.5       ← max wysokość stopnia
    agent_max_slope: 45.0      ← max kąt zbocza (°)
    cell_size: 0.25            ← dokładność siatki
    edge_max_length: 4.0
```

Aby upiec NavMesh w edytorze: kliknij `NavigationRegion3D` → **Bake NavMesh**.

Dla dynamicznego terenu (zmiana w runtime):
```gdscript
NavigationServer3D.region_set_navigation_mesh(region.get_rid(), nav_mesh)
NavigationServer3D.region_bake_navigation_mesh(nav_mesh, get_tree().root)
```

---

### 4.3 — Nawigacja na nieplanarnym terenie

Podejście wielowarstwowe:
1. `NavigationRegion3D` obejmuje cały teren (HeightMapShape3D)
2. `NavigationMesh.sample_partition_type = WATERSHED` — lepsza jakość siatki na zboczach
3. Link nawigacyjny (`NavigationLink3D`) dla skoków/drabin

```gdscript
# Łączenie osobnych wysp nawigacyjnych
var link := NavigationLink3D.new()
link.start_position = Vector3(0, 0, 0)    # krawędź platformy A
link.end_position   = Vector3(0, -3, 5)   # ziemia poniżej
link.bidirectional  = false               # tylko w dół
add_child(link)
```

---

### 4.4 — Kod węzła NPC z NavMesh i animacjami

```gdscript
extends CharacterBody3D

const SPEED_WALK   := 2.5
const SPEED_RUN    := 5.5
const GRAVITY      := 9.8
const STOP_DIST    := 0.5   # dystans do celu, przy którym NPC staje

@onready var _agent      : NavigationAgent3D = $NavigationAgent3D
@onready var _anim_tree  : AnimationTree     = $AnimationTree
@onready var _anim_state : AnimationNodeStateMachinePlayback = \
    _anim_tree.get("parameters/playback")

var _target_position : Vector3 = Vector3.ZERO
var _is_running      : bool    = false

func _ready() -> void:
    _agent.path_desired_distance = 0.5
    _agent.target_desired_distance = STOP_DIST
    _agent.velocity_computed.connect(_on_velocity_computed)

## Ustaw nowy cel nawigacji
func move_to(pos: Vector3) -> void:
    _target_position = pos
    _agent.target_position = pos

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= GRAVITY * delta

    if _agent.is_navigation_finished():
        _set_anim_state("idle")
        return

    var next_pos  := _agent.get_next_path_position()
    var direction := (next_pos - global_position).normalized()
    direction.y = 0.0

    var speed := SPEED_RUN if _is_running else SPEED_WALK
    _agent.velocity = direction * speed   # wyzwala sygnał velocity_computed

    _sync_animation(direction * speed)

    # Obrót NPC w kierunku ruchu
    if direction.length() > 0.01:
        var target_angle := atan2(-direction.x, -direction.z)
        rotation.y = lerp_angle(rotation.y, target_angle, delta * 8.0)

## Wywoływana przez NavigationAgent3D po unikaniu kolizji między NPC
func _on_velocity_computed(safe_vel: Vector3) -> void:
    velocity.x = safe_vel.x
    velocity.z = safe_vel.z
    move_and_slide()

func _sync_animation(vel: Vector3) -> void:
    var speed_2d := Vector2(vel.x, vel.z).length()
    _anim_tree.set("parameters/MovementBlend/blend_amount",
        clamp(speed_2d / SPEED_RUN, 0.0, 1.0))

    if speed_2d < 0.2:
        _set_anim_state("idle")
    elif _is_running:
        _set_anim_state("run")
    else:
        _set_anim_state("walk")

func _set_anim_state(state: String) -> void:
    if _anim_state.get_current_node() != state:
        _anim_state.travel(state)
```

---

### 4.5 — LOD System

Godot 4 ma wbudowany LOD przez `GeometryInstance3D`:

```gdscript
# W MeshInstance3D:
mesh_instance.lod_bias = 1.0      # domyślny bias LOD
mesh_instance.visibility_range_end = 80.0          # znika > 80m
mesh_instance.visibility_range_end_margin = 10.0   # fade na ostatnich 10m
```

Dla NPC warto przygotować 2–3 poziomy LOD w Blenderze:
- **LOD0:** 500–1500 trójkątów (< 20m)
- **LOD1:** 200–400 trójkątów (20–50m)
- **LOD2:** 50–100 trójkątów (50–80m)

---

### 4.6 — Test wydajności

Procedura testowania:
1. Utwórz scenę testową: 100 NPC chodzących po NavMesh po prostym terenie
2. Uruchom **Profiler** (Godot → Debug → Profiler)
3. Sprawdź:
   - `physics_process` NPC < 2 ms łącznie
   - FPS > 60 na GPU mid-range
   - Użycie pamięci: stabilne (brak wzrostu przez 5 minut)

Optymalizacje przy przekroczeniu budżetu:
- Ogranicz `NavigationAgent3D.path_postprocessing` (wyłącz dla odległych NPC)
- Wyłącz Foot IK dla NPC > 15m od gracza
- Użyj `call_deferred` dla operacji nie wymagających natychmiastowej odpowiedzi

---

## ✅ Rezultat fazy

- [ ] Scena NPC zapisana jako oddzielna scena (`.tscn`)
- [ ] NPC porusza się po NavMesh do wskazanego punktu
- [ ] NPC nie wpada przez teren na zboczach
- [ ] AnimationTree synchronizuje animację z prędkością ruchu
- [ ] LOD przełącza mesh przy odpowiedniej odległości
- [ ] 50 NPC jednocześnie = stabilne 60 FPS (scena testowa)
