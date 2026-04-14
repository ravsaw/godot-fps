# Faza 8 — POI i Regiony

> **Cel:** Świat podzielony na sensowne strefy z własną logiką, dynamicznymi spawnami i cyklem dobowym.

---

## 📋 Zadania

| # | Zadanie | Trudność | Czas |
|---|---------|----------|------|
| 8.1 | System regionów — ID, frakcja kontrolująca, zasób strategiczny | 🟡 | 3–4 dni |
| 8.2 | Typy POI — obóz, skrytka, punkt obserwacyjny, ruiny | 🟢 | 2–3 dni |
| 8.3 | Przejścia między mapami — loading, persistent state regionów | 🟡 | 4–6 dni |
| 8.4 | Dynamiczne spawny — NPC pojawiają się logicznie, poza LOS gracza | 🔴 | 4–6 dni |
| 8.5 | Cykl dobowy — wpływ na widoczność, aktywność frakcji, patrole | 🟡 | 3–5 dni |

---

## 🔍 Opis zadań

### 8.1 — System regionów

Każdy region to węzeł sceny z własnymi parametrami:

```gdscript
## SimulationRegion — węzeł umieszczany w scenie świata
class_name SimulationRegion
extends Node3D

@export var region_id           : String  = ""
@export var controlling_faction : String  = "neutral"
@export var strategic_resource  : String  = ""   # "ammo_depot", "medkit_cache", "food_storage"
@export var npc_cap_per_faction : Dictionary = {}  # { "military": 8, "raiders": 5 }

## Symulowane NPC (off-screen) — słowniki zamiast węzłów
var _simulated_npcs : Array[Dictionary] = []

## Historia kontroli — do debug overlay i mapy
var _control_history : Array[Dictionary] = []

func _ready() -> void:
    add_to_group("simulation_region")
    for faction_id in npc_cap_per_faction:
        PopulationManager.register_region(region_id, faction_id,
            npc_cap_per_faction[faction_id])
    WorldEventBus.subscribe("region_control_changed", _on_control_changed)

func change_control(new_faction: String) -> void:
    var old := controlling_faction
    controlling_faction = new_faction
    _control_history.append({
        "from":      old,
        "to":        new_faction,
        "timestamp": Time.get_unix_time_from_system()
    })
    WorldEventBus.publish("region_control_changed",
        global_position, self,
        {
            "region_id":    region_id,
            "old_faction":  old,
            "new_faction":  new_faction,
            "resource":     strategic_resource
        }
    )

func get_faction_strength(faction_id: String) -> float:
    var count := _simulated_npcs.filter(
        func(n): return n["faction"] == faction_id).size()
    var cap   := npc_cap_per_faction.get(faction_id, 1)
    return float(count) / float(cap)

func find_spawn_point_outside_los(player_pos: Vector3, min_dist: float) -> Vector3:
    # Pobierz wszystkie węzły SpawnPoint w regionie
    for sp in get_tree().get_nodes_in_group("spawn_point"):
        if sp.get_parent() != self:
            continue
        var dist := player_pos.distance_to(sp.global_position)
        if dist < min_dist:
            continue
        # Prosty test LOS — raycast od gracza do punktu spawnu
        if not _player_can_see(player_pos, sp.global_position):
            return sp.global_position
    return Vector3.ZERO

func _player_can_see(from: Vector3, to: Vector3) -> bool:
    var space := get_world_3d().direct_space_state
    var query := PhysicsRayQueryParameters3D.create(from, to)
    return get_world_3d().direct_space_state.intersect_ray(query).is_empty() == false
```

---

### 8.2 — Typy POI

| Typ | `task_type` SmartTerrain | Pojemność | Opis |
|-----|--------------------------|-----------|------|
| `camp` | `rest` / `patrol` | 4–8 | Baza frakcji — NPC odpoczywają i patrolują |
| `cache` | `guard` | 1–2 | Skrytka zasobów — wartownik chroni |
| `watchtower` | `patrol` | 1–2 | Punkt obserwacyjny — NPC skanuje okolicę |
| `ruins` | `scavenge` | 2–4 | Ruiny — zbieranie surowców |
| `checkpoint` | `patrol` | 2–3 | Punkt kontrolny na drodze — kontrola przejść |

Każde POI jako scena (`.tscn`) z węzłem `SmartTerrain` i waypointami:

```
POI_Camp (Node3D)
├── SmartTerrain (faction="military", task_type="patrol", capacity=6)
├── Waypoint_A (Node3D)
├── Waypoint_B (Node3D)
├── Waypoint_C (Node3D)
├── SpawnPoint_1 (Node3D) → group: "spawn_point"
├── SpawnPoint_2 (Node3D) → group: "spawn_point"
└── LootContainer (Node3D) → strategiczny zasób regionu
```

---

### 8.3 — Przejścia między mapami

Stan regionów musi przetrwać przejście do innej mapy:

```gdscript
## RegionStateSerializer — zapisuje/wczytuje stan wszystkich regionów
extends Node

const SAVE_PATH := "user://region_states.json"

func save_all_regions() -> void:
    var data := {}
    for region in get_tree().get_nodes_in_group("simulation_region"):
        data[region.region_id] = {
            "controlling_faction": region.controlling_faction,
            "simulated_npcs":      region._simulated_npcs.duplicate(true),
            "control_history":     region._control_history.duplicate(true),
        }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(data))

func load_all_regions() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    var data  = JSON.parse_string(file.get_as_text())
    if not data is Dictionary:
        return
    for region in get_tree().get_nodes_in_group("simulation_region"):
        if not data.has(region.region_id):
            continue
        var state : Dictionary = data[region.region_id]
        region.controlling_faction = state.get("controlling_faction", "neutral")
        region._simulated_npcs     = state.get("simulated_npcs", [])
        region._control_history    = state.get("control_history", [])
```

