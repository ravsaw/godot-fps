#include "game_bootstrap.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

void GameBootstrap::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_debug_mode", "enabled"), &GameBootstrap::set_debug_mode);
    ClassDB::bind_method(D_METHOD("is_debug_mode"), &GameBootstrap::is_debug_mode);
    ClassDB::bind_method(D_METHOD("start_new_game"), &GameBootstrap::start_new_game);

    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "debug_mode"), "set_debug_mode", "is_debug_mode");
}

void GameBootstrap::_ready() {
    UtilityFunctions::print("GameBootstrap ready. Debug mode:", debug_mode);
}

void GameBootstrap::set_debug_mode(bool p_enabled) {
    debug_mode = p_enabled;
}

bool GameBootstrap::is_debug_mode() const {
    return debug_mode;
}

void GameBootstrap::start_new_game() {
    UtilityFunctions::print("Starting new game session.");
}
