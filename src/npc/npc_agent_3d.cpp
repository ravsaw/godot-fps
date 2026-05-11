#include "npc_agent_3d.h"

#include <godot_cpp/core/math.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

void NpcAgent3D::_bind_methods() {
    ClassDB::bind_method(D_METHOD("initialize_from_snapshot", "snapshot"), &NpcAgent3D::initialize_from_snapshot);
    ClassDB::bind_method(D_METHOD("export_snapshot"), &NpcAgent3D::export_snapshot);
    ClassDB::bind_method(D_METHOD("set_target_position", "world_pos"), &NpcAgent3D::set_target_position);
    ClassDB::bind_method(D_METHOD("set_combat_target_node", "target"), &NpcAgent3D::set_combat_target_node);
    ClassDB::bind_method(D_METHOD("set_npc_id", "id"), &NpcAgent3D::set_npc_id);
    ClassDB::bind_method(D_METHOD("get_npc_id"), &NpcAgent3D::get_npc_id);
    ClassDB::bind_method(D_METHOD("set_state", "state"), &NpcAgent3D::set_state);
    ClassDB::bind_method(D_METHOD("get_state"), &NpcAgent3D::get_state);
    ClassDB::bind_method(D_METHOD("apply_damage", "amount", "source_id"), &NpcAgent3D::apply_damage, DEFVAL(-1));
    ClassDB::bind_method(D_METHOD("get_health"), &NpcAgent3D::get_health);

    ADD_PROPERTY(PropertyInfo(Variant::INT, "npc_id"), "set_npc_id", "get_npc_id");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "state"), "set_state", "get_state");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "health", PROPERTY_HINT_NONE, "", PROPERTY_USAGE_READ_ONLY), "", "get_health");

    ADD_SIGNAL(MethodInfo("npc_died", PropertyInfo(Variant::INT, "npc_id"), PropertyInfo(Variant::INT, "source_id")));
    ADD_SIGNAL(MethodInfo("npc_state_changed", PropertyInfo(Variant::INT, "npc_id"), PropertyInfo(Variant::INT, "new_state")));
}

void NpcAgent3D::_ready() {
    if (navigation_agent == nullptr) {
        navigation_agent = memnew(NavigationAgent3D);
        navigation_agent->set_name("NavigationAgent3D");
        navigation_agent->set_path_desired_distance(0.3f);
        navigation_agent->set_target_desired_distance(0.4f);
        add_child(navigation_agent);
    }
}

void NpcAgent3D::_physics_process(double p_delta) {
    if (navigation_agent == nullptr) {
        navigation_agent = Object::cast_to<NavigationAgent3D>(get_node_or_null(NodePath("NavigationAgent3D")));
    }

    if (has_target_position) {
        Vector3 move_target = target_position;
        if (navigation_agent != nullptr) {
            navigation_agent->set_target_position(target_position);
            if (navigation_agent->is_target_reachable() && !navigation_agent->is_navigation_finished()) {
                const Vector3 nav_next = navigation_agent->get_next_path_position();
                if ((nav_next - get_global_position()).length() > 0.08f) {
                    move_target = nav_next;
                }
            }
        }

        Vector3 delta = move_target - get_global_position();
        delta.y = 0.0f;

        if (delta.length() > 0.15f) {
            Vector3 dir = delta.normalized();

            // Rotate NPC to face movement direction so front markers and FOV are meaningful.
            Vector3 rot = get_rotation();
            const float target_yaw = Math::atan2(-dir.x, -dir.z);
            rot.y = Math::lerp_angle(rot.y, target_yaw, 0.2f);
            set_rotation(rot);

            Vector3 v = get_velocity();
            v.x = dir.x * move_speed;
            v.z = dir.z * move_speed;
            set_velocity(v);
            move_and_slide();
        } else {
            has_target_position = false;
            Vector3 v = get_velocity();
            v.x = 0.0f;
            v.z = 0.0f;
            set_velocity(v);
            set_state(STATE_IDLE);
        }
    }

    (void)p_delta;
}

void NpcAgent3D::initialize_from_snapshot(const Dictionary &p_snapshot) {
    if (p_snapshot.has("npc_id")) {
        npc_id = static_cast<int>(p_snapshot.get("npc_id", -1));
    }
    if (p_snapshot.has("state")) {
        set_state(static_cast<int>(p_snapshot.get("state", STATE_IDLE)));
    }
    if (p_snapshot.has("position")) {
        set_global_position(p_snapshot.get("position", Vector3()));
    }
}

Dictionary NpcAgent3D::export_snapshot() const {
    Dictionary snapshot;
    snapshot["npc_id"] = npc_id;
    snapshot["state"] = state;
    snapshot["position"] = get_global_position();
    snapshot["combat_target_id"] = static_cast<int64_t>(combat_target_id);
    return snapshot;
}

void NpcAgent3D::set_target_position(const Vector3 &p_world_pos) {
    target_position = p_world_pos;
    has_target_position = true;
    if (navigation_agent != nullptr) {
        navigation_agent->set_target_position(target_position);
    }
    if (state == STATE_IDLE) {
        set_state(STATE_PATROL);
    }
}

void NpcAgent3D::set_combat_target_node(Node3D *p_target) {
    combat_target_id = p_target == nullptr ? 0 : p_target->get_instance_id();
    set_state(combat_target_id == 0 ? STATE_IDLE : STATE_COMBAT);
}

void NpcAgent3D::set_npc_id(int p_id) {
    npc_id = p_id;
}

int NpcAgent3D::get_npc_id() const {
    return npc_id;
}

void NpcAgent3D::set_state(int p_state) {
    if (state == p_state) {
        return;
    }
    state = p_state;
    emit_signal("npc_state_changed", npc_id, state);
}

int NpcAgent3D::get_state() const {
    return state;
}

void NpcAgent3D::apply_damage(float p_amount, int p_source_id) {
    if (dead || p_amount <= 0.0f) {
        return;
    }

    health -= p_amount;
    if (health <= 0.0f) {
        health = 0.0f;
        dead = true;
        set_state(STATE_IDLE);
        set_physics_process(false);
        UtilityFunctions::print("NPC died. id:", npc_id, "source:", p_source_id);
        emit_signal("npc_died", npc_id, p_source_id);
        queue_free();
    }
}

float NpcAgent3D::get_health() const {
    return health;
}
