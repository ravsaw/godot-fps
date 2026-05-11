#include "weapon_base.h"
#include "bullet_3d.h"

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/physics_body3d.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/classes/window.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <algorithm>
#include <cmath>
#include <random>

using namespace godot;

void WeaponBase::_bind_methods() {
    ClassDB::bind_method(D_METHOD("can_fire"), &WeaponBase::can_fire);
    ClassDB::bind_method(D_METHOD("trigger_fire", "pressed"), &WeaponBase::trigger_fire);
    ClassDB::bind_method(D_METHOD("trigger_reload"), &WeaponBase::trigger_reload);
    ClassDB::bind_method(D_METHOD("trigger_inspect"), &WeaponBase::trigger_inspect);
    ClassDB::bind_method(D_METHOD("get_ammo_in_mag"), &WeaponBase::get_ammo_in_mag);
    ClassDB::bind_method(D_METHOD("get_ammo_reserve"), &WeaponBase::get_ammo_reserve);
    ClassDB::bind_method(D_METHOD("set_ammo_counts", "mag", "reserve"), &WeaponBase::set_ammo_counts);
    ClassDB::bind_method(D_METHOD("has_scope_attachment"), &WeaponBase::has_scope_attachment);
    ClassDB::bind_method(D_METHOD("set_damage_body", "damage"), &WeaponBase::set_damage_body);
    ClassDB::bind_method(D_METHOD("get_damage_body"), &WeaponBase::get_damage_body);
    ClassDB::bind_method(D_METHOD("set_fire_range", "range"), &WeaponBase::set_fire_range);
    ClassDB::bind_method(D_METHOD("get_fire_range"), &WeaponBase::get_fire_range);
    ClassDB::bind_method(D_METHOD("_on_bullet_hit", "hit_success", "target_id", "hit_position"), &WeaponBase::_on_bullet_hit);
    
    // Durability & stats
    ClassDB::bind_method(D_METHOD("get_durability_percent"), &WeaponBase::get_durability_percent);
    ClassDB::bind_method(D_METHOD("repair_weapon", "amount"), &WeaponBase::repair_weapon);
    ClassDB::bind_method(D_METHOD("reset_durability"), &WeaponBase::reset_durability);
    
    // Attachments
    ClassDB::bind_method(D_METHOD("get_num_attachment_slots"), &WeaponBase::get_num_attachment_slots);
    ClassDB::bind_method(D_METHOD("get_final_accuracy_mult"), &WeaponBase::get_final_accuracy_mult);
    ClassDB::bind_method(D_METHOD("get_final_handling_mult"), &WeaponBase::get_final_handling_mult);
    ClassDB::bind_method(D_METHOD("get_final_range_mult"), &WeaponBase::get_final_range_mult);
    
    // Test attachment helpers
    ClassDB::bind_method(D_METHOD("mount_acog_scope"), &WeaponBase::mount_acog_scope);
    ClassDB::bind_method(D_METHOD("mount_suppressor"), &WeaponBase::mount_suppressor);
    ClassDB::bind_method(D_METHOD("mount_stock"), &WeaponBase::mount_stock);
    ClassDB::bind_method(D_METHOD("clear_all_attachments"), &WeaponBase::clear_all_attachments);

    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "damage_body"), "set_damage_body", "get_damage_body");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "fire_range"), "set_fire_range", "get_fire_range");

    ADD_SIGNAL(MethodInfo("fired", PropertyInfo(Variant::INT, "ammo_in_mag"), PropertyInfo(Variant::INT, "reserve")));
    ADD_SIGNAL(MethodInfo("bullet_hit", PropertyInfo(Variant::BOOL, "hit_success"), PropertyInfo(Variant::INT, "target_id"), PropertyInfo(Variant::VECTOR3, "hit_position")));
    ADD_SIGNAL(MethodInfo("reloaded", PropertyInfo(Variant::INT, "new_mag"), PropertyInfo(Variant::INT, "reserve")));
    ADD_SIGNAL(MethodInfo("empty_trigger"));
    ADD_SIGNAL(MethodInfo("durability_changed", PropertyInfo(Variant::FLOAT, "percent")));
    ADD_SIGNAL(MethodInfo("weapon_jammed"));
}

void WeaponBase::_ready() {
    _init_attachment_slots();
}

void WeaponBase::_physics_process(double p_delta) {
    if (fire_cooldown_sec > 0.0f) {
        fire_cooldown_sec -= static_cast<float>(p_delta);
    }

    if (fire_pressed && can_fire()) {
        _fire_once();
    }
}

