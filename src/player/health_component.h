#ifndef GODOT_FPS_HEALTH_COMPONENT_H
#define GODOT_FPS_HEALTH_COMPONENT_H

#include <godot_cpp/classes/node.hpp>

namespace godot {

class HealthComponent : public Node {
    GDCLASS(HealthComponent, Node)

private:
    float max_health = 100.0f;
    float health = 100.0f;
    bool dead = false;

protected:
    static void _bind_methods();

public:
    void set_max_health(float p_value);
    float get_max_health() const;

    void set_health(float p_value);
    float get_health() const;

    void apply_damage(float p_amount, int p_source_id = -1);
    void heal(float p_amount);
    bool is_dead() const;
};

} // namespace godot

#endif
