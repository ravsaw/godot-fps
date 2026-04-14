# Faza 7 — Symulacja Świata

> **Cel:** Żyjący świat symulowany niezależnie od gracza, oparty na eventach — każde zdarzenie ma przyczynę, każdy NPC ma zadanie, każda frakcja ma cel.

---

## 📋 Zadania

| # | Zadanie | Trudność | Czas |
|---|---------|----------|------|
| 7.1 | WorldEventBus w C++ GDExtension — publish/subscribe, rate limiting, autoload | 🔴 | 4–6 dni |
| 7.2 | PopulationManager — liczba NPC per frakcja per region, respawn poza LOS | 🔴 | 4–6 dni |
| 7.3 | Task system — kolejka zadań NPC (patrol, raid, defend, rest, trade) | 🟡 | 4–6 dni |
| 7.4 | Smart Terrain nodes — punkty przyciągania NPC (obóz, skrytka, punkt obserwacyjny) | 🟡 | 3–4 dni |
| 7.5 | Symulacja off-screen — resolver walki dla nieaktywnych regionów | 🔴 | 1–2 tyg. |
| 7.6 | System frakcji — relacje, dynamiczne zmiany, kontrola regionów | 🟡 | 4–6 dni |
| 7.7 | Migracje NPC — przemieszczanie między regionami po logicznych ścieżkach | 🟡 | 3–4 dni |
| 7.8 | Corpse cleanup — usuwanie zwłok po czasie, persistent loot | 🟢 | 2–3 dni |
| 7.9 | Inwentarze NPC — prawdziwe zasoby, handel oparty na realnych potrzebach | 🟡 | 4–6 dni |
| 7.10 | Debug overlay — wizualizacja eventów, populacji, historii decyzji | 🟡 | 3–4 dni |

---

## ��️ Architektura systemu

### Zasady projektowe

| Zasada | Opis |
|--------|------|
| **Zero fake teleportacji** | Wszystko porusza się prawdziwymi ścieżkami NavMesh — nikt nie "pojawia się" w miejscu |
| **Zero fake aktywności** | Żadne zdarzenie nie dzieje się "dla show" — wszystko ma logiczną przyczynę |
| **Wszystko ma przyczynę** | Każde zdarzenie jest reakcją na inne zdarzenie — brak losowych eventów bez kontekstu |
| **Event-driven** | Zamiast pollingu co klatkę, eventy triggerują reakcje asynchronicznie |
| **Token bucket rate limiting** | Kontrola częstotliwości eventów per region — CPU nie jest przeciążane przez burst |
| **Symulacja off-screen** | Świat żyje gdy gracza nie ma w pobliżu — resolver dla nieaktywnych regionów |
| **Pełna obserwowalność** | Debug overlay pokazuje historię decyzji, populację, aktywne eventy |
| **Persistent loot** | Ekwipunek martwego NPC zostaje w świecie — brak magicznych zniknięć |
| **Logiczne spawny** | NPC pojawiają się tylko poza zasięgiem wzroku gracza, w logicznych punktach |

---

### Diagram zależności modułów

```
┌─────────────────────────────────────────────────────────────────┐
│                        WorldSimulation                          │
│  (autoload — koordynuje wszystkie subsystemy)                   │
└───────────────────────────────┬─────────────────────────────────┘
                                │
        ┌───────────────────────┼────────────────────────┐
        ↓                       ↓                        ↓
┌───────────────┐    ┌─────────────────────┐   ┌─────────────────┐
│ WorldEventBus │    │  PopulationManager  │   │  FactionManager │
│   (C++ GDE)   │    │  (respawn, caps)    │   │ (relacje, ctrl) │
└───────┬───────┘    └─────────┬───────────┘   └────────┬────────┘
        │                      │                        │
        │             ┌────────┴────────┐               │
        │             ↓                 ↓               │
        │    ┌──────────────┐  ┌──────────────────┐     │
        │    │  TaskManager │  │ SmartTerrainMgr  │     │
        │    │ (job queue)  │  │ (obozy, POI)     │     │
        │    └──────────────┘  └──────────────────┘     │
        │                                               │
        └─────────────────────────────────────────┐     │
                                                  ↓     ↓
                                        ┌──────────────────────┐
                                        │   OffscreenResolver  │
                                        │  (walki off-screen)  │
                                        └──────────────────────┘
```

