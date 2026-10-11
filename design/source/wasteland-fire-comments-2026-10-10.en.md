# Wasteland Fire — the author's comments of 2026-10-10, English translation

Source: nine comments the author wrote after playing the build with the Flag Walls, the Turrets and
the Truck's Mines (stories 012 to 014, commit 8067cba), pasted in conversation by the developer on
2026-10-10. The Slovak is archived beside this file as `wasteland-fire-comments-2026-10-10.sk.txt`,
exactly as typed (without diacritics). Translated on 2026-10-10, and checked against a second,
independent translation made the same day; where the two differed, the notes below say which reading
is used. Where this translation and the Slovak differ, the Slovak wins. The author's board has no
cards for these features (the developer, 2026-10-10), so the comments are the whole source. This is
the author's text; the project's rules of record are `design/rules.md`, where the developer's ten
answers of 2026-10-10 to what the comments leave open are recorded, and the stories built from them
are listed in `production/epics/wasteland-fire/EPIC.md`.

Built as stories 015 to 024 (decided 2026-10-10), in this order: 015 the Turrets show their damage;
016 a destroyed Unit explodes; 017 badly damaged Units smoke and slow down; 018 the Base walls become
Wall Panels; 019 the Garage walls and the scrap walls become Wall Panels; 020 two Heights, the
Gyrocopter flies high; 021 a Gyrocopter that flies into a Tall piece crashes; 022 ammo, and full
supplies for every new Unit; 023 the Fuel building replaces the Fuel Cans; 024 the ammunition
buildings, and no Mines at the supply zones.

## The comments

1. Those turrets are tuned very well: accuracy, power. If need be, we will still play with their
   HP. It would definitely be nice if you could clearly see on them that they are being destroyed,
   like the walls.
2. I think it could be visible on the vehicles too; or rather, they could have a state: when they
   are at, for example, 20% [of their hit points], smoke comes out of them and they go slower. By
   half, for example.
3. Those walls are good, so let's just replace all the walls on the map with this type.
4. I would also make it, as we talked about, so that there are 2 height levels: in the 1st are the
   vehicles, walls, boulders, ...; in the 2nd the gyro flies, and there are, for example, the
   turrets' heads. Maybe some buildings will be at that height too. At the same time the hitboxes
   are always in both, through the whole height.
5. And so the gyrocopter moves only in that 2nd level; it never descends into the first at all.
6. It would be nice if a destroyed vehicle exploded, whether it was destroyed, self-destructed, or
   the gyrocopter crashed into a high obstacle.
7. So I would also add ammo besides fuel.
8. At the same time both ammo and fuel would be refilled only at buildings meant for it: right in
   front of the ammunition/fuel building there will be a zone where, while you stand there, your
   supplies are topped up.
9. You start with full supplies of both fuel and ammo.

## Translation notes

- The comments are typed fast, without diacritics and with English game words mixed in ("hp",
  "state", "ammo", "fuel", "full", "hitboxy", "gyro"). With the diacritics restored, comment 1
  reads "Veľmi dobre sú tie vežičky vyladené. Presnosť, sila. Keď tak sa ešte pohráme s tými hp."
- "Vežičky" are the project's Turrets (see the board's translation notes of 2026-10-07);
  "vyladené" is "tuned", "dialled in": praise for the values as they are. "Presnosť, sila"
  (accuracy, power) names what is well tuned; the hit points come in the next sentence, so "sila"
  is hitting power, not toughness.
- "Keď tak" is colloquial for "if need be", "perhaps later": the hit-point sentence is a possible
  later tweak, not a request now. "Tými hp" ("those hp") most plainly means the Turrets' hit points.
- "Zreteľné" is "clearly visible"; "že sa ničia" is imperfective ("that they are being destroyed"),
  so the damage is to show step by step as the hit points fall, as on the Flag Walls ("múry" here
  are the board's destructible walls, the project's Flag Walls).
- "Vozidlá" are vehicles, the project's Units ("vehicle" is on `CONTEXT.md`'s avoid list). In
  comment 4 they are set against the gyro, so they mean the ground Units; in comment 6 a destroyed
  "vozidlo" includes the Gyrocopter. Comment 2's damaged state was decided for all four types
  (2026-10-10).
- "Resp." (respektíve) is "or rather", a false friend of "respectively". "State" is the English
  word for a game state; one state is described ("when they have 20%"), and both numbers carry
  "napr." (for example): starting values, not rules.
- "Keď majú 20 %" ("when they have 20%") is read as at or below 20% of the Unit's own maximum hit
  points; "o polovicu" ("by half") as half speed.
- "Nahraďme" is a direct "let's replace", firmer than the conditionals around it. "Všetky múry na
  mape" (all the walls on the map) was decided as every wall of Map 01 (2026-10-10): the Base
  walls, the Garage walls and the two scrap walls.
- "Ako sme sa bavili" ("as we talked about") points to an earlier conversation that the repository
  and the board do not record. "Výškové úrovne" are height levels; the project calls them Heights,
  low and high, because "level" already means a Map or a Round elsewhere and is on the glossary's
  avoid lists.
- "Balvany" are boulders; Map 01 has none by that name, so the low Height is what Map 01 already
  has (the walls, the cover, the cliffs, the water). The author's "..." leaves the list open.
- "Hlavy vežičiek" are the Turrets' turning heads; "napr." marks them as one example of what is
  in the high Height. "Možno niektoré budovy" ("maybe some buildings") is a hedge; the tall pieces
  were decided as today's solid ones (2026-10-10).
- "Hitboxy sú vždy v oboch – cez celú výšku" ("the hitboxes are always in both, through the whole
  height") was read, and decided (2026-10-10), as: Shots ignore the Heights, so every Unit still
  hits every Unit, the Gyrocopter included, and a wall between them still stops the Shot.
- "Vôbec neklesá do prvej": "never descends into the first at all" ("klesať" is to sink).
- "Narazí do" covers a bump as well as a crash; the crash was decided as a hit at speed
  (2026-10-10). "Vysoká prekážka" is a tall obstacle, one that reaches the high Height.
- "Okrem" alone can mean "except", but with "aj" it adds: "also ammo, besides fuel". "Fuelu" is
  the English "fuel" with a Slovak genitive ending.
- "Dopĺňali" is conditional and imperfective: a refill that runs over time. "Pri budovách na to
  určených" (at buildings meant for it) is plural. "Budovov" is not a Slovak form: it is read as
  "budovou" ("in front of the building", singular), since a final v and u sound alike. The slash in
  "ammuniton/fuel" (sic) was read as two kinds of building, one per supply.
- "Kde keď stojí" is third person ("where, when it stands") although the clause goes on with "Ti"
  (you): either a slip for "stojíš" (you stand) or the Unit as the subject. "Stáť" said of a
  vehicle means to stand still, so the refill was decided as needing a stop (2026-10-10).
- "Začínaš" is the generic "you start" (the Player). It was decided (2026-10-10) as every new Unit:
  the first spawn, every respawn and every Swap.
