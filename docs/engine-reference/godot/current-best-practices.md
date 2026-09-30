# Godot — Current Best Practices

Last verified: 2026-09-30 | Engine: Godot 4.7.2

Practices that are **new or changed** since the model's training data (~4.3).
This supplements (not replaces) the agent's built-in knowledge.

<!-- 4.7 sections, newest first. Sourced from the 4.7 release page, curated changelogs, 4.7 class references and
     pull-request texts fetched 2026-09-29/30; breaking changes are in breaking-changes.md and are only pointed to here.
     GH-nnnn is pull request nnnn in godotengine/godot. Changelog "Fix ..." lines list every fix merged in the 4.7
     cycle, including fixes for bugs that only existed in 4.7 development builds; a fix listed here does not by itself
     mean 4.6 projects had the bug. -->

## Rendering (4.7)

- **HDR output is opt-in, Forward+ and Mobile only**: Windows (Direct3D 12), macOS (Metal or Vulkan),
  iOS, visionOS and Linux (Wayland); not Android, X11, web or Compatibility. Enable it with the
  `display/window/hdr/request_hdr_output` setting (default `false`, read at startup, now a basic
  setting per GH-118355) or `Window.hdr_output_requested` at runtime

- **HDR with SubViewports**: every other `SubViewport` of the window needs `Viewport.use_hdr_2d`
  enabled (the main viewport is forced on); the docs' setup also enables `rendering/viewport/hdr_2d`.
  `Viewport.own_world_3d` separates which viewports get tonemapping and `WorldEnvironment` effects

- **Nearest-neighbor 3D scaling** (GH-79731; "has no additional rendering cost", 2D unaffected): use a
  `scaling_3d_scale` of 1/n (0.5, 0.3333, 0.25) to avoid uneven pixels; above `1.0` falls back to
  bilinear. The PR says every renderer supports it; `SubViewport` inherits `Viewport`
  ```gdscript
  sub_viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_NEAREST
  sub_viewport.scaling_3d_scale = 0.5
  ```

- **`AreaLight3D`**: real-time rectangular light with `area_size` (meters), `area_range`,
  `area_attenuation`, `area_normalize_energy` and `area_texture`; soft shadows use PCSS. The release
  page says you "no longer need to use an emissive material combined with Global Illumination"

- **Area light cost**: in Forward+ "there is an additional GPU cost on all rendered objects as soon as
  one area light is present in the view frustum"; Mobile support is limited and Compatibility has no
  area-light shadows. (inference: with two split-screen cameras the cost applies to each view whose
  frustum contains an area light)

- **Performance**: a unique environment uniform buffer per render pass (GH-115177; the PR: 1.84 ms to
  1.55 ms in a scene with many shadows) and per-cascade directional shadow culling (GH-114678)

- **`DrawableTexture2D`**: draw into a texture without `Viewport` or `RenderingDevice` workarounds:
  `setup(width, height, format, color, use_mipmaps)`, then `blit_rect(rect, source, modulate, mipmap,
  material)`. The docs mark `setup`, `blit_rect` and `blit_rect_multi` "Experimental"

