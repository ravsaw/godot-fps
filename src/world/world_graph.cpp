#include "world/world_graph.h"

#include <algorithm>

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void WorldGraph::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_locations", "locations"), &WorldGraph::set_locations);
    ClassDB::bind_method(D_METHOD("add_location", "location"), &WorldGraph::add_location);
    ClassDB::bind_method(D_METHOD("get_location", "location_id"), &WorldGraph::get_location);
    ClassDB::bind_method(D_METHOD("get_neighbors", "location_id"), &WorldGraph::get_neighbors);
    ClassDB::bind_method(D_METHOD("get_neighbor_distances", "location_id"), &WorldGraph::get_neighbor_distances);
    ClassDB::bind_method(D_METHOD("has_connection", "from_id", "to_id"), &WorldGraph::has_connection);
    ClassDB::bind_method(D_METHOD("get_connection_distance", "from_id", "to_id"), &WorldGraph::get_connection_distance);
    ClassDB::bind_method(D_METHOD("get_shortest_path", "from_id", "to_id"), &WorldGraph::get_shortest_path);
    ClassDB::bind_method(D_METHOD("get_all_location_ids"), &WorldGraph::get_all_location_ids);
    ClassDB::bind_method(D_METHOD("get_nearest_location_id", "world_pos"), &WorldGraph::get_nearest_location_id);
}

void WorldGraph::set_locations(const TypedArray<SmartLocation> &p_locations) {
    locations.clear();
    edge_distances.clear();

    for (int64_t i = 0; i < p_locations.size(); i++) {
        Ref<SmartLocation> location = p_locations[i];
        if (location.is_null()) {
            continue;
        }
        locations[location->get_location_id()] = location;
    }

    rebuild_edges();
}

void WorldGraph::add_location(const Ref<SmartLocation> &p_location) {
    if (p_location.is_null()) {
        return;
    }

    locations[p_location->get_location_id()] = p_location;
    rebuild_edges();
}

Ref<SmartLocation> WorldGraph::get_location(int64_t p_location_id) const {
    auto it = locations.find(p_location_id);
    if (it == locations.end()) {
        return Ref<SmartLocation>();
    }
    return it->second;
}

PackedInt32Array WorldGraph::get_neighbors(int64_t p_location_id) const {
    PackedInt32Array neighbors;
    auto it = edge_distances.find(p_location_id);
    if (it == edge_distances.end()) {
        return neighbors;
    }

    for (const auto &entry : it->second) {
        neighbors.append(static_cast<int32_t>(entry.first));
    }

    return neighbors;
}

Dictionary WorldGraph::get_neighbor_distances(int64_t p_location_id) const {
    Dictionary result;
    auto it = edge_distances.find(p_location_id);
    if (it == edge_distances.end()) {
        return result;
    }

    for (const auto &entry : it->second) {
        result[entry.first] = entry.second;
    }

    return result;
}

bool WorldGraph::has_connection(int64_t p_from_id, int64_t p_to_id) const {
    return get_connection_distance(p_from_id, p_to_id) >= 0.0;
}

double WorldGraph::get_connection_distance(int64_t p_from_id, int64_t p_to_id) const {
    if (p_from_id == p_to_id) {
        return 0.0;
    }
    if (locations.find(p_from_id) == locations.end() || locations.find(p_to_id) == locations.end()) {
        return -1.0;
    }

    std::unordered_map<int64_t, double> distances;
    distances[p_from_id] = 0.0;
    std::vector<int64_t> pending;
    pending.push_back(p_from_id);

    while (!pending.empty()) {
        const int64_t current_id = pop_closest_pending(pending, distances);
        const double current_distance = distances[current_id];
        if (current_id == p_to_id) {
            return current_distance;
        }

        auto edge_it = edge_distances.find(current_id);
        if (edge_it == edge_distances.end()) {
            continue;
        }

        for (const auto &entry : edge_it->second) {
            const int64_t neighbor_id = entry.first;
            const double candidate_distance = current_distance + entry.second;
            auto distance_it = distances.find(neighbor_id);
            if (distance_it == distances.end() || candidate_distance < distance_it->second) {
                distances[neighbor_id] = candidate_distance;
                if (std::find(pending.begin(), pending.end(), neighbor_id) == pending.end()) {
                    pending.push_back(neighbor_id);
                }
            }
        }
    }

    return -1.0;
}

