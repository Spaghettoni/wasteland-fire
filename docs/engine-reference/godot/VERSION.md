# Godot Engine — Version Reference

| Field | Value |
|-------|-------|
| **Engine Version** | Godot 4.7.2 |
| **Installed at pin time** | 4.7.2.stable.official.ed1daf0bf — `godot --version` on PATH (`/opt/homebrew/bin/godot` → `/Applications/Godot.app/Contents/MacOS/Godot`), probed 2026-09-29 by `/setup-engine` §3; matches the pin exactly |
| **Release Date** | June 2026 — 4.7-stable 2026-06-18; 4.7.1 2026-07-14; 4.7.2 (the pinned patch) 2026-08-18 (GitHub release tags) |
| **Project Pinned** | 2026-09-30 |
| **Last Docs Verified** | 2026-09-30 |
| **LLM Knowledge Cutoff** | May 2025 |

## Knowledge Gap Warning

The LLM's training data likely covers Godot up to ~4.3. Versions 4.4, 4.5,
4.6 and 4.7 introduced significant changes that the model does NOT know about.
Always cross-reference this directory before suggesting Godot API calls.

## Installed-Version Gap Warning

The warning above is one-directional — it covers the **model** knowing less than
this pin. The reverse gap is real and `/setup-engine` §3 creates it deliberately
("pin the newer one and upgrade later"): this reference can sit **ahead of the
installed editor**, and an agent citing it correctly then emits APIs that do not
compile locally. **Check `Installed at pin time` above before trusting a
version-qualified claim** — `NOT DETERMINED` means the gap is unknown, not absent.

## Post-Cutoff Version Timeline

| Version | Release | Risk Level | Key Theme |
|---------|---------|------------|-----------|
| 4.4 | ~Mid 2025 | MEDIUM | Jolt physics option, FileAccess return types, shader texture type changes |
| 4.5 | ~Late 2025 | HIGH | Accessibility (AccessKit), variadic args, @abstract, shader baker, SMAA |
| 4.6 | Jan 2026 | HIGH | Jolt default, glow rework, D3D12 default on Windows, IK restored |
| 4.7 | Jun 2026 | HIGH | HDR output, AreaLight3D, Control offset transforms, Asset Store; keyboard/mouse device IDs ≠ 0; macOS 11 minimum |

## Verified Sources

- Official docs: https://docs.godotengine.org/en/stable/
- 4.6→4.7 migration: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.7.html (RST source: https://github.com/godotengine/godot-docs/blob/4.7/tutorials/migrating/upgrading_to_godot_4.7.rst)
- 4.5→4.6 migration: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.6.html
- 4.4→4.5 migration: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.5.html
- Changelog: https://github.com/godotengine/godot/blob/master/CHANGELOG.md
- Release notes 4.7: https://godotengine.org/releases/4.7/
- Release notes 4.6: https://godotengine.org/releases/4.6/
- GitHub releases: https://github.com/godotengine/godot/releases/tag/4.7-stable · https://github.com/godotengine/godot/releases/tag/4.7.1-stable · https://github.com/godotengine/godot/releases/tag/4.7.2-stable
- Maintenance releases: https://godotengine.org/article/maintenance-release-godot-4-7-1/ · https://godotengine.org/article/maintenance-release-godot-4-7-2/
- Curated changelog: https://github.com/godotengine/godot/blob/4.7.2-stable/CHANGELOG.md
- 4.7 class references consulted: https://docs.godotengine.org/en/4.7/classes/class_projectsettings.html · class_animationnodeblendspace1d.html · class_richtextlabel.html · class_inputevent.html · class_viewport.html · class_window.html · class_control.html · class_tween.html
- System requirements (4.7): https://docs.godotengine.org/en/4.7/about/system_requirements.html

## Maintenance Releases on This Pin

- 4.7.1 (2026-07-14): "42 contributors submitted 78 fixes for this release."; "As of now, there are no known incompatibilities with the previous Godot 4.7 release."
- 4.7.2 (2026-08-18): "39 contributors submitted 57 fixes for this release."; "As of now, there are no known incompatibilities with the previous Godot 4.7.1 release."
- The curated `CHANGELOG.md` dates 4.7.2 as `2026-08-17`, one day before the GitHub release; the GitHub tag date is used above.

## Defaults That Matter on This Pin (4.7 docs, verified 2026-09-30)

- **3D physics engine**: `physics/3d/physics_engine` defaults to `"DEFAULT"`, which "is currently equivalent to GodotPhysics3D, but may change in future releases. Select an explicit implementation if you want to ensure that your project stays on the same engine." "Jolt Physics is the default for projects created starting in Godot 4.6" — but the engine-level default is `DEFAULT` = GodotPhysics3D (observed on 4.7.2 with the setting absent), so a hand-written `project.godot` must set `3d/physics_engine="Jolt Physics"` itself (this project does). Source: ProjectSettings class reference.
- **macOS rendering driver**: `rendering/rendering_device/driver.macos` defaults to `"metal"` — "Metal from native drivers, only supported on Apple Silicon Macs. On Intel Macs, it will automatically fall back to `vulkan` as Metal support is not implemented." The capture test on this machine reported `Metal 4.0 - Forward+ - Using Device #0: Apple - Apple M4 Pro (Apple9)`.
- **Minimum OS** (System requirements, 4.7): Windows 10; macOS 11 (Intel Macs), macOS 13 (Apple Silicon Macs); Linux distribution released after 2018. The migration guide states the macOS floor moved from 10.13 to 11.
- **Window defaults**: `display/window/size/viewport_width` × `viewport_height` default `1152` × `648`; `display/window/stretch/mode` defaults to `"disabled"` and `stretch/aspect` to `"keep"`, but the migration guide says projects **newly created** in 4.7 get `canvas_items` / `expand`. This project sets 1280×720 and `canvas_items` / `expand` explicitly in `project.godot`.