- **3D particles**: scale and rotation can be tweaked in the particle process; also an "Inherit Emitter
  Scale" flag on `ParticleProcessMaterial` (GH-112184) and "Improve options for orienting particles in
  space" (GH-116620).
  `ParticleProcessMaterial` (4.7 class reference): `use_scale_3d` (default `false`) enables
  `scale_3d_min` / `scale_3d_max` (`Vector3`, random scale per particle); `use_rotation_3d` (default
  `false`) enables `rotation_3d_min` / `rotation_3d_max` (`Vector3`, degrees, 3D only);
  `particle_flag_inherit_emitter_scale` (default `false`, "particles will inherit the scale of the
  emitter"; the docs add that it has no effect when `GPUParticles3D.local_coords` is `true`). GH-112447's description names `angle_3d_min/max`, so it lags the merged API.

- **Shader validation** (changelog): `hint_screen_texture` is forbidden in unsupported shader types
  (GH-119665) and `textureQueryLod` in vertex shaders (GH-118962); a struct name may now be a variable
  name (GH-116888)

Sources:
- Release page: https://godotengine.org/releases/4.7/
- HDR output article: https://godotengine.org/article/hdr-output-arrives-in-godot-4-7/
- HDR output manual: https://docs.godotengine.org/en/4.7/tutorials/rendering/hdr_output.html
- Project Settings: https://docs.godotengine.org/en/4.7/classes/class_projectsettings.html
- Viewport: https://docs.godotengine.org/en/4.7/classes/class_viewport.html
- Window: https://docs.godotengine.org/en/4.7/classes/class_window.html
- AreaLight3D: https://docs.godotengine.org/en/4.7/classes/class_arealight3d.html
- DrawableTexture2D: https://docs.godotengine.org/en/4.7/classes/class_drawabletexture2d.html
- ParticleProcessMaterial: https://docs.godotengine.org/en/4.7/classes/class_particleprocessmaterial.html
- Curated changelog 4.7: https://github.com/godotengine/godot/blob/4.7-stable/CHANGELOG.md

## Physics (4.7)

- **No 3D-physics feature on the release page.** Its one physics item is 2D:
  `CollisionShape2D.one_way_collision_direction` (`Vector2`, default `Vector2(0, 1)`) sets the one-way
  direction "relative and local to the shape"

- **Jolt in the changelog**: updated to 5.5.0 (GH-115877); gravity reworked "to prevent energy increase
  on elastic collisions" (GH-115305); pending transform updates of newly added bodies are no longer discarded
  when a query runs during body state sync such as `_integrate_forces` (GH-115364); area-overlap fixes (GH-118285, GH-120243)

- **`RigidBody3D` and `Area3D` under Jolt** (GH-118197): runtime damping changes from an `Area3D` now
  reach overlapping bodies, and area overlap changes no longer wake a body without a net gravity
  change. (inference: GH-118291, GH-120258 and GH-120298 are same-cycle follow-ups, so 4.6 projects never
  had those bugs; rests on their PR texts saying "After PR #118197" or "the regression from #118197")

- **`ConeTwistJoint3D` under Jolt** now has cone-shaped limits (they were pyramid shaped), matching
  GodotPhysics3D (GH-119982)

- **`physics/2d/run_on_separate_thread` and `physics/3d/run_on_separate_thread`** (both default
  `false`): when enabled, physics server commands issued during physics processing now run
  immediately/synchronously instead of being queued; only `PhysicsServer*D::step()` and
  idle-processing work stay asynchronous (GH-117268). The PR says this "can potentially have a
  non-trivial performance impact" for projects that rely on the setting and do many costly
  physics-related state changes in things like `_physics_process`; for the 3D setting the docs add that
  with Jolt, error messages then refer to nodes as `<unknown>`

- **Pick the engine explicitly**: `physics/3d/physics_engine` defaults to `"DEFAULT"`, "currently
  equivalent to GodotPhysics3D" per the 4.7 docs, and "Jolt Physics is the default for projects
  created starting in Godot 4.6". Check `project.godot` (a docs statement, not a 4.7 change)
  Observed on 4.7.2 (2026-09-30): with the setting absent, Jolt's "not supported when using Jolt
  Physics" runtime warnings do not appear; with `3d/physics_engine="Jolt Physics"` in `project.godot`
  they do. A hand-written `project.godot` must set it — this project does.

- **GodotPhysics3D-only settings are now flagged** in the class reference (GH-116373), for example
  `physics/3d/sleep_threshold_angular`: "It has no effect when using Jolt Physics"

- **Jolt settings behind `CharacterBody3D.move_and_slide()`** (docs, not marked as 4.7 changes):
  `physics/jolt_physics_3d/motion_queries/recovery_amount` (`0.4`),
  `physics/jolt_physics_3d/motion_queries/recovery_iterations` (`4`) and
  `physics/jolt_physics_3d/motion_queries/use_enhanced_internal_edge_removal` (`true`)

- **Jolt `body_test_motion` contact filtering** (GH-118155): filtering moved into a new collector, so
  valid contacts are no longer at risk of being discarded just because they were not the closest one
  (PR text). The PR says it fixes issue 117857 (https://github.com/godotengine/godot/issues/117857),
  "Using CharacterBody3D move_and_collide() from _process() with Jolt physics sometimes fails to
  generate collision responses.", and warns "There's a significant risk of breaking people's character
  controllers when changing anything related to `PhysicsServer3D::body_test_motion`". (inference:
  re-test `CharacterBody3D.move_and_slide()` movement on 4.7; rests on the ProjectSettings note that
  lists `body_test_motion()` and `move_and_slide()` together)

- NOT SOURCEABLE — any 4.7 change to CharacterBody3D itself, not stated at https://github.com/godotengine/godot/blob/4.7-stable/CHANGELOG.md (no entry in the 4.7, 4.7.1 or 4.7.2 lists names it, and the settings page does not mark the motion-query settings above as new)

- Breaking Jolt behavior changes (soft bodies, area overlaps with soft bodies, world-boundary plane
  sign) and the audio `area_mask` default are in the migration guide, not repeated here

Sources:
- Release page: https://godotengine.org/releases/4.7/
- CollisionShape2D: https://docs.godotengine.org/en/4.7/classes/class_collisionshape2d.html
- Project Settings: https://docs.godotengine.org/en/4.7/classes/class_projectsettings.html
- Curated changelogs: https://github.com/godotengine/godot/blob/4.7-stable/CHANGELOG.md · https://github.com/godotengine/godot/blob/4.7.1-stable/CHANGELOG.md · https://github.com/godotengine/godot/blob/4.7.2-stable/CHANGELOG.md
- Migration guide: https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.7.html

## Audio (4.7)

- **`AudioStreamPlayer3D` with several cameras** (GH-114080, fixes the issue "Audio only plays on one
  viewport (3D)"): cameras whose viewport is a 3D audio listener (`Viewport.audio_listener_enable_3d`,
  default `false` per the 4.7 Viewport class reference) are evaluated and their volumes are merged by
  taking the maximum for each output channel (reverb likewise); PR author: "it will use the maximum
  volume for each channel (left and right) and frame across all cameras". (inference: in a two-camera
  split-screen a sound near either camera is heard at its louder per-channel volume; rests on that
  comment and on the 4.7-stable source, which merges the per-camera volumes with a per-channel maximum
  and skips a camera whose viewport is not a 3D audio listener)

