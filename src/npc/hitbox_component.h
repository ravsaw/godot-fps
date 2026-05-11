#ifndef GODOT_FPS_HITBOX_COMPONENT_H
#define GODOT_FPS_HITBOX_COMPONENT_H

#include <godot_cpp/classes/area3d.hpp>

namespace godot {

class HitboxComponent : public Area3D {
    GDCLASS(HitboxComponent, Area3D)

private:
    float damage_multiplier = 1.0f;

protected:
    static void _bind_methods();

public:
    void set_damage_multiplier(float p_value);
    float get_damage_multiplier() const;

    void apply_hit_damage(float p_base_damage, int p_source_id = -1);
};

} // namespace godot

#endif
