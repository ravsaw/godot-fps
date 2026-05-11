#include "player_controller.h"

#include <godot_cpp/classes/capsule_shape3d.hpp>
#include <godot_cpp/classes/collision_shape3d.hpp>
#include <godot_cpp/classes/input.hpp>
#include <godot_cpp/classes/global_constants.hpp>
#include <godot_cpp/classes/input_event_mouse_motion.hpp>
#include <godot_cpp/classes/input_event_key.hpp>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include "weapon/weapon_base.h"

using namespace godot;

void PlayerController::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_input_enabled", "enabled"), &PlayerController::set_input_enabled);
    ClassDB::bind_method(D_METHOD("is_input_enabled"), &PlayerController::is_input_enabled);
    ClassDB::bind_method(D_METHOD("get_velocity_local"), &PlayerController::get_velocity_local);
    ClassDB::bind_method(D_METHOD("get_camera_transform"), &PlayerController::get_camera_transform);
    ClassDB::bind_method(D_METHOD("set_camera_path", "path"), &PlayerController::set_camera_path);
    ClassDB::bind_method(D_METHOD("get_camera_path"), &PlayerController::get_camera_path);
    ClassDB::bind_method(D_METHOD("set_weapon_path", "path"), &PlayerController::set_weapon_path);
    ClassDB::bind_method(D_METHOD("get_weapon_path"), &PlayerController::get_weapon_path);
    ClassDB::bind_method(D_METHOD("apply_damage", "amount", "source_id"), &PlayerController::apply_damage, DEFVAL(-1));
    ClassDB::bind_method(D_METHOD("get_health"), &PlayerController::get_health);
    ClassDB::bind_method(D_METHOD("is_dead"), &PlayerController::is_dead);
    ClassDB::bind_method(D_METHOD("respawn_at", "world_position"), &PlayerController::respawn_at);

    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "input_enabled"), "set_input_enabled", "is_input_enabled");
    ADD_PROPERTY(PropertyInfo(Variant::NODE_PATH, "camera_path"), "set_camera_path", "get_camera_path");
    ADD_PROPERTY(PropertyInfo(Variant::NODE_PATH, "weapon_path"), "set_weapon_path", "get_weapon_path");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "health", PROPERTY_HINT_NONE, "", PROPERTY_USAGE_READ_ONLY), "", "get_health");

    ADD_SIGNAL(MethodInfo("player_died"));
    ADD_SIGNAL(MethodInfo("player_took_damage", PropertyInfo(Variant::FLOAT, "amount")));
}

void PlayerController::_ready() {
    if (!camera_path.is_empty()) {
        camera = Object::cast_to<Camera3D>(get_node_or_null(camera_path));
    }
    if (!weapon_path.is_empty()) {
        weapon = Object::cast_to<WeaponBase>(get_node_or_null(weapon_path));
    }

    if (camera != nullptr) {
        camera_pitch = camera->get_rotation().x;
        stand_camera_height = camera->get_position().y;
        crouch_camera_height = stand_camera_height - 0.5f;
        hip_fov = camera->get_fov();
    }

    for (int i = 0; i < get_child_count(); i++) {
        CollisionShape3D *shape_node = Object::cast_to<CollisionShape3D>(get_child(i));
        if (shape_node == nullptr) {
            continue;
        }
        Ref<CapsuleShape3D> capsule = shape_node->get_shape();
        if (capsule.is_valid()) {
            body_collision = shape_node;
            body_capsule_shape = capsule;
            stand_capsule_height = capsule->get_height();
            stand_collision_y = shape_node->get_position().y;
            break;
        }
    }

    Input::get_singleton()->set_mouse_mode(Input::MOUSE_MODE_CAPTURED);
}

