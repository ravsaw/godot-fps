# Faza 7 — Symulacja Świata

> **Cel:** Żyjący świat symulowany niezależnie od gracza, oparty na eventach.

---

## 📋 Zadania

| # | Zadanie | Trudność | Czas |
|---|---------|----------|------|
| 7.1 | WorldEventBus w C++ GDExtension — publish/subscribe, Callable, autoload singleton | 🔴 | 4–6 dni |
| 7.2 | Rate limiting — token bucket per typ eventu, cooldowny, filtry regionów | 🔴 | 3–4 dni |
| 7.3 | Eventy podstawowe: npc_died, enemy_spotted, shot_fired, area_entered | 🟡 | 2–3 dni |
| 7.4 | Symulacja off-screen — NPC poza aktywnym regionem symulowani uproszczonym modelem | 🔴 | 1–2 tyg. |
| 7.5 | System frakcji — każdy NPC należy do frakcji, frakcje mają relacje (sojusz/wrogość/neutralność) | 🟡 | 4–6 dni |
| 7.6 | Łańcuchy konsekwencji — zdarzenie A powoduje B powoduje C | 🔴 | 1–2 tyg. |
| 7.7 | Inwentarze NPC — prawdziwe zasoby, handel oparty na realnych potrzebach | 🟡 | 4–6 dni |
| 7.8 | Debug overlay — wizualizacja eventów, stanów NPC, historii decyzji | 🟡 | 3–4 dni |

---

## 🏗️ Architektura systemu

### Zasady projektowe

Cały system symulacji świata opiera się na niezmiennych regułach:

| Zasada | Opis |
|--------|------|
| **Zero fake teleportacji** | Wszystko porusza się prawdziwymi ścieżkami NavMesh — nikt nie "pojawia się" w miejscu |
| **Zero fake aktywności** | Żadne zdarzenie nie dzieje się "dla show" — wszystko ma logiczną przyczynę |
| **Wszystko ma przyczynę** | Każde zdarzenie jest reakcją na inne zdarzenie — brak losowych eventów bez kontekstu |
| **Event-driven** | Zamiast pollingu co klatkę, eventy triggerują reakcje asynchronicznie |
| **Token bucket rate limiting** | Kontrola częstotliwości eventów per region — CPU nie jest przeciążane przez burst eventów |
| **Symulacja off-screen** | Świat żyje gdy gracza nie ma w pobliżu — uproszczony model dla nieaktywnych regionów |
| **Pełna obserwowalność** | Debug overlay pokazuje historię decyzji, stany NPC, aktywne eventy |

---

### Event Bus — architektura publish/subscribe

```
[Źródło eventu]                [WorldEventBus (C++)]         [Subscriber]
  NPC::die()      ──publish──>  queue + rate_limit    ──>   FactionManager
  Weapon::shoot() ──publish──>  token_bucket check    ──>   NearbyNPC
  Player::enter() ──publish──>  region_filter         ──>   RegionController
```

Każdy event niesie:
- `type` (String) — np. `"npc_died"`, `"shot_fired"`
- `position` (Vector3) — miejsce zdarzenia
- `source` (Variant) — kto wywołał
- `data` (Dictionary) — dane specyficzne dla eventu

---

## 7.1 — WorldEventBus w C++ (GDExtension)

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
    String    type;
    Vector3   position;
    Variant   source;
    Dictionary data;
    double    timestamp;
};

struct TokenBucket {
    double tokens;
    double capacity;
    double refill_rate;   // tokenów / sekundę
    double last_refill;
};

class WorldEventBus : public Node {
    GDCLASS(WorldEventBus, Node)

public:
    static WorldEventBus* get_singleton();

    // GDScript API
    void   publish(const String& type, const Vector3& pos,
                   const Variant& source, const Dictionary& data);
    void   subscribe(const String& type, const Callable& callback);
    void   unsubscribe(const String& type, const Callable& callback);
    void   set_rate_limit(const String& type, double capacity,
                          double refill_rate);
    Array  get_recent_events(int count) const;

    void _process(double delta) override;

protected:
    static void _bind_methods();

private:
    static WorldEventBus* _singleton;

    std::unordered_map<std::string,
        std::vector<Callable>>        _subscribers;
    std::unordered_map<std::string,
        TokenBucket>                  _rate_limits;
    std::deque<WorldEvent>            _event_history;
    std::vector<WorldEvent>           _pending_events;

