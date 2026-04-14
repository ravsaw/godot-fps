# Faza 6 — AI Bazowa

> **Cel:** NPC który widzi, słyszy i reaguje — fundament pod symulację świata.

---

## 📋 Zadania

| # | Zadanie | Trudność | Czas |
|---|---------|----------|------|
| 6.1 | State Machine: Idle → Patrol → Alert → Combat → Retreat → Dead | 🟡 | 3–5 dni |
| 6.2 | Line of Sight — raycast + kąt FOV + zasięg | 🟡 | 3–4 dni |
| 6.3 | Hearing system — noise eventy z zasięgiem | 🟡 | 2–3 dni |
| 6.4 | Patrol między waypoints | 🟢 | 2–3 dni |
| 6.5 | Combat AI — strzelanie, osłona, dystans | 🔴 | 1–2 tyg. |
| 6.6 | Squad system — koordynacja grupy, flankowanie | 🔴 | 1–2 tyg. |
| 6.7 | Reakcje na śmierć sojusznika | 🟡 | 3–4 dni |

---

## 🔍 Opis zadań

### 6.1 — State Machine

Stany NPC tworzą maszynę stanów z przejściami opartymi na percepcji:

```
         ┌─────────────────────────────────────┐
         │                                     ↓
[IDLE] ──→ [PATROL] ──→ [ALERT] ──→ [COMBAT] ──→ [RETREAT]
              ↑              │                        │
              └──────────────┘                        │
                  (zagrożenie                  ↓
                   minęło)               [DEAD] (terminal)
```

```gdscript
class_name NPCStateMachine
extends Node

enum State { IDLE, PATROL, ALERT, COMBAT, RETREAT, DEAD }

var current_state : State = State.IDLE
var _npc          : CharacterBody3D

signal state_changed(old_state: State, new_state: State)

func _ready() -> void:
    _npc = get_parent()

func transition_to(new_state: State) -> void:
    if new_state == current_state:
        return
    var old := current_state
    _exit_state(old)
    current_state = new_state
    _enter_state(new_state)
    state_changed.emit(old, new_state)

func _enter_state(state: State) -> void:
    match state:
        State.IDLE:
            _npc.stop_movement()
        State.PATROL:
            _npc.start_patrol()
        State.ALERT:
            _npc.investigate_last_known_position()
        State.COMBAT:
            _npc.engage_target()
        State.RETREAT:
            _npc.find_cover()
        State.DEAD:
            _npc.die()

func _exit_state(state: State) -> void:
    match state:
        State.COMBAT:
            _npc.stop_shooting()
```

---

### 6.2 — Line of Sight

Percepcja wzrokowa NPC: trzy warunki muszą być spełnione jednocześnie:
1. Cel w zasięgu (odległość)
2. Cel w stożku FOV
3. Brak przeszkód (raycast)

```gdscript
extends Node   # NPCPerception

const SIGHT_RANGE  := 30.0    # metry
const SIGHT_FOV    := 90.0    # stopnie (połowa kąta = 45° na stronę)
const CHECK_RATE   := 0.15    # sekundy między sprawdzeniami

@onready var _npc : CharacterBody3D = get_parent()
var _check_timer  := 0.0

func _process(delta: float) -> void:
    _check_timer -= delta
    if _check_timer > 0.0:
        return
    _check_timer = CHECK_RATE
    _update_sight()

func can_see(target: Node3D) -> bool:
    var to_target := target.global_position - _npc.global_position
    var distance  := to_target.length()

    # 1. Zasięg
    if distance > SIGHT_RANGE:
        return false

    # 2. Kąt FOV
    var forward    := -_npc.global_transform.basis.z
    var angle      := rad_to_deg(forward.angle_to(to_target.normalized()))
    if angle > SIGHT_FOV * 0.5:
        return false

    # 3. Raycast — czy nic nie blokuje widoku
    var space    := _npc.get_world_3d().direct_space_state
    var query    := PhysicsRayQueryParameters3D.create(
        _npc.global_position + Vector3.UP * 1.6,
        target.global_position + Vector3.UP * 1.0
    )
    query.exclude = [_npc]
    var result   := space.intersect_ray(query)
    return result.is_empty() or result["collider"] == target

func _update_sight() -> void:
    var player := get_tree().get_first_node_in_group("player")
    if player and can_see(player):
        _npc.get_node("StateMachine").transition_to(
            NPCStateMachine.State.COMBAT)
```

---

### 6.3 — Hearing System

Dźwięki emitują „noise eventy" — NPC w zasięgu reagują:

```gdscript
## Globalna klasa — autoload "NoiseSystem"
class_name NoiseSystem
extends Node

signal noise_emitted(position: Vector3, range: float, source: Node)

## Wywoływane przez gracza, broń, eksplozje — cokolwiek wydaje dźwięk
static func emit(position: Vector3, range: float, source: Node = null) -> void:
    NoiseSystem._instance.noise_emitted.emit(position, range, source)

var _instance : NoiseSystem   # ustawiane w _ready()

func _ready() -> void:
    _instance = self
```