---

## 7.1 — WorldEventBus (C++ GDExtension)

### Nagłówek `world_event_bus.h`

```cpp
#pragma once
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <unordered_map>
#include <vector>
#include <deque>

namespace godot {

struct WorldEvent {
    String     type;
    Vector3    position;
    Variant    source;
    Dictionary data;
    double     timestamp;
    String     region_id;
};

struct TokenBucket {
    double tokens;
    double capacity;
    double refill_rate;
    double last_refill;
};

class WorldEventBus : public Node {
    GDCLASS(WorldEventBus, Node)

public:
    static WorldEventBus* get_singleton();

    void   publish(const String& type, const Vector3& pos,
                   const Variant& source, const Dictionary& data);
    void   subscribe(const String& type, const Callable& callback);
    void   unsubscribe(const String& type, const Callable& callback);
    void   set_rate_limit(const String& type,
                          double capacity, double refill_rate);
    Array  get_recent_events(int count) const;
    Array  get_events_in_region(const String& region_id, int count) const;

    void _process(double delta) override;

protected:
    static void _bind_methods();

private:
    static WorldEventBus* _singleton;
    static constexpr size_t HISTORY_MAX        = 1000;
    static constexpr int    DISPATCH_PER_FRAME = 30;

    std::unordered_map<std::string, std::vector<Callable>> _subscribers;
    std::unordered_map<std::string, TokenBucket>           _rate_limits;
    std::deque<WorldEvent>                                 _event_history;
    std::vector<WorldEvent>                                _pending_events;

    bool _consume_token(const String& type);
    void _dispatch_pending();
};

} // namespace godot
```

### Implementacja `world_event_bus.cpp` (fragment)

```cpp
void WorldEventBus::publish(
    const String& type, const Vector3& pos,
    const Variant& source, const Dictionary& data)
{
    if (!_consume_token(type)) return;   // rate limit odrzuca burst

    WorldEvent ev;
    ev.type      = type;
    ev.position  = pos;
    ev.source    = source;
    ev.data      = data;
    ev.timestamp = Time::get_singleton()->get_unix_time_from_system();
    ev.region_id = data.get("region_id", String(""));
    _pending_events.push_back(ev);
}

bool WorldEventBus::_consume_token(const String& type) {
    auto key = type.utf8().get_data();
    auto it  = _rate_limits.find(key);
    if (it == _rate_limits.end()) return true;

    auto& b   = it->second;
    double now = Time::get_singleton()->get_unix_time_from_system();
    b.tokens  = std::min(b.capacity,
        b.tokens + b.refill_rate * (now - b.last_refill));
    b.last_refill = now;

    if (b.tokens < 1.0) return false;
    b.tokens -= 1.0;
    return true;
}

void WorldEventBus::_dispatch_pending() {
    int dispatched = 0;
    std::vector<WorldEvent> remaining;

    for (auto& ev : _pending_events) {
        if (dispatched >= DISPATCH_PER_FRAME) {
            remaining.push_back(ev);
            continue;
        }
        auto key = ev.type.utf8().get_data();
        auto it  = _subscribers.find(key);
        if (it != _subscribers.end()) {
            Dictionary payload;
            payload["type"]      = ev.type;
            payload["position"]  = ev.position;
            payload["source"]    = ev.source;
            payload["data"]      = ev.data;
            payload["region_id"] = ev.region_id;
            for (auto& cb : it->second) cb.call(payload);
        }
        _event_history.push_back(ev);
        if (_event_history.size() > HISTORY_MAX)
            _event_history.pop_front();
        ++dispatched;
    }
    _pending_events = remaining;
}
```

---

## 7.2 — PopulationManager

Inspiracja: mechanizm zarządzania populacją znany z zaawansowanych modów symulacyjnych — każda frakcja ma przydzielony limit NPC per region, system respawnuje brakujące jednostki poza LOS gracza.