- **Smaller changes**: the Spectrum Analyzer effect no longer returns jittered values, but GH-114355
  also removes `AudioEffectSpectrumAnalyzer.tap_back_pos` (breaking; migration guide, Audio) and, per
  the PR, "magnitudes will update less frequently"; `AudioStreamInteractive` binds
  `TRANSITION_TO_TIME_PREVIOUS_POSITION` (GH-114129). The release page has no audio item

Sources:
- Release page: https://godotengine.org/releases/4.7/
- Migration guide: https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.7.html
- Curated changelog 4.7: https://github.com/godotengine/godot/blob/4.7-stable/CHANGELOG.md
- Viewport: https://docs.godotengine.org/en/4.7/classes/class_viewport.html
- GH-114080: https://github.com/godotengine/godot/pull/114080
- Source, 4.7-stable: https://github.com/godotengine/godot/blob/4.7-stable/scene/3d/audio_stream_player_3d.cpp

## Input (4.7)

- **Keyboard and mouse events carry device IDs**: `InputEvent.DEVICE_ID_KEYBOARD` is 16 and
  `InputEvent.DEVICE_ID_MOUSE` is 32 in the 4.7 docs. The release page says the change "does not add
  support for differentiating between multiple keyboards or mice connected to the same system".
  (inference: two players on one keyboard still need separate key bindings)

