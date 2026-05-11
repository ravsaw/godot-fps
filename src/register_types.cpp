#include "register_types.h"

#include <godot_cpp/core/class_db.hpp>

#include "core/game_bootstrap.h"
#include "alife/npc_data.h"
#include "alife/squad_data.h"
#include "npc/hitbox_component.h"
#include "npc/npc_agent_3d.h"
#include "player/health_component.h"
#include "player/player_controller.h"
#include "world/smart_location.h"
#include "world/world_graph.h"
#include "world/zone_manager.h"
#include "weapon/weapon_base.h"
#include "weapon/bullet_3d.h"

using namespace godot;

void initialize_godot_fps_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }

    ClassDB::register_class<GameBootstrap>();
    ClassDB::register_class<NpcData>();
    ClassDB::register_class<SquadData>();
    ClassDB::register_class<HealthComponent>();
    ClassDB::register_class<WeaponBase>();
    ClassDB::register_class<Bullet3D>();
    ClassDB::register_class<HitboxComponent>();
    ClassDB::register_class<NpcAgent3D>();
    ClassDB::register_class<PlayerController>();
    ClassDB::register_class<SmartLocation>();
    ClassDB::register_class<WorldGraph>();
    ClassDB::register_class<ZoneManager>();
}

void uninitialize_godot_fps_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
}