```gdscript
## Autoload: PopulationManager
extends Node

## Definicja limitu per frakcja per region
## Klucz: "region_id:faction_id" → { cap, current, respawn_cooldown }
var _population : Dictionary = {}

const CHECK_INTERVAL    := 10.0   # sekund
const RESPAWN_DELAY     := 30.0   # min. czas od śmierci do respawnu
const SPAWN_PLAYER_DIST := 80.0   # min. odległość od gracza do spawnu

var _check_timer := 0.0

func _process(delta: float) -> void:
    _check_timer -= delta
    if _check_timer > 0.0:
        return
    _check_timer = CHECK_INTERVAL
    _check_all_regions()

func register_region(region_id: String, faction_id: String, cap: int) -> void:
    var key := "%s:%s" % [region_id, faction_id]
    _population[key] = {
        "cap":              cap,
        "current":          0,
        "last_death_time":  -RESPAWN_DELAY,
        "region":           region_id,
        "faction":          faction_id
    }

func on_npc_spawned(region_id: String, faction_id: String) -> void:
    var key := "%s:%s" % [region_id, faction_id]
    if _population.has(key):
        _population[key]["current"] += 1

func on_npc_died(region_id: String, faction_id: String) -> void:
    var key := "%s:%s" % [region_id, faction_id]
    if _population.has(key):
        _population[key]["current"]          = max(0, _population[key]["current"] - 1)
        _population[key]["last_death_time"]  = Time.get_unix_time_from_system()

func _check_all_regions() -> void:
    var player_pos := _get_player_position()
    var now        := Time.get_unix_time_from_system()

    for key in _population:
        var entry  : Dictionary = _population[key]
        var deficit : int = entry["cap"] - entry["current"]
        if deficit <= 0:
            continue
        # Cooldown po śmierci
        if now - entry["last_death_time"] < RESPAWN_DELAY:
            continue
        var region := _get_region(entry["region"])
        if not region:
            continue
        # Znajdź punkt spawnu poza LOS gracza
        var spawn_pos := region.find_spawn_point_outside_los(
            player_pos, SPAWN_PLAYER_DIST)
        if spawn_pos == Vector3.ZERO:
            continue
        _spawn_npc(entry["faction"], spawn_pos, entry["region"])

func _spawn_npc(faction_id: String, pos: Vector3, region_id: String) -> void:
    var scene := FactionManager.get_npc_scene(faction_id)
    var npc   : CharacterBody3D = scene.instantiate()
    get_tree().root.add_child(npc)
    npc.global_position = pos
    npc.faction_id      = faction_id
    npc.region_id       = region_id
    on_npc_spawned(region_id, faction_id)
    WorldEventBus.publish("npc_spawned", pos, npc,
        { "faction": faction_id, "region_id": region_id })
```

---

## 7.3 — Task System (Kolejka Zadań NPC)

Każdy NPC ma kolejkę zadań — zamiast globalnego stanu, każde zadanie ma priorytet, warunki zakończenia i akcję powrotu.

```gdscript
## Klasa: NPCTask (bazowa)
class_name NPCTask
extends RefCounted

enum Priority { LOW = 0, NORMAL = 1, HIGH = 2, URGENT = 3 }

var priority   : Priority = Priority.NORMAL
var expiry     : float    = -1.0   # -1 = nigdy nie wygasa
var is_done    : bool     = false

## Wywoływane co klatkę — zwraca true gdy zadanie ukończone
func tick(npc: CharacterBody3D, delta: float) -> bool:
    return false

## Wywoływane gdy zadanie jest przerywane przez wyższy priorytet
func cancel(npc: CharacterBody3D) -> void:
    pass
```