- **Saved input maps** that serialised `device=0` are normalised on load (GH-116526); how to check
  events after the device-ID change is in the migration guide, not repeated here

- **4.7.2 fixes**: simultaneous Shift release (GH-120327); mouse movement performance at high polling
  rates on Windows (GH-109639)

Sources:
- Release page: https://godotengine.org/releases/4.7/
- InputEvent: https://docs.godotengine.org/en/4.7/classes/class_inputevent.html
- Migration guide: https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.7.html
- Curated changelog 4.7.2: https://github.com/godotengine/godot/blob/4.7.2-stable/CHANGELOG.md
- GH-116526: https://github.com/godotengine/godot/pull/116526

## UI (4.7)

- **`Control` offset transform**: move, rotate or scale a Control without the layout undoing it
  (containers reset child transforms when they re-sort). Enable `offset_transform_enabled` (default
  `false`), then set `offset_transform_position`, `offset_transform_position_ratio`,
  `offset_transform_rotation`, `offset_transform_scale`, `offset_transform_pivot` or
  `offset_transform_pivot_ratio`; `offset_transform_visual_only` (default `true`) keeps input at the
  original location
  ```gdscript
  button.offset_transform_enabled = true
  button.offset_transform_scale = Vector2(1.1, 1.1)
  ```

- **`Control.custom_maximum_size`** (`Vector2`, default `Vector2(-1, -1)`, meaning no maximum); parent
  containers can still limit the effective size, and 4.7.1 and 4.7.2 fix several maximum-size issues

- **`RichTextLabel` images can follow the font size**:
  `[font_size=40]Example: [img height=1em]example.png[/img][/font_size]`; the image-method signature
  changes are in the migration guide

- **Accessibility**: landmark navigation lets a screen reader announce context when focus enters a
  region (GH-114449); accessibility methods and enums moved from `DisplayServer` to the
  `AccessibilityServer` singleton (GH-116839), so search scripts for `DisplayServer` accessibility calls

- **Smaller items**: `Tree` drag and drop shows a drop position indicator (GH-112993);
  `TabContainer.all_tabs_in_front` is deprecated "due to now being useless" (GH-118623)

Sources:
- Release page: https://godotengine.org/releases/4.7/
- Control: https://docs.godotengine.org/en/4.7/classes/class_control.html
- Curated changelogs: https://github.com/godotengine/godot/blob/4.7-stable/CHANGELOG.md · https://github.com/godotengine/godot/blob/4.7.1-stable/CHANGELOG.md · https://github.com/godotengine/godot/blob/4.7.2-stable/CHANGELOG.md
- Migration guide: https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.7.html

## Animation (4.7)

- **`Tween.tween_await(signal)`** pauses a tween until the signal is emitted and returns an
  `AwaitTweener`; use `AwaitTweener.set_timeout()` when emission may not happen. The awaited signal
  should be emitted during the step when the `AwaitTweener` is active
  ```gdscript
  var tween = create_tween()
  tween.tween_callback(launch)
  tween.tween_await(collided).set_timeout(4.0)
  tween.tween_callback(explode)
  ```

- **`Tween.has_tweeners()`** returns `true` when a Tweener was added and the Tween is valid; killing an
  empty tween before it starts prevents errors

- **BlendSpace and sprites**: `sync_mode` on BlendSpace1D and BlendSpace2D (GH-117275): new enum
  `SyncMode` with `SYNC_MODE_NONE`, `SYNC_MODE_INDEPENDENT` (equivalent to the previous `sync = true`),
  `SYNC_MODE_CYCLIC_MUTABLE` and `SYNC_MODE_CYCLIC_CONSTANT` (uses `cyclic_length`); the bool `sync` is
  deprecated; ping-pong playback for `SpriteFrames`, `AnimatedSprite2D` and `AnimatedSprite3D`
  (GH-114556)

