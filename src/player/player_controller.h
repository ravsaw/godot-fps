#ifndef GODOT_FPS_PLAYER_CONTROLLER_H
#define GODOT_FPS_PLAYER_CONTROLLER_H

#include <godot_cpp/classes/camera3d.hpp>
#include <godot_cpp/classes/capsule_shape3d.hpp>
#include <godot_cpp/classes/character_body3d.hpp>
#include <godot_cpp/classes/collision_shape3d.hpp>
#include <godot_cpp/classes/input_event.hpp>

namespace godot {

class WeaponBase;

class PlayerController : public CharacterBody3D {
    GDCLASS(PlayerController, CharacterBody3D)

private:
    bool input_enabled = true;
    bool dead = false;
    float walk_speed = 4.0f;
    float sprint_speed = 7.0f;
    float crouch_speed = 2.2f;
    float gravity = 18.0f;
    float mouse_sensitivity = 0.0025f;
    float max_pitch_rad = 1.3962634f; // 80 degrees
    float max_health = 100.0f;
    float health = 100.0f;
    bool crouching = false;
    float stand_camera_height = 1.6f;
    float crouch_camera_height = 1.1f;
    float head_bob_time = 0.0f;
    float head_bob_amp_walk = 0.065f;
    float head_bob_amp_sprint = 0.095f;
    float head_bob_amp_crouch = 0.04f;
    float head_bob_side_amp_walk = 0.016f;
    float head_bob_side_amp_sprint = 0.023f;
    float head_bob_side_amp_crouch = 0.010f;
    float head_bob_roll_amp_walk = 0.014f;
    float head_bob_roll_amp_sprint = 0.020f;
    float head_bob_roll_amp_crouch = 0.009f;
    float head_bob_freq_walk = 9.0f;
    float head_bob_freq_sprint = 13.0f;
    float head_bob_freq_crouch = 6.0f;
    CollisionShape3D *body_collision = nullptr;
    Ref<CapsuleShape3D> body_capsule_shape;
    float stand_capsule_height = 1.0f;
    float stand_collision_y = 1.0f;
    float hip_fov = 75.0f;
    float ads_fov = 58.0f;
    float ads_scope_fov = 38.0f;
    float ads_lerp_speed = 12.0f;

    float camera_pitch = 0.0f;

    NodePath camera_path;
    NodePath weapon_path;

    Camera3D *camera = nullptr;
    WeaponBase *weapon = nullptr;

protected:
    static void _bind_methods();
    void _update_crouch_state(bool p_crouch);

public:
    void _ready() override;
    void _physics_process(double p_delta) override;
    void _unhandled_input(const Ref<InputEvent> &p_event) override;

    void set_input_enabled(bool p_enabled);
    bool is_input_enabled() const;

    Vector3 get_velocity_local() const;
    Transform3D get_camera_transform() const;

    void set_camera_path(const NodePath &p_path);
    NodePath get_camera_path() const;

    void set_weapon_path(const NodePath &p_path);
    NodePath get_weapon_path() const;

    void apply_damage(float p_amount, int p_source_id = -1);
    float get_health() const;
    bool is_dead() const;
    void respawn_at(const Vector3 &p_world_position);
};

} // namespace godot

#endif
