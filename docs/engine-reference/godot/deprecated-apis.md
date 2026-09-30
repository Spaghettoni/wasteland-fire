# Godot — Deprecated APIs

Last verified: 2026-09-30

If an agent suggests any API in the "Deprecated" column, it MUST be replaced
with the "Use Instead" column.

Marks in Notes are the 4.6→4.7 migration guide's (GDScript / C# binary / C# source; ✔ = does not break compatibility, ✔ with compat = a compatibility method was added, ❌ = breaks compatibility); GH-nnnn is pull request nnnn in godotengine/godot — full legend in breaking-changes.md.

## Nodes & Classes

| Deprecated | Use Instead | Since | Notes |
|------------|-------------|-------|-------|
| `TileMap` | `TileMapLayer` | 4.3 | One node per layer instead of multi-layer node |
| `VisibilityNotifier2D` | `VisibleOnScreenNotifier2D` | 4.0 | Renamed for clarity |
| `VisibilityNotifier3D` | `VisibleOnScreenNotifier3D` | 4.0 | Renamed for clarity |
| `YSort` | `Node2D.y_sort_enabled` | 4.0 | Property on Node2D, not a separate node |
| `Navigation2D` / `Navigation3D` | `NavigationServer2D` / `NavigationServer3D` | 4.0 | Server-based API |
| `EditorSceneFormatImporterFBX` | `EditorSceneFormatImporterFBX2GLTF` | 4.3 | Renamed |

## Methods & Properties

