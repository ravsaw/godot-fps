#ifndef GODOT_FPS_NPC_AGENT_3D_H
#define GODOT_FPS_NPC_AGENT_3D_H

#include <godot_cpp/classes/character_body3d.hpp>
#include <godot_cpp/classes/navigation_agent3d.hpp>
#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

class NpcAgent3D : public CharacterBody3D {
    GDCLASS(NpcAgent3D, CharacterBody3D)

private:
    enum NpcState {
        STATE_IDLE = 0,
        STATE_PATROL = 1,
        STATE_INVESTIGATE = 2,
        STATE_COMBAT = 3,
        STATE_FLEE = 4,
    };

    int npc_id = -1;
    float move_speed = 3.2f;
    float max_health = 100.0f;
    float health = 100.0f;
    bool dead = false;
    int state = STATE_IDLE;

    bool has_target_position = false;
    Vector3 target_position;
    NavigationAgent3D *navigation_agent = nullptr;

    uint64_t combat_target_id = 0;

protected:
    static void _bind_methods();

public:
    void _ready() override;
    void _physics_process(double p_delta) override;

    void initialize_from_snapshot(const Dictionary &p_snapshot);
    Dictionary export_snapshot() const;

    void set_target_position(const Vector3 &p_world_pos);
    void set_combat_target_node(Node3D *p_target);

    void set_npc_id(int p_id);
    int get_npc_id() const;

    void set_state(int p_state);
    int get_state() const;

    void apply_damage(float p_amount, int p_source_id = -1);
    float get_health() const;
};

} // namespace godot

#endif
