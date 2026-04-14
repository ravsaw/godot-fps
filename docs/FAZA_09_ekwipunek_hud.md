# Faza 9 — Ekwipunek i HUD

> **Cel:** Minimalistyczny interfejs i zarządzanie przedmiotami spójne z logiką symulacji świata.

---

## 📋 Zadania

| # | Zadanie | Trudność | Czas |
|---|---------|----------|------|
| 9.1 | System ekwipunku — sloty, waga, stack przedmiotów | 🟡 | 4–6 dni |
| 9.2 | Loot z NPC — po śmierci NPC zostawia swój prawdziwy inwentarz | 🟢 | 2–3 dni |
| 9.3 | HUD — zdrowie, stamina, amunicja — minimalistyczny | 🟢 | 2–3 dni |
| 9.4 | Mapa regionu — schematyczna, aktualizowana przez eventy symulacji | 🟡 | 4–6 dni |

---

## 🔍 Opis zadań

### 9.1 — System Ekwipunku

Ekwipunek gracza działa tak samo jak inwentarz NPC (`NPCInventory` z Fazy 7) — ta sama klasa, ten sam format serializacji.

```gdscript
## PlayerInventory — rozszerza NPCInventory
class_name PlayerInventory
extends NPCInventory

## Sloty wyposażenia (aktywne przedmioty)
var _equipped : Dictionary = {
    "weapon_primary":   null,
    "weapon_secondary": null,
    "helmet":           null,
    "vest":             null,
    "backpack":         null,
}

signal item_added(item_id: String, count: int)
signal item_removed(item_id: String, count: int)
signal item_equipped(slot: String, item_id: String)

func equip(slot: String, item_id: String) -> bool:
    if not has_item(item_id):
        return false
    if not ItemDatabase.is_equippable_in_slot(item_id, slot):
        return false
    _equipped[slot] = item_id
    item_equipped.emit(slot, item_id)
    return true

func get_equipped(slot: String):
    return _equipped.get(slot, null)

## Pojemność zależy od plecaka
func _get_max_weight() -> float:
    var base   := 20.0
    var bag    := _equipped.get("backpack", null)
    if bag:
        base += ItemDatabase.get_carry_bonus(bag)
    return base
```

**Baza danych przedmiotów (`ItemDatabase`):**

```gdscript
## Autoload: ItemDatabase
extends Node

const _items : Dictionary = {
    "rifle_assault": {
        "name":          "Karabin szturmowy",
        "weight":        3.2,
        "equip_slots":   ["weapon_primary"],
        "carry_bonus":   0.0,
    },
    "medkit_small": {
        "name":          "Mały apteczka",
        "weight":        0.3,
        "equip_slots":   [],
        "carry_bonus":   0.0,
    },
    "backpack_large": {
        "name":          "Duży plecak",
        "weight":        2.0,
        "equip_slots":   ["backpack"],
        "carry_bonus":   15.0,
    },
    "ammo_rifle_545": {
        "name":          "Naboje 5.45mm",
        "weight":        0.01,    # na sztukę
        "equip_slots":   [],
        "carry_bonus":   0.0,
    },
}

func get_weight(item_id: String) -> float:
    return _items.get(item_id, {}).get("weight", 0.0)

func is_equippable_in_slot(item_id: String, slot: String) -> bool:
    var slots : Array = _items.get(item_id, {}).get("equip_slots", [])
    return slot in slots

func get_carry_bonus(item_id: String) -> float:
    return _items.get(item_id, {}).get("carry_bonus", 0.0)
```

---

### 9.2 — Loot z NPC

Gdy NPC umiera, tworzy `NPCCorpse` z jego prawdziwym inwentarzem — nie generuje losowego łupu.

```gdscript
## Fragment kodu śmierci NPC
func die() -> void:
    _state_machine.transition_to(NPCStateMachine.State.DEAD)

    # Stwórz zwłoki z kopią inwentarza
    var corpse_scene := preload("res://scenes/npc/npc_corpse.tscn")
    var corpse       : NPCCorpse = corpse_scene.instantiate()
    get_parent().add_child(corpse)
    corpse.global_transform = global_transform
    corpse.inventory        = _inventory.duplicate(true)

    WorldEventBus.publish("npc_died",
        global_position, self,
        {
            "faction":   faction_id,
            "region_id": region_id,
            "killer":    _last_attacker,
            "inventory": _inventory.serialize(),
        }
    )
    queue_free()
```

Interakcja gracza ze zwłokami (przez raycast z Fazy 2):
```gdscript
## NPCCorpse — metoda interact() wywoływana przez gracza
func interact(player: CharacterBody3D) -> void:
    if inventory.items.is_empty():
        return
    # Otwórz UI transferu przedmiotów
    LootUI.open(self, player.get_node("Inventory"))
```

---

### 9.3 — HUD (Minimalistyczny)

Struktura sceny HUD:

```
HUD (CanvasLayer)
├── HealthBar (ProgressBar)          — lewy dolny róg, czerwony
├── StaminaBar (ProgressBar)         — pod zdrowiem, zielony, ukrywa się gdy pełna
├── AmmoDisplay (HBoxContainer)
│   ├── AmmoCurrentLabel (Label)     — "28"
│   ├── Separator (Label)            — "/"
│   └── AmmoReserveLabel (Label)     — "90"
├── WeaponName (Label)               — nazwa aktywnej broni
├── Crosshair (TextureRect)          — dot lub krzyżyk
└── InteractionPrompt (Label)        — "[E] Przeszukaj" — pojawia się gdy raycast trafi
```