void WeaponBase::_init_attachment_slots() {
    // Clear and initialize 4 slot types
    attachment_slots.clear();
    attachment_slots.push_back(WeaponAttachmentSlot(AttachmentType::BARREL));
    attachment_slots.push_back(WeaponAttachmentSlot(AttachmentType::RAIL));
    attachment_slots.push_back(WeaponAttachmentSlot(AttachmentType::STOCK));
    attachment_slots.push_back(WeaponAttachmentSlot(AttachmentType::SIGHT));
}

bool WeaponBase::can_fire() const {
    return ammo_in_mag > 0 && fire_cooldown_sec <= 0.0f;
}

void WeaponBase::trigger_fire(bool p_pressed) {
    fire_pressed = p_pressed;
}

void WeaponBase::trigger_reload() {
    if (ammo_in_mag >= mag_size || ammo_reserve <= 0) {
        return;
    }

    const int needed = mag_size - ammo_in_mag;
    const int taken = needed < ammo_reserve ? needed : ammo_reserve;
    ammo_in_mag += taken;
    ammo_reserve -= taken;

    emit_signal("reloaded", ammo_in_mag, ammo_reserve);
}

void WeaponBase::trigger_inspect() {
    UtilityFunctions::print("Weapon inspect");
}

int WeaponBase::get_ammo_in_mag() const {
    return ammo_in_mag;
}

int WeaponBase::get_ammo_reserve() const {
    return ammo_reserve;
}

void WeaponBase::set_ammo_counts(int p_mag, int p_reserve) {
    int clamped_mag = p_mag;
    if (clamped_mag < 0) {
        clamped_mag = 0;
    }
    if (clamped_mag > mag_size) {
        clamped_mag = mag_size;
    }

    ammo_in_mag = clamped_mag;
    ammo_reserve = p_reserve < 0 ? 0 : p_reserve;
}

bool WeaponBase::has_scope_attachment() const {
    if (attachment_slots.size() <= 3) {
        return false;
    }
    return !attachment_slots[3].is_empty_slot();
}

void WeaponBase::_fire_once() {
    if (!can_fire()) {
        emit_signal("empty_trigger");
        return;
    }

    // Check for jam before firing
    if (weapon_stats.check_jam()) {
        UtilityFunctions::print("Weapon jammed! Reliability: ", weapon_stats.get_reliability_percent() * 100.0f, "%");
        emit_signal("weapon_jammed");
        return;
    }

    ammo_in_mag -= 1;
    fire_cooldown_sec = 60.0f / rounds_per_minute;

    // Decrement durability
    weapon_stats.fire_shot();
    emit_signal("durability_changed", weapon_stats.get_durability_percent());

    const Transform3D xf = get_global_transform();
    const Vector3 dir = (-xf.basis.get_column(2)).normalized();

    // Apply spread from final accuracy so wear/attachments are visible in gameplay.
    static thread_local std::mt19937 rng(std::random_device{}());
    std::uniform_real_distribution<float> spread_dist(-1.0f, 1.0f);

    const float accuracy_mult = get_final_accuracy_mult();
    const float clamped_accuracy = std::clamp(accuracy_mult, 0.1f, 1.25f);
    const float inaccuracy = std::clamp(1.0f - clamped_accuracy, 0.0f, 0.9f);
    const float max_spread_deg = 0.35f + (inaccuracy * 8.0f);
    const float max_spread_rad = max_spread_deg * 0.01745329252f;

    Vector3 right = dir.cross(Vector3(0.0f, 1.0f, 0.0f));
    if (right.length_squared() < 0.0001f) {
        right = dir.cross(Vector3(1.0f, 0.0f, 0.0f));
    }
    right = right.normalized();
    const Vector3 up = right.cross(dir).normalized();

    float sx = 0.0f;
    float sy = 0.0f;
    for (int i = 0; i < 6; i++) {
        const float tx = spread_dist(rng);
        const float ty = spread_dist(rng);
        if ((tx * tx + ty * ty) <= 1.0f) {
            sx = tx;
            sy = ty;
            break;
        }
    }

    const Vector3 spread_dir = (dir + right * (sx * max_spread_rad) + up * (sy * max_spread_rad)).normalized();

    Bullet3D *bullet = memnew(Bullet3D);
    get_tree()->get_root()->add_child(bullet);
    bullet->set_global_position(xf.origin);

    bullet->initialize(spread_dir, damage_body, 80.0f);
    bullet->connect("bullet_hit", Callable(this, "_on_bullet_hit"));

    // Exclude player body from bullet collisions
    Node *cam = get_parent();
    Node *player_node = cam ? cam->get_parent() : nullptr;
    if (player_node != nullptr) {
        PhysicsBody3D *player_body = Object::cast_to<PhysicsBody3D>(player_node);
        if (player_body != nullptr) {
            bullet->add_collision_exception_with(player_body);
        }
    }

    UtilityFunctions::print("Weapon fired. Ammo:", ammo_in_mag, " Durability:", weapon_stats.get_durability_percent() * 100.0f, "%");
    emit_signal("fired", ammo_in_mag, ammo_reserve);
}