| Deprecated | Use Instead | Since | Notes |
|------------|-------------|-------|-------|
| `yield()` | `await signal` | 4.0 | GDScript 2.0 coroutine syntax |
| `connect("signal", obj, "method")` | `signal.connect(callable)` | 4.0 | Callable-based connections |
| `instance()` | `instantiate()` | 4.0 | Renamed |
| `PackedScene.instance()` | `PackedScene.instantiate()` | 4.0 | Renamed |
| `get_world()` | `get_world_3d()` | 4.0 | Explicit 2D/3D split |
| `OS.get_ticks_msec()` | `Time.get_ticks_msec()` | 4.0 | Time singleton preferred |
| `duplicate()` for nested resources | `duplicate_deep()` | 4.5 | Explicit deep copy control |
| `Skeleton3D` signal `bone_pose_updated` | `skeleton_updated` | 4.3 | Renamed |
| `AnimationPlayer.method_call_mode` | `AnimationMixer.callback_mode_method` | 4.3 | Moved to base class |
| `AnimationPlayer.playback_active` | `AnimationMixer.active` | 4.3 | Moved to base class |
| `Control.accessibility_live` typed as `DisplayServer.AccessibilityLiveMode` | `AccessibilityServer.AccessibilityLiveMode` | 4.7 | The guide states a property type change from the first type to the second. GDScript ✔ · C# binary ❌ · C# source ❌ · GH-116839 |
| `RichTextLabel.ImageUpdateMask.UPDATE_WIDTH_IN_PERCENT` | `RichTextLabel.ImageUpdateMask.UPDATE_WIDTH_UNIT` | 4.7 | Enum field renamed. GDScript ❌ · C# binary ✔ · C# source ❌ · GH-112617 |
| `RichTextLabel.add_image` / `RichTextLabel.update_image` parameters `width_in_percent`, `height_in_percent` (type `bool`) | Parameters `width_unit`, `height_unit` (type `RichTextLabel.ImageUnit`) | 4.7 | Renamed and retyped on both methods. GDScript ✔ · C# binary ✔ with compat · C# source ❌ · GH-112617. `RichTextLabel.ImageUnit` in the 4.7 class reference (https://docs.godotengine.org/en/4.7/classes/class_richtextlabel.html): `IMAGE_UNIT_PIXEL` = 0 ("Images drawn with this unit will be in pixels."), `IMAGE_UNIT_PERCENT` = 1 ("…in percentages of the control width."), `IMAGE_UNIT_EM` = 2 ("…in percentages of the surrounding font size."); `width_unit` and `height_unit` default to `0`. (inference: the old `false` corresponds to `IMAGE_UNIT_PIXEL` and the old `true` to `IMAGE_UNIT_PERCENT`, from the member names and the default `0` replacing `false`; neither page states the mapping.) |
| `ImageTexture.get_format` / `PortableCompressedTexture2D.get_format` | `Texture2D.get_format` | 4.7 | Guide: "moved to base class `Texture2D`". The guide marks it non-breaking: GDScript ✔ · C# binary ✔ · C# source ✔ · GH-109004 |
| `RenderingServer.particles_request_process_time` parameter `time` | Parameter `process_time` | 4.7 | Renamed; the same change adds a new optional `process_time_residual` parameter. GDScript ✔ · C# binary ✔ with compat · C# source ❌ · GH-109142 |
| `AudioEffectSpectrumAnalyzer.tap_back_pos` | none stated in the guide | 4.7 | Property removed. GDScript ❌ · C# binary ❌ · C# source ❌ · GH-114355 |
| `EditorSceneFormatImporter` constants `IMPORT_ANIMATION`, `IMPORT_DISCARD_MESHES_AND_MATERIALS`, `IMPORT_FAIL_ON_MISSING_DEPENDENCIES`, `IMPORT_FORCE_DISABLE_MESH_COMPRESSION`, `IMPORT_GENERATE_TANGENT_ARRAYS`, `IMPORT_SCENE`, `IMPORT_USE_NAMED_SKIN_BINDS` | The same constants in enum `ImportFlags` | 4.7 | Guide: each "moved to enum `ImportFlags`"; it states no rename. GDScript ✔ · C# binary ✔ · C# source ❌ · GH-115788 |
| `AnimationNodeBlendSpace1D` / `AnimationNodeBlendSpace2D` boolean `sync` property | New `SyncMode` enum, documented as `AnimationNodeBlendSpace1D.sync_mode` / `AnimationNodeBlendSpace2D.sync_mode` | 4.7 | Behavior-change note, no compat marks or GH number in the guide. The guide says you may need to set that value in each of your blend spaces if animations in an `AnimationTree` are not transitioning correctly after upgrading. 4.7 class reference (https://docs.godotengine.org/en/4.7/classes/class_animationnodeblendspace1d.html): `sync_mode` defaults to `0` = `SYNC_MODE_NONE` ("Inactive animations are frozen and do not advance."); `SYNC_MODE_INDEPENDENT` = `1` "is equivalent to the previous `sync = true` behavior"; `SYNC_MODE_CYCLIC_MUTABLE` = `2` and `SYNC_MODE_CYCLIC_CONSTANT` = `3` (the latter uses `cyclic_length`). The boolean `sync` "is kept for backward compatibility". |

## Patterns (Not Just APIs)

| Deprecated Pattern | Use Instead | Why |
|--------------------|-------------|-----|
| String-based `connect()` | Typed signal connections | Type-safe, refactor-friendly |
| `$NodePath` in `_process()` | `@onready var` cached reference | Performance: path lookup every frame |
| Untyped `Array` / `Dictionary` | `Array[Type]`, typed variables | GDScript compiler optimizations |
| `Texture2D` in `Shader.set_default_texture_parameter()` / `get_default_texture_parameter()` | `Texture` base type | Changed in 4.4; the shading language's `sampler2D` / `texture()` did not change |
| Manual post-process viewport chains | `Compositor` + `CompositorEffect` | Structured post-processing (4.3+) |
| GodotPhysics3D for new projects | Jolt Physics 3D — set `physics/3d/physics_engine="Jolt Physics"` explicitly | The 4.7 ProjectSettings reference says Jolt "is the default for projects created starting in Godot 4.6", but a `project.godot` that leaves the setting at `DEFAULT` runs GodotPhysics3D ("DEFAULT is currently equivalent to GodotPhysics3D"; observed on 4.7.2) |
| Assuming keyboard and mouse events have `InputEvent.device` equal to `0` | Compare `InputEvent.device` to `InputEvent.DEVICE_ID_KEYBOARD` / `InputEvent.DEVICE_ID_MOUSE`, or check the input event by type | Since 4.7: the device IDs for mouse and keyboard were changed from `0` because some joypads may use `0` as their ID (GH-116274) (the guide names no event classes; for example `event is InputEventKey` / `event is InputEventMouseButton`, the pattern in `modules/input.md`) |
| Overriding a method that has a typed return, with no explicit `return` statement in the override | Add `return null` to the end of the method | Since 4.7: methods that inherit from a method with a typed return now inherit the return type as well, requiring an explicit return statement in the override (GH-115763) |