```gdscript
## Klasa: TaskQueue — komponent NPC
class_name TaskQueue
extends Node

var _queue   : Array[NPCTask] = []
var _current : NPCTask        = null

func push(task: NPCTask) -> void:
    _queue.append(task)
    _queue.sort_custom(func(a, b): return a.priority > b.priority)
    # Jeśli nowe zadanie ma wyższy priorytet niż bieżące — przerwij
    if _current and task.priority > _current.priority:
        _current.cancel(get_parent())
        _current = null

func _process(delta: float) -> void:
    _prune_expired()
    if not _current:
        _current = _queue.pop_front() if not _queue.is_empty() else null
    if not _current:
        return
    if _current.tick(get_parent(), delta):
        _current = null

func _prune_expired() -> void:
    var now := Time.get_unix_time_from_system()
    _queue = _queue.filter(func(t): return t.expiry < 0 or t.expiry > now)
```

Przykładowe typy zadań:

| Klasa zadania | Opis | Priorytet |
|---------------|------|-----------|
| `TaskPatrol` | Chód między waypointami Smart Terrain | NORMAL |
| `TaskRest` | Postój w obozie przez X minut | LOW |
| `TaskInvestigateNoise` | Idź do miejsca dźwięku | HIGH |
| `TaskEngageCombat` | Walcz z celem do śmierci/ucieczki | URGENT |
| `TaskRetreat` | Wycofaj się do najbliższego obozu | HIGH |
| `TaskTrade` | Idź do handlarza i wymień zasoby | LOW |
| `TaskReinforce` | Idź wzmocnić sojuszników w walce | HIGH |
| `TaskMigrate` | Przemieść się do innego regionu | NORMAL |

---

## 7.4 — Smart Terrain Nodes

Smart Terrain to węzeł sceny (POI) który "przyciąga" NPC danej frakcji — podobnie jak w zaawansowanych modach symulacyjnych, gdzie każda lokacja jest przypisana do konkretnej grupy NPC.

```gdscript
## SmartTerrain — węzeł sceny, umieszczany w edytorze przy każdym POI
class_name SmartTerrain
extends Node3D

@export var terrain_id      : String  = ""
@export var faction_id      : String  = ""        # frakcja która "należy" do terenu
@export var capacity        : int     = 5         # max NPC jednocześnie
@export var task_type       : String  = "patrol"  # domyślne zadanie
@export var waypoints       : Array[NodePath] = []

## Zarejestrowane NPC aktualnie przypisane do tego terenu
var _assigned_npcs : Array[CharacterBody3D] = []

func _ready() -> void:
    SmartTerrainManager.register(self)
    add_to_group("smart_terrain")

func can_assign() -> bool:
    return _assigned_npcs.size() < capacity

func assign_npc(npc: CharacterBody3D) -> void:
    if not can_assign():
        return
    _assigned_npcs.append(npc)
    npc.home_terrain = self
    var task := _create_task(npc)
    npc.get_node("TaskQueue").push(task)

func release_npc(npc: CharacterBody3D) -> void:
    _assigned_npcs.erase(npc)

func _create_task(npc: CharacterBody3D) -> NPCTask:
    match task_type:
        "patrol":
            var t := TaskPatrol.new()
            t.waypoints = waypoints.map(func(p): return get_node(p).global_position)
            return t
        "rest":
            var t := TaskRest.new()
            t.rest_position = global_position
            t.duration = randf_range(60.0, 300.0)
            return t
        _:
            return TaskPatrol.new()

func get_waypoint_positions() -> Array[Vector3]:
    return waypoints.map(func(p): return get_node(p).global_position)
```

---

## 7.5 — Symulacja Off-Screen (OffscreenResolver)

Gdy gracz jest dalej niż `ACTIVE_RADIUS` od regionu, walki są rozstrzygane przez uproszczony model probabilistyczny — zamiast pełnej fizyki i pathfindingu.