```gdscript
## HUD.gd
extends CanvasLayer

@onready var _health_bar    : ProgressBar = $HealthBar
@onready var _stamina_bar   : ProgressBar = $StaminaBar
@onready var _ammo_current  : Label       = $AmmoDisplay/AmmoCurrentLabel
@onready var _ammo_reserve  : Label       = $AmmoDisplay/AmmoReserveLabel
@onready var _interact_lbl  : Label       = $InteractionPrompt
@onready var _weapon_name   : Label       = $WeaponName

func _ready() -> void:
    # Podłącz sygnały gracza
    var player := get_tree().get_first_node_in_group("player")
    player.health_changed.connect(_on_health_changed)
    player.stamina_changed.connect(_on_stamina_changed)
    player.weapon_changed.connect(_on_weapon_changed)
    player.ammo_changed.connect(_on_ammo_changed)
    player.interaction_target_changed.connect(_on_interaction_target)

func _on_health_changed(value: float, max_val: float) -> void:
    _health_bar.value = value / max_val * 100.0

func _on_stamina_changed(value: float, max_val: float) -> void:
    _stamina_bar.value  = value / max_val * 100.0
    _stamina_bar.visible = value < max_val   # ukryj gdy pełna

func _on_ammo_changed(current: int, reserve: int) -> void:
    _ammo_current.text = str(current)
    _ammo_reserve.text = str(reserve)
    # Czerwony kolor gdy mało amunicji
    _ammo_current.modulate = Color.RED if current <= 5 else Color.WHITE

func _on_weapon_changed(weapon_name: String) -> void:
    _weapon_name.text = weapon_name

func _on_interaction_target(target_name: String) -> void:
    _interact_lbl.text    = "[E] %s" % target_name if target_name else ""
    _interact_lbl.visible = target_name != ""
```

---

### 9.4 — Mapa Regionu

Mapa schematyczna — nie fotorealistyczna, tylko ikony regionów i frakcji:

```gdscript
## RegionMap — Control node w HUD, otwierana klawiszem M
extends Control

@onready var _canvas : Node2D = $MapCanvas

## Pozycje regionów na mapie (2D, przeliczone ze współrzędnych 3D świata)
var _region_icons : Dictionary = {}   # region_id → TextureRect

func _ready() -> void:
    visible = false
    _build_map()
    # Subskrybuj eventy zmieniające mapę
    WorldEventBus.subscribe("region_control_changed", _on_region_changed)
    WorldEventBus.subscribe("npc_died",               _on_npc_died)

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("open_map"):
        visible = not visible

func _build_map() -> void:
    for region in get_tree().get_nodes_in_group("simulation_region"):
        var icon     := TextureRect.new()
        icon.texture  = _get_faction_icon(region.controlling_faction)
        icon.position = _world_to_map(region.global_position)
        icon.pivot_offset = icon.size / 2.0
        _canvas.add_child(icon)
        _region_icons[region.region_id] = icon

        # Etykieta nazwy regionu
        var label      := Label.new()
        label.text      = region.region_id
        label.position  = icon.position + Vector2(12, -8)
        _canvas.add_child(label)

func _on_region_changed(event: Dictionary) -> void:
    var region_id   : String = event["data"].get("region_id", "")
    var new_faction : String = event["data"].get("new_faction", "neutral")
    if _region_icons.has(region_id):
        _region_icons[region_id].texture = _get_faction_icon(new_faction)

func _world_to_map(world_pos: Vector3) -> Vector2:
    ## Przelicz współrzędne 3D na pozycję 2D na mapie
    ## (wymaga zdefiniowania min/max współrzędnych świata)
    const WORLD_MIN := Vector2(-500, -500)
    const WORLD_MAX := Vector2(500, 500)
    const MAP_SIZE  := Vector2(400, 400)

    var normalized := Vector2(
        (world_pos.x - WORLD_MIN.x) / (WORLD_MAX.x - WORLD_MIN.x),
        (world_pos.z - WORLD_MIN.y) / (WORLD_MAX.y - WORLD_MIN.y)
    )
    return normalized * MAP_SIZE

func _get_faction_icon(faction_id: String) -> Texture2D:
    ## Zwraca ikonę frakcji z katalogu assets/ui/factions/
    var path := "res://assets/ui/factions/%s.png" % faction_id
    if ResourceLoader.exists(path):
        return load(path)
    return load("res://assets/ui/factions/neutral.png")
```

---

## ✅ Rezultat fazy

- [ ] Ekwipunek gracza: sloty wyposażenia, limit wagowy, stackowanie
- [ ] Martwy NPC zostawia wyłącznie swój własny inwentarz — zero losowego łupu
- [ ] Interfejs lootowania: transfer przedmiotów gracz ↔ zwłoki
- [ ] HUD: pasek zdrowia, staminy (znika gdy pełna), amunicja, nazwa broni
- [ ] Podpowiedź interakcji pojawia się gdy gracz celuje w obiekt z `interact()`
- [ ] Mapa regionów: ikony frakcji, aktualizuje się po `region_control_changed`
- [ ] Waga ekwipunku rośnie z dodawaniem przedmiotów — spowolnienie przy przeciążeniu
