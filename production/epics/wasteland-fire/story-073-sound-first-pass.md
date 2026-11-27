# Story 073: Sound, first pass (recovered)

> **Epic**: Wasteland Fire — First Playable
> **Status**: Done
> **Layer**: Presentation
> **Type**: Integration
> **Last Updated**: 2026-11-27

## Context

Built with Martin on 2026-11-23 in another session ("Zvukové efekty: Kenney a Sonniss"): sounds picked from the Kenney and Sonniss packs, cut to 21 game-ready .ogg files in `C:\DATA\Ronin Ya\Wasteland Fire\Sound\_hra`, and wired on a local branch `audio/first-pass` that was never committed or pushed. Martin, 2026-11-27: "mam pocit ze zmizol zvuk". Recovered here from that session's record and committed.

## What

- `assets/audio/sfx/` — the 21 sounds (engine, flamer and fire loops imported looping).
- `SoundPlay` (one-shots at a point or flat, loops) and `UnitEngineSound` (the engine loop, pitch from speed) in `src/gameplay/audio/`; randomizers in `src/gameplay/audio/data/`.
- Hooks: Shot launch and impact (metal on what takes damage, ground otherwise), the rocket, Unit explosions, Mine blasts, Structures falling, the flamer's roar (Weapon), the burning crackle (Burning), menu sounds (side pick, map choice, unit choice). Volumes and pitches in the data (UnitStats, StructureStats, ExplosionSettings, MineSettings, the shot scenes).
- The two Player SubViewports listen in 3D (`audio_listener_enable_3d`), so each Player hears round their own vehicle.
- Change against 2026-11-23: the loops' random start point comes from the node id, not the global random numbers the game logic draws from.

## Test Evidence

Full regression (132): the same exits as before, except one `ammo_buildings` run that crashed in the engine (a thread error, signal 11); rerun three times alone, ok each time. A recording of `effects_showcase` with sound: audible engines, shots and impacts (`/mnt/user-data/outputs/wasteland-fire-zvuk-a-grafika.mp4`, sent to Martin); frame `production/qa/evidence/story-073/game-frame.png`.
