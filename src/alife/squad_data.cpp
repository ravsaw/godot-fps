#include "alife/squad_data.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void SquadData::_bind_methods() {
    BIND_ENUM_CONSTANT(STATE_IDLE);
    BIND_ENUM_CONSTANT(STATE_MOVING);
    BIND_ENUM_CONSTANT(STATE_RESTING);
    BIND_ENUM_CONSTANT(FORMATION_REST_SCATTERED);
    BIND_ENUM_CONSTANT(FORMATION_MARCH_TIGHT);

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

    // Phase 1 C++ migration methods
    ClassDB::bind_method(D_METHOD("tick_movement", "delta"), &SquadData::tick_movement);
    ClassDB::bind_method(D_METHOD("compute_formation_positions"), &SquadData::compute_formation_positions);
    ClassDB::bind_method(D_METHOD("get_formation_positions"), &SquadData::get_formation_positions);
    ClassDB::bind_method(D_METHOD("set_formation_type", "type"), &SquadData::set_formation_type);
    ClassDB::bind_method(D_METHOD("get_formation_type"), &SquadData::get_formation_type);
    ClassDB::bind_method(D_METHOD("get_arrived_this_frame"), &SquadData::get_arrived_this_frame);
    ClassDB::bind_method(D_METHOD("get_computed_position"), &SquadData::get_computed_position);

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

// ============================================================================
// Phase 1 C++ Migration: Movement & Formation Simulation
// ============================================================================

void SquadData::tick_movement(double delta) {
    arrived_this_frame = false;

    // Only tick if traveling
    if (squad_state != STATE_MOVING) {
        computed_position = from_position;
        return;
    }

    // Accumulate travel time
    travel_elapsed += delta;

    // Calculate interpolation parameter t (0 to 1)
    double t = travel_duration > 0.0 ? travel_elapsed / travel_duration : 1.0;
    t = CLAMP(t, 0.0, 1.0);

    // Interpolate position
    computed_position = from_position.lerp(to_position, t);

    // Check if arrived
    if (t >= 1.0) {
        arrived_this_frame = true;
        computed_position = to_position;
    }
}

void SquadData::compute_formation_positions() {
    // Clear and pre-allocate formation positions array
    formation_positions.clear();

    // Ensure formation_positions can hold up to 5 vectors (leader + 4 members max)
    for (int i = 0; i < 5; i++) {
        formation_positions.append(Vector3());
    }

    // Calculate travel direction
    Vector3 travel_dir = (to_position - from_position).normalized();
    if (travel_dir.length_squared() < 0.0001f) {
        travel_dir = Vector3(0, 0, 1); // Default forward if no movement
    }

    // Calculate right vector (perpendicular to travel direction)
    Vector3 right = travel_dir.cross(Vector3(0, 1, 0)).normalized();
    if (right.length_squared() < 0.0001f) {
        right = Vector3(1, 0, 0); // Default right if travel is vertical
    }

    // Get formation offsets based on NPC count
    const float member_offset = 1.2f; // Distance from leader
    const float side_offset = 0.85f;
    const float rear_offset = 0.8f;

    // Place leader at computed position
    Vector3 leader_pos = computed_position;
    formation_positions[0] = leader_pos;

    // Place members based on NPC count
    if (npc_count >= 2) {
        // Left member
        formation_positions[1] = leader_pos + right * (-side_offset) + travel_dir * member_offset;
    }
    if (npc_count >= 3) {
        // Right member
        formation_positions[2] = leader_pos + right * side_offset + travel_dir * member_offset;
    }
    if (npc_count >= 4) {
        // Rear member
        formation_positions[3] = leader_pos + travel_dir * (member_offset * 2.0f);
    }
    if (npc_count >= 5) {
        // Left-rear member
        formation_positions[4] = leader_pos + right * (-0.55f) + travel_dir * (member_offset * 2.2f);
    }
}

TypedArray<Vector3> SquadData::get_formation_positions() const {
    return formation_positions;
}

void SquadData::set_formation_type(int64_t p_type) {
    formation_type = p_type;
}

int64_t SquadData::get_formation_type() const {
    return formation_type;
}

bool SquadData::get_arrived_this_frame() const {
    return arrived_this_frame;
}

Vector3 SquadData::get_computed_position() const {
    return computed_position;
}