void WeaponBase::_on_bullet_hit(bool p_hit, int p_target_id, Vector3 p_pos) {
    emit_signal("bullet_hit", p_hit, p_target_id, p_pos);
}

void WeaponBase::set_damage_body(float p_damage) {
    damage_body = p_damage < 1.0f ? 1.0f : p_damage;
}

float WeaponBase::get_damage_body() const {
    return damage_body;
}

void WeaponBase::set_fire_range(float p_range) {
    fire_range = p_range < 1.0f ? 1.0f : p_range;
}

float WeaponBase::get_fire_range() const {
    return fire_range;
}

// Durability & stats
float WeaponBase::get_durability_percent() const {
    return weapon_stats.get_durability_percent();
}

void WeaponBase::repair_weapon(float amount) {
    weapon_stats.repair(amount);
    emit_signal("durability_changed", weapon_stats.get_durability_percent());
}

void WeaponBase::reset_durability() {
    weapon_stats.reset_to_new();
    emit_signal("durability_changed", weapon_stats.get_durability_percent());
}

// Attachment slot accessors
bool WeaponBase::mount_attachment(int p_slot_idx, const Attachment& p_attachment) {
    if (p_slot_idx < 0 || p_slot_idx >= static_cast<int>(attachment_slots.size())) {
        return false;
    }
    return attachment_slots[p_slot_idx].mount_attachment(p_attachment);
}

bool WeaponBase::unmount_attachment(int p_slot_idx) {
    if (p_slot_idx < 0 || p_slot_idx >= static_cast<int>(attachment_slots.size())) {
        return false;
    }
    return attachment_slots[p_slot_idx].unmount_attachment();
}

WeaponAttachmentSlot* WeaponBase::get_attachment_slot(int p_slot_idx) {
    if (p_slot_idx < 0 || p_slot_idx >= static_cast<int>(attachment_slots.size())) {
        return nullptr;
    }
    return &attachment_slots[p_slot_idx];
}

int WeaponBase::get_num_attachment_slots() const {
    return static_cast<int>(attachment_slots.size());
}

// Stat aggregation
float WeaponBase::get_final_accuracy_mult() const {
    float acc = 1.0f;
    
    // Sum all attachment bonuses
    for (const auto& slot : attachment_slots) {
        acc *= slot.get_accuracy_bonus();
    }
    
    // Apply durability penalty
    acc *= weapon_stats.get_accuracy_multiplier();
    
    return acc;
}

float WeaponBase::get_final_handling_mult() const {
    float handling = 1.0f;
    
    for (const auto& slot : attachment_slots) {
        handling *= slot.get_handling_bonus();
    }
    
    return handling;
}

float WeaponBase::get_final_range_mult() const {
    float range = 1.0f;
    
    for (const auto& slot : attachment_slots) {
        range *= slot.get_range_bonus();
    }
    
    return range;
}

// Test/helper attachment mounting (GDScript-friendly)
void WeaponBase::mount_acog_scope() {
    Attachment acog(AttachmentType::SIGHT, "ACOG 4x", 1.15f, 0.95f, 1.25f, 1.0f);
    mount_attachment(3, acog); // slot 3 = SIGHT
    UtilityFunctions::print("Mounted ACOG scope. Accuracy: +15%, Range: +25%");
}

void WeaponBase::mount_suppressor() {
    Attachment suppressor(AttachmentType::BARREL, "Suppressor", 0.90f, 1.05f, 1.1f, 0.8f);
    mount_attachment(0, suppressor); // slot 0 = BARREL
    UtilityFunctions::print("Mounted suppressor. Accuracy: -10%, Range: +10%, Recoil: -20%");
}

void WeaponBase::mount_stock() {
    Attachment stock(AttachmentType::STOCK, "Combat Stock", 1.0f, 1.2f, 1.0f, 0.85f);
    mount_attachment(2, stock); // slot 2 = STOCK
    UtilityFunctions::print("Mounted combat stock. Handling: +20%, Recoil: -15%");
}

void WeaponBase::clear_all_attachments() {
    for (int i = 0; i < static_cast<int>(attachment_slots.size()); ++i) {
        unmount_attachment(i);
    }
    UtilityFunctions::print("Cleared all attachments");
}
