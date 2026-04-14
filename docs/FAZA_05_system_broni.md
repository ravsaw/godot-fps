# Faza 5 — System Broni

> **Cel:** Broń która wygląda, brzmi i zachowuje się satysfakcjonująco.

---

## 📋 Zadania

| # | Zadanie | Trudność | Czas |
|---|---------|----------|------|
| 5.1 | ViewModel broni — osobna kamera | 🟡 | 2–3 dni |
| 5.2 | Weapon sway — inercja | 🟡 | 2–3 dni |
| 5.3 | Head bob synchronizacja z bronią | 🟢 | 1–2 dni |
| 5.4 | Recoil — impuls kamery + recovery + visual recoil | 🔴 | 4–6 dni |
| 5.5 | ADS (Aim Down Sights) — lerp pozycji + zoom FOV | 🟡 | 2–3 dni |
| 5.6 | Animacje broni: idle, walk, sprint, ads, shoot, reload | 🟡 | 1–2 tyg. |
| 5.7 | Raycast strzału — trafienie, obrażenia, decale | 🟡 | 3–4 dni |
| 5.8 | Łuski — cząsteczki z komory nabojowej | 🟢 | 1–2 dni |
| 5.9 | Dźwięk broni — 3D positional audio | 🟡 | 3–4 dni |
| 5.10 | Kondycja broni — degradacja, zacięcia | 🟡 | 3–4 dni |

---

## 🔍 Opis zadań

### 5.1 — ViewModel (osobna kamera broni)

Broń renderowana jest na **osobnej kamerze** — zapobiega to przenikaniu broni przez ściany:

```
Player (CharacterBody3D)
└── Head (Node3D)
    ├── Camera3D (fov=70)           ← kamera świata
    └── WeaponCamera (Camera3D)     ← kamera broni (fov=60, cull_mask tylko Layer 2)
        └── WeaponAnchor (Node3D)   ← punkt montowania broni
            └── Weapon (Node3D)     ← model broni

# Ważne: WeaponCamera.clear_color = transparent, render_priority = 1
# Broń rysowana na wierzchu sceny (depth clear disabled)
```

Konfiguracja w Godot:
- Kamera broni: `Environment.background_mode = BACKGROUND_KEEP` (nie czyści tła)
- Model broni na layerze 2: `MeshInstance3D.layers = 2`
- Kamera główna: `cull_mask` wyklucza layer 2

---

### 5.2 — Weapon Sway (inercja broni)

```gdscript
extends Node3D   # WeaponAnchor

const SWAY_AMOUNT  := 0.04
const SWAY_SMOOTH  := 8.0
const SWAY_MAX     := 0.08

var _target_rotation := Vector3.ZERO

func _process(delta: float) -> void:
    var mouse_vel := _get_mouse_delta()   # z InputEventMouseMotion
    _target_rotation.x = clamp(-mouse_vel.y * SWAY_AMOUNT, -SWAY_MAX, SWAY_MAX)
    _target_rotation.y = clamp(-mouse_vel.x * SWAY_AMOUNT, -SWAY_MAX, SWAY_MAX)
    rotation = rotation.lerp(_target_rotation, delta * SWAY_SMOOTH)
    _target_rotation = _target_rotation.lerp(Vector3.ZERO, delta * SWAY_SMOOTH)
```

---

### 5.4 — Recoil

System recoilu składa się z dwóch warstw: **kamera** (ruch w górę/bok) i **visual recoil** (model broni):

```gdscript
extends Node3D   # WeaponController

# ── Parametry recoilu ──────────────────────────────────────
const RECOIL_UP      := 1.2    # stopnie w górę na strzał
const RECOIL_SIDE    := 0.4    # max odchylenie boczne (losowe)
const RECOIL_VISUAL  := 0.05   # odskok modelu broni (metry)
const RECOVER_SPEED  := 6.0    # szybkość powrotu do zero
const KICK_SPEED     := 40.0   # szybkość impulsu recoilu

var _recoil_target  := Vector3.ZERO   # cel rotacji kamery
var _current_recoil := Vector3.ZERO   # aktualna rotacja

@onready var _head       : Node3D = get_parent().get_parent()
@onready var _weapon_pos : Node3D = $WeaponAnchor

func _process(delta: float) -> void:
    # Interpolacja do celu — impuls
    _current_recoil = _current_recoil.lerp(
        _recoil_target, delta * KICK_SPEED)
    # Decay — powrót do zera
    _recoil_target = _recoil_target.lerp(
        Vector3.ZERO, delta * RECOVER_SPEED)
    # Aplikacja rotacji do głowy gracza
    _head.rotation.x -= _current_recoil.x * delta
    _head.rotation.y -= _current_recoil.y * delta

func apply_recoil() -> void:
    var side := randf_range(-RECOIL_SIDE, RECOIL_SIDE)
    _recoil_target += Vector3(
        deg_to_rad(RECOIL_UP),
        deg_to_rad(side),
        0.0
    )
    # Visual recoil — broń odskakuje do tyłu
    _weapon_pos.position.z = RECOIL_VISUAL
```