    static constexpr size_t HISTORY_MAX = 500;
    static constexpr int    DISPATCH_PER_FRAME = 20;

    bool _consume_token(const String& type, double delta);
    void _dispatch_pending();
};

} // namespace godot
```

### Implementacja `world_event_bus.cpp`

```cpp
#include "world_event_bus.h"
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

WorldEventBus* WorldEventBus::_singleton = nullptr;

WorldEventBus* WorldEventBus::get_singleton() {
    return _singleton;
}

void WorldEventBus::_bind_methods() {
    ClassDB::bind_method(D_METHOD("publish", "type", "position",
        "source", "data"), &WorldEventBus::publish);
    ClassDB::bind_method(D_METHOD("subscribe", "type", "callback"),
        &WorldEventBus::subscribe);
    ClassDB::bind_method(D_METHOD("unsubscribe", "type", "callback"),
        &WorldEventBus::unsubscribe);
    ClassDB::bind_method(D_METHOD("set_rate_limit", "type",
        "capacity", "refill_rate"), &WorldEventBus::set_rate_limit);
    ClassDB::bind_method(D_METHOD("get_recent_events", "count"),
        &WorldEventBus::get_recent_events);
}

void WorldEventBus::publish(
    const String& type, const Vector3& pos,
    const Variant& source, const Dictionary& data)
{
    WorldEvent ev;
    ev.type      = type;
    ev.position  = pos;
    ev.source    = source;
    ev.data      = data;
    ev.timestamp = Time::get_singleton()->get_unix_time_from_system();
    _pending_events.push_back(ev);
}

void WorldEventBus::subscribe(
    const String& type, const Callable& callback)
{
    _subscribers[type.utf8().get_data()].push_back(callback);
}

void WorldEventBus::unsubscribe(
    const String& type, const Callable& callback)
{
    auto& vec = _subscribers[type.utf8().get_data()];
    vec.erase(std::remove_if(vec.begin(), vec.end(),
        [&](const Callable& c){ return c == callback; }), vec.end());
}

void WorldEventBus::set_rate_limit(
    const String& type, double capacity, double refill_rate)
{
    TokenBucket bucket;
    bucket.tokens      = capacity;
    bucket.capacity    = capacity;
    bucket.refill_rate = refill_rate;
    bucket.last_refill = 0.0;
    _rate_limits[type.utf8().get_data()] = bucket;
}

bool WorldEventBus::_consume_token(const String& type, double delta) {
    auto key = type.utf8().get_data();
    auto it  = _rate_limits.find(key);
    if (it == _rate_limits.end()) return true;   // brak limitu = przepuść

    auto& bucket = it->second;
    bucket.tokens = std::min(bucket.capacity,
        bucket.tokens + bucket.refill_rate * delta);
    if (bucket.tokens < 1.0) return false;
    bucket.tokens -= 1.0;
    return true;
}

void WorldEventBus::_process(double delta) {
    _dispatch_pending();
}

void WorldEventBus::_dispatch_pending() {
    int dispatched = 0;
    for (auto& ev : _pending_events) {
        if (dispatched >= DISPATCH_PER_FRAME) break;
        auto key = ev.type.utf8().get_data();
        auto it  = _subscribers.find(key);
        if (it == _subscribers.end()) continue;

        Dictionary payload;
        payload["type"]     = ev.type;
        payload["position"] = ev.position;
        payload["source"]   = ev.source;
        payload["data"]     = ev.data;

        for (auto& cb : it->second) {
            cb.call(payload);
        }

        _event_history.push_back(ev);
        if (_event_history.size() > HISTORY_MAX)
            _event_history.pop_front();

        ++dispatched;
    }
    _pending_events.erase(_pending_events.begin(),
        _pending_events.begin() + dispatched);
}

