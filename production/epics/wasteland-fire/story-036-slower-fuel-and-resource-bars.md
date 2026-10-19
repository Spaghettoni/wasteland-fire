# Story 036: Fuel lasts three times longer, and Fuel and ammo are two coloured bars with icons

> **Epic**: Wasteland Fire — First Playable
> **Status**: In Progress
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: S (half a day at `coarse`: four data lines, one new bar, two icons)
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-19

## Context

**GDD**: `design/game-brief.md`, `design/rules.md` ("Resources"); `CONTEXT.md` (Fuel, Ammo)
**Requirement**: Martin's request of 2026-10-19, made in a session: "chcem aby sa benzin ovela menej minal - ze 3x pomalsie. a potom, rad by som aby aj ammo, aj benzin boli bars, z ktorych sa mina, kazdy inej farby, vedla seba. a nemusi tam byt napis, ale ikonka benzinu a ikonka municie" (Fuel should burn much less, three times slower; ammo and Fuel should both be bars that empty, each its own colour, side by side, with no text but a Fuel icon and an ammo icon).

Today every type burns `fuel_use` per second while it drives and `fuel_use_idle` while it stands (Motorbike 2.0 / 0.5, Buggy 2.5 / 0.625, Truck 3.0 / 0.75, Gyrocopter 5.0 / 1.25, with a 100 tank: `src/gameplay/units/data/*_stats.tres`). The HUD band shows the hit points as a green bar with "HP n / max" and the Fuel as an amber bar with "Fuel n / 100" (`player_hud.tscn`, x 332 to 624); the ammo is a text line "Ammo n / max" under the band (`ammo_count.tscn`, story 022).

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From Martin's request of 2026-10-19, scoped to this story:*

- [ ] AC-1: Every type burns Fuel three times slower, driving and standing: Motorbike 0.667 / 0.167, Buggy 0.833 / 0.208, Truck 1.0 / 0.25, Gyrocopter 1.667 / 0.417 per second (data, the four `*_stats.tres`); a full tank lasts three times as long, measured in ticks. The tank, the refill at the Fuel building and the Gyrocopter's crash when empty do not change.
- [ ] AC-2: In each Player's HUD band, right of the hit-point bar, a Fuel icon and the Fuel bar, then an ammo icon and the ammo bar, side by side on the same row, each bar its own colour (Fuel amber as today, ammo a colour no other bar or Team uses), with no text on or under them. The bars empty as Fuel burns and Shots are fired, refill at the supply buildings and are full for every new Unit.
- [ ] AC-3: The "Ammo n / max" line under the band is gone; the Mines line stays where it is. A type with no ammo count (capacity 0) shows no ammo bar and no ammo icon.
- [ ] AC-4: The icons are the repository's own (SVG drawn for this story, no downloaded art), readable on sand, salt flat and water in both views, with the Team edge still round the whole band.
- [ ] AC-5: Every value is data: the burn rates in the stats, the colours and sizes in the scenes; no number in code but 0 and 1.
- [ ] AC-6: The older evidence scenarios keep their outputs against the capture taken at the start: the runner gives them the old burn rates and the old HUD (a frozen copy of today's `player_hud.tscn` and the Ammo line) unless they declare `RESOURCE_BARS`.

---

## Implementation Notes

- Burn: divide the eight values by three in the four stats files. The runner (`tools/evidence/split_screen_harness.gd`) restores the old rates on the shared resources, before the older data helpers run, for every scenario that does not declare `RESOURCE_BARS`.
- Bars: the Fuel bar keeps its node and colour, loses its line and gets a `FuelIcon`; a new `AmmoBar` (icon and ProgressBar, listening to `Weapon.ammo_changed` as `AmmoCount` does) replaces each Player's `AmmoCount` in `split_screen.tscn`. `AmmoCount` stays in `src/ui/hud/` for the runner's older scenarios. The band's Team edge is drawn round PlayerHud's children; the AmmoBar sits inside that rectangle.
- Docs in the same change: `design/rules.md` Resources (the rates and the bars as built), README, `tests/smoke/critical-paths.md`, EPIC.md.

---

## Out of Scope

- The hit-point bar keeps its "HP n / max" line (not asked).
- The Mines line stays text.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: UI
**Required evidence**: a retained screenshot of the HUD band in both views (a full tank and gun, a half-empty one, a Unit with an empty gun), in `production/qa/evidence/story-036-slower-fuel-and-resource-bars/`, and the scenario `resource_bars` measuring the burn rates and the bars.

**Status**: [x] Created 2026-10-19: `production/qa/evidence/story-036-slower-fuel-and-resource-bars-evidence.md`, three frames and `scenario-outputs/resource_bars.txt`; the human checks and sign-off are for `/story-done`

---

## Dependencies

- Depends on: None.
- Unlocks: None.
