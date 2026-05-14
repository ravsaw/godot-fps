#ifndef GODOT_FPS_SMART_LOCATION_H
#define GODOT_FPS_SMART_LOCATION_H

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace godot {

class SmartLocation : public Resource {
    GDCLASS(SmartLocation, Resource)

private:
    int64_t location_id = -1;
    String location_name = "Unknown";
    StringName zone_id = StringName("zone_a");
    StringName location_type = StringName("camp");
    Vector3 world_position = Vector3();
    int64_t max_population = 6;
    int64_t faction_owner_id = -1;
    PackedInt32Array neighbor_location_ids;
    PackedVector3Array path_points;

protected:
    static void _bind_methods();

public:
    void set_location_id(int64_t p_location_id);
    int64_t get_location_id() const;

    void set_location_name(const String &p_location_name);
    String get_location_name() const;

    void set_zone_id(const StringName &p_zone_id);
    StringName get_zone_id() const;

    void set_location_type(const StringName &p_location_type);
    StringName get_location_type() const;

    void set_world_position(const Vector3 &p_world_position);
    Vector3 get_world_position() const;

    void set_max_population(int64_t p_max_population);
    int64_t get_max_population() const;

    void set_faction_owner_id(int64_t p_faction_owner_id);
    int64_t get_faction_owner_id() const;

    void set_neighbor_location_ids(const PackedInt32Array &p_neighbor_location_ids);
    PackedInt32Array get_neighbor_location_ids() const;

    void set_path_points(const PackedVector3Array &p_path_points);
    PackedVector3Array get_path_points() const;

    String to_debug_string() const;
};

} // namespace godot

#endif