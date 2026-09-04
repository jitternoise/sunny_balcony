# Flash Flood — Story Bible (wordless)

**Status:** design doc, agreed 2026-08-31. Nothing in the engine implements this yet.

---

## The rule

**The story contains no text.** No narration, no dialogue, no character names, no
written lore, anywhere in the story layer. Everything is carried by animation,
staging, colour and sound.

**Menus and UI keep their words and numbers.** Level names, the Level Select list,
Start / Retry / Back / Got it / Next, inventory counts, "Tiles left: 3", level
numbers — all fine. The line is: *if it's telling you the story, it has no words;
if it's telling you how to operate the game, it can.*

Open decision on `intro_text` — see "Open decisions" at the bottom.

---

## Premise (never stated in-game)

Once a year the snowfield at the top of the mountain lets go all at once. For one
afternoon there is a river. It doesn't wait, it doesn't come back, and every pool
it misses stays dry until next spring.

Every animal on the mountain has a pool. Most years, most of them stay dry.

Partway down the river, humans built a hydroelectric plant. It dams the flood. The
pools below it have been drying up for years and no animal understands why.

The player is a small bird who goes out ahead of the flood and sets the stones.

*None of the above is ever written down for the player. It is inferred from what
they watch.*

---

## The central idea: the pool bar is the story

The pool status bar is currently four abstract boxes above a hex, filling one per
connected beat (`POOL_BEATS_REQUIRED = 4`). Replace the boxes with an animal.

| Beats | What the player sees |
|---|---|
| 0 (bar hidden) | an animal lying beside a dry basin, not looking at anything |
| 1 | its head comes up |
| 2 | it stands |
| 3 | it walks to the edge |
| 4 | it drinks |

Same data, same four beats, no new mechanics, no new simulation state. Every pool
in all 100 levels becomes a small silent scene. This is where roughly 90% of the
storytelling happens, and it costs one drawing routine plus a sprite set per
chapter animal.

Cumulative progress already behaves correctly for this: the README notes lit boxes
never un-light when a stream is diverted away, so the animal never walks backwards
— it waits, standing, which reads exactly right.

---

## Every existing mechanic is already a story beat

Nothing below requires new gameplay. It is restaging what the engine already does.

| Mechanic | Staged as |
|---|---|
| Water source | the mountain letting go |
| Pool fills | an animal drinking (above) |
| Fire | an animal backed against flame; water lands, smoke turns white, it walks out |
| Town | lit windows. Water reaches a town cell and the lights go out one by one — that is the loss screen |
| Bottom-edge loss | water hits sand and is simply gone; cut to something far downhill that had started walking toward it, stopping |
| Mudslide | the river losing patience. It shoves |
| Dirt / digging | ground too hard to open until the flood is pressing on it — which is exactly the post-Start-only dig rule from 2026-08-31 |
| Geyser | something buried shaking itself awake |
| Splitter | one stream, two animals drinking at once |
| Wall (2 cells) | a boulder. It settles where it settles; you always get more stone than you asked for |
| Bomb Catapult | human quarry charge, not an animal's tool. Given to the bird by the village dog in Ch. 8 |
| Hydro plant | concrete. Water piles against it and just sits. Opened: three rivers, **and the village lights stay on** |

The hydro plant's activation rule (water must back up against it before it can be
opened) is the ending's dramatic structure, already implemented.

---

## The recurring frame: the Pan

One image, returned to at every chapter break, same camera angle, thirteen times:
**the dry lake at the bottom of the mountain.**

Cracked white → a dark stain at one edge → damp → a puddle → shallow water →
horses walking into it.

Thirteen versions of one still frame with light motion. This is the cheapest
storytelling in the plan and probably the most effective — the whole arc, wordless,
at a glance.

---

## The mother

Not dead, not missing, never named, never explained.

**Backstory (never stated):** when the plant went in, there was no longer enough
flood to reach every pool. She chose to save everything *above* the plant and let
everything below it go. She has not been below the concrete since.

**Her visual rule — this is the entire characterisation:** in every chapter of Acts
I and II she appears as a small shape high in the frame, always upstream, always on
the high side of the plant. Never once below it.

**One flashback vignette**, at the Act II turn: the plant going up, the river
splitting into reachable and not, her turning uphill, the bottom of the mountain
going brown behind her. Four shots.

**The payoff is one frame in the finale: she is standing below the plant.** That is
the reunion, the apology and the forgiveness in a single composition, and a player
who has seen the previous ninety-nine levels reads it instantly.

---

## The ending

The plant cannot be opened by one river. It needs water backed up hard against all
three of its cells — the whole mountain's water arriving at once: the geysers woken
in Ch. 3 and 10, the badgers' channels, the ants' network, the catapult from Ch. 8.
That convergence *is* what the Gauntlet levels already are mechanically.

**The last input of the game is one tap.** Everything is placed, the water is
standing against the concrete, and the final act is opening it.

Three rivers come out. Water keeps running through — nothing is destroyed, the
village keeps its lights, nobody is punished. The Pan fills for the first time in
the bird's life. The mother is standing below the plant. Every animal from all
thirteen chapters is at the water's edge.

---

## The thirteen chapters

Mapped one-to-one onto the existing campaign groups. No level data changes.

### Act I — the way it's always been done

