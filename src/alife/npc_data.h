#ifndef GODOT_FPS_NPC_DATA_H
#define GODOT_FPS_NPC_DATA_H

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

class NpcData : public Resource {
    GDCLASS(NpcData, Resource)

private:
    int64_t npc_id = -1;
    int64_t faction_id = -1;
    int64_t squad_id = -1;
    float health = 100.0f;
    int64_t location_id = -1;
    bool is_alive = true;

protected:
    static void _bind_methods();

public:
    void set_npc_id(int64_t p_id);
    int64_t get_npc_id() const;

    void set_faction_id(int64_t p_id);
    int64_t get_faction_id() const;

    void set_squad_id(int64_t p_id);
    int64_t get_squad_id() const;

    void set_health(float p_health);
    float get_health() const;

    void set_location_id(int64_t p_id);
    int64_t get_location_id() const;

    void set_is_alive(bool p_alive);
    bool get_is_alive() const;
};

} // namespace godot

#endif