void PlayerController::_physics_process(double p_delta) {
    if (!input_enabled) {
        return;
    }

    if (camera == nullptr && !camera_path.is_empty()) {
        camera = Object::cast_to<Camera3D>(get_node_or_null(camera_path));
        if (camera != nullptr && stand_camera_height <= 0.01f) {
            stand_camera_height = camera->get_position().y;
            crouch_camera_height = stand_camera_height - 0.5f;
        }
    }
    if (camera == nullptr) {
        camera = Object::cast_to<Camera3D>(get_node_or_null(NodePath("PlayerCamera")));
        if (camera != nullptr && stand_camera_height <= 0.01f) {
            stand_camera_height = camera->get_position().y;
            crouch_camera_height = stand_camera_height - 0.5f;
        }
    }
    if (weapon == nullptr && !weapon_path.is_empty()) {
        weapon = Object::cast_to<WeaponBase>(get_node_or_null(weapon_path));
    }
    if (body_collision == nullptr || !body_capsule_shape.is_valid()) {
        for (int i = 0; i < get_child_count(); i++) {
            CollisionShape3D *shape_node = Object::cast_to<CollisionShape3D>(get_child(i));
            if (shape_node == nullptr) {
                continue;
            }
            Ref<CapsuleShape3D> capsule = shape_node->get_shape();
            if (capsule.is_valid()) {
                body_collision = shape_node;
                body_capsule_shape = capsule;
                stand_capsule_height = capsule->get_height();
                stand_collision_y = shape_node->get_position().y;
                break;
            }
        }
    }

    Input *input = Input::get_singleton();
    Vector2 move_input;
    move_input.x = input->get_action_strength("move_right") - input->get_action_strength("move_left");
    move_input.y = input->get_action_strength("move_backward") - input->get_action_strength("move_forward");

    Vector3 direction;
    Basis basis = get_global_transform().basis;
    direction += basis.get_column(0) * move_input.x;
    direction += basis.get_column(2) * move_input.y;
    direction.y = 0.0f;

    if (direction.length() > 0.0f) {
        direction = direction.normalized();
    }

    const bool crouch_pressed = input->is_action_pressed("crouch")
            || input->is_key_pressed(Key::KEY_CTRL)
            || input->is_key_pressed(Key::KEY_C);
    _update_crouch_state(crouch_pressed);

    const bool sprinting = input->is_action_pressed("sprint");
    float speed = walk_speed;
    if (crouching) {
        speed = crouch_speed;
    } else if (sprinting) {
        speed = sprint_speed;
    }

    Vector3 v = get_velocity();
    v.x = direction.x * speed;
    v.z = direction.z * speed;
    if (!is_on_floor()) {
        v.y -= gravity * static_cast<float>(p_delta);
    } else if (v.y < 0.0f) {
        v.y = 0.0f;
    }
    set_velocity(v);
    move_and_slide();

    if (camera != nullptr) {
        const bool aiming = Input::get_singleton()->is_mouse_button_pressed(MouseButton::MOUSE_BUTTON_RIGHT)
                && Input::get_singleton()->get_mouse_mode() == Input::MOUSE_MODE_CAPTURED;
        float target_fov = hip_fov;
        if (aiming) {
            const bool has_scope = (weapon != nullptr) && weapon->has_scope_attachment();
            target_fov = has_scope ? ads_scope_fov : ads_fov;
        }
        const float fov_lerp_t = Math::clamp(static_cast<float>(p_delta) * ads_lerp_speed, 0.0f, 1.0f);
        camera->set_fov(Math::lerp(camera->get_fov(), target_fov, fov_lerp_t));

        float bob_amp = head_bob_amp_walk;
        float side_amp = head_bob_side_amp_walk;
        float roll_amp = head_bob_roll_amp_walk;
        float bob_freq = head_bob_freq_walk;
        if (crouching) {
            bob_amp = head_bob_amp_crouch;
            side_amp = head_bob_side_amp_crouch;
            roll_amp = head_bob_roll_amp_crouch;
            bob_freq = head_bob_freq_crouch;
        } else if (sprinting) {
            bob_amp = head_bob_amp_sprint;
            side_amp = head_bob_side_amp_sprint;
            roll_amp = head_bob_roll_amp_sprint;
            bob_freq = head_bob_freq_sprint;
        }

        const bool moving = direction.length_squared() > 0.01f && is_on_floor();
        if (moving) {
            head_bob_time += static_cast<float>(p_delta) * bob_freq;
        }

        const float bob_offset = moving ? Math::sin(head_bob_time) * bob_amp : 0.0f;
        const float side_offset = moving ? Math::cos(head_bob_time * 0.5f) * side_amp : 0.0f;
        const float roll_offset = moving ? Math::sin(head_bob_time * 0.5f) * roll_amp : 0.0f;
        const float target_base_y = crouching ? crouch_camera_height : stand_camera_height;
        const float target_y = target_base_y + bob_offset;
        const float target_x = side_offset;

        Vector3 cam_pos = camera->get_position();
        cam_pos.y = cam_pos.y + (target_y - cam_pos.y) * (moving ? 0.7f : 0.2f);
        cam_pos.x = cam_pos.x + (target_x - cam_pos.x) * (moving ? 0.6f : 0.18f);
        camera->set_position(cam_pos);

        Vector3 cam_rot = camera->get_rotation();
        cam_rot.z = cam_rot.z + (roll_offset - cam_rot.z) * (moving ? 0.65f : 0.18f);
        camera->set_rotation(cam_rot);
    }

    if (weapon != nullptr) {
        weapon->trigger_fire(input->is_action_pressed("fire"));
        if (input->is_action_just_pressed("reload")) {
            weapon->trigger_reload();
        }
    }

}

