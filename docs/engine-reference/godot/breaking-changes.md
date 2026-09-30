# Godot — Breaking Changes

Last verified: 2026-09-30

Changes between Godot versions, focused on post-LLM-cutoff changes (4.4+).

## 4.6 → 4.7 (Jun 2026 — POST-CUTOFF, HIGH RISK)

*Source: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.7.html — GH-nnnn is pull request nnnn in godotengine/godot.*

| Subsystem | Change | Details |
|-----------|--------|---------|
| Core | `Object.is_class`: `class` parameter type changed | Method `is_class` changes `class` parameter type from `String` to `StringName`. GDScript ✔ · C# binary ✔ with compat · C# source ✔ · GH-118582 |
| Core | `ZIPPacker.start_file`: new optional parameters | Method `start_file` adds new `permissions` and `modified_time` optional parameters. GDScript ✔ · C# binary ✔ with compat · C# source ✔ · GH-115946 |
| Core | `OptimizedTranslation.generate`: return type changed | Method `generate` changes return type from `void` to `bool`. GDScript ✔ · C# binary ❌ · C# source ✔ · GH-119563 |
| 2D | `CPUParticles2D` and `GPUParticles2D`: `request_particles_process` gains a parameter | On both classes, method `request_particles_process` adds new `process_time_residual` optional parameter. GDScript ✔ · C# binary ✔ with compat · C# source ✔ · GH-109142 |
| 3D | `CPUParticles3D` and `GPUParticles3D`: `request_particles_process` gains a parameter | On both classes, method `request_particles_process` adds new `process_time_residual` optional parameter. GDScript ✔ · C# binary ✔ with compat · C# source ✔ · GH-109142 |
| GUI nodes | `Control.accessibility_live`: property type changed | Property `accessibility_live` changes type from `DisplayServer.AccessibilityLiveMode` to `AccessibilityServer.AccessibilityLiveMode`. GDScript ✔ · C# binary ❌ · C# source ❌ · GH-116839 |
| GUI nodes | `RichTextLabel`: enum field `ImageUpdateMask.UPDATE_WIDTH_IN_PERCENT` renamed | Enum field `ImageUpdateMask.UPDATE_WIDTH_IN_PERCENT` renamed to `ImageUpdateMask.UPDATE_WIDTH_UNIT` (the guide lists no other `ImageUpdateMask` member). GDScript ❌ · C# binary ✔ · C# source ❌ · GH-112617 |
| GUI nodes | `RichTextLabel.add_image` and `update_image`: `width` and `height` are now `float` | On both methods, the `width` parameter type changes from `int` to `float` and the `height` parameter type changes from `int` to `float`. GDScript ✔ · C# binary ✔ with compat · C# source ✔ · GH-112617 |
| GUI nodes | `RichTextLabel.add_image` and `update_image`: `width_in_percent` and `height_in_percent` renamed and retyped | On both methods, `width_in_percent` is renamed to `width_unit` and `height_in_percent` is renamed to `height_unit`; both change type from `bool` to `RichTextLabel.ImageUnit`. Their defaults are listed under Changed defaults (the guide lists them there under the old names). `RichTextLabel.ImageUnit` in the 4.7 class reference (https://docs.godotengine.org/en/4.7/classes/class_richtextlabel.html): `IMAGE_UNIT_PIXEL` = 0 ("Images drawn with this unit will be in pixels."), `IMAGE_UNIT_PERCENT` = 1 ("…in percentages of the control width."), `IMAGE_UNIT_EM` = 2 ("…in percentages of the surrounding font size."); `width_unit` and `height_unit` default to `0`. (inference: the old `false` corresponds to `IMAGE_UNIT_PIXEL` and the old `true` to `IMAGE_UNIT_PERCENT`, from the member names and the default `0` replacing `false`; neither page states the mapping.) GDScript ✔ · C# binary ✔ with compat · C# source ❌ · GH-112617 |
| Text | `Font.find_variation`: new optional parameters | Method `find_variation` adds new `palette_index` and `custom_colors` optional parameters. GDScript ✔ · C# binary ✔ with compat · C# source ✔ · GH-117149 |
| Text | `TreeItem.select`: new optional parameter | Method `select` adds new `set_as_cursor` optional parameter. GDScript ✔ · C# binary ✔ with compat · C# source ✔ · GH-119367 |
| Rendering | `Image.save_exr` and `save_exr_to_buffer`: new optional parameters | Both methods add new `color_image` and `max_linear_value` optional parameters. GDScript ✔ · C# binary ✔ with compat · C# source ✔ · GH-117800 |
| Rendering | `ImageTexture.get_format` and `PortableCompressedTexture2D.get_format` moved to the base class | On both classes, method `get_format` moved to base class `Texture2D`. GDScript ✔ · C# binary ✔ · C# source ✔ · GH-109004 |
| Rendering | `RenderingServer.particles_request_process_time`: parameter renamed, new optional parameter | Method `particles_request_process_time` renames `time` parameter to `process_time` and adds new `process_time_residual` optional parameter. GDScript ✔ · C# binary ✔ with compat · C# source ❌ · GH-109142 |
| Rendering | `RenderingServer.viewport_set_size`: new optional parameter | Method `viewport_set_size` adds new `view_count` optional parameter. GDScript ✔ · C# binary ✔ with compat · C# source ✔ · GH-115799 |
| Animation | `Animation.length`: type metadata changed | Property `length` changes type metadata from `float` to `double`. GDScript ✔ · C# binary ❌ · C# source ❌ · GH-116394 |
| Animation | `AnimationNodeBlendSpace1D` and `AnimationNodeBlendSpace2D`: `add_blend_point` gains a parameter | On both classes, method `add_blend_point` adds new `name` optional parameter. GDScript ✔ · C# binary ✔ with compat · C# source ✔ · GH-110369 |
| Physics | `PhysicsServer2D.body_set_shape_as_one_way_collision`: new optional parameter | Method `body_set_shape_as_one_way_collision` adds new `direction` optional parameter. GDScript ✔ · C# binary ✔ with compat · C# source ✔ · GH-104736 |
| Physics | `PhysicsServer2DExtension._body_set_shape_as_one_way_collision`: new parameter | Method `_body_set_shape_as_one_way_collision` adds new `direction` parameter (the guide does not call it optional). GDScript ❌ · C# binary ❌ · C# source ❌ · GH-104736 |
| Audio | `AudioEffectSpectrumAnalyzer.tap_back_pos` removed | Property `tap_back_pos` removed; the guide states no replacement. GDScript ❌ · C# binary ❌ · C# source ❌ · GH-114355 |
| XR | `OpenXRExtensionWrapper._on_register_metadata`: new parameter | Method `_on_register_metadata` adds new `interaction_profile_metadata` parameter. GDScript ❌ · C# binary ❌ · C# source ❌ · GH-117399 |
| XR | `OpenXRSpatialAnchorCapability.create_new_anchor`: new optional parameter | Method `create_new_anchor` adds new `next` optional parameter. GDScript ✔ · C# binary ✔ with compat · C# source ✔ · GH-118128 |
| Editor | `EditorSceneFormatImporter` constants moved to enum `ImportFlags` | Constants `IMPORT_ANIMATION`, `IMPORT_DISCARD_MESHES_AND_MATERIALS`, `IMPORT_FAIL_ON_MISSING_DEPENDENCIES`, `IMPORT_FORCE_DISABLE_MESH_COMPRESSION`, `IMPORT_GENERATE_TANGENT_ARRAYS`, `IMPORT_SCENE` and `IMPORT_USE_NAMED_SKIN_BINDS` are each moved to enum `ImportFlags` (the guide states no rename). GDScript ✔ · C# binary ✔ · C# source ❌ · GH-115788 |
| Editor | `EditorVCSInterface._commit`: new parameter | Method `_commit` adds new `amend` parameter. GDScript ❌ · C# binary ❌ · C# source ❌ · GH-117968 |
| Animation (behavior) | `SyncMode` enum replaces the boolean `sync` property on `AnimationNodeBlendSpace1D` and `AnimationNodeBlendSpace2D` | Guide: "If you are using an AnimationTree and your animations aren't transitioning correctly after upgrading, you may need to set that value in each of your blend spaces to get the desired behavior back." The new sync modes are documented in `AnimationNodeBlendSpace1D.sync_mode` and `AnimationNodeBlendSpace2D.sync_mode`. No GH number given. 4.7 class reference (https://docs.godotengine.org/en/4.7/classes/class_animationnodeblendspace1d.html): `sync_mode` defaults to `0` = `SYNC_MODE_NONE` ("Inactive animations are frozen and do not advance."); `SYNC_MODE_INDEPENDENT` = `1` "is equivalent to the previous `sync = true` behavior"; `SYNC_MODE_CYCLIC_MUTABLE` = `2` and `SYNC_MODE_CYCLIC_CONSTANT` = `3` (the latter uses `cyclic_length`). The boolean `sync` "is kept for backward compatibility". |
| Rendering (behavior) | `LinearToSRGB` visual shader no longer clamps | The `LinearToSRGB` visual shader no longer clamps to the range `[0.0, 1.0]` when using the Mobile or Forward+ renderer. GH-113956. The guide gives no adaptation advice. |
| Rendering (behavior) | `CanvasItem` no longer adds the antialiasing feather when drawing lines | The feather made lines appear thicker than intended. Guide: "projects that relied on this behavior will have to be updated to draw a thicker line width." GH-105122 |
| Physics (behavior) | `AudioStreamPlayer` default `area_mask` changed from `1` to `0` (disabled) | GH-107679. Guide: if you use the `audio_bus_override` feature on `Area2D` or `Area3D` **and** you use the `AudioStreamPlayer` default `area_mask` (just layer `1` ticked), "you will need to reset the mask to layer `1` — otherwise, the bus overrides will stop working." If the mask was set to anything except layer `1`, "it will continue to work as expected." |
| Physics (behavior) | Jolt: `WorldBoundaryShape3D.plane.d` sign is interpreted the opposite way | When using Jolt Physics as the 3D physics engine, `WorldBoundaryShape3D` now uses the same convention as Godot when applying `WorldBoundaryShape3D.plane.d`, so the sign of the plane distance is interpreted the opposite way compared to Godot 4.6. Guide: "You will need to flip the sign yourself to get the same behavior as in Godot 4.6." GH-118948 |
| Physics (behavior) | Jolt: `SoftBody3D` default mass | When using Jolt Physics as the 3D physics engine, `SoftBody3D` no longer defaults its mass to `0` (which gave an automatically calculated weight of 1 kg per point, "resulting in a very high total mass for the body"); it now defaults to 1 kg for the entire `SoftBody3D`, same as Godot Physics. GH-116041. The guide gives no adaptation advice for this note. |
| Physics (behavior) | Jolt: `SoftBody3D.linear_stiffness` is applied differently | When using Jolt Physics as the 3D physics engine, `SoftBody3D` now applies `SoftBody3D.linear_stiffness` in a way that better matches Godot Physics; this affects every `SoftBody3D` instance "in one way or another". Guide: "you will need to re-tweak properties like `SoftBody3D.linear_stiffness` and `SoftBody3D.damping_coefficient` to achieve your desired behavior." GH-116041 |
| Physics (behavior) | Jolt: `Area3D` now reports overlaps with `SoftBody3D` | When using Jolt Physics as the 3D physics engine, `Area3D` reports overlaps with `SoftBody3D` from its various signals and methods. Guide: "configure your collision layers/masks such that any undesirable interactions between `Area3D` and `SoftBody3D` are ignored." GH-114198 |
| Input (behavior) | Mouse and keyboard device IDs changed from `0` | The device IDs for mouse and keyboard were changed from `0` to `InputEvent.DEVICE_ID_MOUSE` and `InputEvent.DEVICE_ID_KEYBOARD` "because some joypads may use `0` as their ID". Guide: "Check the input event by type or compare the device ID `InputEvent.device` to the constants `InputEvent.DEVICE_ID_MOUSE` and `InputEvent.DEVICE_ID_KEYBOARD` instead." GH-116274 (the guide names no event classes; for example `event is InputEventKey` / `event is InputEventMouseButton`, the pattern in `modules/input.md`) |
| GDScript (behavior) | Setting an element of a packed array no longer calls the property setter | Guide: "Setting the element of packed arrays no longer calls the setter for the entire packed array property". GH-113228. The guide gives no adaptation advice. |
| GDScript (behavior) | Overrides inherit the typed return of the overridden method | Guide: "Methods that inherit from a method with a typed return now inherit the return type as well, requiring an explicit return statement in the override". Fix: "Add `return null` to the end of the method to fix the error." GH-115763 |
| Platforms (behavior) | Minimum macOS version raised | The minimum macOS version required to run Godot was increased from macOS 10.13 (High Sierra) to macOS 11 (Big Sur). The guide gives no GH number and no adaptation advice. |
| New projects (default) | Default stretch mode and stretch aspect | For **newly created** projects the default stretch mode is now `canvas_items` (previously `disabled`) and the default stretch aspect is now `expand` (previously `keep`). Guide: this can be changed in the Project Settings under `display/window/stretch/mode` and `display/window/stretch/aspect`. |
| Animation (default) | `LookAtModifier3D.relative` default changed | Property `relative`: old default `true`, new default `false`. Guide's advice for changed defaults: manually set the old value (`true`) to get a similar behavior to the previous version. |
| Core (default) | `ProjectSettings` `rendering/reflections/sky_reflections/roughness_layers` default changed | Old default `7`, new default `8`. Guide's advice for changed defaults: manually set the old value (`7`) to get a similar behavior to the previous version. |
| GUI nodes (default) | `RichTextLabel.add_image` and `update_image`: defaults of `width_in_percent` and `height_in_percent` changed | The guide's defaults table lists `width_in_percent` and `height_in_percent` of both methods under these old names: old default `false`, new default `0`. (inference: these are the parameters renamed to `width_unit` and `height_unit` above, because the names match; the guide does not say so.) Guide's advice for changed defaults: manually set the old value to get a similar behavior to the previous version. 4.7 class reference (https://docs.godotengine.org/en/4.7/classes/class_richtextlabel.html): `width_unit` and `height_unit` default to `0` = `IMAGE_UNIT_PIXEL`. |
| Import (default) | `ResourceImporterDynamicFont.hinting` default changed | Property `hinting`: old default `1`, new default `3`. Guide's advice for changed defaults: manually set the old value (`1`) to get a similar behavior to the previous version. |

*Marks are the guide's own: ✔ = does not break compatibility; ✔ with compat = does not break compatibility, a compatibility method was added; ❌ = breaks compatibility. C# binary compatible = existing binaries load and run without recompilation and runtime behavior does not change; C# source compatible = source code compiles without changes. For rows that add optional parameters, the guide names the parameters only; it states no types or default values for them.*

## 4.5 → 4.6 (Jan 2026 — POST-CUTOFF, HIGH RISK)

| Subsystem | Change | Details |
|-----------|--------|---------|
| Physics | Jolt is now the DEFAULT 3D physics engine | New projects use Jolt automatically. Existing projects keep their setting. Some HingeJoint3D properties (like `damp`) only work with GodotPhysics. |
| Rendering | Glow processes BEFORE tonemapping | Was after tonemapping. Scenes with glow will look different. Adjust intensity/blend in WorldEnvironment. |
| Rendering | D3D12 default on Windows | Was Vulkan. For better driver compatibility. |
| Rendering | AgX tonemapper new controls | White point and contrast parameters added. |
| Core | Quaternion initializes to identity | Was zero. Unlikely to affect most code but technically breaking. |
| UI | Dual-focus system | Mouse/touch focus now separate from keyboard/gamepad focus. Visual feedback differs by input method. |
| Animation | IK system fully restored | CCDIK, FABRIK, Jacobian IK, Spline IK, TwoBoneIK via SkeletonModifier3D nodes. |
| Editor | New "Modern" theme default | Grayscale replaces blue-tint. Restore: Editor Settings → Interface → Theme → Style: Classic |
| Editor | "Select Mode" keybind changed | New "Select Mode" (v key) prevents accidental transforms. Old mode renamed "Transform Mode" (q key). |
| 2D | TileMapLayer scene tile rotation | Scene tiles can now be rotated like atlas tiles. |
| Localization | CSV plural form support | No longer requires Gettext for plurals. Context columns added. |
| C# | Automatic string extraction | Translation strings auto-extracted from C# code. |
| Plugins | New EditorDock class | Specialized container for plugin docks with layout control. |

## 4.4 → 4.5 (Late 2025 — POST-CUTOFF, HIGH RISK)

| Subsystem | Change | Details |
|-----------|--------|---------|
| GDScript | Variadic arguments added | Functions can accept `...` arbitrary params — new language feature |
| GDScript | `@abstract` decorator | Abstract classes and methods now enforceable |
| GDScript | Script backtracing | Detailed call stacks available even in Release builds |
| Rendering | Stencil buffer support | New capability for advanced visual effects |
| Rendering | SMAA 1x antialiasing | New post-processing AA option |
| Rendering | Shader Baker | Pre-compiles shaders — reportedly 20x faster startup on some demos |
| Rendering | Bent normal maps, specular occlusion | New material features |
| Accessibility | Screen reader support | Control nodes work with accessibility tools via AccessKit |
| Editor | Live translation preview | Test GUI layouts in different languages in-editor |
| Physics | 3D interpolation rearchitected | Moved from RenderingServer to SceneTree. API unchanged but internals differ. |
| Animation | BoneConstraint3D | New: AimModifier3D, CopyTransformModifier3D, ConvertTransformModifier3D |
| Resources | `duplicate_deep()` added | New explicit method for deep duplication of nested resources |
| Navigation | Dedicated 2D navigation server | No longer a proxy to 3D navigation; smaller export for 2D games |
| UI | FoldableContainer node | New accordion-style container for collapsible UI sections |
| UI | Recursive Control behavior | Disable mouse/focus interactions across entire node hierarchies |
| Platform | visionOS export support | New platform target |
| Platform | SDL3 gamepad driver | Delegated gamepad handling to SDL library |
| Platform | Android 16KB page support | Required for Google Play targeting Android 15+ |

## 4.3 → 4.4 (Mid 2025 — NEAR CUTOFF, VERIFY)

| Subsystem | Change | Details |
|-----------|--------|---------|
| Core | `FileAccess.store_*` return `bool` | Was `void`. Methods: `store_8`, `store_16`, `store_32`, `store_64`, `store_buffer`, `store_csv_line`, `store_double`, `store_float`, `store_half`, `store_line`, `store_pascal_string`, `store_real`, `store_string`, `store_var` |
| Core | `OS.execute_with_pipe` | Added optional `blocking` parameter |
| Core | `RegEx.compile/create_from_string` | Added optional `show_error` parameter |
| Rendering | `RenderingDevice.draw_list_begin` | Many parameters removed; `breadcrumb` parameter added |
| Rendering | `Shader.set_default_texture_parameter()` / `get_default_texture_parameter()` | Parameter/return type changed from `Texture2D` to `Texture`; the shading language did not change |
| Particles | `.restart()` method | Added optional `keep_seed` parameter (CPU/GPU 2D/3D) |
| GUI | `RichTextLabel.push_meta` | Added optional `tooltip` parameter |
| GUI | `GraphEdit.connect_node` | Added optional `keep_alive` parameter |

## 4.2 → 4.3 (In Training Data — LOW RISK)

| Subsystem | Change | Details |
|-----------|--------|---------|
| Animation | `Skeleton3D.add_bone` returns `int32` | Was `void` |
| Animation | `bone_pose_updated` signal | Replaced by `skeleton_updated` |
| TileMap | `TileMapLayer` replaces `TileMap` | One node per layer instead of multi-layer single node |
| Navigation | `NavigationRegion2D` | Removed `avoidance_layers`, `constrain_avoidance` properties |
| Editor | `EditorSceneFormatImporterFBX` | Renamed to `EditorSceneFormatImporterFBX2GLTF` |
| Animation | AnimationMixer base class | AnimationPlayer and AnimationTree now extend AnimationMixer |