Rejestracja NPC do nasłuchiwania:
```gdscript
## W NPCPerception
func _ready() -> void:
    NoiseSystem.noise_emitted.connect(_on_noise)

func _on_noise(position: Vector3, range: float, source: Node) -> void:
    var dist := _npc.global_position.distance_to(position)
    if dist > range:
        return
    if source == _npc:   # własny dźwięk — ignoruj
        return
    # Przejdź do ALERT jeśli nie walczysz
    var sm := _npc.get_node("StateMachine")
    if sm.current_state in [NPCStateMachine.State.IDLE,
                             NPCStateMachine.State.PATROL]:
        _npc.last_known_noise_position = position
        sm.transition_to(NPCStateMachine.State.ALERT)
```

---

### 6.4 — Patrol między Waypoints

```gdscript
extends Node   # NPCPatrol

@export var waypoints : Array[NodePath] = []
var _waypoint_nodes   : Array[Node3D]   = []
var _current_idx      : int             = 0

func _ready() -> void:
    for path in waypoints:
        _waypoint_nodes.append(get_node(path))

func get_next_waypoint() -> Vector3:
    if _waypoint_nodes.is_empty():
        return get_parent().global_position
    var wp := _waypoint_nodes[_current_idx]
    _current_idx = (_current_idx + 1) % _waypoint_nodes.size()
    return wp.global_position
```

---

### 6.5 — Combat AI

Zachowanie w walce:
1. **Strzelanie:** jeśli gracz widoczny → strzelaj co `fire_rate` sekund
2. **Osłona:** jeśli zdrowie < 30% → szukaj najbliższego `CoverPoint`
3. **Dystans:** NPC stara się trzymać 8–15m od celu (nie podchodzi za blisko)

```gdscript
## Uproszczony fragment logiki walki
func _combat_tick(delta: float) -> void:
    if not _perception.can_see(_target):
        _last_known_pos = _target.global_position
        _state_machine.transition_to(NPCStateMachine.State.ALERT)
        return

    var dist := global_position.distance_to(_target.global_position)

    match _combat_phase:
        "engage":
            if dist > 15.0:
                move_to(_target.global_position)
            elif dist < 8.0:
                _strafe_away_from_target()
            _try_shoot(delta)
        "seek_cover":
            var cover := _find_nearest_cover()
            if cover:
                move_to(cover)
```

---

### 6.6 — Squad System

Koordynacja grupy przez wspólny blackboard:

```gdscript
## Autoload: SquadManager
class_name SquadManager
extends Node

var squads : Dictionary = {}   # squad_id → { leader, members, target, orders }

func register_npc(npc: CharacterBody3D, squad_id: String) -> void:
    if not squads.has(squad_id):
        squads[squad_id] = { "members": [], "target": null, "order": "idle" }
    squads[squad_id]["members"].append(npc)

func issue_order(squad_id: String, order: String, target = null) -> void:
    if not squads.has(squad_id):
        return
    squads[squad_id]["order"] = order
    squads[squad_id]["target"] = target
    for member in squads[squad_id]["members"]:
        member.receive_squad_order(order, target)

## Flankowanie:
func flank(squad_id: String, target: Node3D) -> void:
    var members : Array = squads[squad_id]["members"]
    var angles  := [0.0, 90.0, -90.0, 180.0]
    for i in members.size():
        var angle := deg_to_rad(angles[i % angles.size()])
        var offset := Vector3(sin(angle), 0, cos(angle)) * 8.0
        members[i].move_to(target.global_position + offset)
```

---

### 6.7 — Reakcje na śmierć sojusznika

```gdscript
## NoiseSystem.emit(dead_npc.global_position, 25.0) przy śmierci

func _on_ally_died(position: Vector3) -> void:
    match _state_machine.current_state:
        NPCStateMachine.State.IDLE, NPCStateMachine.State.PATROL:
            _morale -= 20
            if _morale < 30:
                _state_machine.transition_to(NPCStateMachine.State.RETREAT)
            else:
                _last_known_noise_position = position
                _state_machine.transition_to(NPCStateMachine.State.ALERT)
```

---

## ✅ Rezultat fazy

- [ ] NPC przechodzi przez stany: Idle → Patrol → Alert → Combat → Retreat → Dead
- [ ] Line of Sight działa poprawnie z kątem FOV i raycasem
- [ ] Dźwięk gracza alarmuje pobliskich NPC
- [ ] Patrol po waypointach działa na terenie nieplanarnym
- [ ] Combat AI strzela, szuka osłony, trzyma dystans
- [ ] Oddział (squad) koordynuje flankowanie
- [ ] Śmierć sojusznika wpływa na morale grupy
