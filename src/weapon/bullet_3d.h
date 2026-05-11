#ifndef GODOT_FPS_BULLET_3D_H
#define GODOT_FPS_BULLET_3D_H

#include <godot_cpp/classes/character_body3d.hpp>

namespace godot {

class Bullet3D : public CharacterBody3D {
    GDCLASS(Bullet3D, CharacterBody3D)

private:
    Vector3 _velocity;
    float _damage = 20.0f;
    float _gravity = 4.0f;
    int _max_ricochets = 2;
    float _ricochet_retention = 0.65f;
    float _ttl = 4.0f;
    int _ricochet_count = 0;

protected:
    static void _bind_methods();

public:
    void _ready() override;
    void _physics_process(double p_delta) override;

    void initialize(const Vector3 &p_direction, float p_damage, float p_speed);
};

} // namespace godot

#endif
