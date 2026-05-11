#ifndef GODOT_FPS_GAME_BOOTSTRAP_H
#define GODOT_FPS_GAME_BOOTSTRAP_H

#include <godot_cpp/classes/node.hpp>

namespace godot {

class GameBootstrap : public Node {
    GDCLASS(GameBootstrap, Node)

private:
    bool debug_mode = false;

protected:
    static void _bind_methods();

public:
    void _ready() override;

    void set_debug_mode(bool p_enabled);
    bool is_debug_mode() const;

    void start_new_game();
};

} // namespace godot

#endif
