#ifndef GODOT_FPS_ZONE_MANAGER_H
#define GODOT_FPS_ZONE_MANAGER_H

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include "world/smart_location.h"
#include "world/world_graph.h"

namespace godot {

class ZoneManager : public Node {
    GDCLASS(ZoneManager, Node)

public:
    static constexpr int64_t FACTION_NONE = -1;
    static constexpr int64_t FACTION_SCAVENGERS = 1;
    static constexpr int64_t FACTION_THRESHOLD_GUARDIANS = 2;

private:
    Ref<WorldGraph> world_graph;
    TypedArray<SmartLocation> locations;
    StringName current_zone_id = StringName("zone_a");

protected:
    static void _bind_methods();

public:
    ZoneManager();

    void _ready() override;

    Ref<WorldGraph> get_world_graph() const;
    StringName get_current_zone_id() const;
    TypedArray<SmartLocation> get_locations() const;
    int64_t get_nearest_location_id(const Vector3 &p_world_pos) const;
    Ref<SmartLocation> get_nearest_location(const Vector3 &p_world_pos) const;
    String get_zone_debug_text(const Vector3 &p_world_pos) const;
    String get_faction_name(int64_t p_faction_id) const;
    void request_zone_transition(const StringName &p_to_id);

private:
    void load_zone(const StringName &p_zone_id);
    TypedArray<SmartLocation> build_locations_for_zone(const StringName &p_zone_id) const;
    Ref<SmartLocation> make_location(int64_t p_location_id, const String &p_location_name, const StringName &p_zone_id, const StringName &p_location_type, const Vector3 &p_world_position, const PackedInt32Array &p_neighbors) const;
    int64_t get_default_owner_for(const StringName &p_location_type) const;
};

} // namespace godot

#endif