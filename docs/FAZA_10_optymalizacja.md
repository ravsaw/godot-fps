# Faza 10 — Optymalizacja

> **Cel:** Gra działa stabilnie przez wiele godzin z dużą liczbą aktywnych NPC, bez wycieków pamięci ani dryftu symulacji.

---

## 📋 Zadania

| # | Zadanie | Trudność | Czas |
|---|---------|----------|------|
| 10.1 | Profiling renderingu — GPU Profiler w Godot | 🟡 | 3–4 dni |
| 10.2 | Profiling symulacji świata — event bus, task queue, off-screen resolver | 🟡 | 3–4 dni |
| 10.3 | LOD system globalny — geometria i dźwięk maleją z odległością | 🟡 | 4–6 dni |
| 10.4 | Testy długich sesji (8h+) — wycieki pamięci, dryft symulacji | 🔴 | 1–2 tyg. |
| 10.5 | Save/Load stanu świata — frakcje, NPC, ekwipunek, pora dnia | 🔴 | 1–2 tyg. |

---

## 🔍 Opis zadań

### 10.1 — Profiling Renderingu

**Narzędzia Godot:**
- `Debug → Profiler` — CPU/GPU czas klatek
- `Debug → Monitor` — FPS, VRAM, draw calls, triangles
- `Rendering → Debug → Wireframe` — weryfikacja LOD

**Cele wydajności (mid-range GPU — GTX 1060 / RX 580):**

| Metryka | Cel | Alarm |
|---------|-----|-------|
| FPS | ≥ 60 | < 45 |
| Frame time | ≤ 16.7 ms | > 22 ms |
| Draw calls | ≤ 300 | > 600 |
| Triangles | ≤ 500k | > 1M |
| VRAM | ≤ 1.5 GB | > 2 GB |

**Optymalizacje renderingu:**
```gdscript
# Project Settings → Rendering:
# - shadows/directional/soft_shadow_quality: Hard (wzrost FPS)
# - reflections/sky_reflections/roughness_layers: 4 (było 7)
# - gi/use_half_resolution: true (GI w połowie rozdzielczości)
# - occlusion_culling/occlusion_rays_per_frame: 512 (domyślnie 512 — sprawdź)
```

**Batching statycznej geometrii:**
```gdscript
## Łączenie statycznych meshy w jeden draw call
var rock_scene   := preload("res://assets/models/rock_low.glb")
var rock_meshes  := rock_scene.meshes if "meshes" in rock_scene else []
if rock_meshes.is_empty():
    push_error("rock_low.glb nie zawiera żadnego mesha")
    return
var multi_mesh := MultiMesh.new()
multi_mesh.mesh          = rock_meshes[0]
multi_mesh.instance_count = rocks.size()
for i in rocks.size():
    multi_mesh.set_instance_transform(i, rocks[i].global_transform)

var mmi := MultiMeshInstance3D.new()
mmi.multimesh = multi_mesh
get_parent().add_child(mmi)
# Usuń oryginalne węzły
for rock in rocks:
    rock.queue_free()
```

---

### 10.2 — Profiling Symulacji Świata

Monitoruj czas CPU poświęcany na symulację:

```gdscript
## WorldSimulation — dodaj pomiar czasu
func _process(delta: float) -> void:
    var t0 := Time.get_ticks_usec()

    _tick_offscreen_resolver(delta)
    _tick_population_manager(delta)
    _tick_task_queues(delta)

    var elapsed_us := Time.get_ticks_usec() - t0
    if elapsed_us > 2000:   # > 2ms to alarm
        push_warning("WorldSimulation tick: %.2f ms" % (elapsed_us / 1000.0))
    DebugOverlay.record_sim_time(elapsed_us)
```

**Optymalizacje symulacji:**

| Problem | Rozwiązanie |
|---------|-------------|
| Zbyt wiele eventów per klatkę | Rate limiting w `WorldEventBus` (już zaimplementowane) |
| Task queue sprawdzana co klatkę | Sprawdzaj tylko NPC w promieniu 100m od gracza |
| Off-screen resolver za częsty | Zwiększ `TICK_RATE` do 10s gdy > 200 NPC |
| Pathfinding NPC co klatkę | Używaj `NavigationAgent3D.target_desired_distance = 1.5` — rzadsze update'y |

