# Story 036: Fuel lasts twice as long, and Fuel and ammo are two coloured bars with icons

> **Epic**: Wasteland Fire — First Playable
> **Status**: Complete
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

- [x] AC-1: Every type burns Fuel at half its earlier rate, driving and standing: Motorbike 1.0 / 0.25, Buggy 1.25 / 0.3125, Truck 1.5 / 0.375, Gyrocopter 2.5 / 0.625 per second (data, the four `*_stats.tres`); a full tank lasts twice as long, measured in ticks. (Built first at a third; Martin played it and chose half, 2026-10-19: "3x pomalsie je az prilis pomala, dajme to na 2x pomalsie". The ammo bar is blue, Martin's choice after seeing lavender.) The tank, the refill at the Fuel building and the Gyrocopter's crash when empty do not change.
- [x] AC-2: In each Player's HUD band, right of the hit-point bar, a Fuel icon and the Fuel bar, then an ammo icon and the ammo bar, side by side on the same row, each bar its own colour (Fuel amber as today, ammo a colour no other bar or Team uses), with no text on or under them. The bars empty as Fuel burns and Shots are fired, refill at the supply buildings and are full for every new Unit.
- [x] AC-3: The "Ammo n / max" line under the band is gone; the Mines line stays where it is. The ammo bar and its icon show always, as the Fuel bar does, an empty bar while no Unit is in play (Martin, 2026-10-19: "aby sa ammo zobrazovalo aj ked nemas este vybraty voz, tak ako sa zobrazuje fuel"; built first hidden while the Weapon's capacity was 0).
- [x] AC-4: The icons are the repository's own (SVG drawn for this story, no downloaded art), readable on sand, salt flat and water in both views, with the Team edge still round the whole band.
- [x] AC-5: Every value is data: the burn rates in the stats, the colours and sizes in the scenes; no number in code but 0 and 1.
- [x] AC-6: The older evidence scenarios keep their outputs against the capture taken at the start: the runner gives them the old burn rates and the old HUD (a frozen copy of today's `player_hud.tscn` and the Ammo line) unless they declare `RESOURCE_BARS`.

---

## Implementation Notes

- Burn: halve the eight values in the four stats files. The runner (`tools/evidence/split_screen_harness.gd`) restores the old rates on the shared resources, before the older data helpers run, for every scenario that does not declare `RESOURCE_BARS`.
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

---

## Completion Notes

**Completed**: 2026-10-19
**Criteria**: 6/6 passing (`resource_bars`, 5 checks, run twice byte-identical; three frames), with the changes Martin asked for after playing, the same day: the burn halved instead of a third, the ammo bar blue instead of lavender, and the ammo bar shown always (empty while no Unit is in play) instead of hidden.
**Deviations**: None.
**Test Evidence**: UI: `production/qa/evidence/story-036-slower-fuel-and-resource-bars-evidence.md` (sign-off `[x]`, 2026-10-19), frames in `production/qa/evidence/story-036-slower-fuel-and-resource-bars/`, the regressions of story 036 and story 037.
**Code Review**: Skipped, Solo mode; QL-TEST-COVERAGE skipped, `qa.level` minimal.
**Tech debt logged**: None. `src/ui/hud/ammo_count.gd`/`.tscn` stay under `src/` used only by the evidence runner's older scenarios (as TD-015 records for the Fuel Can).