```gdscript
## OffscreenResolver — uruchamiany co TICK_RATE sekund
extends Node

const ACTIVE_RADIUS  := 200.0   # metry — granica pełnej symulacji
const TICK_RATE      := 5.0     # sekund między tickami
const TICK_VARIANCE  := 1.0     # losowe przesunięcie ±1s (zapobiega synchronizacji)

var _tick_timer := 0.0

func _process(delta: float) -> void:
    _tick_timer -= delta
    if _tick_timer > 0.0:
        return
    _tick_timer = TICK_RATE + randf_range(-TICK_VARIANCE, TICK_VARIANCE)
    _resolve_all_offscreen()

func _resolve_all_offscreen() -> void:
    var player_pos := _get_player_position()
    for region in get_tree().get_nodes_in_group("simulation_region"):
        if player_pos.distance_to(region.global_position) <= ACTIVE_RADIUS:
            continue
        _resolve_region(region)

func _resolve_region(region) -> void:
    var factions := region.get_present_factions()
    if factions.size() < 2:
        return

    # Znajdź pary wrogich frakcji
    for i in factions.size():
        for j in range(i + 1, factions.size()):
            var fa : String = factions[i]
            var fb : String = factions[j]
            if not FactionManager.is_hostile(fa, fb):
                continue
            _resolve_battle(region, fa, fb)

func _resolve_battle(region, faction_a: String, faction_b: String) -> void:
    var power_a := _calc_power(region, faction_a)
    var power_b := _calc_power(region, faction_b)

    if power_a < 0.01 and power_b < 0.01:
        return

    # Losowy wynik proporcjonalny do siły
    var total   := power_a + power_b
    var outcome := randf()

    if outcome < power_a / total:
        # Frakcja A wygrywa tę wymianę
        _apply_casualty(region, faction_b)
    else:
        _apply_casualty(region, faction_a)

func _calc_power(region, faction_id: String) -> float:
    var npcs    := region.get_simulated_npcs(faction_id)
    var base    := float(npcs.size())
    # Modyfikatory: uzbrojenie, zdrowie, teren
    var gear_bonus := npcs.reduce(func(acc, n): return acc + n.sim_gear_rating, 0.0)
    return base * (1.0 + gear_bonus / max(1.0, base) * 0.3) * randf_range(0.85, 1.15)

func _apply_casualty(region, faction_id: String) -> void:
    var npcs := region.get_simulated_npcs(faction_id)
    if npcs.is_empty():
        return
    var victim : Dictionary = npcs.pick_random()
    region.remove_simulated_npc(victim["id"])
    WorldEventBus.publish("npc_died",
        victim.get("position", region.global_position),
        null,
        {
            "faction":   faction_id,
            "region_id": region.region_id,
            "offscreen": true,
            "inventory": victim.get("inventory", {})
        }
    )
    PopulationManager.on_npc_died(region.region_id, faction_id)
```

---

## 7.6 — System Frakcji

```gdscript
## Autoload: FactionManager
extends Node

enum Relation { ALLY = 2, NEUTRAL = 1, HOSTILE = 0 }

## Tabela relacji — modyfikowalna w runtime
var _relations : Dictionary = {
    "military":  { "military": Relation.ALLY,    "raiders": Relation.HOSTILE, "traders": Relation.NEUTRAL },
    "raiders":   { "military": Relation.HOSTILE,  "raiders": Relation.ALLY,    "traders": Relation.HOSTILE },
    "traders":   { "military": Relation.NEUTRAL,  "raiders": Relation.HOSTILE, "traders": Relation.ALLY    },
    "scavengers":{ "military": Relation.NEUTRAL,  "raiders": Relation.HOSTILE, "traders": Relation.NEUTRAL },
}

## Zasoby strategiczne per frakcja
var _faction_resources : Dictionary = {
    "military":   { "ammo": 500, "medkits": 50, "food": 200 },
    "raiders":    { "ammo": 200, "medkits": 10, "food": 100 },
    "traders":    { "ammo": 100, "medkits": 100, "food": 500 },
    "scavengers": { "ammo": 50,  "medkits": 20, "food": 150 },
}

func get_relation(fa: String, fb: String) -> Relation:
    return _relations.get(fa, {}).get(fb, Relation.NEUTRAL) as Relation

func is_hostile(fa: String, fb: String) -> bool:
    return get_relation(fa, fb) == Relation.HOSTILE

## Dynamiczna zmiana relacji
func modify_relation(fa: String, fb: String, delta: int) -> void:
    var current := get_relation(fa, fb) as int
    var new_val := clamp(current + delta, 0, 2) as Relation
    if not _relations.has(fa): _relations[fa] = {}
    _relations[fa][fb] = new_val
    # Symetrycznie
    if not _relations.has(fb): _relations[fb] = {}
    _relations[fb][fa] = new_val
    WorldEventBus.publish("faction_relation_changed",
        Vector3.ZERO, null,
        { "faction_a": fa, "faction_b": fb, "new_relation": new_val })

## Reakcja na eventy wpływające na relacje
func _ready() -> void:
    WorldEventBus.subscribe("npc_died", _on_npc_died)

func _on_npc_died(event: Dictionary) -> void:
    var victim_faction : String = event["data"].get("faction", "")
    var killer         : Variant = event["data"].get("killer", null)
    if killer and killer is CharacterBody3D and killer.has_method("get_faction"):
        var killer_faction : String = killer.get_faction()
        if killer_faction != victim_faction:
            # Seria zabójstw pogarsza relacje
            modify_relation(victim_faction, killer_faction, -1)
```

