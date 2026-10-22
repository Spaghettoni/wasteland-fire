# Story 044: Secondaries recharge, a bar for each, the Motorbike drops the Flag, bigger Bushes

> **Epic**: Wasteland Fire — First Playable
> **Status**: In Progress
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-22

## Context

**GDD**: `design/rules.md` ("Secondaries recharge"); `CONTEXT.md` (Secondary weapon, Nitro, Smoke screen)
**Requirement**: Martin, 2026-10-22, after playing story 042: "zvacsi trochu kricky, paci sa mi myslienka ze sa schovas s moto do kricku" (make the bushes a bit bigger, I like hiding in a bush with the motorbike); "nitro super, daj 15 s nabijanie" (15 s recharge); "smoke, super len nech sa spravi pred gyro, nech trva 3 sek a tiez sa nabija ale 15s" (the smoke appears in front of the gyro, lasts 3 s and recharges in 15 s); "skusme dat aj miny ze sa nabijaju 15s a dat tam ku kazdemu vozitku nejaky bar co sa dobija aj s popisom smoke/mine/boost a pri moto drop flag ked je to aktualne" (Mines recharge in 15 s too; a recharging bar for every vehicle labelled smoke/mine/boost, and drop flag for the motorbike when it applies).

Reading taken (Martin was not asked): every secondary has one charge that refills in 15 s, with no count; the Truck's Mines become unlimited; the Motorbike's secondary key drops the Flag it carries.

**ADR Governing Implementation**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM

---

## Acceptance Criteria

- [x] AC-1: The Buggy's boost recharges 15 s after it ends (it still runs 2 s at 1.6 ×).
- [x] AC-2: The Gyrocopter's smoke screen is dropped 10 m ahead of it, hangs 3 s (1 s fade) and recharges 15 s; no count.
- [x] AC-3: The Truck's Mine recharges 15 s after a lay; the Mines are unlimited and the count line is hidden; a refused lay costs no charge.
- [x] AC-4: While a Motorbike carries a Flag the secondary key drops it at its tail (flag_dropped, DROPPED); the Motorbike does not take it again until it has been 5 m away and out of its touch.
- [x] AC-5: Each view shows the secondary's bar with its name ("Boost", "Smoke", "Mine", "Drop flag"): full and yellow when ready, grey while it refills; hidden with nothing on the key.
- [x] AC-6: Bushes are 1.4 times their size (looks, sight body and trigger); a Motorbike in one is not seen by a Turret. All values are data (`buggy_stats.tres`, `gyrocopter_stats.tres`, `truck_stats.tres`, `smoke_settings.tres`, `match_rules.tres`, `bush.tscn`); the older scenarios keep their outputs.
- [x] AC-7: The look: frames of each bar and of the Motorbike in a Bush.

---

## Implementation Notes

- `UnitStats`: `smoke_cooldown_seconds` replaces `smoke_capacity`; `mine_cooldown_seconds` (zero keeps story 014's count).
- `SmokeLauncher` recharges and drops ahead (`SmokeSettings.ahead`); `MineLayer.recharges()`, `charge()`; `NitroBooster.charge()`.
- `FlagDropper` (one per Player) calls `MatchController.request_flag_drop()`; `FlagRules.release()` keeps the releaser off the Flag until it is `flag_release_metres` away and out of its touch (a teleport leaves stale overlaps for a tick).
- `SecondaryStatus` is now a name and a `ProgressBar`.
- `Bush.size`, applied to the looks and the cylinders in `_ready()` (`set_size()`).

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `secondary` (X1 to X6, rewritten for this story), twice byte-identical; five frames in `production/qa/evidence/story-044-secondaries-recharge/`; the regression; Martin's play.

**Status**: [x] Created 2026-10-22: `production/qa/evidence/story-044-secondaries-recharge-evidence.md`

---

## Dependencies

- Depends on: story 042, story 043, story 038 (Bushes).
- Unlocks: none.
