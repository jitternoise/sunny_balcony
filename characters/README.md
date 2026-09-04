# Character art

First-pass character concepts from the 2026-08-31 session. Unpacked from
`flash-flood_checkThese.zip`, which has since been removed from the repo now
that its contents live here.

**Nothing in this directory is wired into the engine yet.** These are concept
assets, not game resources — no `.tres`, no `preload()`, nothing referenced by
a scene.

## Contents

| | |
|---|---|
| `svg/` | The 15 characters, 100×100 viewBox, stroke `#0b3d63` width 5 |
| `png/` | 200px renders of the same 15 |
| `pool-sequence/` | The 5 drinking-progress frames (svg + png) |
| `contact-sheet.png` | All 15 on one sheet |
| `pool-sequence-strip.png` | The 5 frames in a row |

The cast: dipper, mother, beaver, salmon, toad, mole, otter, tortoise, ants,
sheepdog, bison, flamingo, badger, everyone (crowd glyph), horse. They map onto
the 13 chapters described in [`story-bible.md`](../story-bible.md).

The stroke system deliberately matches the existing `game/assets/icons/` set,
so these can be imported by Godot directly (it reads SVG natively) if and when
they're brought into the game.

## Known weaknesses

Carried over from the original packaging note: **the sheepdog, the crowd glyph
(`14_everyone`) and the mole are the three weakest reads** and should be
redrawn before anyone animates them.

## Related

[`../character-plates.html`](../character-plates.html) — open in a browser for
all 15 on hex tiles, the chapter mapping, a 58px legibility row, and the
5-state pool sequence with a play button. Every SVG is inlined there, so it
stands alone. It predates this directory and is kept at the repo root.