Sources:
- Release page: https://godotengine.org/releases/4.7/
- Tween: https://docs.godotengine.org/en/4.7/classes/class_tween.html
- AnimationNodeBlendSpace1D: https://docs.godotengine.org/en/4.7/classes/class_animationnodeblendspace1d.html
- Curated changelog 4.7: https://github.com/godotengine/godot/blob/4.7-stable/CHANGELOG.md

## GDScript (4.7)

- **New warning `CONFUSABLE_TEMPORARY_MODIFICATION`** (GH-118002): the PR closes the issue "Can't directly
  modify points of Line2D" and links two more about updating points on `Line2D` and `CSGPolygon3D`.
  Project setting `debug/gdscript/warnings/confusable_temporary_modification` (default `1`, like the
  other `confusable_*` warnings): when set to Warn or Error, it produces a warning or an error
  respectively when a built-in property of type `Packed*Array` is modified using a complex assignment
  chain or a non-`const` method call, because that only modifies a temporary value and the property's
  value remains unchanged

- **`type_exists()` is deprecated** (GH-116899): the PR calls it a full alias for
  `ClassDB.class_exists()` that does not support `Variant` types or global custom classes

- **Static methods of a native base class can be called on a GDScript object at runtime** (GH-93298)

- **`Basis.is_orthonormal()`** is exposed (GH-117206); `JSON.stringify` uses a compact form for an
  empty `Dictionary` (GH-115883)

- **`ResourceLoader`**: threaded-load deadlock and race fixes (GH-119757, GH-118824, GH-120077); the PR
  texts describe several of these bugs as existing ones

- Return-type inheritance for untyped overrides and packed-array setter changes are in the migration guide

Sources:
- Curated changelog 4.7: https://github.com/godotengine/godot/blob/4.7-stable/CHANGELOG.md
- Project Settings: https://docs.godotengine.org/en/4.7/classes/class_projectsettings.html
- Migration guide: https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.7.html

## Platform (4.7)

- **Desktop**: HDR output on Windows, macOS and Linux (Wayland), see Rendering; SDL3 already drives
  controllers on Windows, macOS and Linux; Windows and macOS gain taskbar progress and state support
  (GH-106560); Wayland gains initial touch support; macOS confined mouse movement no longer gets out
  of sync (GH-116242)

- **macOS maintenance fixes**: 4.7.1 "Update macOS/iOS min. versions in plist and exporter" (GH-121129);
  4.7.2 "macOS: Fix initial window flags" (GH-120533) and "Fix copy paste error in macos mediaKeyEvent
  handler" (GH-121225)

- **Export templates**: the new downloader (GH-117072) fetches templates for individual platforms or specific
  architectures; the PR organises them as Platform Family, Platform, Template, File, and downloads keep
  running in the background if the dialog is closed

