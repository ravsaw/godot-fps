#include "bullet_3d.h"

#include <godot_cpp/classes/collision_shape3d.hpp>
#include <godot_cpp/classes/mesh_instance3d.hpp>
#include <godot_cpp/classes/physics_direct_space_state3d.hpp>
#include <godot_cpp/classes/physics_ray_query_parameters3d.hpp>
#include <godot_cpp/classes/sphere_shape3d.hpp>
#include <godot_cpp/classes/sphere_mesh.hpp>
#include <godot_cpp/classes/box_mesh.hpp>
#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/standard_material3d.hpp>
#include <godot_cpp/classes/static_body3d.hpp>
#include <godot_cpp/classes/world3d.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

namespace {
float compute_hit_multiplier(Object *p_collider, const Vector3 &p_hit_position) {
    Node3D *collider_node = Object::cast_to<Node3D>(p_collider);
    if (collider_node == nullptr) {
        return 1.0f;
    }

    const Vector3 local_hit = collider_node->to_local(p_hit_position);
    if (local_hit.y >= 1.45f) {
        return 2.0f; // head
    }
    if (local_hit.y <= 0.7f) {
        return 0.85f; // lower body / legs
    }
    return 1.0f; // torso
}
} // namespace

void Bullet3D::_bind_methods() {
    ClassDB::bind_method(D_METHOD("initialize", "direction", "damage", "speed"), &Bullet3D::initialize);

    ADD_SIGNAL(MethodInfo("bullet_hit",
            PropertyInfo(Variant::BOOL, "hit_success"),
            PropertyInfo(Variant::INT, "target_id"),
            PropertyInfo(Variant::VECTOR3, "hit_position")));
}

void Bullet3D::_ready() {
    CollisionShape3D *shape_node = memnew(CollisionShape3D);
    Ref<SphereShape3D> sphere;
    sphere.instantiate();
    sphere->set_radius(0.04f);
    shape_node->set_shape(sphere);
    add_child(shape_node);

    MeshInstance3D *bullet_mesh_node = memnew(MeshInstance3D);
    Ref<SphereMesh> bullet_mesh;
    bullet_mesh.instantiate();
    bullet_mesh->set_radius(0.09f);
    bullet_mesh->set_height(0.18f);
    bullet_mesh_node->set_mesh(bullet_mesh);

    Ref<StandardMaterial3D> bullet_mat;
    bullet_mat.instantiate();
    bullet_mat->set_albedo(Color(1.0f, 0.8f, 0.35f));
    bullet_mat->set_emission(Color(1.0f, 0.75f, 0.25f));
    bullet_mesh_node->set_material_override(bullet_mat);
    add_child(bullet_mesh_node);

    MeshInstance3D *tracer_mesh_node = memnew(MeshInstance3D);
    Ref<BoxMesh> tracer_mesh;
    tracer_mesh.instantiate();
    tracer_mesh->set_size(Vector3(0.025f, 0.025f, 0.9f));
    tracer_mesh_node->set_mesh(tracer_mesh);
    tracer_mesh_node->set_position(Vector3(0.0f, 0.0f, 0.45f));

    Ref<StandardMaterial3D> tracer_mat;
    tracer_mat.instantiate();
    tracer_mat->set_albedo(Color(1.0f, 0.9f, 0.45f, 0.65f));
    tracer_mat->set_transparency(BaseMaterial3D::TRANSPARENCY_ALPHA);
    tracer_mat->set_emission(Color(1.0f, 0.85f, 0.35f));
    tracer_mesh_node->set_material_override(tracer_mat);
    add_child(tracer_mesh_node);
}

void Bullet3D::initialize(const Vector3 &p_direction, float p_damage, float p_speed) {
    _damage = p_damage;
    _velocity = p_direction * p_speed;
}

void Bullet3D::_physics_process(double p_delta) {
    float dt = static_cast<float>(p_delta);

    _ttl -= dt;
    if (_ttl <= 0.0f) {
        queue_free();
        return;
    }

    _velocity.y -= _gravity * dt;

    if (_velocity.length_squared() > 0.0001f) {
        look_at(get_global_position() + _velocity.normalized(), Vector3(0, 1, 0));
    }

    const Vector3 origin = get_global_position();
    const Vector3 next_pos = origin + _velocity * dt;

    Ref<World3D> world = get_world_3d();
    if (!world.is_valid()) {
        set_global_position(next_pos);
        return;
    }

    PhysicsDirectSpaceState3D *space_state = world->get_direct_space_state();
    if (space_state == nullptr) {
        set_global_position(next_pos);
        return;
    }

    Ref<PhysicsRayQueryParameters3D> query = PhysicsRayQueryParameters3D::create(origin, next_pos);
    query->set_collide_with_bodies(true);
    query->set_collide_with_areas(true);

    Array exclude;
    exclude.push_back(get_rid());
    query->set_exclude(exclude);

    Dictionary hit = space_state->intersect_ray(query);
    if (hit.is_empty()) {
        set_global_position(next_pos);
        return;
    }

    Object *collider = hit.get("collider", Variant());
    const Vector3 hit_pos = hit.get("position", origin);
    const Vector3 hit_normal = hit.get("normal", Vector3(0, 1, 0));
    int target_id = -1;
    if (collider != nullptr) {
        target_id = static_cast<int>(collider->get_instance_id());
    }

    // Ricochet off static geometry if budget allows
    if (collider != nullptr && Object::cast_to<StaticBody3D>(collider) != nullptr
            && _ricochet_count < _max_ricochets) {
        _velocity = _velocity.bounce(hit_normal) * _ricochet_retention;
        _ricochet_count++;
        set_global_position(hit_pos + hit_normal * 0.03f);
        return;
    }

    // Hit — apply damage then destroy
    bool hit_success = false;
    if (collider != nullptr) {
        hit_success = true;
        if (collider->has_method("apply_hit_damage")) {
            collider->call("apply_hit_damage", _damage, static_cast<int>(get_instance_id()));
        } else if (collider->has_method("apply_damage")) {
            const float hit_multiplier = compute_hit_multiplier(collider, hit_pos);
            collider->call("apply_damage", _damage * hit_multiplier, static_cast<int>(get_instance_id()));
        }
    }

    emit_signal("bullet_hit", hit_success, target_id, hit_pos);
    queue_free();
}