---

## 7.7 — Migracje NPC Między Regionami

NPC nie "teleportuje się" do nowego regionu — maszeruje prawdziwą ścieżką przez NavMesh.

```gdscript
## TaskMigrate — zadanie migracji NPC do innego regionu
class_name TaskMigrate
extends NPCTask

var target_region   : Node        = null
var target_position : Vector3     = Vector3.ZERO
var _arrived        : bool        = false

func _init(region) -> void:
    target_region   = region
    target_position = region.get_entry_point()
    priority        = Priority.NORMAL

func tick(npc: CharacterBody3D, _delta: float) -> bool:
    if _arrived:
        return true
    npc.move_to(target_position)
    if npc.global_position.distance_to(target_position) < 2.0:
        _on_arrived(npc)
        return true
    return false

func _on_arrived(npc: CharacterBody3D) -> void:
    var old_region := npc.region_id
    PopulationManager.on_npc_died(old_region, npc.faction_id)
    npc.region_id = target_region.region_id
    PopulationManager.on_npc_spawned(target_region.region_id, npc.faction_id)
    target_region.add_npc(npc)
    WorldEventBus.publish("npc_migrated",
        npc.global_position, npc,
        {
            "faction":      npc.faction_id,
            "from_region":  old_region,
            "to_region":    target_region.region_id
        }
    )
    _arrived = true
```

---

## 7.8 — Corpse Cleanup

```gdscript
## NPCCorpse — węzeł tworzony po śmierci NPC
class_name NPCCorpse
extends StaticBody3D

const CLEANUP_TIME := 300.0   # 5 minut — czas do usunięcia zwłok
const LOOT_TIME    := 600.0   # 10 minut — czas do zniknięcia loot containera

@export var inventory : NPCInventory = null

var _elapsed := 0.0
var _looted  := false

func _ready() -> void:
    # Wyłącz AI, zostaw model i kolizję
    add_to_group("corpse")

func _process(delta: float) -> void:
    _elapsed += delta
    if _elapsed > LOOT_TIME and _looted:
        queue_free()
    elif _elapsed > CLEANUP_TIME and inventory.items.is_empty():
        queue_free()

func loot_all() -> Array[Dictionary]:
    _looted = true
    var items := inventory.items.duplicate(true)
    inventory.items.clear()
    return items
```

---

## 7.9 — Inwentarze NPC