Array WorldEventBus::get_recent_events(int count) const {
    Array result;
    int start = std::max(0, (int)_event_history.size() - count);
    for (int i = start; i < (int)_event_history.size(); ++i) {
        Dictionary d;
        d["type"]     = _event_history[i].type;
        d["position"] = _event_history[i].position;
        result.push_back(d);
    }
    return result;
}
```

---

## 7.2 — Rate Limiting (Token Bucket)

Token bucket zapobiega "burstom" eventów zalewającym system:

```gdscript
## W autoload WorldSimulation (inicjalizacja rate limitów)
func _ready() -> void:
    var bus : WorldEventBus = WorldEventBus.get_singleton()
    # Typ eventu | max burst | odnawianie/s
    bus.set_rate_limit("shot_fired",    10.0, 5.0)   # max 10 strzałów na raz, 5/s odnawia
    bus.set_rate_limit("npc_died",       5.0, 1.0)   # śmierci nie mogą wychodzić zbyt często
    bus.set_rate_limit("enemy_spotted",  8.0, 3.0)
    bus.set_rate_limit("area_entered",  20.0, 10.0)
```

---

## 7.3 — Eventy podstawowe

```gdscript
## Przykłady emitowania eventów z GDScript

# Strzał
func _shoot() -> void:
    WorldEventBus.publish("shot_fired",
        global_position,
        self,
        { "weapon": _current_weapon, "faction": faction_id }
    )

# Śmierć NPC
func die() -> void:
    WorldEventBus.publish("npc_died",
        global_position,
        self,
        {
            "faction": faction_id,
            "inventory": _inventory.serialize(),
            "killer": _last_attacker
        }
    )

# Wykrycie wroga
func _on_enemy_spotted(enemy: Node3D) -> void:
    WorldEventBus.publish("enemy_spotted",
        global_position,
        self,
        { "enemy": enemy, "enemy_faction": enemy.faction_id }
    )
```

---

## 7.4 — Symulacja Off-Screen

NPC poza aktywnym regionem (> 200m od gracza) nie są symulowani pełnym modelem fizyki — zamiast tego używany jest uproszczony model probabilistyczny:

```gdscript
## WorldSimulation — autoload
extends Node

const ACTIVE_RADIUS := 200.0          # promień pełnej symulacji (metry)
const TICK_RATE     := 5.0            # sekund między tickami off-screen
var   _sim_timer    := 0.0

func _process(delta: float) -> void:
    _sim_timer -= delta
    if _sim_timer > 0.0:
        return
    _sim_timer = TICK_RATE
    _tick_offscreen_regions()

func _tick_offscreen_regions() -> void:
    var player_pos := _get_player_position()
    for region in get_tree().get_nodes_in_group("simulation_region"):
        var dist := player_pos.distance_to(region.global_position)
        if dist <= ACTIVE_RADIUS:
            continue   # aktywny region — pełna symulacja
        _simulate_region_abstract(region)

func _simulate_region_abstract(region: Node) -> void:
    # Uproszczona logika: losuj wynik walki frakcji w regionie
    var attackers := region.get_npcs_of_faction("hostile")
    var defenders := region.get_npcs_of_faction("neutral")

    if attackers.is_empty() or defenders.is_empty():
        return

    # Prosta heurystyka: liczebność + losowość
    var att_power := attackers.size() * randf_range(0.8, 1.2)
    var def_power := defenders.size() * randf_range(0.8, 1.2)

    if att_power > def_power * 1.5:
        # Napastnicy wygrywają — usuń losowego obrońcę
        var victim : Node = defenders.pick_random()
        WorldEventBus.publish("npc_died",
            victim.sim_position,
            null,
            { "faction": victim.faction_id, "offscreen": true })
        region.remove_simulated_npc(victim)
```

---

## 7.5 — System Frakcji

```gdscript
## Autoload: FactionManager
extends Node

enum Relation { ALLY, NEUTRAL, HOSTILE }

# Tablica relacji: faction_a → faction_b → relacja
var _relations : Dictionary = {
    "military":   { "military": Relation.ALLY,    "bandits": Relation.HOSTILE, "civilians": Relation.NEUTRAL },
    "bandits":    { "military": Relation.HOSTILE,  "bandits": Relation.ALLY,    "civilians": Relation.HOSTILE },
    "civilians":  { "military": Relation.NEUTRAL,  "bandits": Relation.HOSTILE, "civilians": Relation.ALLY    },
}

func get_relation(faction_a: String, faction_b: String) -> Relation:
    if not _relations.has(faction_a):
        return Relation.NEUTRAL
    return _relations[faction_a].get(faction_b, Relation.NEUTRAL)

func is_hostile(faction_a: String, faction_b: String) -> bool:
    return get_relation(faction_a, faction_b) == Relation.HOSTILE

