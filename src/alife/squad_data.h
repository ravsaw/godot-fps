#ifndef GODOT_FPS_SQUAD_DATA_H
#define GODOT_FPS_SQUAD_DATA_H

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace godot {

class SquadData : public Resource {
    GDCLASS(SquadData, Resource)

public:
    enum SquadState {
        STATE_IDLE = 0,
        STATE_MOVING = 1,
        STATE_RESTING = 2,
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
};

} // namespace godot

VARIANT_ENUM_CAST(godot::SquadData::SquadState);

#endif