```gdscript
## Priorytetyzacja task queue — tylko bliscy NPC
const TASK_UPDATE_RADIUS := 100.0

func _tick_task_queues(delta: float) -> void:
    var player_pos := _get_player_position()
    for npc in get_tree().get_nodes_in_group("npc"):
        # Dalej niż 100m — pomiń task update tej klatki
        if npc.global_position.distance_to(player_pos) > TASK_UPDATE_RADIUS:
            continue
        var tq := npc.get_node_or_null("TaskQueue") as TaskQueue
        if tq:
            tq._process(delta)   # ręczne wywołanie — wyłącz _process() w TaskQueue
```

---

### 10.3 — LOD System Globalny

**Geometria (Godot wbudowany LOD):**
```gdscript
## W każdym MeshInstance3D NPC:
mesh_instance.lod_bias                    = 1.0
mesh_instance.visibility_range_begin      = 0.0
mesh_instance.visibility_range_end        = 80.0
mesh_instance.visibility_range_end_margin = 15.0   # fade
mesh_instance.visibility_range_fade_mode  = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
```

**Dźwięk z odległością:**
```gdscript
## AudioStreamPlayer3D — ustawienia w Inspector:
# max_distance: 60.0
# unit_size: 10.0
# attenuation_model: ATTENUATION_LOGARITHMIC
# bus: "SFX"

## Globalne — wyłącz dźwięki NPC > 60m
for audio in get_tree().get_nodes_in_group("npc_audio"):
    var dist := audio.global_position.distance_to(player_pos)
    audio.stream_paused = dist > 60.0
```

**Kolizje z odległością:**
```gdscript
## Wyłącz Foot IK i szczegółowe kolizje dla odległych NPC
for npc in get_tree().get_nodes_in_group("npc"):
    var dist := npc.global_position.distance_to(player_pos)
    var ik_l := npc.get_node_or_null("MeshInstance3D/Skeleton3D/IK_FootLeft")
    var ik_r := npc.get_node_or_null("MeshInstance3D/Skeleton3D/IK_FootRight")
    if ik_l: ik_l.enabled = dist < 15.0
    if ik_r: ik_r.enabled = dist < 15.0
```

---

### 10.4 — Testy Długich Sesji

Procedura testu:

```
1. Uruchom grę z 80 aktywnymi NPC w scenie testowej
2. Włącz zapis metryk co 60 sekund do pliku CSV
3. Pozostaw grę przez 8 godzin (overnight)
4. Analiza CSV: FPS, RAM, VRAM, liczba węzłów, czas tick symulacji
```

```gdscript
## MetricsLogger — autoload dla testów długich sesji
extends Node

const LOG_INTERVAL := 60.0
const LOG_PATH     := "user://session_metrics.csv"

var _timer    := 0.0
var _log_file : FileAccess = null

func _ready() -> void:
    if OS.has_feature("debug"):
        _log_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
        _log_file.store_line("time_s,fps,ram_mb,vram_mb,node_count,npc_count,sim_ms")

func _process(delta: float) -> void:
    if not _log_file:
        return
    _timer += delta
    if _timer < LOG_INTERVAL:
        return
    _timer = 0.0

    var fps       := Engine.get_frames_per_second()
    var ram_mb    := OS.get_static_memory_usage() / 1024.0 / 1024.0
    var vram_mb   := RenderingServer.get_rendering_info(
        RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1024.0 / 1024.0
    var nodes     := get_tree().get_node_count()
    var npcs      := get_tree().get_nodes_in_group("npc").size()
    var sim_ms    := DebugOverlay.get_last_sim_time_ms()

    _log_file.store_line("%d,%.1f,%.1f,%.1f,%d,%d,%.2f" % [
        int(Time.get_unix_time_from_system()),
        fps, ram_mb, vram_mb, nodes, npcs, sim_ms])
```

