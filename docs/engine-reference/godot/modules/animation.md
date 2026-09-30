# Godot Animation — Quick Reference

Last verified: 2026-09-30 | Engine: Godot 4.7.2

## What Changed Since ~4.3 (LLM Cutoff)

### 4.7 Changes
<!-- 4.7 items: the migration guide (https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.7.html) for breaking/behavior/default changes; the 4.7 release page, curated changelogs and 4.7 class references for the rest. GH-nnnn is pull request nnnn in godotengine/godot -->
- **`SyncMode` enum**: replaces the boolean `sync` property on `AnimationNodeBlendSpace1D` and `AnimationNodeBlendSpace2D`. Guide: "If you are using an AnimationTree and your animations aren't transitioning correctly after upgrading, you may need to set that value in each of your blend spaces to get the desired behavior back." See `AnimationNodeBlendSpace1D.sync_mode` and `AnimationNodeBlendSpace2D.sync_mode`. 4.7 class reference (https://docs.godotengine.org/en/4.7/classes/class_animationnodeblendspace1d.html): `sync_mode` defaults to `0` = `SYNC_MODE_NONE` ("Inactive animations are frozen and do not advance."); `SYNC_MODE_INDEPENDENT` = `1` "is equivalent to the previous `sync = true` behavior"; `SYNC_MODE_CYCLIC_MUTABLE` = `2` and `SYNC_MODE_CYCLIC_CONSTANT` = `3` (the latter uses `cyclic_length`). The boolean `sync` "is kept for backward compatibility" (GH-117275).
- **`Animation.length`**: type metadata `float` → `double` (GDScript ✔ · C# binary ❌ · C# source ❌ · GH-116394).
- **`AnimationNodeBlendSpace1D.add_blend_point` and `AnimationNodeBlendSpace2D.add_blend_point`**: new `name` optional parameter (GDScript ✔ · C# binary ✔ with compat · C# source ✔ · GH-110369).
- **`LookAtModifier3D.relative`**: default `true` → `false`. Guide's advice for changed defaults: manually set the old value to get a similar behavior to the previous version.
- **`Tween.tween_await(signal)`**: pauses a tween until the signal is emitted and returns an `AwaitTweener`; use `AwaitTweener.set_timeout()` if emission may not happen; the awaited signal should be emitted during the step when the `AwaitTweener` is active
- **`Tween.has_tweeners()`**: `true` when a Tweener was added and the Tween is valid; kill an empty tween before it starts to avoid errors
- **Sprites**: ping-pong playback for `SpriteFrames`, `AnimatedSprite2D` and `AnimatedSprite3D` (GH-114556)
- **Performance**: Animation resource, library, mixer and player optimized (GH-116394); `AnimationTree` optimized (GH-117277)

### 4.6 Changes
- **IK system fully restored**: Complete inverse kinematics for 3D skeletons
  - CCDIK, FABRIK, Jacobian IK, Spline IK, TwoBoneIK
  - Applied via `SkeletonModifier3D` nodes (not the old IK approach)
- **Animation editor QoL**: Solo/hide/lock/delete for Bezier node groups; draggable timeline

### 4.5 Changes
- **BoneConstraint3D**: Bind bones to other bones with modifiers
  - `AimModifier3D`, `CopyTransformModifier3D`, `ConvertTransformModifier3D`

### 4.3 Changes (in training data)
- **AnimationMixer**: Base class for both AnimationPlayer and AnimationTree
  - `method_call_mode` → `callback_mode_method`
  - `playback_active` → `active`
  - `bone_pose_updated` signal → `skeleton_updated`
- **`Skeleton3D.add_bone()`**: Now returns `int32` (was `void`)

## Current API Patterns

### AnimationPlayer (unchanged API, new base class)
```gdscript
@onready var anim_player: AnimationPlayer = %AnimationPlayer

func play_attack() -> void:
    anim_player.play(&"attack")
    await anim_player.animation_finished
```

### IK Setup (4.6 — NEW)
```gdscript
# Add SkeletonModifier3D-based IK nodes as children of Skeleton3D
# Available types:
# - SkeletonModifier3D (base)
# - TwoBoneIK (arms, legs)
# - FABRIK (chains, tentacles)
# - CCDIK (tails, spines)
# - Jacobian IK (complex multi-joint)
# - Spline IK (along curves)

# Configure in editor or code:
# 1. Add IK modifier node as child of Skeleton3D
# 2. Set target bone and tip bone
# 3. Add a Marker3D as the IK target
# 4. IK solver runs automatically each frame
```

### BoneConstraint3D (4.5 — NEW)
```gdscript
# Add as child of Skeleton3D
# Types:
# - AimModifier3D: Point bone at target
# - CopyTransformModifier3D: Mirror another bone's transform
# - ConvertTransformModifier3D: Remap transform values
```

### AnimationTree (base class changed in 4.3)
```gdscript
# AnimationTree now extends AnimationMixer (not Node directly)
# Use AnimationMixer properties:
@onready var anim_tree: AnimationTree = %AnimationTree

func _ready() -> void:
    anim_tree.active = true  # NOT playback_active (deprecated 4.3)
```

## Common Mistakes
- Using `playback_active` instead of `active` (deprecated since 4.3)
- Using `bone_pose_updated` signal instead of `skeleton_updated` (renamed in 4.3)
- Using old IK approach instead of SkeletonModifier3D system (restored in 4.6)
- Not checking `is AnimationMixer` when type-checking animation nodes
- Setting the deprecated boolean `sync` on a blend space instead of `sync_mode` (`SYNC_MODE_INDEPENDENT` is the old `sync = true`; the default `SYNC_MODE_NONE` freezes inactive animations — 4.7)
