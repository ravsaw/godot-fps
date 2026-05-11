#include "alife/npc_data.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void NpcData::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_npc_id", "id"), &NpcData::set_npc_id);
    ClassDB::bind_method(D_METHOD("get_npc_id"), &NpcData::get_npc_id);
    ClassDB::bind_method(D_METHOD("set_faction_id", "id"), &NpcData::set_faction_id);
    ClassDB::bind_method(D_METHOD("get_faction_id"), &NpcData::get_faction_id);
    ClassDB::bind_method(D_METHOD("set_squad_id", "id"), &NpcData::set_squad_id);
    ClassDB::bind_method(D_METHOD("get_squad_id"), &NpcData::get_squad_id);
    ClassDB::bind_method(D_METHOD("set_health", "health"), &NpcData::set_health);
    ClassDB::bind_method(D_METHOD("get_health"), &NpcData::get_health);
    ClassDB::bind_method(D_METHOD("set_location_id", "id"), &NpcData::set_location_id);
    ClassDB::bind_method(D_METHOD("get_location_id"), &NpcData::get_location_id);
    ClassDB::bind_method(D_METHOD("set_is_alive", "alive"), &NpcData::set_is_alive);
    ClassDB::bind_method(D_METHOD("get_is_alive"), &NpcData::get_is_alive);

    ADD_PROPERTY(PropertyInfo(Variant::INT, "npc_id"), "set_npc_id", "get_npc_id");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "faction_id"), "set_faction_id", "get_faction_id");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "squad_id"), "set_squad_id", "get_squad_id");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "health"), "set_health", "get_health");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "location_id"), "set_location_id", "get_location_id");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "is_alive"), "set_is_alive", "get_is_alive");
}

void NpcData::set_npc_id(int64_t p_id) { npc_id = p_id; }
int64_t NpcData::get_npc_id() const { return npc_id; }

void NpcData::set_faction_id(int64_t p_id) { faction_id = p_id; }
int64_t NpcData::get_faction_id() const { return faction_id; }

void NpcData::set_squad_id(int64_t p_id) { squad_id = p_id; }
int64_t NpcData::get_squad_id() const { return squad_id; }

void NpcData::set_health(float p_health) { health = p_health; }
float NpcData::get_health() const { return health; }

void NpcData::set_location_id(int64_t p_id) { location_id = p_id; }
int64_t NpcData::get_location_id() const { return location_id; }

void NpcData::set_is_alive(bool p_alive) { is_alive = p_alive; }
bool NpcData::get_is_alive() const { return is_alive; }