---

### 5.5 — ADS (Aim Down Sights)

```gdscript
const ADS_FOV      := 45.0
const NORMAL_FOV   := 70.0
const ADS_POS      := Vector3(0.0, -0.12, -0.25)   # pozycja broni w ADS
const NORMAL_POS   := Vector3(0.15, -0.2, -0.4)

var _is_ads := false

func _process(delta: float) -> void:
    _is_ads = Input.is_action_pressed("ads")
    var target_fov := ADS_FOV if _is_ads else NORMAL_FOV
    var target_pos := ADS_POS if _is_ads else NORMAL_POS

    _camera.fov = lerp(_camera.fov, target_fov, delta * 10.0)
    _weapon_anchor.position = _weapon_anchor.position.lerp(
        target_pos, delta * 12.0)
```

---

### 5.7 — Raycast strzału

```gdscript
func _shoot() -> void:
    if _ammo <= 0 or _is_reloading:
        return

    _ammo -= 1
    apply_recoil()
    _play_shoot_effects()

    # Raycast od centrum ekranu
    var cam    := _head.get_node("Camera3D")
    var origin := cam.global_position
    var dir    := -cam.global_transform.basis.z

    var query := PhysicsRayQueryParameters3D.create(
        origin, origin + dir * 200.0)
    query.exclude = [owner]     # wyklucz gracza
    var hit := get_world_3d().direct_space_state.intersect_ray(query)

    if hit:
        _spawn_decal(hit["position"], hit["normal"])
        if hit["collider"].has_method("take_damage"):
            hit["collider"].take_damage(25, owner)

func _spawn_decal(pos: Vector3, normal: Vector3) -> void:
    var decal : Decal = BULLET_DECAL.instantiate()
    get_tree().root.add_child(decal)
    decal.global_position = pos + normal * 0.01
    decal.look_at(pos - normal)
    # Auto-usuń po 30 sekundach
    get_tree().create_timer(30.0).timeout.connect(decal.queue_free)
```

---

### 5.9 — Dźwięk broni (3D positional audio)

```gdscript
@onready var _audio_shoot  : AudioStreamPlayer3D = $AudioShoot
@onready var _audio_reload : AudioStreamPlayer3D = $AudioReload

# Konfiguracja AudioStreamPlayer3D:
# unit_size: 1.0
# max_distance: 200.0
# attenuation_model: ATTENUATION_INVERSE_SQUARE_DISTANCE
# bus: "SFX"

func _play_shoot_effects() -> void:
    _audio_shoot.pitch_scale = randf_range(0.95, 1.05)  # lekka losowość
    _audio_shoot.play()
```

---

### 5.10 — Kondycja broni

```gdscript
var _durability    := 100.0   # 0–100
var _jam_threshold := 10.0    # < 10% → możliwe zacięcie

func _on_shoot() -> void:
    _durability -= 0.5   # degradacja per strzał
    if _durability < _jam_threshold and randf() < 0.05:
        _trigger_jam()

func _trigger_jam() -> void:
    _is_jammed = true
    # Gracz musi wykonać "clear jam" akcję
    _anim_tree.set("parameters/playback", "clear_jam")

func repair(amount: float) -> void:
    _durability = min(100.0, _durability + amount)
    _is_jammed  = false
```

---

## ✅ Rezultat fazy

- [ ] Broń widoczna przez osobną kamerę — nie przetnika przez ściany
- [ ] Weapon sway reaguje na ruch myszy z inercją
- [ ] Recoil: kamera skacze w górę, powraca płynnie do neutralnej pozycji
- [ ] ADS: broń przesuwa się do oka, FOV zmniejsza się
- [ ] Strzał rejestruje trafienie raycasem i generuje decal
- [ ] Łuski emitowane z komory nabojowej przy strzale
- [ ] Dźwięk strzału zanika z odległością (3D audio)
- [ ] Kondycja maleje z każdym strzałem; zacięcie możliwe przy < 10%
