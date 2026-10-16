# Story 030: Hits and shots: flashes, charring, tracers, muzzle flashes and impacts

> **Epic**: Wasteland Fire — First Playable
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: L+ (more than two days at `coarse`, likely two sessions: the developer chose one story per idea over smaller ones, 2026-10-15)
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-16

## Context

**GDD**: `design/game-brief.md`, `design/rules.md` ("Teams and visual style"; "Units"; "Turrets, Flag Walls and Mines"); `CONTEXT.md` (Unit, Badly damaged, Turret, Wall Panel, Flag Wall)
**Requirement**: The developer's request of 2026-10-15, made in a session. Asked whether the game uses shaders and whether they could improve the visuals, they were offered six ideas and answered "create stories for each of those except number 5" (the fifth, more marks in story 026's track map, was left out). This is the fourth idea, as offered: "Hit feedback: whatever gets hit flashes white for 2–3 physics ticks. This needs a small Unit shader with a per-object flash value, the same pattern as the rotor blur. Tracers become glowing streaks, with a muzzle flash and sparks where a Shot hits. Optionally, the model chars gradually as HP drops." No card of the author's board names it (the developer, 2026-10-15). The developer's answers of the same day (decided 2026-10-15): one story per idea; and of the hit looks offered, the flash, the charring and the red edge of the view: "A 2-3 tick white flash on any Unit, Turret, Wall Panel or Flag Wall a Shot damages. Units darken in patches as HP drops (structures keep their two decided damage steps)." The red edge of the view whose Unit was hit is story 031's.

Today a hit shows only in the HUD's hit points and, on a Turret, a Flag Wall or a Wall Panel, in its two damaged looks below 80% and 35% of its hit points; a Unit looks whole until it smokes at a fifth of its hit points (story 017). A Shot is a pale yellow box 1.2 m long that vanishes where it stops.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From the developer's request and answers of 2026-10-15, scoped to this story:*

