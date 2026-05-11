#include "world/zone_manager.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

namespace {

PackedInt32Array make_neighbor_ids(std::initializer_list<int32_t> p_ids) {
    PackedInt32Array result;
    for (int32_t id : p_ids) {
        result.append(id);
    }
    return result;
}

} // namespace

void ZoneManager::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_world_graph"), &ZoneManager::get_world_graph);
    ClassDB::bind_method(D_METHOD("get_current_zone_id"), &ZoneManager::get_current_zone_id);
    ClassDB::bind_method(D_METHOD("get_locations"), &ZoneManager::get_locations);
    ClassDB::bind_method(D_METHOD("get_nearest_location_id", "world_pos"), &ZoneManager::get_nearest_location_id);
    ClassDB::bind_method(D_METHOD("get_nearest_location", "world_pos"), &ZoneManager::get_nearest_location);
    ClassDB::bind_method(D_METHOD("get_zone_debug_text", "world_pos"), &ZoneManager::get_zone_debug_text);
    ClassDB::bind_method(D_METHOD("get_faction_name", "faction_id"), &ZoneManager::get_faction_name);
    ClassDB::bind_method(D_METHOD("request_zone_transition", "to_id"), &ZoneManager::request_zone_transition);

    ADD_SIGNAL(MethodInfo("zone_transition_started", PropertyInfo(Variant::STRING_NAME, "from_id"), PropertyInfo(Variant::STRING_NAME, "to_id")));
    ADD_SIGNAL(MethodInfo("zone_transition_finished", PropertyInfo(Variant::STRING_NAME, "from_id"), PropertyInfo(Variant::STRING_NAME, "to_id")));
}

ZoneManager::ZoneManager() {
    world_graph.instantiate();
}

void ZoneManager::_ready() {
    load_zone(current_zone_id);
}

Ref<WorldGraph> ZoneManager::get_world_graph() const {
    return world_graph;
}

StringName ZoneManager::get_current_zone_id() const {
    return current_zone_id;
}

TypedArray<SmartLocation> ZoneManager::get_locations() const {
    return locations;
}

int64_t ZoneManager::get_nearest_location_id(const Vector3 &p_world_pos) const {
    if (world_graph.is_null()) {
        return -1;
    }
    return world_graph->get_nearest_location_id(p_world_pos);
}

Ref<SmartLocation> ZoneManager::get_nearest_location(const Vector3 &p_world_pos) const {
    const int64_t location_id = get_nearest_location_id(p_world_pos);
    if (world_graph.is_null() || location_id < 0) {
        return Ref<SmartLocation>();
    }
    return world_graph->get_location(location_id);
}

String ZoneManager::get_zone_debug_text(const Vector3 &p_world_pos) const {
    const Ref<SmartLocation> nearest = get_nearest_location(p_world_pos);
    if (nearest.is_null()) {
        return vformat("Zone: %s | Loc: n/a", String(current_zone_id));
    }

    const String owner_name = get_faction_name(nearest->get_faction_owner_id());
    return vformat("Zone: %s | Loc: %s (%s) | Owner: %s", String(current_zone_id), nearest->get_location_name(), String(nearest->get_location_type()), owner_name);
}

String ZoneManager::get_faction_name(int64_t p_faction_id) const {
    switch (p_faction_id) {
        case FACTION_SCAVENGERS:
            return "Scavengers";
        case FACTION_THRESHOLD_GUARDIANS:
            return "Threshold Guardians";
        default:
            return "Neutral";
    }
}

void ZoneManager::request_zone_transition(const StringName &p_to_id) {
    if (p_to_id == current_zone_id) {
        return;
    }
    if (p_to_id != StringName("zone_a") && p_to_id != StringName("zone_b")) {
        return;
    }

    const StringName from_id = current_zone_id;
    emit_signal("zone_transition_started", from_id, p_to_id);
    load_zone(p_to_id);
    emit_signal("zone_transition_finished", from_id, p_to_id);
}

void ZoneManager::load_zone(const StringName &p_zone_id) {
    current_zone_id = p_zone_id;
    locations = build_locations_for_zone(p_zone_id);
    if (world_graph.is_valid()) {
        world_graph->set_locations(locations);
    }
}

TypedArray<SmartLocation> ZoneManager::build_locations_for_zone(const StringName &p_zone_id) const {
    TypedArray<SmartLocation> result;
    Vector3 zone_offset;
    if (p_zone_id == StringName("zone_b")) {
        zone_offset = Vector3(42.0, 0.0, 0.0);
    }

    result.append(make_location(1, "Scav Camp", p_zone_id, StringName("camp"), Vector3(-8, 0, -8) + zone_offset, make_neighbor_ids({2, 3})));
    result.append(make_location(2, "Workshop", p_zone_id, StringName("trader"), Vector3(-3, 0, -4) + zone_offset, make_neighbor_ids({1, 4})));
    result.append(make_location(3, "Ruins", p_zone_id, StringName("ruins"), Vector3(-10, 0, 3) + zone_offset, make_neighbor_ids({1, 5})));
    result.append(make_location(4, "Crossroad", p_zone_id, StringName("crossroad"), Vector3(0, 0, 0) + zone_offset, make_neighbor_ids({2, 5, 6})));
    result.append(make_location(5, "Threshold Checkpoint", p_zone_id, StringName("checkpoint"), Vector3(7, 0, -5) + zone_offset, make_neighbor_ids({3, 4, 7})));
    result.append(make_location(6, "Warehouse", p_zone_id, StringName("warehouse"), Vector3(6, 0, 6) + zone_offset, make_neighbor_ids({4, 8})));
    result.append(make_location(7, "Anomaly Field", p_zone_id, StringName("anomaly"), Vector3(11, 0, 2) + zone_offset, make_neighbor_ids({5, 8})));
    result.append(make_location(8, "Microzone Gate", p_zone_id, StringName("gate"), Vector3(14, 0, 8) + zone_offset, make_neighbor_ids({6, 7})));
    return result;
}

Ref<SmartLocation> ZoneManager::make_location(int64_t p_location_id, const String &p_location_name, const StringName &p_zone_id, const StringName &p_location_type, const Vector3 &p_world_position, const PackedInt32Array &p_neighbors) const {
    Ref<SmartLocation> location;
    location.instantiate();
    location->set_location_id(p_location_id);
    location->set_location_name(p_location_name);
    location->set_zone_id(p_zone_id);
    location->set_location_type(p_location_type);
    location->set_world_position(p_world_position);
    location->set_faction_owner_id(get_default_owner_for(p_location_type));
    location->set_neighbor_location_ids(p_neighbors);
    return location;
}

int64_t ZoneManager::get_default_owner_for(const StringName &p_location_type) const {
    if (p_location_type == StringName("camp") || p_location_type == StringName("trader") || p_location_type == StringName("ruins")) {
        return FACTION_SCAVENGERS;
    }
    if (p_location_type == StringName("checkpoint") || p_location_type == StringName("gate")) {
        return FACTION_THRESHOLD_GUARDIANS;
    }
    return FACTION_NONE;
}