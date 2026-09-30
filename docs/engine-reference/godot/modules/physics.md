# Godot Physics — Quick Reference

Last verified: 2026-09-30 | Engine: Godot 4.7.2

## What Changed Since ~4.3 (LLM Cutoff)

### 4.7 Changes
<!-- 4.7 items: the migration guide (https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.7.html) for breaking/behavior/default changes; the 4.7 release page, curated changelogs and 4.7 class references for the rest. GH-nnnn is pull request nnnn in godotengine/godot -->
- **Jolt-only notes**: The next four Jolt bullets apply, in the guide's words, "When using Jolt Physics as the 3D physics engine".
- **PITFALL (3D local multiplayer), Jolt**: `WorldBoundaryShape3D` now uses the same convention as Godot when applying `WorldBoundaryShape3D.plane.d`, so the sign of the plane distance is interpreted the opposite way compared to Godot 4.6 (GH-118948). Guide: "You will need to flip the sign yourself to get the same behavior as in Godot 4.6."
- **PITFALL (3D local multiplayer), Jolt**: `SoftBody3D` no longer defaults its mass to `0` (an automatically calculated weight of 1 kg per point, "resulting in a very high total mass for the body"); it now defaults to 1 kg for the entire `SoftBody3D`, same as Godot Physics (GH-116041). The guide gives no action for this note.
- **PITFALL (3D local multiplayer), Jolt**: `SoftBody3D` now applies `SoftBody3D.linear_stiffness` in a way that better matches Godot Physics (GH-116041). Guide: "you will need to re-tweak properties like `SoftBody3D.linear_stiffness` and `SoftBody3D.damping_coefficient` to achieve your desired behavior."
- **PITFALL (3D local multiplayer), Jolt**: `Area3D` now reports overlaps with `SoftBody3D` from its various signals and methods (GH-114198). Guide: "configure your collision layers/masks such that any undesirable interactions between `Area3D` and `SoftBody3D` are ignored."
- **PITFALL (3D local multiplayer)**: `AudioStreamPlayer` default `area_mask` changed from `1` to `0` (GH-107679). The guide lists this note under its Physics heading and it concerns `audio_bus_override` on `Area2D` / `Area3D`. If you use the `audio_bus_override` feature on `Area2D` or `Area3D` **and** the `AudioStreamPlayer` default `area_mask` (just layer `1` ticked): "you will need to reset the mask to layer `1` — otherwise, the bus overrides will stop working." A mask set to anything except layer `1` "will continue to work as expected."
- **`PhysicsServer2D.body_set_shape_as_one_way_collision`**: new `direction` optional parameter (GDScript ✔ · C# binary ✔ with compat · C# source ✔ · GH-104736). `PhysicsServer2DExtension._body_set_shape_as_one_way_collision`: new `direction` parameter (GDScript ❌ · C# binary ❌ · C# source ❌ · GH-104736).
- **2D**: `CollisionShape2D.one_way_collision_direction` (`Vector2`, default `Vector2(0, 1)`) sets the one-way direction relative and local to the shape (GH-104736); the release page has no 3D-physics item
- **Jolt**: updated to 5.5.0 (GH-115877); Jolt behavior changes that break existing setups are in the migration guide
- **Jolt gravity and areas**: gravity reworked "to prevent energy increase on elastic collisions" (GH-115305); `RigidBody3D` picks up runtime `Area3D` damping changes and overlap changes no longer wake it without a net gravity change (GH-118197), with same-cycle follow-ups GH-118291, GH-120258, GH-120298
- **Jolt body sync and overlaps**: pending transform updates of newly added bodies are no longer dropped when a query runs during body state sync such as `_integrate_forces` (GH-115364); area-overlap fixes (GH-118285, GH-120243)
- **`physics/2d/run_on_separate_thread` / `physics/3d/run_on_separate_thread`** (default `false`): when enabled, commands issued during physics processing run immediately instead of being queued (GH-117268); the PR says this "can potentially have a non-trivial performance impact"; with Jolt (3D setting), errors refer to nodes as `<unknown>`
- **Engine choice**: `physics/3d/physics_engine` defaults to `"DEFAULT"`, "currently equivalent to GodotPhysics3D" per the 4.7 docs; GodotPhysics3D-only settings are now flagged, e.g. `physics/3d/sleep_threshold_angular` (GH-116373). Observed on 4.7.2 (2026-09-30): with the setting absent, Jolt's "not supported when using Jolt Physics" runtime warnings do not appear; with `3d/physics_engine="Jolt Physics"` in `project.godot` they do — a hand-written `project.godot` must set it
- **Motion queries** (`CharacterBody3D.move_and_slide()` family): `physics/jolt_physics_3d/motion_queries/recovery_amount` (`0.4`), `recovery_iterations` (`4`), `use_enhanced_internal_edge_removal` (`true`); the docs do not mark them as new in 4.7; GH-118155 moved the Jolt `body_test_motion` contact filtering into a collector and the PR warns of "a significant risk of breaking people's character controllers"

### 4.6 Changes
- **Jolt Physics is the DEFAULT 3D engine** for new projects — per the 4.7 ProjectSettings reference Jolt "is the default for projects created starting in Godot 4.6", while the engine-level `DEFAULT` "is currently equivalent to GodotPhysics3D"
  - Existing projects keep their current physics engine setting
  - Better determinism, stability, and performance than GodotPhysics3D
  - Some HingeJoint3D properties (`damp`) only work with GodotPhysics3D
  - 2D physics UNCHANGED (still Godot Physics 2D)

### 4.5 Changes
- **3D physics interpolation rearchitected**: Moved from RenderingServer to SceneTree
  - User-facing API unchanged, but internal behavior may differ in edge cases

## Physics Engine Selection (4.6)

```
Project Settings → Physics → 3D → Physics Engine:
- Jolt Physics (the docs' default for projects created starting in 4.6)
- GodotPhysics3D (legacy, still available)
- DEFAULT = GodotPhysics3D (4.7 docs: "may change in future releases") — a hand-written
  project.godot needs   [physics]   3d/physics_engine="Jolt Physics"   to run Jolt
```

### Jolt vs GodotPhysics3D

| Feature | Jolt (default) | GodotPhysics3D |
|---------|---------------|----------------|
| Determinism | Better | Inconsistent |
| Stability | Better | Adequate |
| Performance | Better for complex scenes | Adequate |
| HingeJoint3D `damp` | NOT supported | Supported |
| Runtime warnings | Yes, for unsupported properties | No |
| Collision margins | May behave differently | Original behavior |

## Current API Patterns

### Basic Physics Setup (unchanged)
```gdscript
# CharacterBody3D movement — API unchanged across engines
extends CharacterBody3D

@export var speed: float = 5.0
@export var jump_velocity: float = 4.5

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity += get_gravity() * delta

    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = jump_velocity

    var input_dir: Vector2 = Input.get_vector("left", "right", "forward", "back")
    var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    velocity.x = direction.x * speed
    velocity.z = direction.z * speed

    move_and_slide()
```

### Raycasting (unchanged)
```gdscript
var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
var query := PhysicsRayQueryParameters3D.create(from, to)
query.collision_mask = collision_mask
var result: Dictionary = space_state.intersect_ray(query)
if result:
    var hit_point: Vector3 = result.position
    var hit_normal: Vector3 = result.normal
```

## Common Mistakes
- Assuming a `project.godot` without `physics/3d/physics_engine` runs Jolt — unset means `DEFAULT` = GodotPhysics3D (4.7 docs; observed on 4.7.2)
- Tuning `WorldBoundaryShape3D.plane.d` from a 4.6 project under Jolt without flipping the sign (4.7)
- Using HingeJoint3D `damp` property without checking physics engine (Jolt ignores it)
- Not testing collision edge cases when switching between physics engines
