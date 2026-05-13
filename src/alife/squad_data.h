#ifndef GODOT_FPS_SQUAD_DATA_H
#define GODOT_FPS_SQUAD_DATA_H

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <vector>

namespace godot {

class SquadData : public Resource {
    GDCLASS(SquadData, Resource)

public:
    enum SquadState {
        STATE_IDLE = 0,
        STATE_MOVING = 1,
        STATE_RESTING = 2,
    };

    enum FormationType {
        FORMATION_REST_SCATTERED = 0,
        FORMATION_MARCH_TIGHT = 1,
    };

private:
    String squad_name = "Squad";
    int64_t faction_id = -1;
    int64_t current_location_id = -1;
    int64_t home_location_id = -1;
    int64_t squad_state = STATE_IDLE;
    int64_t target_location_id = -1;
    int64_t npc_count = 3;
    double travel_elapsed = 0.0;
    double travel_duration = 1.0;
    int64_t route_step = 0;
    Vector3 from_position;
    Vector3 to_position;
    int64_t formation_type = FORMATION_MARCH_TIGHT;
    bool arrived_this_frame = false;
    Vector3 computed_position;
    TypedArray<Vector3> formation_positions;

    std::vector<int64_t> goal_stack;

protected:
    static void _bind_methods();

public:
    void set_squad_name(const String &p_squad_name);
    String get_squad_name() const;

    void set_faction_id(int64_t p_faction_id);
    int64_t get_faction_id() const;

    void set_current_location_id(int64_t p_current_location_id);
    int64_t get_current_location_id() const;

    void set_home_location_id(int64_t p_home_location_id);
    int64_t get_home_location_id() const;

    void set_squad_state(int64_t p_squad_state);
    int64_t get_squad_state() const;

    void set_target_location_id(int64_t p_target_location_id);
    int64_t get_target_location_id() const;

    void set_travel_elapsed(double p_travel_elapsed);
    double get_travel_elapsed() const;

    void set_travel_duration(double p_travel_duration);
    double get_travel_duration() const;

    void set_route_step(int64_t p_route_step);
    int64_t get_route_step() const;

    void set_from_position(const Vector3 &p_from_position);
    Vector3 get_from_position() const;

    void set_to_position(const Vector3 &p_to_position);
    Vector3 get_to_position() const;

    void set_npc_count(int64_t p_count);
    int64_t get_npc_count() const;

    bool is_traveling() const;
    String get_status_text() const;

    // Movement & Formation simulation (Phase 1 C++ migration)
    void tick_movement(double delta);
    void compute_formation_positions();
    TypedArray<Vector3> get_formation_positions() const;
    void set_formation_type(int64_t p_type);
    int64_t get_formation_type() const;
    bool get_arrived_this_frame() const;
    Vector3 get_computed_position() const;

    // Goal stack (TIER 2 C++ migration)
    int64_t get_active_goal() const;
    void set_explicit_goal(int64_t goal_id);
    void push_low_priority_goal(int64_t goal_id);
    int64_t pop_goal_and_get_next();
    int64_t get_goal_stack_size() const;
    void clear_goal();
};

} // namespace godot

VARIANT_ENUM_CAST(godot::SquadData::SquadState);
VARIANT_ENUM_CAST(godot::SquadData::FormationType);

#endif