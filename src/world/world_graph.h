#ifndef GODOT_FPS_WORLD_GRAPH_H
#define GODOT_FPS_WORLD_GRAPH_H

#include <unordered_map>
#include <vector>

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include "world/smart_location.h"

namespace godot {

class WorldGraph : public RefCounted {
    GDCLASS(WorldGraph, RefCounted)

private:
    std::unordered_map<int64_t, Ref<SmartLocation>> locations;
    std::unordered_map<int64_t, std::unordered_map<int64_t, double>> edge_distances;

protected:
    static void _bind_methods();

public:
    void set_locations(const TypedArray<SmartLocation> &p_locations);
    void add_location(const Ref<SmartLocation> &p_location);
    Ref<SmartLocation> get_location(int64_t p_location_id) const;
    PackedInt32Array get_neighbors(int64_t p_location_id) const;
    Dictionary get_neighbor_distances(int64_t p_location_id) const;
    bool has_connection(int64_t p_from_id, int64_t p_to_id) const;
    double get_connection_distance(int64_t p_from_id, int64_t p_to_id) const;
    PackedInt32Array get_shortest_path(int64_t p_from_id, int64_t p_to_id) const;
    PackedInt32Array get_all_location_ids() const;
    int64_t get_nearest_location_id(const Vector3 &p_world_pos) const;

private:
    void rebuild_edges();
    int64_t pop_closest_pending(std::vector<int64_t> &p_pending, const std::unordered_map<int64_t, double> &p_distances) const;
};

} // namespace godot

#endif