| Ch | Group | Levels | Animal | Vignette (~4s, no words) |
|---|---|---|---|---|
| 1 | Riverbed Basics | 1–12 | Beavers | An old beaver sets a stone. Water bends. She looks at the young bird: *you try.* |
| 2 | Long Corridors | 13–17 | Salmon | A school pressed into a shrinking channel, all facing one way |
| 3 | Special Waters | 18–20 | Spadefoot toads | Cracked mud. A hand comes out of it |
| 4 | Dig the River | 21–22 | Moles | A mole digging in the dark, ear to the earth, listening for water |

### Act II — something is wrong with the river

| Ch | Group | Levels | Animal | Vignette |
|---|---|---|---|---|
| 5 | Diverter Drills | 23–30 | Otters | Otters sliding, joyful. Pull back: the wet mark on the rock is a metre above the waterline |
| 6 | Wall Work | 31–38 | Tortoise | A tortoise at a dry basin. It looks at the bird, looks up at the shape upstream, and turns away |
| 7 | Split Networks | 39–46 | Ants | A single line of ants carrying water one drop at a time. Very slow. It isn't working |
| 8 | Town Defense | 47–54 | Village dogs | A sheepdog at a fence, looking uphill at the concrete, then downhill at the lit village. She pushes something toward you with her nose |
| 9 | Flat Fields | 55–62 | Bison | An enormous herd. One small wet patch |

**The flashback vignette plays at the Ch. 8 break** — the turn of the whole game,
and the point where the player stops only helping animals and starts protecting the
people whose plant broke the river.

### Act III — the thing in the river

| Ch | Group | Levels | Animal | Vignette |
|---|---|---|---|---|
| 10 | Geyser Country | 63–70 | Flamingos | Steam. Colour. Water where nobody was looking for it |
| 11 | Big Digs | 71–78 | Badgers | A four-hundred-year tunnel. Beside it, a blast crater. The badger considers both |
| 12 | Jamboree Runs | 79–86 | Everyone | Every animal from Ch. 1–11 arriving, each carrying one stone — which is *why* the block budget is shared |
| 13 | The Gauntlet | 87–100 | Wild horses | The Pan. Horses standing on white ground, facing the mountain |

Ch. 12 is the warmest chapter in the game and it exists because of an inventory
mode. The shared `total_block_budget` stops being an abstract variant and becomes
"everyone brought what they had."

---

## Cast design constraints

Every animal must be legible as a **silhouette at hex size on a phone**, since it
is drawn inside a single tile. Chosen partly for this:

- Strong silhouettes: flamingo, tortoise, bison, horse, beaver (tail), badger (face
  stripes), salmon (arc)
- Needs care: mole vs. badger read alike — differentiate by size and by the mole's
  pale hands; ants work as a *moving line/texture*, never as one insect
- The player bird: small and grey, but with a white bib (a real dipper's marking) —
  the only white shape on the board, so she always reads

The mountain deliberately mixes biomes (beavers and flamingos do not share a real
watershed). This is a storybook mountain, chosen over a real one because a real
biome costs either the beavers or the flamingos and buys nothing a player notices.

---

## Audio is now load-bearing

`README.md` currently lists "no audio wired in yet" as a known gap. With text
removed it stops being a gap and becomes the other half of the storytelling.

Minimum set: water (the dominant voice of the game), wind, animal breath, the
generator hum at the plant — and, at the finale, **the hum continuing after the
gates open**, which is how the player hears that the village was not sacrificed.

---

## Teaching the controls without sentences

Four gestures, no sentence available: tap-to-place, three-taps-to-dig,
drag-to-scroll, press-and-hold-to-aim (catapult).

- Ghost-hand animation on the first level that uses each gesture
- The amber pre-start flow-preview arrows are already a wordless teaching system —
  they show consequence before commitment. Lean on them harder; they are the single
  most valuable wordless asset already built
- Dig progress is already colour-staged only, by deliberate design — that decision
  now pays off

---

## What this changes in the build

Engine / asset work this implies, none of it started:

1. **Pool bar → animal states.** Replace the 4-box bar draw with a per-chapter
   animal sprite in 5 states (absent/0/1/2/3/4). Reads the same
   `pool_progress` data.
2. **Town loss staging.** Lit windows; extinguish on flood. Currently the flooded
   town cell just turns light blue.
3. **Edge-loss staging.** Water into sand, plus the downhill reaction shot.
4. **13 vignettes + 1 flashback.** ~4s each, silent. Needs a playback scene and a
   trigger at group boundaries (the win popup's Next path is the natural hook).
5. **The Pan frame.** 13 states of one image, shown at the same trigger.
6. **Audio pass.** From nothing to load-bearing.
7. **Ghost-hand tutorial** for the four gestures.
8. **Hydro plant levels do not exist.** No `.tres` file uses `hydro_plant_cells`.
   The ending is currently writing a cheque the level data cannot cash. Needs one
   teaching level (~level 60, found but not openable) and the plant as the Gauntlet
   spine from 87 up.

Item 8 is the real blocker; items 1 and 5 are the highest story value per hour.

---

## Open decisions

- **`intro_text`.** All 100 levels have one, and they are prose. Recommendation:
  *keep the popup, strip it to mechanics only* — it is UI (how to operate the
  level), not story, and it is currently the game's only onboarding. Any sentence
  in it that characterises an animal, the mother, the village or the plant should
  go. The alternative is deleting the field entirely and carrying 100% of teaching
  on ghost hands and preview arrows, which is purer and considerably more work.
- **Level Select as a map.** A descending map of the mountain, with completed
  pools shown filled and their animals present, would make the level picker itself
  a story surface. Level names and numbers stay — it is a menu. Not scoped here.
