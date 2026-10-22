# Story 045: The secondary bar in the Tokens line's place, zone colours like the bars

> **Epic**: Wasteland Fire — First Playable
> **Status**: In Progress
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: S
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-22

## Context

**GDD**: `design/rules.md` ("The HUD's bar and the zones' colours")
**Requirement**: Martin, 2026-10-22, on story 044's frames: "drop flag nepotrebuje bar. a dajme prec tu info kolko ostava moto a tam posunme ten bar. tiez zmenme farbu tankovacich ploch, nech benzinova ma rovnaku ako ma fuel bar a ammo plocha modru ako ammo bar. boost moze byt sede pozadie biely bar" (drop flag needs no bar; remove the Motorbikes-left info and move the bar there; the fuel zones the fuel bar's colour, the ammo zone blue like the ammo bar; the boost can be a white bar on grey).

**ADR Governing Implementation**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: LOW

---

## Acceptance Criteria

- [x] AC-1: The HUD shows no Motorbike Tokens line; the secondary bar stands in its place on the band's second row.
- [x] AC-2: "Drop flag" is a name with no bar, ending at the band's right edge.
- [x] AC-3: The boost bar is white on grey (with a dark edge, so it reads on the salt flat); the other bars as in story 044.
- [x] AC-4: A Fuel zone's marking is the fuel bar's amber and an ammunition zone's the ammo bar's blue, drawn unshaded.
- [x] AC-5: The older scenarios keep their outputs (the runner shows the Tokens line and gives the zones their old look unless a scenario declares `SECONDARY`).
- [x] AC-6: Frames of each screen touched.

---

## Implementation Notes

- `PlayerHud.show_tokens_line` (the launch scene sets it false; the label keeps its place in the band).
- `SecondaryStatus`: `background_style`, `boost_fill_style`, `boost_background_style`; the bar is hidden for "Drop flag".
- `supply_zone.tscn` amber unshaded; `ammo_building.tscn` gets its own zone material (0.24, 0.545, 1, unshaded), the building's pale yellow paint stays.

---

## Test Evidence

**Story Type**: UI
**Required evidence**: `secondary` X4 and X6 (extended); six frames in `production/qa/evidence/story-045-hud-and-zone-colours/`; the regression.

**Status**: [x] Created 2026-10-22: `production/qa/evidence/story-045-hud-and-zone-colours-evidence.md`

---

## Dependencies

- Depends on: story 044.
- Unlocks: none.
