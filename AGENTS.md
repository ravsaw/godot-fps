# Godot FPS — Agent Instructions

FPS game built with **Godot 4.6+ + GDExtension (C++)** — low-poly 3D, event-driven world simulation.

⚠️ **CRITICAL: Godot 4 API ONLY.** Do NOT use Godot 3 APIs, enums, or properties. Assume Godot 4.6.2+ unless stated otherwise.

## Agent Behavioral Guidelines

See [CLAUDE.md](CLAUDE.md) for full guidelines. Summary:

- **Ask before assuming.** State assumptions explicitly; surface tradeoffs instead of picking silently.
- **Simplicity first.** Minimum code that solves the problem — no speculative features, no single-use abstractions.
- **Surgical changes.** Touch only what the request requires; match existing style; don't refactor unrelated code.
- **Goal-driven.** For multi-step tasks, state a brief plan with verifiable success criteria before implementing.

## Project Layout (expected conventions)

```
godot-fps/
├── project/          # Godot project root (project.godot lives here)
│   ├── scenes/       # .tscn scene files
│   ├── scripts/      # GDScript (.gd) for lightweight glue / UI
│   └── assets/       # meshes, textures, audio
├── src/              # GDExtension C++ source
│   ├── register_types.cpp / .h
│   └── <module>/     # one folder per logical subsystem
├── SConstruct        # build entry point (SCons)
└── gdextension.gdextension  # extension manifest
```

## Build

```sh
# Debug
scons target=template_debug

# Release
scons target=template_release
```

The compiled `.dll` / `.so` output is referenced by `gdextension.gdextension`.  
Godot editor picks it up automatically on restart (or hot-reload if enabled).

## GDExtension (C++) Conventions

- All custom nodes/resources inherit from a Godot class via `GDCLASS(MyClass, Node)`.
- `_bind_methods()` must register every method, property, and signal exposed to GDScript.
- Use `ClassDB::bind_method` for methods, `ADD_PROPERTY` for properties, `ADD_SIGNAL` for signals.
- Prefer `Variant` for cross-boundary values; use typed C++ internally.
- Never use raw `new`/`delete` for Godot objects — use `memnew` / `memdelete`.

## Event-Driven Architecture

- World state changes are broadcast as Godot **signals** (or an `EventBus` autoload singleton).
- Systems **subscribe** to relevant events; they do not poll each frame unless performance-critical.
- Keep gameplay logic in C++ extensions; keep scene wiring and UI in GDScript.

## GDScript Conventions (glue code)

- GDScript files are thin: connect signals, pass data to C++ nodes, drive UI.
- Avoid heavy logic in GDScript; move it to GDExtension if it becomes non-trivial.
- Use `@export` for designer-tunable values.

## Godot 4 Specifics

**API Version:** Godot 4.6.2 only. Do NOT mix Godot 3 or future API.

**Nodes & Physics:**
- `CharacterBody3D` + `move_and_slide()` for player controller (Godot 4 only).
- `Area3D` for triggers and collision queries (Godot 4 API).
- `PhysicsRayQueryParameters3D` for raycasts (NOT RayQuery from Godot 3).
- `PhysicsServer3D.space_state` accessed via `get_world_3d().direct_space_state`.

**Rendering & Materials:**
- `StandardMaterial3D` for basic materials (Godot 4 updated API).
- Light properties: Use `.light_energy` (NOT `.energy` or `.energy_multiplier`), `.rotation_degrees` (NOT `.rotation` in radians).
- `WorldEnvironment` + `Environment` for ambient lighting.

**Input & Scene:**
- Input handled via `InputMap` actions, not hardcoded keys.
- Use `@export` for designer-tunable values (Godot 4 syntax).
- Scene tree access: `get_tree()` returns valid tree when node is in scene (use `add_child()` before `get_tree()`).
- Signal emission: Use `emit_signal("name", args)` in GDScript; C++ uses `emit_signal` overloads.

**Deferred Calls:**
- During `_ready()`, parent node may be busy setting up children.
- Use `add_child.call_deferred(node)` instead of direct `add_child(node)` to avoid "Parent node is busy" error.

## Common Pitfalls (Godot 4 Specifics)

**C++ Extension:**
- Recompiling requires Godot editor to **reload the project** (or use hot-reload plugin).
- `GDCLASS` macro must appear in class body before other declarations.
- Signals: C++ emits with `emit_signal("name", args)` overloads; GDScript calls `emit_signal("name", args)`.
- SCons build cache (`/.scons_cache`) goes in `.gitignore`.

**GDScript API Mistakes (Godot 3 vs Godot 4):**
- ❌ `DirectionalLight3D.energy_multiplier` → ✅ Use `.light_energy` (Godot 4)
- ❌ `DirectionalLight3D.energy` → ✅ Use `.light_energy` (Godot 4)
- ❌ `Environment.AMBIENT_LIGHT_FIXED` → ✅ Just set `.ambient_light_energy` directly (Godot 4)
- ❌ `Environment.AMBIENT_LIGHT_ENERGY_LUMENS` → ✅ Not needed; `.ambient_light_energy` is the property
- ❌ `NavigationMesh.bake_aabb` read-write → ✅ Read-only in Godot 4; remove manual assignment
- ❌ `add_child(node)` during `_ready()` parent setup → ✅ Use `add_child.call_deferred(node)`
- ❌ `get_tree()` on node not in scene → ✅ Ensure node is `add_child()` to scene first
- ❌ Godot 3 enums/properties (e.g., `call_id`, non-existent exports) → ✅ Verify property exists in Godot 4 docs

**Type Checking & Instance Safety:**
- Use `if item is LootItem:` for type checks (NOT `item.has_property("name")`).
- Use `is_instance_valid(node)` to check if node is alive before calling methods.
- Use `node.get_node_or_null("path")` instead of `node.get_node()` to avoid errors on missing children.