PackedInt32Array WorldGraph::get_shortest_path(int64_t p_from_id, int64_t p_to_id) const {
    PackedInt32Array path;
    if (locations.find(p_from_id) == locations.end() || locations.find(p_to_id) == locations.end()) {
        return path;
    }
    if (p_from_id == p_to_id) {
        path.append(static_cast<int32_t>(p_from_id));
        return path;
    }

    std::unordered_map<int64_t, double> distances;
    std::unordered_map<int64_t, int64_t> previous;
    distances[p_from_id] = 0.0;

    std::vector<int64_t> pending;
    pending.push_back(p_from_id);

    while (!pending.empty()) {
        const int64_t current_id = pop_closest_pending(pending, distances);
        if (current_id == p_to_id) {
            break;
        }

        auto current_distance_it = distances.find(current_id);
        if (current_distance_it == distances.end()) {
            continue;
        }
        const double current_distance = current_distance_it->second;

        auto edge_it = edge_distances.find(current_id);
        if (edge_it == edge_distances.end()) {
            continue;
        }

        for (const auto &entry : edge_it->second) {
            const int64_t neighbor_id = entry.first;
            const double candidate_distance = current_distance + entry.second;
            auto distance_it = distances.find(neighbor_id);
            if (distance_it == distances.end() || candidate_distance < distance_it->second) {
                distances[neighbor_id] = candidate_distance;
                previous[neighbor_id] = current_id;
                if (std::find(pending.begin(), pending.end(), neighbor_id) == pending.end()) {
                    pending.push_back(neighbor_id);
                }
            }
        }
    }

    if (previous.find(p_to_id) == previous.end()) {
        return path;
    }

    std::vector<int64_t> reverse_path;
    reverse_path.push_back(p_to_id);
    int64_t cursor = p_to_id;
    while (previous.find(cursor) != previous.end()) {
        cursor = previous[cursor];
        reverse_path.push_back(cursor);
        if (cursor == p_from_id) {
            break;
        }
    }

    if (reverse_path.empty() || reverse_path.back() != p_from_id) {
        return PackedInt32Array();
    }

    for (auto it = reverse_path.rbegin(); it != reverse_path.rend(); ++it) {
        path.append(static_cast<int32_t>(*it));
    }
    return path;
}

PackedInt32Array WorldGraph::get_all_location_ids() const {
    std::vector<int64_t> ids;
    ids.reserve(locations.size());
    for (const auto &entry : locations) {
        ids.push_back(entry.first);
    }
    std::sort(ids.begin(), ids.end());

    PackedInt32Array result;
    for (int64_t id : ids) {
        result.append(static_cast<int32_t>(id));
    }
    return result;
}

int64_t WorldGraph::get_nearest_location_id(const Vector3 &p_world_pos) const {
    int64_t best_id = -1;
    double best_dist_sq = Math_INF;

    for (const auto &entry : locations) {
        const Ref<SmartLocation> &location = entry.second;
        if (location.is_null()) {
            continue;
        }

        const double dist_sq = p_world_pos.distance_squared_to(location->get_world_position());
        if (dist_sq < best_dist_sq) {
            best_dist_sq = dist_sq;
            best_id = entry.first;
        }
    }

    return best_id;
}

void WorldGraph::rebuild_edges() {
    edge_distances.clear();
    for (const auto &entry : locations) {
        edge_distances[entry.first] = std::unordered_map<int64_t, double>();
    }

    for (const auto &entry : locations) {
        const Ref<SmartLocation> &location = entry.second;
        if (location.is_null()) {
            continue;
        }

        const PackedInt32Array neighbors = location->get_neighbor_location_ids();
        for (int64_t i = 0; i < neighbors.size(); i++) {
            const int64_t neighbor_id = neighbors[i];
            auto neighbor_it = locations.find(neighbor_id);
            if (neighbor_it == locations.end() || neighbor_it->second.is_null()) {
                continue;
            }

            const Vector3 from_pos = location->get_world_position();
            const Vector3 to_pos = neighbor_it->second->get_world_position();
            const PackedVector3Array path_points = location->get_path_points();

            double distance;
            if (!path_points.is_empty()) {
                // Use Bezier curve distance if path_points defined
                distance = compute_bezier_curve_length(from_pos, to_pos, path_points);
            } else {
                // Fallback to straight-line distance
                distance = from_pos.distance_to(to_pos);
            }

            edge_distances[location->get_location_id()][neighbor_id] = distance;
            edge_distances[neighbor_id][location->get_location_id()] = distance;
        }
    }
}

double WorldGraph::compute_bezier_curve_length(const Vector3 &p_start, const Vector3 &p_end, const PackedVector3Array &p_control_points) const {
    // Compute length of cubic Bezier curve with adaptive subdivision
    // Curve is defined by start, control points, and end
    // Uses simple arc-length approximation by subdividing the curve

    // For a cubic Bezier defined by P0, P1, P2, P3 (start, 2 controls, end)
    // We evaluate the curve at regular intervals and sum distances
    // This is approximate but sufficient for pathfinding
    
    if (p_control_points.is_empty()) {
        return p_start.distance_to(p_end);
    }

    // Use the control points as intermediate waypoints
    // The curve passes through start and end, uses control points as guides
    double total_length = 0.0;
    Vector3 current_pos = p_start;

    // Walk along the path: start -> each control point -> end
    for (int i = 0; i < static_cast<int>(p_control_points.size()); i++) {
        const Vector3 next_pos = p_control_points[i];
        total_length += current_pos.distance_to(next_pos);
        current_pos = next_pos;
    }

    // Add distance from last control point to end
    total_length += current_pos.distance_to(p_end);

    return total_length;
}

int64_t WorldGraph::pop_closest_pending(std::vector<int64_t> &p_pending, const std::unordered_map<int64_t, double> &p_distances) const {
    int best_index = 0;
    int64_t best_id = p_pending[0];
    double best_distance = p_distances.at(best_id);

    for (int i = 1; i < static_cast<int>(p_pending.size()); i++) {
        const int64_t candidate_id = p_pending[i];
        auto candidate_it = p_distances.find(candidate_id);
        if (candidate_it == p_distances.end()) {
            continue;
        }
        if (candidate_it->second < best_distance) {
            best_distance = candidate_it->second;
            best_index = i;
            best_id = candidate_id;
        }
    }

    p_pending.erase(p_pending.begin() + best_index);
    return best_id;
}