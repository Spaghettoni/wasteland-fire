# Story 051: The HUD in one row, with icons

> **Epic**: Wasteland Fire — First Playable
> **Status**: In Progress
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: S
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

**Requirement**: Martin, 2026-10-25: "musime zmensit tie ui veci - health bar a tak, vsetko by to malo byt v jednom riadku, aj boost a tak. to kde je vlajka by mala byt symbol vlajocka v doceku, vlajocka uteka. alebo nieco take. pre boost, minu, smoke drop dajme tiez ikonky. hp staci bar, nemusi byt aj pocet hp napisany." (make the HUD smaller, all in one row, the boost too; the Flag's state as a symbol, a flag in its dock, a flag running off; icons for boost, mine, smoke, drop; the hit points as a bar only.)

**ADR Governing Implementation**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: LOW

---

## Acceptance Criteria

- [x] AC-1: Each view's HUD is one row from x 16 to 624, about 28 px tall, inside the Team edge: the Flag icon first (Martin, the same day: "Daj prosim este tu vlajku v ui uplne dolava"), hit-point bar, Fuel icon and bar, ammunition icon and bar, secondary icon and bar.
- [x] AC-2: The hit-point bar shows no number.
- [x] AC-3: The Flag icon shows the Flag in its dock (own Flag at home), the red Flag running off (own Flag away), the golden Flag on a wheel (carrying the enemy Flag); the three differ in shape, not only colour.
- [x] AC-4: The secondary weapon shows as an icon: a flame (Boost), a cloud (Smoke), a Mine, a Flag with an arrow down (Drop flag, no bar).
- [x] AC-5: The hidden text lines keep their texts (the evidence and a later translation read them); the earlier scenarios pass.

---

## Implementation Notes

- New SVGs in `assets/art/ui/`: `flag_home_icon`, `flag_away_icon`, `flag_carrying_icon`, `boost_icon`, `smoke_icon`, `mine_icon`, `drop_flag_icon` (48 x 48, the dark 3 px outline of the Fuel and ammunition icons).
- `player_hud.tscn`: one row; `HitPointsLabel`, `FlagStatusLabel` and `TokensLabel` hidden with their texts; a `FlagIcon` and an empty `SecondarySlot` that keeps the Team edge round the `SecondaryStatus` beside the HUD. `PlayerHud` sets the icon with the status line and leaves hidden elements out of the edge.
- `secondary_status.tscn`: 468 to 624 on the first row, an `Icon` and the bar, the name hidden; `SecondaryStatus` sets the icon with the name.

---

## Test Evidence

**Story Type**: UI
**Required evidence**: frames of the HUD with two and four Players and with the Flag at home, away and carried in `production/qa/evidence/story-051-one-row-hud/`; `hud_showcase` S1; the regression.

**Status**: [x] Created 2026-10-25: `production/qa/evidence/story-051-one-row-hud-evidence.md`

---

## Dependencies

- Depends on: stories 004, 006, 022, 036, 045 (the HUD's elements).
- Unlocks: none.
