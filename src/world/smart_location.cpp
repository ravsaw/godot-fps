#include "world/smart_location.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void SmartLocation::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_location_id", "location_id"), &SmartLocation::set_location_id);
    ClassDB::bind_method(D_METHOD("get_location_id"), &SmartLocation::get_location_id);
    ClassDB::bind_method(D_METHOD("set_location_name", "location_name"), &SmartLocation::set_location_name);
    ClassDB::bind_method(D_METHOD("get_location_name"), &SmartLocation::get_location_name);
    ClassDB::bind_method(D_METHOD("set_zone_id", "zone_id"), &SmartLocation::set_zone_id);
    ClassDB::bind_method(D_METHOD("get_zone_id"), &SmartLocation::get_zone_id);
    ClassDB::bind_method(D_METHOD("set_location_type", "location_type"), &SmartLocation::set_location_type);
    ClassDB::bind_method(D_METHOD("get_location_type"), &SmartLocation::get_location_type);
    ClassDB::bind_method(D_METHOD("set_world_position", "world_position"), &SmartLocation::set_world_position);
    ClassDB::bind_method(D_METHOD("get_world_position"), &SmartLocation::get_world_position);
    ClassDB::bind_method(D_METHOD("set_max_population", "max_population"), &SmartLocation::set_max_population);
    ClassDB::bind_method(D_METHOD("get_max_population"), &SmartLocation::get_max_population);
    ClassDB::bind_method(D_METHOD("set_faction_owner_id", "faction_owner_id"), &SmartLocation::set_faction_owner_id);
    ClassDB::bind_method(D_METHOD("get_faction_owner_id"), &SmartLocation::get_faction_owner_id);
    ClassDB::bind_method(D_METHOD("set_neighbor_location_ids", "neighbor_location_ids"), &SmartLocation::set_neighbor_location_ids);
    ClassDB::bind_method(D_METHOD("get_neighbor_location_ids"), &SmartLocation::get_neighbor_location_ids);
    ClassDB::bind_method(D_METHOD("set_path_points", "path_points"), &SmartLocation::set_path_points);
    ClassDB::bind_method(D_METHOD("get_path_points"), &SmartLocation::get_path_points);
    ClassDB::bind_method(D_METHOD("to_debug_string"), &SmartLocation::to_debug_string);

    ADD_PROPERTY(PropertyInfo(Variant::INT, "location_id"), "set_location_id", "get_location_id");
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "location_name"), "set_location_name", "get_location_name");
    ADD_PROPERTY(PropertyInfo(Variant::STRING_NAME, "zone_id"), "set_zone_id", "get_zone_id");
    ADD_PROPERTY(PropertyInfo(Variant::STRING_NAME, "location_type"), "set_location_type", "get_location_type");
    ADD_PROPERTY(PropertyInfo(Variant::VECTOR3, "world_position"), "set_world_position", "get_world_position");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "max_population"), "set_max_population", "get_max_population");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "faction_owner_id"), "set_faction_owner_id", "get_faction_owner_id");
    ADD_PROPERTY(PropertyInfo(Variant::PACKED_INT32_ARRAY, "neighbor_location_ids"), "set_neighbor_location_ids", "get_neighbor_location_ids");
    ADD_PROPERTY(PropertyInfo(Variant::PACKED_VECTOR3_ARRAY, "path_points"), "set_path_points", "get_path_points");
}

void SmartLocation::set_location_id(int64_t p_location_id) {
    location_id = p_location_id;
}

int64_t SmartLocation::get_location_id() const {
    return location_id;
}

void SmartLocation::set_location_name(const String &p_location_name) {
    location_name = p_location_name;
}

String SmartLocation::get_location_name() const {
    return location_name;
}

void SmartLocation::set_zone_id(const StringName &p_zone_id) {
    zone_id = p_zone_id;
}

StringName SmartLocation::get_zone_id() const {
    return zone_id;
}

void SmartLocation::set_location_type(const StringName &p_location_type) {
    location_type = p_location_type;
}

StringName SmartLocation::get_location_type() const {
    return location_type;
}

void SmartLocation::set_world_position(const Vector3 &p_world_position) {
    world_position = p_world_position;
}

Vector3 SmartLocation::get_world_position() const {
    return world_position;
}

void SmartLocation::set_max_population(int64_t p_max_population) {
    max_population = p_max_population;
}

int64_t SmartLocation::get_max_population() const {
    return max_population;
}

void SmartLocation::set_faction_owner_id(int64_t p_faction_owner_id) {
    faction_owner_id = p_faction_owner_id;
}

int64_t SmartLocation::get_faction_owner_id() const {
    return faction_owner_id;
}

void SmartLocation::set_neighbor_location_ids(const PackedInt32Array &p_neighbor_location_ids) {
    neighbor_location_ids = p_neighbor_location_ids;
}

PackedInt32Array SmartLocation::get_neighbor_location_ids() const {
    return neighbor_location_ids;
}

void SmartLocation::set_path_points(const PackedVector3Array &p_path_points) {
    path_points = p_path_points;
}

PackedVector3Array SmartLocation::get_path_points() const {
    return path_points;
}

String SmartLocation::to_debug_string() const {
    return vformat("%s (%s)", location_name, String(location_type));
}