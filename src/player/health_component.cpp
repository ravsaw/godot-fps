#include "health_component.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

void HealthComponent::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_max_health", "value"), &HealthComponent::set_max_health);
    ClassDB::bind_method(D_METHOD("get_max_health"), &HealthComponent::get_max_health);
    ClassDB::bind_method(D_METHOD("set_health", "value"), &HealthComponent::set_health);
    ClassDB::bind_method(D_METHOD("get_health"), &HealthComponent::get_health);
    ClassDB::bind_method(D_METHOD("apply_damage", "amount", "source_id"), &HealthComponent::apply_damage, DEFVAL(-1));
    ClassDB::bind_method(D_METHOD("heal", "amount"), &HealthComponent::heal);
    ClassDB::bind_method(D_METHOD("is_dead"), &HealthComponent::is_dead);

    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "max_health"), "set_max_health", "get_max_health");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "health"), "set_health", "get_health");

    ADD_SIGNAL(MethodInfo("damaged", PropertyInfo(Variant::FLOAT, "amount"), PropertyInfo(Variant::INT, "source_id")));
    ADD_SIGNAL(MethodInfo("died", PropertyInfo(Variant::INT, "source_id")));
}

void HealthComponent::set_max_health(float p_value) {
    max_health = p_value < 1.0f ? 1.0f : p_value;
    if (health > max_health) {
        health = max_health;
    }
}

float HealthComponent::get_max_health() const {
    return max_health;
}

void HealthComponent::set_health(float p_value) {
    health = p_value;
    if (health < 0.0f) {
        health = 0.0f;
    }
    if (health > max_health) {
        health = max_health;
    }
    dead = health <= 0.0f;
}

float HealthComponent::get_health() const {
    return health;
}

void HealthComponent::apply_damage(float p_amount, int p_source_id) {
    if (dead || p_amount <= 0.0f) {
        return;
    }

    set_health(health - p_amount);
    emit_signal("damaged", p_amount, p_source_id);

    if (dead) {
        UtilityFunctions::print("Entity died. Source:", p_source_id);
        emit_signal("died", p_source_id);
    }
}

void HealthComponent::heal(float p_amount) {
    if (dead || p_amount <= 0.0f) {
        return;
    }
    set_health(health + p_amount);
}

bool HealthComponent::is_dead() const {
    return dead;
}