**Przejście między mapami (loading screen):**
```gdscript
func _change_map(new_scene_path: String) -> void:
    RegionStateSerializer.save_all_regions()
    # Pokaż ekran ładowania
    get_tree().change_scene_to_file("res://scenes/ui/loading_screen.tscn")
    await get_tree().process_frame
    get_tree().change_scene_to_file(new_scene_path)
    await get_tree().node_added   # czekaj na załadowanie sceny
    RegionStateSerializer.load_all_regions()
```

---

### 8.4 — Dynamiczne spawny poza LOS

Spawny uruchamiane przez `PopulationManager` (patrz Faza 7) + dodatkowe wyzwalacze:

```gdscript
## SpawnTrigger — Area3D uruchamiający spawn gdy gracz wchodzi do regionu
class_name SpawnTrigger
extends Area3D

@export var spawn_faction : String = ""
@export var spawn_count   : int    = 3

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
    if not body.is_in_group("player"):
        return
    # Spawniaj NPC "za plecami" gracza lub po bokach
    var behind := -body.global_transform.basis.z * 60.0
    var offsets := [
        behind + Vector3(20, 0, 0),
        behind + Vector3(-20, 0, 0),
        behind,
    ]
    for i in min(spawn_count, offsets.size()):
        var pos := global_position + offsets[i]
        # Znajdź najbliższy punkt na NavMesh
        var closest_nav_point := NavigationServer3D.map_get_closest_point(
            get_world_3d().navigation_map, pos)
        if closest_nav_point != Vector3.ZERO:
            PopulationManager._spawn_npc(spawn_faction, closest_nav_point, _get_region_id())
    queue_free()   # trigger jednorazowy
```

---

### 8.5 — Cykl Dobowy

```gdscript
## DayNightCycle — autoload
extends Node

const DAY_DURATION  := 1200.0   # sekundy = 20 minut realnego czasu = 24h w grze
const DAWN_HOUR     := 6.0
const DUSK_HOUR     := 20.0

var _time_of_day    := 10.0   # godzina 0–24, start o 10:00
var _time_scale     := 24.0 / DAY_DURATION

signal hour_changed(new_hour: float)
signal day_phase_changed(phase: String)   # "day", "night", "dawn", "dusk"

@onready var _sun       : DirectionalLight3D = $Sun
@onready var _env       : WorldEnvironment   = $WorldEnvironment

func _process(delta: float) -> void:
    var old_hour := _time_of_day
    _time_of_day  = fmod(_time_of_day + delta * _time_scale, 24.0)

    if int(old_hour) != int(_time_of_day):
        hour_changed.emit(_time_of_day)

    _update_sun()
    _update_sky()

func _update_sun() -> void:
    # Słońce obraca się 360° przez 24h
    var angle := (_time_of_day / 24.0) * TAU - PI * 0.5
    _sun.rotation.x = angle
    # Intensywność — 0 w nocy, 1.5 w południe
    var intensity := max(0.0, sin(angle + PI * 0.5))
    _sun.light_energy = intensity * 1.5

func _update_sky() -> void:
    var sky := _env.environment.sky.sky_material as ProceduralSkyMaterial
    if not sky:
        return
    var t := _time_of_day / 24.0
    # Prosta interpolacja kolorów: noc (ciemny granat) → świt (pomarańcz) → dzień (błękit) → zmierzch
    sky.sky_top_color    = _sky_color(t)
    sky.sky_horizon_color = _horizon_color(t)

func _sky_color(t: float) -> Color:
    # Uproszczone — do rozbudowania
    if t < 0.25:   return Color(0.05, 0.05, 0.15)   # noc
    elif t < 0.3:  return Color(0.8, 0.4, 0.1)       # świt
    elif t < 0.75: return Color(0.3, 0.6, 1.0)        # dzień
    elif t < 0.85: return Color(0.9, 0.3, 0.05)       # zmierzch
    else:          return Color(0.05, 0.05, 0.15)     # noc

func is_night() -> bool:
    return _time_of_day < DAWN_HOUR or _time_of_day >= DUSK_HOUR

func get_visibility_factor() -> float:
    ## 0.0 = ciemno, 1.0 = pełna widoczność
    if is_night():
        return 0.25   # latarki wymagane
    return 1.0
```

**Wpływ pory dnia na AI:**
```gdscript
## W NPCPerception — modyfikuj zasięg widzenia przez czas
func get_effective_sight_range() -> float:
    var base    := SIGHT_RANGE
    var vis_mod := DayNightCycle.get_visibility_factor()
    return base * vis_mod   # w nocy widzą 4x krócej

## W PopulationManager — frakcje aktywne w nocy vs w dzień
func _get_active_factions_at_hour(hour: float) -> Array[String]:
    if hour < 6.0 or hour >= 22.0:
        return ["raiders"]          # najeźdźcy aktywni w nocy
    return ["military", "traders", "scavengers"]
```

---

## ✅ Rezultat fazy

- [ ] Każdy region ma ID, frakcję kontrolującą i zasób strategiczny
- [ ] POI (obozy, skrytki, wieżyczki, ruiny) rozmieszczone w scenie jako SmartTerrain
- [ ] Stan regionów zapisuje się i ładuje między zmianami map
- [ ] Dynamiczne spawny — NPC pojawiają się wyłącznie poza LOS gracza
- [ ] Cykl dobowy: słońce wschodzi i zachodzi co 20 minut realnego czasu
- [ ] AI modyfikuje zasięg widzenia i aktywność zależnie od pory dnia
- [ ] Zmiana kontroli regionu emituje event i aktualizuje mapę