- [ ] AC-1: When a Shot takes hit points from a Unit, a Turret, a Wall Panel or a Flag Wall and it survives, the whole drawn piece flashes white (data: colour and strength) on the tick of the hit and fades out over a few ticks (data: 3 to start, at 60 ticks a second), in both views; a new hit starts the flash again. A Shot that takes nothing flashes nothing (the Motorbike's on a wall, whose multiplier is 0; a Shot on its own Player's piece), and the lethal hit flashes nothing (the explosion or the fall takes over).
- [ ] AC-2: A Unit darkens in patches as it loses hit points (decided 2026-10-15): from a share of its hit points (data: 90% to start) the patches grow until a lower share (data: the badly damaged edge, 20%), where they reach their full cover (data: at most about half of the body, so the Team colour still reads: measured in frames from above and in the chase view). The patches stay on the body as it moves and turns; two Units of a type do not char alike; a new Unit, after a respawn or a Swap, starts clean. The Turrets, the Flag Walls and the Wall Panels keep their two damaged looks and get no charring (decided 2026-10-15).
- [ ] AC-3: A Shot is drawn as a glowing streak along its flight (data: length, width, a bright core and a fading tail), brighter than white so that it blooms with story 027's glow, never ahead of the Shot and never streaking from the world's origin on its first frame (`launch_from()` places it and resets the interpolation: `shot.gd:159-160`). The Shot's flight, speed, range, hit test and damage do not change.
- [ ] AC-4: On the tick a Unit or a Turret fires, a short flash shows at the Shot's origin (data: ticks, size, colour), in both views, where it was fired and not following the Shot. A Turret's Shot leaves at the shooting height, 2.15 m under its barrel's tip (kept in story 015), so its flash shows there too (question 4).
- [ ] AC-5: Where a Shot ends on something (a Unit, a Turret, a wall, the cover, a building), a short burst shows at the hit point for a few ticks (data) and then frees itself: sparks when the Shot took hit points, a puff of dust when it took none. A Shot that reaches the end of its range shows nothing. The bursts and the flashes are pictures only: nothing collides, damages or stops.
- [ ] AC-6: Every effect counts its own physics ticks (no TIME, nothing random: the sparks fly along fixed directions, as the explosion's chunks do), so the same run draws the same frames; the bursts and the muzzle flashes stop under the Round-over screen with the Shots, and a restart (R) frees every one of them, as it frees the Shots.
- [ ] AC-7: Every value is data (settings resources with zero defaults and a `first_problem()`); one material per kind of effect, shared by every copy, with the per-piece values in instance uniforms, colours as a Vector4 (story 025's trap). No number in code but 0 and 1.
- [ ] AC-8: A long fight keeps the project budget, measured windowed at 1280 x 720 the `map_fps` way: both Players firing at each other and at a Turret that fires back, Shots stopping on walls and cover, in both views (the lowest one-second rate at least 60 fps, a frame at most 16.6 ms, at most 1,000 draw calls for both views together). The frame time with and without the new looks, and the draw calls they add at their peak, are recorded as observations beside TD-016 and TD-017.
- [ ] AC-9: The older evidence scenarios keep their outputs byte for byte against the capture taken at the start of the story: every scenario that does not declare the new opt-in runs with today's Shot, no flash, no charring, no muzzle flash and no bursts.

---

## Implementation Notes

*At `minimal` there is no ADR; these are pointers, not decisions. The file:line pointers are the working tree of 2026-10-16 (`main` at 14eec71 plus story 025's uncommitted build): re-find them as stories 025 to 029 leave them.*

- **What the tree gives.** `src/gameplay/combat/shot.tscn`: a Node3D in the group `shots` with a Tracer, a 0.3 x 0.3 x 1.2 m BoxMesh in an unshaded pale yellow `(1, 0.95, 0.55)` that casts no shadow. `shot.gd` flies once per tick (`:78-100`): on a hit it moves to the hit position (`:93`), calls `_damage_target()` (`:94`, `:108-119`: `apply_damage()` on a collider that offers it, has a type and is not the shooter's Player's) and frees itself (`:95`); at its range it frees itself (`:99-100`). `Weapon._fire()` (`weapon.gd:198-212`) fires from the Unit's origin plus `muzzle_forward` along its facing plus the shooting height, and adds the Shot to the Unit's parent in the same tick; `Turret._fire()` (`turret.gd:345-355`) fires from its centre plus `muzzle_forward` at the shooting height. `Unit.apply_damage()` (`unit.gd:542-551`) ignores an amount that is not above zero, destroys at zero, and otherwise emits `hit_points_changed`, which `destroy()`, `leave_play()` and `spawn()` emit too (`:582-594`, `:610-622`, `:653-675`); its callers are the Shot and the debug-damage key (`player_match_input.gd:125`). `Structure.apply_damage()` (`structure.gd:160-168`) is the same for the Turrets, the Flag Walls and the Wall Panels, whose looks swap whole nodes and whose Turret head takes `material_override` (`turret.gd:241-247`). SplitScreen frees the Shots at every Round (`_free_shots()`, `split_screen.gd:368`) and the explosions through their group (`EXPLOSION_GROUP`, `:191`; `_free_explosions()`, `:386`).
- **Build order inside the story** (so that a session break leaves whole parts): the Shot's looks first (the tracer, the muzzle flash, the bursts: AC-3 to AC-5), then the hit flash (AC-1), then the charring (AC-2), each with its checks and frames before the next.
- **A hit.** A survived hit is a `hit_points_changed` with a lower value than the last while the piece stays in play or standing; a Shot that takes nothing emits nothing (both `apply_damage()`s), so the flash needs no change to the Shot. A refill at a spawn and a `restore()` raise the value, a bench and a destruction set it to zero: none of them flashes. The listener is the model (a Unit's `UnitModel` already listens to its Unit, `unit_model.gd:264-268`) or a small node of the piece: the build's call, with no search of the tree.
- **The flash and the charring** (measure first). `GeometryInstance3D.material_overlay` (probed on 4.7.2: it takes a BaseMaterial3D or a ShaderMaterial) draws a second material over every surface of a mesh, whatever `material_override` the damaged looks have put on it, so one shared overlay ShaderMaterial (say `src/gameplay/effects/spatial_fx_hit.gdshader`) could carry both: the flash as an emission by a per-instance strength, and the charring as soot patches by a per-instance amount, from a noise sampled in the model's own frame (object space), so the patches ride with the body, at a per-Unit offset (data, deterministic). Measure on 4.7.2: that an instance uniform of the overlay is set by `set_instance_shader_parameter()` on the same instance; whether an overlay of strength 0 left on costs a pass per mesh in both views (or is set only while needed); how a lit overlay shades the soot on the Team colour. The alternative is a ShaderMaterial that replaces the Unit's materials and reproduces their vertex-coloured look with the flash and the charring added, which must keep `Unit._paint_team_colour()` working (`unit.gd:888-895`): more work, the build's call. The Unit's meshes are the Accent, the Neutral, the Lamp and the turning parts (`mesh_unit_model.gd:73-121`); not the rotor's smear, the smoke or story 027's silhouette copies. A Structure's are every visible GeometryInstance3D of its intact look, its damaged looks and the Turret's head.
- **The tracer.** The Tracer stays the Shot's child, so the Shot moves it and World interpolates it. A new shader on its mesh (a box along the flight, or a quad that faces the camera along the flight: the build's call), unshaded, a core-to-edge falloff across it and a head-to-tail fade along it, an emission above 1 (data). In the chase view a tracer starts hidden behind its own Unit's model (a known trap of the evidence: `heights_shots.gd:54` reads the box's size).
- **The muzzle flash and the bursts.** Picture-only nodes in `src/gameplay/effects/`, instanced from a scene that is data (an export on the Shot, say, so that the Weapon and the Turret are untouched: the flash at `launch_from()`'s origin, top level, so it stays where it was fired; the burst added to the Shot's parent at the hit position just before the Shot frees itself, `shot.gd:93-95`). A star-shaped quad or a few billboard quads in one shared HDR material, their ticks and size in settings; the sparks thrown along fixed directions (data) and falling, the dust a soft puff in story 029's smoke shader if it is built first. In a group that SplitScreen frees at every Round, beside the Shots. Pausable, so they stop under the Round-over screen with the Shots (the explosion, which plays out, is the exception: `explosion.tscn:30`).
- **The older outputs** (AC-9). `tools/evidence/split_screen/heights_shots.gd:54` reads the Tracer as a BoxMesh, and the scenarios that count what is under World would see the bursts. The runner (`tools/evidence/split_screen_harness.gd`) gets a new opt-in, `const HITS_AND_SHOTS: bool = true`; for every other scenario the Weapons and the Turrets fire today's Shot (a byte copy of today's `shot.tscn` under `tools/evidence/frozen/`, or the new looks as data the runner nulls: the build's call, as in story 029), and the flash and the charring are off (their settings nulled on the shared resources before the scene is instanced, the `_apply_badly_damaged_off()` way: `:1313`). The baseline is the retained outputs of the last closed story, captured twice before the first edit.
- **The evidence scenarios.** `hits_and_shots` (headless, run twice byte-identical, declaring `HITS_AND_SHOTS` and the opt-ins its pieces need: the Turrets, the Wall Panels, the Flag Walls) checks: a hit on a Unit, a Turret, a Wall Panel and a Flag Wall, the flash's strength tick by tick and its end; none on a Shot of multiplier 0, on an own piece, at a spawn, a restore or a bench, or on the lethal hit; a second hit restarting it; the charring's amount against the hit points for each type, its full cover at the badly damaged edge, zero after a respawn and a Swap, two Units of a type at different offsets, none on a Structure; the tracer's material and size; the muzzle flash at the Shot's origin for a Unit and a Turret, for its ticks; the burst at the hit point, sparks on damage and dust on none, none at the end of the range; every effect freed at R; the settings refusing a negative tick count and a cover above 1; a lint of the new files (the `mines_lint` way: `tools/evidence/split_screen/mines.gd:170`). `hits_and_shots_showcase` (windowed `--write-movie`, waiting for 120 fps): a Buggy firing at a Turret (tracers, muzzle flashes, sparks, the Turret flashing, then its damaged looks); a Motorbike's Shots stopping on a wall (dust, no flash); a Turret firing at a Unit (its flash under its barrel, the Unit flashing); each type at full, half and badly damaged hit points, both Teams, from above and in the chase view; four consecutive frames of a tracer; before and after. `hits_and_shots_fps` (windowed A/B, AC-8).
- **Seeded defects** (story 011's script as the template). At least: a flash on a Shot that took nothing; a flash that never fades; a flash on the lethal hit; the charring not reset at a spawn; the charring sampled in world space (the patches slide over a moving Unit: windowed); charring on a Structure; a tracer that starts at the world's origin (windowed); a burst at the Shot's last position instead of the hit point; a burst left after R; a colour given to an instance uniform as a Color; spark directions that differ between runs; a number written in code (the lint); the runner leaving the new looks on (the regression fails).
- **Docs in the same change** (`design/rules.md`, Process rules): in "Teams and visual style", the flash, the charring and the Shot's looks as built; `CONTEXT.md`'s "Hit flash" and "Charring" as built; the shaders' headers; README's How it plays; a Story 030 entry in `tests/smoke/critical-paths.md`; EPIC.md's row at the close.
- Process (`design/rules.md`, Process rules): after the change, say how to test it: the main scene; fire at the other Player's Unit, at a Turret and at a wall with a Buggy and with a Motorbike; let a Turret hit you; take a Unit down to a fifth of its hit points; watch from both cameras.

---

## Out of Scope

- The red edge of the view whose Unit was hit: story 031.
- Charring on the Turrets, the Flag Walls and the Wall Panels: they keep their two damaged looks (decided 2026-10-15).
- Scorch marks on the ground (the fifth idea, left out on 2026-10-15); a Mine's flash and its blast; the Gyrocopter's crash.
- Damage numbers, recoil, shell cases, ricochets, hit sounds.
- Any change to the Shot's flight, the Weapon's cadence, a Turret's aim or the damage.

**Questions for the author** (built as read; asked at `/story-done`)
1. A piece a Shot damages flashes white for 3 ticks (a twentieth of a second). Keep, longer, shorter, or another colour?
2. A Unit darkens in patches from 90% of its hit points and is fully charred at 20%, where it starts to smoke, with about half of its body still in its Team colour. Keep?
3. Tracers are now glowing streaks. Keep the length and the brightness?
4. A Turret's muzzle flash shows under its barrel, where its Shot starts at the shooting height (kept in story 015). Keep, or at the barrel's tip (then the flash and the tracer do not meet)?
5. Where a Shot stops without doing damage (a Motorbike's on a wall) it raises a puff of dust and the wall does not flash. Keep?

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Visual/Feel
**Required evidence**:
- Retained screenshots and the lead's sign-off; record the evidence in `production/qa/evidence/story-030-hits-and-shots-evidence.md`: `hits_and_shots` run headless twice byte-identical; the windowed `hits_and_shots_showcase` and `hits_and_shots_fps` (AC-8's bar, the frame time and the draw calls as observations); the facts measured first (the overlay's instance uniforms and cost); the regression against the capture taken at the start of the story; the seeded defects.
- Retain frames in `production/qa/evidence/story-030-hits-and-shots/`: 00 the launch; a flash on each kind of piece; a Motorbike's dust on a wall; each type at full, half and badly damaged hit points, both Teams, both views; four consecutive frames of a tracer; a muzzle flash of a Unit and of a Turret; sparks at a hit.
- The human checks at `/story-done`: a fight in play (both views, both cameras); the five questions.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 027 (the glow for the tracers, the flashes and the sparks). Story 029, if built first, gives the dust its smoke shader. Never beside another story: every one of them edits the runner and re-baselines the same outputs.
- Unlocks: None (story 031's red edge reads the same hits from the Unit's `hit_points_changed`, with or without this story).