## Modyfikacja relacji na podstawie eventów
func _on_world_event(event: Dictionary) -> void:
    if event["type"] == "npc_died":
        var dead_faction : String = event["data"].get("faction", "")
        var killer       : Node   = event["data"].get("killer", null)
        if killer and killer.has_method("get_faction"):
            _on_kill(killer.get_faction(), dead_faction)

func _on_kill(killer_faction: String, victim_faction: String) -> void:
    if killer_faction == victim_faction:
        return   # bratobójstwo — brak zmiany relacji frakcji
    # Możliwość: dynamiczna zmiana relacji po serii incydentów
```

---

## 7.6 — Łańcuchy Konsekwencji

Przykład łańcucha: `strzał → alarm → patrol wysłany → walka → śmierć NPC → zmiana kontroli regionu`

```gdscript
## WorldSimulation subskrybuje eventy i wywołuje reakcje

func _ready() -> void:
    WorldEventBus.subscribe("shot_fired",     _on_shot_fired)
    WorldEventBus.subscribe("npc_died",       _on_npc_died)
    WorldEventBus.subscribe("enemy_spotted",  _on_enemy_spotted)

func _on_shot_fired(event: Dictionary) -> void:
    # Pobliskie placówki wysyłają patrol w kierunku strzału
    var range := 150.0
    for outpost in _get_outposts_in_range(event["position"], range):
        outpost.dispatch_patrol(event["position"])

func _on_npc_died(event: Dictionary) -> void:
    var faction : String = event["data"].get("faction", "")
    var region  := _get_region_at(event["position"])
    if region:
        region.record_loss(faction)
        # Jeśli frakcja straciła za dużo NPC — wycofuje się z regionu
        if region.get_faction_strength(faction) < 0.2:
            region.change_control(faction, "contested")
            WorldEventBus.publish("region_control_changed",
                region.global_position, null,
                { "region_id": region.region_id, "new_state": "contested" })
```

---

## 7.7 — Inwentarze NPC

```gdscript
## Klasa: NPCInventory
class_name NPCInventory
extends Resource

@export var items : Array[Dictionary] = []   # [{ id, count, condition }]
@export var max_weight : float = 30.0

var _current_weight : float = 0.0

func add_item(item_id: String, count: int, condition: float = 1.0) -> bool:
    var weight := ItemDatabase.get_weight(item_id) * count
    if _current_weight + weight > max_weight:
        return false
    items.append({ "id": item_id, "count": count, "condition": condition })
    _current_weight += weight
    return true

func serialize() -> Dictionary:
    return { "items": items.duplicate(true), "weight": _current_weight }

static func deserialize(data: Dictionary) -> NPCInventory:
    var inv := NPCInventory.new()
    inv.items = data.get("items", [])
    inv._current_weight = data.get("weight", 0.0)
    return inv
```

Po śmierci NPC jego inwentarz staje się lootem (patrz Faza 9).

---

## 7.8 — Debug Overlay

```gdscript
## DebugOverlay — autoload, widoczny po wciśnięciu F3
extends CanvasLayer

@onready var _label : RichTextLabel = $Panel/RichTextLabel

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("debug_overlay"):
        visible = not visible

func _process(_delta: float) -> void:
    if not visible:
        return
    var bus := WorldEventBus
    var events := WorldEventBus.get_recent_events(10)
    var text := "[b]Ostatnie eventy:[/b]\n"
    for ev in events:
        text += "• [color=yellow]%s[/color] @ %s\n" % [
            ev["type"], str(ev["position"]).substr(0, 20)]
    _label.text = text
```

---

## ✅ Rezultat fazy

- [ ] `WorldEventBus` skompilowany jako GDExtension i widoczny w Godot
- [ ] Eventy podstawowe emitowane przez gracza, NPC i broń
- [ ] Rate limiting działa — burst eventów nie przeciąża CPU
- [ ] Symulacja off-screen: walki toczą się poza zasięgiem gracza
- [ ] System frakcji: NPC reagują inaczej na sojuszników i wrogów
- [ ] Łańcuch konsekwencji: strzał → alarm → patrol → walka → zmiana regionu
- [ ] Inwentarze NPC: prawdziwe zasoby, transferowane po śmierci
- [ ] Debug overlay pokazuje historię eventów w runtime
