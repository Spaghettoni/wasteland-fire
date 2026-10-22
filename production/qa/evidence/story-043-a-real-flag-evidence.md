# Story 043 evidence: A real flag

> **Story**: `production/epics/wasteland-fire/story-043-a-real-flag.md`
> **Type**: Visual/Feel (headless scenario + windowed frames)
> **Written**: 2026-10-22, by `/dev-story` in a cloud session (Linux, Godot 4.7.2 official build)
> **Sign-off**: [ ] Martin, after playing `WastelandFire-2026-10-22-secondary-flag.exe`

## Acceptance criteria, as measured (`real_flag`, Map 01)

| AC | Result | Check |
|---|---|---|
| AC-1 pole, cloth, foot | PASS: both Flags 3.12 m tall, 4 of 4 panels in their Base's colour, the foot shown | F1 |
| AC-2 waves | PASS: 4 of 4 hinges turned in 15 ticks, widest 0.296 rad (amplitude then 0.32; now 0.42) | F2 |
| AC-3 banner | PASS: picked up by Player 1's Motorbike; no foot; the cloth's middle 0.69 m behind its pole along the Motorbike's back | F3 |
| AC-4 planted; rules unchanged | PASS: DROPPED, leaning 9.0°, sunk 0.25 m, no foot; seated again upright on its foot; `flag_run`, `flag_open` and every flag scenario byte-identical | F4, regression |
| AC-5 the look | frames below | — |

`real_flag` ran twice, byte-identical (`story-043-a-real-flag/real_flag.txt`).

## Seeded defects

| Mutation | Caught by |
|---|---|
| `apply_color()` paints only the first panel | F1 (1 of 4) |
| The wave is zero | F2 |
| The carried mast is not turned (the cloth sticks out sideways) | F3 (-0.29 m) |

## Frames

`secondary_flag_showcase`, windowed, 1280 x 720. `03-flag-on-its-seat.png` (Player 2's Flag under its water tower, whose top is not drawn from above), `04-motorbike-carrying-the-flag.png`, `05-flag-planted-where-the-carrier-fell.png`, and two close-ups from a low camera: `06-close-up-planted.png` (planted on the flat, leaning) and `07-close-up-on-its-seat.png` (on its foot under the tower). From the game's cameras the Flag is small, as a 3 m thing is next to a 2 m Motorbike; the cloth was made bigger (1.92 × 1.1 m) and waves wider after the first frames.

## Human checks

1. Can you see the Flag well enough from above, on its seat and on the Motorbike?
2. Is the wave too much, too little?