```gdscript
## NPCInventory — Resource
class_name NPCInventory
extends Resource

@export var items      : Array[Dictionary] = []
@export var max_weight : float             = 30.0

var _current_weight : float = 0.0

func add_item(item_id: String, count: int = 1, condition: float = 1.0) -> bool:
    var weight := ItemDatabase.get_weight(item_id) * count
    if _current_weight + weight > max_weight:
        return false
    # Sprawdź czy już mamy ten item (stack)
    for item in items:
        if item["id"] == item_id and item["condition"] == condition:
            item["count"] += count
            _current_weight += weight
            return true
    items.append({ "id": item_id, "count": count, "condition": condition })
    _current_weight += weight
    return true

func remove_item(item_id: String, count: int = 1) -> bool:
    for i in items.size():
        if items[i]["id"] == item_id:
            items[i]["count"] -= count
            if items[i]["count"] <= 0:
                items.remove_at(i)
            _current_weight -= ItemDatabase.get_weight(item_id) * count
            return true
    return false

func has_item(item_id: String, min_count: int = 1) -> bool:
    for item in items:
        if item["id"] == item_id and item["count"] >= min_count:
            return true
    return false

func serialize() -> Dictionary:
    return { "items": items.duplicate(true), "weight": _current_weight }

static func deserialize(data: Dictionary) -> NPCInventory:
    var inv := NPCInventory.new()
    for item in data.get("items", []):
        inv.items.append(item.duplicate())
    inv._current_weight = data.get("weight", 0.0)
    return inv
```

---

## 7.10 — Debug Overlay

```gdscript
## DebugOverlay — autoload, F3 toggle
extends CanvasLayer

@onready var _panel      : PanelContainer = $Panel
@onready var _events_lbl : RichTextLabel  = $Panel/VBox/EventsLabel
@onready var _pop_lbl    : RichTextLabel  = $Panel/VBox/PopLabel
@onready var _task_lbl   : RichTextLabel  = $Panel/VBox/TaskLabel

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("debug_overlay"):
        _panel.visible = not _panel.visible

func _process(_delta: float) -> void:
    if not _panel.visible:
        return
    _update_events()
    _update_population()
    _update_tasks()

func _update_events() -> void:
    var events := WorldEventBus.get_recent_events(8)
    var txt    := "[b][color=cyan]Eventy (ostatnie 8):[/color][/b]\n"
    for ev in events:
        txt += "  [color=yellow]%s[/color]  %s\n" % [
            ev["type"], _short_vec(ev["position"])]
    _events_lbl.text = txt

func _update_population() -> void:
    var txt := "[b][color=lime]Populacja:[/color][/b]\n"
    for key in PopulationManager._population:
        var e : Dictionary = PopulationManager._population[key]
        txt += "  %s  %d/%d\n" % [key, e["current"], e["cap"]]
    _pop_lbl.text = txt

func _update_tasks() -> void:
    var npcs := get_tree().get_nodes_in_group("npc")
    var txt  := "[b][color=orange]Zadania NPC (do 5):[/color][/b]\n"
    for i in min(5, npcs.size()):
        var npc     := npcs[i] as CharacterBody3D
        var tq      := npc.get_node_or_null("TaskQueue") as TaskQueue
        var current := tq._current.get_class() if tq and tq._current else "brak"
        txt += "  %s → [color=white]%s[/color]\n" % [npc.name, current]
    _task_lbl.text = txt

func _short_vec(v: Vector3) -> String:
    return "(%.0f, %.0f, %.0f)" % [v.x, v.y, v.z]
```

---

## ✅ Rezultat fazy

- [ ] `WorldEventBus` skompilowany jako GDExtension — widoczny w Godot jako autoload
- [ ] Rate limiting działa — burst eventów jest odrzucany bez crashu
- [ ] `PopulationManager` utrzymuje limity per frakcja per region
- [ ] NPC respawnują wyłącznie poza LOS gracza (min. 80m)
- [ ] `TaskQueue` na każdym NPC — zadania priorytetyzowane poprawnie
- [ ] `SmartTerrain` przyciąga NPC danej frakcji do POI
- [ ] `OffscreenResolver` tykuje co 5s — walki toczą się poza zasięgiem gracza
- [ ] Relacje frakcji zmieniają się na podstawie eventów (seria zabójstw)
- [ ] Migracje NPC: przemieszczanie po NavMesh, brak teleportacji
- [ ] Corpse cleanup: zwłoki znikają po 5 min (jeśli splądrowane) lub 10 min
- [ ] Inwentarze NPC: persistent loot po śmierci
- [ ] Debug overlay (F3): eventy, populacja, aktywne zadania NPC widoczne w runtime
