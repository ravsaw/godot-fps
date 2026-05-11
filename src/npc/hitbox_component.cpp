#include "hitbox_component.h"

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void HitboxComponent::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_damage_multiplier", "value"), &HitboxComponent::set_damage_multiplier);
    ClassDB::bind_method(D_METHOD("get_damage_multiplier"), &HitboxComponent::get_damage_multiplier);
    ClassDB::bind_method(D_METHOD("apply_hit_damage", "base_damage", "source_id"), &HitboxComponent::apply_hit_damage, DEFVAL(-1));

    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "damage_multiplier"), "set_damage_multiplier", "get_damage_multiplier");
}

void HitboxComponent::set_damage_multiplier(float p_value) {
    damage_multiplier = p_value < 0.1f ? 0.1f : p_value;
}

float HitboxComponent::get_damage_multiplier() const {
    return damage_multiplier;
}

void HitboxComponent::apply_hit_damage(float p_base_damage, int p_source_id) {
    const float final_damage = p_base_damage * damage_multiplier;

    Node *owner = get_owner();
    if (owner == nullptr) {
        owner = get_parent();
    }
    if (owner != nullptr) {
        owner->call("apply_damage", final_damage, p_source_id);
    }
}
