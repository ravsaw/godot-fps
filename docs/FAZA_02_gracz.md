# Faza 2 — Gracz

> **Cel:** Responsywny ruch gracza, kamera FPS, podstawowe interakcje.

---

## 📋 Zadania

| # | Zadanie | Trudność | Czas |
|---|---------|----------|------|
| 2.1 | CharacterBody3D — ruch WASD, grawitacja | 🟢 | 2–3 dni |
| 2.2 | Kamera FPS — obrót myszą, clamp pitch, mouse capture | 🟢 | 1–2 dni |
| 2.3 | Ruch po nieplanarnym terenie — schody, zbocza | 🟡 | 3–4 dni |
| 2.4 | Sprint + stamina — FOV kick | 🟢 | 2 dni |
| 2.5 | Raycast interakcji | 🟢 | 1–2 dni |
| 2.6 | Head bob — kołysanie kamery przy chodzeniu | 🟢 | 1–2 dni |

---

## 🔍 Opis zadań

### 2.1 & 2.2 — Kontroler gracza z kamerą FPS

Struktura sceny gracza:

```
Player (CharacterBody3D)
├── CollisionShape3D (CapsuleShape3D — h:1.8m, r:0.4m)
├── Head (Node3D — obrót góra/dół)
│   ├── Camera3D              — kamera FPS
│   └── WeaponAnchor (Node3D) — punkt montowania broni
└── InteractionRay (RayCast3D) — 2.5m do przodu
```

---

### 2.3 & 2.6 — Pełny kod kontrolera gracza

Poniżej kompletny przykład GDScript z head bobem i raycasem:

```gdscript
extends CharacterBody3D

# ── Parametry ruchu ──────────────────────────────────────────
const SPEED_WALK    := 4.0
const SPEED_SPRINT  := 7.0
const JUMP_VELOCITY := 4.5
const GRAVITY       := 9.8
const MOUSE_SENS    := 0.002

# ── Head bob ─────────────────────────────────────────────────
const BOB_FREQ   := 2.0    # Hz — częstotliwość kołysania
const BOB_AMP    := 0.06   # metry — amplituda
var   _bob_t     := 0.0    # akumulator czasu

# ── Sprint / stamina ─────────────────────────────────────────
const STAMINA_MAX      := 100.0
const STAMINA_DRAIN    := 20.0   # /s podczas sprintu
const STAMINA_RECOVER  := 10.0   # /s podczas chodzenia
var   _stamina         := STAMINA_MAX
var   _is_sprinting    := false

# ── Referencje ────────────────────────────────────────────────
@onready var _head     : Node3D   = $Head
@onready var _camera   : Camera3D = $Head/Camera3D
@onready var _ray      : RayCast3D = $InteractionRay

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        _rotate_camera(event.relative)
    if event.is_action_pressed("ui_cancel"):
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _rotate_camera(delta: Vector2) -> void:
    rotate_y(-delta.x * MOUSE_SENS)
    _head.rotate_x(-delta.y * MOUSE_SENS)
    # Clamp pitch: -85° … +85°
    _head.rotation.x = clamp(_head.rotation.x,
        deg_to_rad(-85.0), deg_to_rad(85.0))

func _physics_process(delta: float) -> void:
    _apply_gravity(delta)
    _handle_sprint(delta)
    _handle_movement(delta)
    _handle_jump()
    _head_bob(delta)
    move_and_slide()
    _check_interaction()

func _apply_gravity(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= GRAVITY * delta

func _handle_sprint(delta: float) -> void:
    var want_sprint := Input.is_action_pressed("sprint") and _stamina > 0
    _is_sprinting = want_sprint and _get_move_dir().length() > 0.1

    if _is_sprinting:
        _stamina = max(0.0, _stamina - STAMINA_DRAIN * delta)
        _camera.fov = lerp(_camera.fov, 80.0, delta * 8.0)   # FOV kick
    else:
        _stamina = min(STAMINA_MAX, _stamina + STAMINA_RECOVER * delta)
        _camera.fov = lerp(_camera.fov, 70.0, delta * 8.0)

func _handle_movement(delta: float) -> void:
    var dir := _get_move_dir()
    var speed := SPEED_SPRINT if _is_sprinting else SPEED_WALK
    if dir.length() > 0.1:
        velocity.x = dir.x * speed
        velocity.z = dir.z * speed
    else:
        velocity.x = move_toward(velocity.x, 0, speed * delta * 10.0)
        velocity.z = move_toward(velocity.z, 0, speed * delta * 10.0)

func _get_move_dir() -> Vector3:
    var input := Vector2(
        Input.get_axis("move_left", "move_right"),
        Input.get_axis("move_forward", "move_back")
    )
    return (transform.basis * Vector3(input.x, 0, input.y)).normalized()

func _handle_jump() -> void:
    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = JUMP_VELOCITY

func _head_bob(delta: float) -> void:
    var moving := velocity.length() > 0.5 and is_on_floor()
    if moving:
        _bob_t += delta * BOB_FREQ * (1.5 if _is_sprinting else 1.0)
        _head.position.y = sin(_bob_t * TAU) * BOB_AMP
        _head.position.x = cos(_bob_t * PI) * BOB_AMP * 0.5
    else:
        _bob_t = 0.0
        _head.position = _head.position.lerp(Vector3.ZERO, delta * 10.0)

func _check_interaction() -> void:
    if not _ray.is_colliding():
        return
    var obj := _ray.get_collider()
    if obj.has_method("interact") and Input.is_action_just_pressed("interact"):
        obj.interact(self)
```

---

### 2.3 — Ruch po nieplanarnym terenie

Godot `CharacterBody3D` z `move_and_slide()` obsługuje schody i zbocza automatycznie przez:

```gdscript
# W węźle CharacterBody3D (Inspector):
floor_max_angle     = 45°     # max kąt zbocza, po którym można chodzić
floor_snap_length   = 0.3     # "klej" do podłogi — zapobiega lataniu na schodach
wall_min_slide_angle = 15°    # min kąt ściany do slajdowania

# Dla schodów dodaj Shape pomocnicze (Step Shape):
# Niższy capsule + mały box u dołu = gracz „wchodzi" na stopień
```

---

## ✅ Rezultat fazy

- [ ] Gracz porusza się WASD po scenie bez przenikania przez kolizje
- [ ] Kamera obraca się myszą z poprawnym clampem pitch
- [ ] Gracz chodzi po zboczach i wchodzi na schody (max 45°)
- [ ] Sprint działa — widać FOV kick, stamina się wyczerpuje
- [ ] Head bob aktywuje się podczas chodzenia/sprintu
- [ ] Raycast interakcji wykrywa obiekty z metodą `interact()`
- [ ] Kursor myszy jest ukryty/przechwycony podczas gry
