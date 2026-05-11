#ifndef GODOT_FPS_WEAPON_BASE_H
#define GODOT_FPS_WEAPON_BASE_H

#include <godot_cpp/classes/node3d.hpp>
#include <vector>
#include "weapon_stats.h"
#include "weapon_attachment_slot.h"

namespace godot {

class WeaponBase : public Node3D {
    GDCLASS(WeaponBase, Node3D)

private:
    bool fire_pressed = false;
    float fire_cooldown_sec = 0.0f;

    int ammo_in_mag = 30;
    int ammo_reserve = 240;
    int mag_size = 30;

    float rounds_per_minute = 600.0f;
    float damage_body = 20.0f;
    float fire_range = 120.0f;

    // Weapon stats (durability)
    WeaponStats weapon_stats;

    // Attachment slots
    std::vector<WeaponAttachmentSlot> attachment_slots;

    // Initialize attachment slots
    void _init_attachment_slots();

protected:
    static void _bind_methods();

    void _fire_once();
    void _on_bullet_hit(bool p_hit, int p_target_id, Vector3 p_pos);

public:
    void _ready() override;
    void _physics_process(double p_delta) override;

    bool can_fire() const;
    void trigger_fire(bool p_pressed);
    void trigger_reload();
    void trigger_inspect();

    int get_ammo_in_mag() const;
    int get_ammo_reserve() const;
    void set_ammo_counts(int p_mag, int p_reserve);
    bool has_scope_attachment() const;

    void set_damage_body(float p_damage);
    float get_damage_body() const;

    void set_fire_range(float p_range);
    float get_fire_range() const;

    // Durability & stats accessors
    float get_durability_percent() const;
    void repair_weapon(float amount);
    void reset_durability();

    // Attachment slot accessors
    bool mount_attachment(int p_slot_idx, const Attachment& p_attachment);
    bool unmount_attachment(int p_slot_idx);
    WeaponAttachmentSlot* get_attachment_slot(int p_slot_idx);
    int get_num_attachment_slots() const;

    // Stat aggregation (base + attachments + durability)
    float get_final_accuracy_mult() const;
    float get_final_handling_mult() const;
    float get_final_range_mult() const;

    // Helper methods for testing/easy mounting (GDScript-friendly)
    void mount_acog_scope();     // +accuracy, +range
    void mount_suppressor();     // -accuracy, +range (subsonic rounds trade accuracy for stealth)
    void mount_stock();          // +handling
    void clear_all_attachments();
};

} // namespace godot

#endif