- **`export_presets.cfg`**: `runnable` moves from each preset into a new `runnable_presets` section
  (GH-114930: "There is no compatibility breakage"). (inference: a 4.7 editor writes that section when
  it saves the file; rests on the PR saying `runnable` is "no longer stored as part of the preset, but
  in a new section")

- **Export content**: the global script cache file is always included in the PCK, even without global
  classes (GH-118487); "Fix incorrect feature overrides when exporting for Linux" (GH-119274);
  "Fix export errors with non-resources" (GH-119554)

- **Headless export** (4.7.1, GH-120794): per-instance shader parameters were wrong in `--headless`
  exports; the PR says the bug only reproduced when the project cache was deleted before exporting

Sources:
- Release page: https://godotengine.org/releases/4.7/
- Curated changelogs: https://github.com/godotengine/godot/blob/4.7-stable/CHANGELOG.md · https://github.com/godotengine/godot/blob/4.7.1-stable/CHANGELOG.md · https://github.com/godotengine/godot/blob/4.7.2-stable/CHANGELOG.md
- System requirements: https://docs.godotengine.org/en/4.7/about/system_requirements.html

## Editor Workflow (4.7)

- **Asset Store** replaces the Asset Library, with ratings, zoomable previews and background threading
  (https://store.godotengine.org/)
- **Project Manager** shows an upgrade or downgrade icon next to a project's version when the current
  editor must convert it; a different icon marks a major-version upgrade
- **Create dialog** has filters: check only "Show Custom" to find what you can instantiate from code
- **Inspector**: right-click a category or group to copy and paste its values; the Remote Scene
  Inspector folds groups and subgroups; the Remote Tree Inspector shows enum names for non-exported
  enum variables
- **Embedded game view** shares the 3D camera controller (`View3DController`): configurable shortcuts,
  navigation scheme, orbit snapping and inertia
- **3D editor**: Vertex Snap (`B`), follow selection (Focus Selection, `F`, pressed twice), trackball
  rotation (`U`), `Path3D` points can snap to colliders, the ruler shows per-axis lengths while Shift
  is held, CSG Autosmooth (Smoothing Angle defaults to 50 degrees), a `MeshLibrary` editor for `GridMap`
- **2D editor**: Scene Paint Mode (`B` by default) quickly scatters things like collectables, enemies or
  decorations
- **Script and shader editors**: double-click the current script name to reveal it in the list; text
  shaders get inline previews; symbols use a monospace font (editor setting Interface > Theme > Use
  Monospace Font for Editor Symbols)

Sources:
- Release page: https://godotengine.org/releases/4.7/
- Curated changelog 4.7: https://github.com/godotengine/godot/blob/4.7-stable/CHANGELOG.md

## Tooling (4.7)

- **`--ignore-error-breaks` now works with the local debugger** (GH-116823): the PR says the flag "only did
  so for `RemoteDebugger` and not `LocalDebugger`, so doesn't work in the context of `--debug`".
  (inference: it is the flag that could remove the `debug>` wait described under "Command Line — Tests and Parse Check" below;
  rests on `-d` being the local debugger, and the PR does not mention gdUnit4)

- NOT SOURCEABLE — whether `--ignore-error-breaks` removes the `debug>` wait in the gdUnit4 headless command, not stated at https://github.com/godotengine/godot/pull/116823

- **Debugger stop without a server** (GH-117434): "Silently stop all script debuggers if no debugging
  server is active"; per the PR the `stopped` signal is now propagated only if the debug server is valid
  or a session is active. Its effect on the `--remote-debug tcp://127.0.0.1:0` pattern is not stated

- **Other command-line and import items** (changelog): "Warn about `--gpu-index` CLI argument being
  unsupported in Compatibility" (GH-119289); "Fix newly imported files not having existing UID assigned"
  (GH-118037); "Don't print UID errors when cache is not initialized" (GH-118527)

- **gdUnit4 on 4.7**: the gdUnit4 README compatibility table lists v6.2.1 (and v6.2.0) for Godot v4.5–v4.7.1 (https://github.com/godot-gdunit-labs/gdUnit4/blob/master/README.md); 4.7.2 is not yet in the table. Observed on 4.7.2 (2026-09-30): gdUnit4 v6.2.1 installed from the release zipball, plugin enabled, `godot --headless -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode` ran one suite — 1 test case, 0 failures, exit 0, 8 ms — with the two expected port-0 `ERROR:` lines

Sources:
- Curated changelog 4.7: https://github.com/godotengine/godot/blob/4.7-stable/CHANGELOG.md
- GH-116823: https://github.com/godotengine/godot/pull/116823
- GH-117434: https://github.com/godotengine/godot/pull/117434

## GDScript (4.5+)

- **Variadic arguments**: Functions can accept arbitrary parameter counts. The
  rest parameter is written `...name`, comes last, and is typed `Array` or left
  untyped — `values: Variant...` and `...values: Array[int]` do not parse
  ```gdscript
  func log_values(prefix: String, ...values: Array) -> void:
      for v in values:
          print(prefix, ": ", v)
  ```

- **Lambdas capture local variables by value** (every Godot 4 version): a local
  is captured once, when the lambda is created, and a lambda cannot reassign an
  outer local — `var hit := false` / `func(): hit = true` leaves the caller's
  `hit` false. Share state through a reference type (a Dictionary, an Array or
  an object) and mutate its contents. A rest parameter works in a lambda too, so
  `func(...args)` connects to a signal with any number of arguments (observed on
  4.6.1; a one-argument lambda on a zero-argument signal errors "Method expected
  1 argument(s), but called with 0")
  ```gdscript
  var state := {"emitted": false}
  some_signal.connect(func(...args): state.emitted = true)
  ```

- **Abstract classes and methods**: Use `@abstract` to enforce inheritance
  ```gdscript
  @abstract
  class_name BaseEnemy extends CharacterBody3D

  # No body: "a newline or a semicolon is expected after the function header".
  # Subclasses MUST override it.
  @abstract func get_attack_pattern() -> Array[Attack]
  ```

- **Script backtracing**: Detailed call stacks available even in Release builds

## Physics (4.6)

- **Jolt Physics is the default 3D engine** for new projects (the 4.7 docs: Jolt "is the default for
  projects created starting in Godot 4.6"); `physics/3d/physics_engine` left at `DEFAULT` is
  GodotPhysics3D (see Physics (4.7))
  - Better determinism and stability than GodotPhysics3D
  - Some HingeJoint3D properties (`damp`) only work with GodotPhysics
  - Switch: Project Settings → Physics → 3D → Physics Engine
  - 2D physics unchanged (still Godot Physics 2D)

## Rendering (4.6)

- **D3D12 is the default backend on Windows** (was Vulkan) — for better driver compatibility
- **Glow now processes before tonemapping** with screen blending mode — existing glow setups may look different
- **SSR overhauled** — significant improvement in realism, stability, and performance
- **AgX tonemapper** — new white point and contrast controls

## Rendering (4.5)

- **Shader Baker**: Pre-compile shaders to eliminate startup hitching
- **SMAA 1x**: New AA option — sharper than FXAA, cheaper than TAA
- **Stencil buffer**: Available for advanced masking/portal effects
- **Bent normal maps**: Directional occlusion in normal map textures
- **Specular occlusion**: Ambient occlusion now affects reflections

## Accessibility (4.5+)

- **Screen reader support**: Control nodes integrate with accessibility tools via AccessKit
- **Live translation preview**: Test GUI layouts in different languages directly in-editor
- **FoldableContainer**: New accordion-style UI node for collapsible sections
- **Recursive Control disable**: Disable mouse/focus interactions for entire node hierarchies with a single property

## Animation (4.5+)

- **BoneConstraint3D**: Bind bones to other bones with modifiers
  - AimModifier3D, CopyTransformModifier3D, ConvertTransformModifier3D

## Animation (4.6)

- **IK system fully restored**: Complete inverse kinematics reintroduced for 3D
  - Available modifiers: CCDIK, FABRIK, Jacobian IK, Spline IK, TwoBoneIK
  - Applied via `SkeletonModifier3D` nodes

## Resources (4.5+)

- **`duplicate_deep()`**: Explicit deep duplication for nested resource trees
  - Old `duplicate()` behavior retained for backward compatibility
  - Use `duplicate_deep()` when you need per-instance copies of nested resources

## Navigation (4.5+)

- **Dedicated 2D navigation server**: No longer proxied through 3D NavigationServer
  - Reduces export binary size for 2D-only games

## UI (4.6)

- **Dual-focus system**: Mouse/touch focus is now separate from keyboard/gamepad focus
  - Visual feedback differs depending on input method
  - Consider this when designing custom focus behavior

## Editor Workflow (4.6)

- Flexible dock drag-and-drop with blue outline preview (including bottom panel)
- Most panels support floating windows (except Debugger)
- New keyboard shortcuts: Alt+O (Output), Alt+S (Shader)
- Export variable auto-generation: drag resource from FileSystem into script editor
- Live preview in Quick Open dialog when "Live Preview" enabled
- New "Select Mode" (v key) prevents accidental transforms; old mode renamed "Transform Mode" (q key)

## Tooling

- **ripgrep has no `gdscript` type**: `*.gd` is registered under `gap` (GAP programming language).
  `rg --type gdscript` is a hard error — the search never executes.
  Always use `rg --glob "*.gd"` (shell) or `glob: "*.gd"` (Grep tool) to filter GDScript files.

## Command Line — Tests and Parse Check

Flags, from Godot's command-line tutorial: `--headless` (headless display and a
dummy audio driver, "useful for servers and with `--script`"), `--path <dir>`
(a directory holding `project.godot`), `-s`/`--script <script>`, `-d`/`--debug`
(the local stdout debugger), `--remote-debug <protocol>://<host>[:<port>]`,
`--import` (starts the editor, waits for the import, and quits),
`--quit-after <n>` (iterations), `--export-debug <preset>` (implies `--import`)
and `--check-only` (parse for errors and quit, with `--script`). The editor is
not on `PATH` by default: on Windows and Linux run the binary by its relative or
absolute path; on macOS run `Godot.app/Contents/MacOS/Godot` inside the bundle.

gdUnit4's runner is `res://addons/gdUnit4/bin/GdUnitCmdTool.gd`; `-a <dir|suite>`
adds suites, reports go to `res://reports/` by default (`-rd` changes it), and
the documented exit codes are 0 (all passed), 100 (failures) and 101 (warnings).
The command the framework uses:
`godot --headless -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode`.

Observed on Godot 4.7.2 (macOS, 2026-09-30): `godot --headless --path . --import` exits 0 on a project with
no scenes; `godot --path . --windowed --resolution 1280x720 --write-movie shots/x.png --quit-after 60 res://x.tscn`
writes 60 PNG frames at the **project viewport size** (`display/window/size/viewport_width/height`, default
1152×648) — `--resolution 1280x720` did not change the recording size; the recording follows the project
viewport. This project sets 1280×720.

Observed on Godot 4.6.1 with gdUnit4 6.1.3 — not in the docs:
- 101 is also the exit when every test passed but a test leaked orphan nodes;
  105 means a test script does not parse; 103 means gdUnit4 refused to run
  headless (`--ignoreHeadlessMode` missing). 104 is gdUnit4 refusing a Godot
  older than 4.3 — not reproducible on the pin.
- Over zero tests the runner prints `No test cases found` and exits 0.
- Without `--remote-debug tcp://127.0.0.1:0`, a script error opens the `-d`
  debugger and the run waits at a `debug>` prompt; with it, every run prints two
  `ERROR:` lines about the remote port, which are expected.
- A fresh clone has no `.godot/` class cache: run
  `godot --headless --path . --import` first, or `GdUnitCmdTool.gd` does not
  load and the run exits 1 having run nothing.
- `--check-only` with `-s <file>` exits 1 on valid code that names an autoload
  (`Identifier not found`), and `--import` / `--quit-after` exit 0 on a parse
  error — neither is a parse check. The framework's parse check is
  `godot --headless --path . -s res://.claude/scripts/godot-parse-check.gd -- res://<file>.gd …`
  (exit 1 when a script does not load).
- On Windows, a quoted full path to the editor (`"C:/Program Files/Godot/…exe"`)
  runs from Git Bash with its stdout and exit code intact.

Sources:
- Command line tutorial: https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html
- gdUnit4 command line tool: https://godot-gdunit-labs.github.io/gdUnit4/latest/advanced_testing/cmd/
- GDScript reference, lambda functions and rest parameters: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html

## Platform (4.5+)

- **visionOS export**: First new platform since open-sourcing (windowed app mode)
- **SDL3 gamepad driver**: Better cross-platform gamepad support
- **Android**: Edge-to-edge display, camera feed access, 16KB page support (Android 15+)
- **Linux**: Wayland subwindow support for multi-window capability