void PlayerController::_update_crouch_state(bool p_crouch) {
    crouching = p_crouch;

    if (body_collision != nullptr && body_capsule_shape.is_valid()) {
        const float crouch_factor = 0.58f;
        const float target_height = crouching ? stand_capsule_height * crouch_factor : stand_capsule_height;
        body_capsule_shape->set_height(target_height);

        Vector3 shape_pos = body_collision->get_position();
        shape_pos.y = crouching ? stand_collision_y * crouch_factor : stand_collision_y;
        body_collision->set_position(shape_pos);
    }
}

void PlayerController::_unhandled_input(const Ref<InputEvent> &p_event) {
    if (!input_enabled || p_event.is_null()) {
        return;
    }

    Ref<InputEventKey> key_event = p_event;
    if (key_event.is_valid() && key_event->is_pressed() && !key_event->is_echo() && key_event->get_keycode() == Key::KEY_ESCAPE) {
        Input *input = Input::get_singleton();
        const Input::MouseMode current = input->get_mouse_mode();
        input->set_mouse_mode(current == Input::MOUSE_MODE_CAPTURED ? Input::MOUSE_MODE_VISIBLE : Input::MOUSE_MODE_CAPTURED);
        return;
    }

    if (camera == nullptr) {
        return;
    }

    if (Input::get_singleton()->get_mouse_mode() != Input::MOUSE_MODE_CAPTURED) {
        return;
    }

    Ref<InputEventMouseMotion> motion = p_event;
    if (motion.is_valid()) {
        rotate_y(-motion->get_relative().x * mouse_sensitivity);
        camera_pitch -= motion->get_relative().y * mouse_sensitivity;
        if (camera_pitch > max_pitch_rad) {
            camera_pitch = max_pitch_rad;
        }
        if (camera_pitch < -max_pitch_rad) {
            camera_pitch = -max_pitch_rad;
        }

        Vector3 cam_rot = camera->get_rotation();
        cam_rot.x = camera_pitch;
        camera->set_rotation(cam_rot);
    }
}

void PlayerController::set_input_enabled(bool p_enabled) {
    input_enabled = p_enabled;
}

bool PlayerController::is_input_enabled() const {
    return input_enabled;
}

Vector3 PlayerController::get_velocity_local() const {
    return get_velocity();
}

Transform3D PlayerController::get_camera_transform() const {
    if (camera == nullptr) {
        return Transform3D();
    }
    return camera->get_global_transform();
}

void PlayerController::set_camera_path(const NodePath &p_path) {
    camera_path = p_path;
}

NodePath PlayerController::get_camera_path() const {
    return camera_path;
}

void PlayerController::set_weapon_path(const NodePath &p_path) {
    weapon_path = p_path;
}

NodePath PlayerController::get_weapon_path() const {
    return weapon_path;
}

void PlayerController::apply_damage(float p_amount, int p_source_id) {
    if (dead || p_amount <= 0.0f) {
        return;
    }

    health -= p_amount;
    if (health < 0.0f) {
        health = 0.0f;
    }

    UtilityFunctions::print("Player took damage:", p_amount, "source:", p_source_id, "hp:", health);
    emit_signal("player_took_damage", p_amount);

    if (health <= 0.0f) {
        dead = true;
        input_enabled = false;
        set_velocity(Vector3());
        UtilityFunctions::print("Player died. Source:", p_source_id);
        emit_signal("player_died");
    }
}

float PlayerController::get_health() const {
    return health;
}

bool PlayerController::is_dead() const {
    return dead;
}

void PlayerController::respawn_at(const Vector3 &p_world_position) {
    dead = false;
    input_enabled = true;
    crouching = false;
    health = max_health;
    set_global_position(p_world_position);
    set_velocity(Vector3());
    camera_pitch = 0.0f;
    head_bob_time = 0.0f;

    if (camera != nullptr) {
        Vector3 cam_pos = camera->get_position();
        cam_pos.y = stand_camera_height;
        camera->set_position(cam_pos);
        camera->set_rotation(Vector3());
        camera->set_fov(hip_fov);
    }
    if (body_collision != nullptr && body_capsule_shape.is_valid()) {
        body_capsule_shape->set_height(stand_capsule_height);
        Vector3 shape_pos = body_collision->get_position();
        shape_pos.y = stand_collision_y;
        body_collision->set_position(shape_pos);
    }

    Input::get_singleton()->set_mouse_mode(Input::MOUSE_MODE_CAPTURED);
}
