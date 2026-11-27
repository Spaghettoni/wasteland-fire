# Story 072: Art overhaul, Martin's first feedback

> **Epic**: Wasteland Fire — First Playable
> **Status**: Done
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: M
> **Last Updated**: 2026-11-27

## Context

**Requirement**: Martin, 2026-11-27, on the Story 071 build: "paci sa mi ako to vyzera, to svetlo farby, tiene. ale spravil by som tieto zmeny:"
- "ten tilt shif skusme vypnut, sa s tym tazko hra"
- "ten piesok - rozne kocky to je fajn, len prilis vidno ten grid ... paci sa mi low poly, ale asi nie take pravouhle. nech to nie je ako minecraft"
- "tie oranzove kopky co sme tam pridali tie by som dal prec. kaktusy su zatial ok, ale nech nad nimi preleti gyro."
- "zelene kricky fajn, len tiez su minecraftove"
- "mam pocit ze zmizol zvuk" — the Godot game has never had sound: no audio file or player in the repository's history (all 60 commits) or on the other branch. Answered, not changed.
- "tie velke kopce v pozadi su tiez take minecraftove, mohli by byt jednoduchsie. davaju mi zmysel, ale nie na ostrovnych mapach."
- "ohen z flame trucku, je stale velmi nepresvedcivy, mohol by byt lepsie spraveny"

## Acceptance Criteria

- [x] AC-1: No tilt-shift: the Player cameras carry no camera attributes.
- [x] AC-2: The ground's square tiles became irregular low-poly facets (Voronoi cells about 0.9 m, each its own tone and tilt, no seams).
- [x] AC-3: No rocks; cactuses drawn no taller than 1.9 m (colliders 1.2 m), under the Gyrocopter's 2.5 m.
- [x] AC-4: The Bush's looks are faceted low-poly blobs, not voxels.
- [x] AC-5: Mesas only on Map 02 (the desert; Maps 01 and 03 are island Maps), low-poly tiers with strata bands, their whole footprint out of play. Cliffs and canyon walls: smooth wavy strata on their sides, sand on their tops.
- [x] AC-6: The flame stream is soft, flickering fire sprites (spatial_fx_fire_sprite.gdshader): white-yellow core that blooms, orange, red, then smoke; the puffs swell, rise and never repeat.
- [x] AC-7: The full regression has the same exits as before the overhaul.

## Test Evidence

`production/qa/evidence/story-072-evidence.md`, frames in `production/qa/evidence/story-072/`.