**Czego szukać w wynikach:**

| Problem | Symptom w CSV |
|---------|---------------|
| Wyciek pamięci | RAM rośnie o > 50 MB/h |
| Wyciek węzłów | `node_count` rośnie bez zatrzymania |
| Dryft symulacji | `npc_count` spada do 0 (bug populacji) |
| Degradacja FPS | FPS spada > 10% po 4h |

---

### 10.5 — Save / Load Stanu Świata

Pełny save łączy stan wszystkich subsystemów:

```gdscript
## SaveManager — autoload
extends Node

const SAVE_PATH := "user://save_game.json"

func save_game() -> void:
    var data := {
        "version":     "1.0",
        "timestamp":   Time.get_unix_time_from_system(),
        "day_time":    DayNightCycle._time_of_day,
        "player":      _save_player(),
        "regions":     _save_regions(),
        "factions":    _save_factions(),
        "world_events": WorldEventBus.get_recent_events(100),
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(data, "\t"))
    print("Gra zapisana.")

func load_game() -> bool:
    if not FileAccess.file_exists(SAVE_PATH):
        return false
    var file   := FileAccess.open(SAVE_PATH, FileAccess.READ)
    var data    = JSON.parse_string(file.get_as_text())
    if not data is Dictionary:
        return false

    DayNightCycle._time_of_day = data.get("day_time", 10.0)
    _load_player(data.get("player", {}))
    _load_regions(data.get("regions", {}))
    _load_factions(data.get("factions", {}))
    return true

func _save_player() -> Dictionary:
    var player := get_tree().get_first_node_in_group("player")
    return {
        "position":  var_to_str(player.global_position),
        "rotation":  var_to_str(player.rotation),
        "health":    player.health,
        "inventory": player.get_node("Inventory").serialize(),
    }

func _save_regions() -> Dictionary:
    var result := {}
    for region in get_tree().get_nodes_in_group("simulation_region"):
        result[region.region_id] = {
            "controlling_faction": region.controlling_faction,
            "simulated_npcs":      region._simulated_npcs.duplicate(true),
        }
    return result

func _save_factions() -> Dictionary:
    return {
        "relations":  FactionManager._relations.duplicate(true),
        "resources":  FactionManager._faction_resources.duplicate(true),
    }

func _load_player(data: Dictionary) -> void:
    var player := get_tree().get_first_node_in_group("player")
    player.global_position = str_to_var(data.get("position", "Vector3(0,0,0)"))
    player.rotation        = str_to_var(data.get("rotation", "Vector3(0,0,0)"))
    player.health          = data.get("health", 100.0)
    player.get_node("Inventory").deserialize(data.get("inventory", {}))

func _load_regions(data: Dictionary) -> void:
    for region in get_tree().get_nodes_in_group("simulation_region"):
        if not data.has(region.region_id):
            continue
        var s : Dictionary = data[region.region_id]
        region.controlling_faction = s.get("controlling_faction", "neutral")
        region._simulated_npcs     = s.get("simulated_npcs", [])

func _load_factions(data: Dictionary) -> void:
    FactionManager._relations        = data.get("relations", {})
    FactionManager._faction_resources = data.get("resources", {})
```

---

## ✅ Rezultat fazy

- [ ] GPU Profiler: draw calls ≤ 300, triangles ≤ 500k przy 60 FPS
- [ ] CPU symulacji: tick ≤ 2ms przy 80 NPC
- [ ] LOD geometrii działa — widać zmianę liczby trójkątów w monitorze
- [ ] Dźwięki NPC wyłączane > 60m — brak narzutu CPU/audio
- [ ] Foot IK wyłączane dla NPC > 15m
- [ ] Test 8h: RAM stabilny (wzrost < 50 MB/h), FPS bez degradacji
- [ ] Test 8h: `node_count` stabilny — brak wycieków węzłów
- [ ] Save/Load: pełny stan świata (frakcje, regiony, gracz, pora dnia) zapisuje się i ładuje poprawnie
- [ ] Załadowany save: symulacja kontynuuje od miejsca zapisu bez resetu populacji
