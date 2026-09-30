# Godot Rendering — Quick Reference

Last verified: 2026-09-30 | Engine: Godot 4.7.2

## What Changed Since ~4.3 (LLM Cutoff)

### 4.7 Changes
<!-- 4.7 items: the migration guide (https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.7.html) for breaking/behavior/default changes; the 4.7 release page, curated changelogs and 4.7 class references for the rest. GH-nnnn is pull request nnnn in godotengine/godot -->
- **`CPUParticles2D`, `GPUParticles2D`, `CPUParticles3D`, `GPUParticles3D`**: method `request_particles_process` adds new `process_time_residual` optional parameter (GDScript ✔ · C# binary ✔ with compat · C# source ✔ · GH-109142).
- **`RenderingServer.particles_request_process_time`**: `time` parameter renamed to `process_time`, new `process_time_residual` optional parameter (GDScript ✔ · C# binary ✔ with compat · C# source ❌ · GH-109142).
- **`RenderingServer.viewport_set_size`**: new `view_count` optional parameter (GDScript ✔ · C# binary ✔ with compat · C# source ✔ · GH-115799).
- **`Image.save_exr` and `Image.save_exr_to_buffer`**: new `color_image` and `max_linear_value` optional parameters (GDScript ✔ · C# binary ✔ with compat · C# source ✔ · GH-117800).
- **`ImageTexture.get_format` and `PortableCompressedTexture2D.get_format`**: moved to base class `Texture2D` (GDScript ✔ · C# binary ✔ · C# source ✔ · GH-109004).
- **`LinearToSRGB` visual shader**: no longer clamps to the range `[0.0, 1.0]` when using the Mobile or Forward+ renderer (GH-113956). The guide gives no adaptation advice.
- **`CanvasItem`**: now avoids adding the antialiasing feather when drawing lines (GH-105122). The feather made lines appear thicker than intended; guide: "projects that relied on this behavior will have to be updated to draw a thicker line width."
- **`ProjectSettings` `rendering/reflections/sky_reflections/roughness_layers`**: default `7` → `8`. Guide's advice for changed defaults: manually set the old value to get a similar behavior to the previous version.
- **HDR output** (Forward+ and Mobile only; Windows Direct3D 12, macOS Metal or Vulkan, Linux Wayland, iOS, visionOS): `display/window/hdr/request_hdr_output` (default `false`) or `Window.hdr_output_requested`; not Compatibility, Android, Linux X11 or web
- **HDR with SubViewports**: enable `Viewport.use_hdr_2d` on every other `SubViewport` of the window; Filmic and ACES tonemappers stay in the SDR range; `Window.get_output_max_linear_value()` reports the headroom
- **Nearest-neighbor 3D scaling**: `Viewport.SCALING_3D_MODE_NEAREST` for `scaling_3d_mode`; prefer scales like 0.5, 0.3333, 0.25; values above `1.0` fall back to bilinear (GH-79731)
- **`AreaLight3D`**: rectangular real-time light; in Forward+ any area light in the view frustum adds GPU cost to all rendered objects; limited in Mobile, no shadows in Compatibility
- **`DrawableTexture2D`**: `setup()` then `blit_rect()`; the docs mark these methods experimental (GH-105701)
- **Performance**: a unique environment uniform buffer per pass (GH-115177); per-cascade directional shadow culling (GH-114678)
- **Particles and shaders**: 3D particle scale and rotation controls, "Inherit Emitter Scale" flag on `ParticleProcessMaterial` (GH-112184); `hint_screen_texture` forbidden in unsupported shader types (GH-119665)

### 4.6 Changes
- **D3D12 is the default rendering backend on Windows** (was Vulkan)
- **Glow processes before tonemapping** (was after) — uses screen blending mode
- **AgX tonemapper**: new white point and contrast controls
- **SSR overhauled**: better realism, visual stability, and performance

### 4.5 Changes
- **Shader Baker**: Pre-compiles shaders to reduce startup time
- **SMAA 1x**: New anti-aliasing option (sharper than FXAA, cheaper than TAA)
- **Stencil buffer support**: Enables selective geometry masking/portal effects
- **Bent normal maps**: Directional occlusion encoded in normal map textures
- **Specular occlusion**: Ambient occlusion now correctly affects reflections

### 4.4 Changes
- **`RenderingDevice.draw_list_begin`**: Many parameters removed; optional `breadcrumb` added
- **`Shader` default-texture methods**: `set_default_texture_parameter()` takes and
  `get_default_texture_parameter()` returns `Texture`, not `Texture2D` (the shading
  language's `sampler2D` / `texture()` did not change)
- **Particles `.restart()`**: Added optional `keep_seed` parameter

### 4.3 Changes (in training data)
- **Compositor node**: `Compositor` + `CompositorEffect` for post-processing chains

## Current API Patterns

### Post-Processing (4.3+)
```gdscript
# Use Compositor node — NOT manual viewport shader chains
# Add Compositor as child of WorldEnvironment or Camera3D
# Create CompositorEffect resources for each post-process step
```

### Anti-Aliasing Options (4.6)
```
Project Settings → Rendering → Anti Aliasing:
- MSAA 2D/3D: Hardware MSAA (quality but expensive)
- Screen Space AA: FXAA (fast, blurry) or SMAA (sharp, moderate cost)  # SMAA new in 4.5
- TAA: Temporal (best quality, ghosting on fast motion)
```

### Rendering Backend Selection (4.6)
```
Project Settings → Rendering → Renderer:
- Forward+ (default): Full featured, desktop-focused
- Mobile: Optimized for mobile/low-end, limited features
- Compatibility: OpenGL 3.3 / WebGL 2, broadest hardware support

Windows default backend: D3D12 (was Vulkan pre-4.6)
macOS driver (4.7 docs): rendering/rendering_device/driver.macos = "metal" — native Metal on Apple Silicon;
  Intel Macs fall back to "vulkan" (MoltenVK)
```

## Common Mistakes
- Assuming Vulkan is the default backend on Windows (D3D12 since 4.6)
- Using manual viewport chains instead of Compositor for post-processing
- Passing or expecting `Texture2D` in `Shader.set_default_texture_parameter()` /
  `get_default_texture_parameter()` (the type is `Texture` since 4.4 — the shading
  language's `sampler2D` / `texture()` did not change)
- Not using Shader Baker for projects with many shader variants
- Relying on `LinearToSRGB` clamping to `[0.0, 1.0]` in Forward+/Mobile (no longer clamps since 4.7)
- Relying on the antialiasing feather to thicken `CanvasItem` lines (removed in 4.7 — draw a thicker width)
