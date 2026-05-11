#include "alife/squad_data.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void SquadData::_bind_methods() {
    BIND_ENUM_CONSTANT(STATE_IDLE);
    BIND_ENUM_CONSTANT(STATE_MOVING);
    BIND_ENUM_CONSTANT(STATE_RESTING);

    ClassDB::bind_method(D_METHOD("set_squad_name", "squad_name"), &SquadData::set_squad_name);
    ClassDB::bind_method(D_METHOD("get_squad_name"), &SquadData::get_squad_name);
    ClassDB::bind_method(D_METHOD("set_faction_id", "faction_id"), &SquadData::set_faction_id);
    ClassDB::bind_method(D_METHOD("get_faction_id"), &SquadData::get_faction_id);
    ClassDB::bind_method(D_METHOD("set_current_location_id", "current_location_id"), &SquadData::set_current_location_id);
    ClassDB::bind_method(D_METHOD("get_current_location_id"), &SquadData::get_current_location_id);
    ClassDB::bind_method(D_METHOD("set_home_location_id", "home_location_id"), &SquadData::set_home_location_id);
    ClassDB::bind_method(D_METHOD("get_home_location_id"), &SquadData::get_home_location_id);
    ClassDB::bind_method(D_METHOD("set_squad_state", "squad_state"), &SquadData::set_squad_state);
    ClassDB::bind_method(D_METHOD("get_squad_state"), &SquadData::get_squad_state);
    ClassDB::bind_method(D_METHOD("set_target_location_id", "target_location_id"), &SquadData::set_target_location_id);
    ClassDB::bind_method(D_METHOD("get_target_location_id"), &SquadData::get_target_location_id);
    ClassDB::bind_method(D_METHOD("set_travel_elapsed", "travel_elapsed"), &SquadData::set_travel_elapsed);
    ClassDB::bind_method(D_METHOD("get_travel_elapsed"), &SquadData::get_travel_elapsed);
    ClassDB::bind_method(D_METHOD("set_travel_duration", "travel_duration"), &SquadData::set_travel_duration);
    ClassDB::bind_method(D_METHOD("get_travel_duration"), &SquadData::get_travel_duration);
    ClassDB::bind_method(D_METHOD("set_route_step", "route_step"), &SquadData::set_route_step);
    ClassDB::bind_method(D_METHOD("get_route_step"), &SquadData::get_route_step);
    ClassDB::bind_method(D_METHOD("set_from_position", "from_position"), &SquadData::set_from_position);
    ClassDB::bind_method(D_METHOD("get_from_position"), &SquadData::get_from_position);
    ClassDB::bind_method(D_METHOD("set_to_position", "to_position"), &SquadData::set_to_position);
    ClassDB::bind_method(D_METHOD("get_to_position"), &SquadData::get_to_position);
    ClassDB::bind_method(D_METHOD("is_traveling"), &SquadData::is_traveling);
    ClassDB::bind_method(D_METHOD("get_status_text"), &SquadData::get_status_text);

    ADD_PROPERTY(PropertyInfo(Variant::STRING, "squad_name"), "set_squad_name", "get_squad_name");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "faction_id"), "set_faction_id", "get_faction_id");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "current_location_id"), "set_current_location_id", "get_current_location_id");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "home_location_id"), "set_home_location_id", "get_home_location_id");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "squad_state"), "set_squad_state", "get_squad_state");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "target_location_id"), "set_target_location_id", "get_target_location_id");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "travel_elapsed"), "set_travel_elapsed", "get_travel_elapsed");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "travel_duration"), "set_travel_duration", "get_travel_duration");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "route_step"), "set_route_step", "get_route_step");
    ADD_PROPERTY(PropertyInfo(Variant::VECTOR3, "from_position"), "set_from_position", "get_from_position");
    ADD_PROPERTY(PropertyInfo(Variant::VECTOR3, "to_position"), "set_to_position", "get_to_position");

    ClassDB::bind_method(D_METHOD("set_npc_count", "count"), &SquadData::set_npc_count);
    ClassDB::bind_method(D_METHOD("get_npc_count"), &SquadData::get_npc_count);
    ADD_PROPERTY(PropertyInfo(Variant::INT, "npc_count"), "set_npc_count", "get_npc_count");
}

void SquadData::set_squad_name(const String &p_squad_name) {
    squad_name = p_squad_name;
}

String SquadData::get_squad_name() const {
    return squad_name;
}

void SquadData::set_faction_id(int64_t p_faction_id) {
    faction_id = p_faction_id;
}

int64_t SquadData::get_faction_id() const {
    return faction_id;
}

void SquadData::set_current_location_id(int64_t p_current_location_id) {
    current_location_id = p_current_location_id;
}

int64_t SquadData::get_current_location_id() const {
    return current_location_id;
}

void SquadData::set_home_location_id(int64_t p_home_location_id) {
    home_location_id = p_home_location_id;
}

int64_t SquadData::get_home_location_id() const {
    return home_location_id;
}

void SquadData::set_squad_state(int64_t p_squad_state) {
    squad_state = p_squad_state;
}

int64_t SquadData::get_squad_state() const {
    return squad_state;
}

void SquadData::set_target_location_id(int64_t p_target_location_id) {
    target_location_id = p_target_location_id;
}

int64_t SquadData::get_target_location_id() const {
    return target_location_id;
}

void SquadData::set_travel_elapsed(double p_travel_elapsed) {
    travel_elapsed = p_travel_elapsed;
}

double SquadData::get_travel_elapsed() const {
    return travel_elapsed;
}

void SquadData::set_travel_duration(double p_travel_duration) {
    travel_duration = p_travel_duration;
}

double SquadData::get_travel_duration() const {
    return travel_duration;
}

void SquadData::set_route_step(int64_t p_route_step) {
    route_step = p_route_step;
}

int64_t SquadData::get_route_step() const {
    return route_step;
}

void SquadData::set_from_position(const Vector3 &p_from_position) {
    from_position = p_from_position;
}

Vector3 SquadData::get_from_position() const {
    return from_position;
}

void SquadData::set_to_position(const Vector3 &p_to_position) {
    to_position = p_to_position;
}

Vector3 SquadData::get_to_position() const {
    return to_position;
}

void SquadData::set_npc_count(int64_t p_count) { npc_count = p_count; }
int64_t SquadData::get_npc_count() const { return npc_count; }

bool SquadData::is_traveling() const {
    return squad_state == STATE_MOVING;
}

String SquadData::get_status_text() const {
    if (squad_state == STATE_MOVING) {
        return vformat("%s moving %d->%d", squad_name, current_location_id, target_location_id);
    }
    if (squad_state == STATE_RESTING) {
        return vformat("%s resting @%d", squad_name, current_location_id);
    }
    return vformat("%s idle @%d", squad_name, current_location_id);
}