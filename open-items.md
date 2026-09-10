# Flash Flood — Open Items

Reconciled 2026-09-04 against the actual code and level data. The previous
version of this file was compiled from the 2026-08-10 `dev-progress.md`
session and had drifted badly: it described a 20-level project with no dig
mechanic, no mudslides, no hydro plant and no bomb catapult, all of which now
exist. Every claim below was checked against the tree rather than carried
forward from the older doc.

Method and its limits: everything here is verified by reading source, level
`.tres` data and asset paths. **Nothing has been run.** Godot is not installed
in the environment where this reconciliation was done, so no claim about how
anything *looks or feels* is verified — see "Needs a live playtest" at the end.

---

## ✅ Blockers cleared 2026-09-04

Both missing icon assets have been supplied and installed, and every `res://`
reference in the project now resolves (120 checked: scripts, scenes, block and
level data, theme). The project should compile again.

- **`icon_hydro.svg`** — was `preload()`ed as a `const` on `HexBoard.gd:38`
  without existing, a parse-time failure that stopped the whole game loading,
  not just the hydro feature. Now at `game/assets/icons/icon_hydro.svg`.
- **`icon_catapult.svg`** — referenced as an `ext_resource` by
  `game/data/blocks/bomb_catapult.tres`. Now present.

Both arrived in the `hydro-catapult-tiles/` drop (commit `2a081ed`) and match
the house style `icon-system.md` specifies — 100×100 viewBox, `#1e2530`
outline, stroke-width 5, same as the existing Diverter and Splitter glyphs.

⚠️ **Compilation is inferred from static reference checking, not observed.**
Godot still isn't installed here, so nothing has actually been launched. The
first real playtest is still pending and is still the project's largest
unknown.

Note that the same drop also carried older copies of `HexBoard.gd`, `Level.gd`,
`BlockData.gd` and `LevelData.gd` predating the 2026-08-31 session — they lack
`_draw_block_direction_arrows`, `_block_target_offsets`, `_preview_arrows`,
`_preview_from_cells` and `footprint_offsets`. **Those were deliberately not
taken**; only the two icons were. Anyone revisiting commit `2a081ed` should
know its scripts are a regression, not an update.

---

## ✅ Resolved since the 2026-08-10 list

- **All 100 levels are authored.** The old list said "currently 20 of ~100".
  `game/data/levels/` holds 100 `.tres` files, `level_id` 1–100 with no gaps
  or duplicates, every one carrying a non-empty `intro_text`, a `pool_targets`
  entry, and (99 of 100) `fire_cells`. `LevelSelect.LEVEL_PATHS` lists all 100.
- **A fresh project build was delivered.** The old list asked for a rebuilt zip
  because the last one predated the win popup, intro popup, flow-preview
  arrows, town-flood color, the array-type crash fix, geyser feed-blocking and
  the 4-beat tick cycle. All of those are present in the current tree
  (`win_panel`, `intro_panel`, `flow_preview`, `flooded_towns`, the
  `BeatPhase` enum).

## ❌ Still open — verified as genuinely outstanding

**The level editor is further behind than the old list said.**
`level-editor.html` supports 6 level fields: `water_sources`, `fire_cells`,
`pool_targets`, `starting_inventory`, `blocked_cells`, `town_cells`. It knows
nothing of the other **nine**: `intro_text`, `grid_style`, `source_flow_style`,
`geyser_cells`, `dirt_cells`, `hydro_plant_cells`, `total_block_budget`,
`corridor_half_width`, `preset_blocks` — nor of `footprint_offsets`, so it
still draws the Wall one cell wide when the game now makes it two. The old list
named four missing fields; it is nine.

**No Geyser icon.** Still using the procedural `_draw_geyser_icon()` droplet
(`HexBoard.gd:1954`) while every other terrain type has real art.

**Tempo work — all three items untouched.**
- `ticks_per_beat` is a single global `var` on `Level.gd:31`, currently `2`.
  It is not per-level and the 72/80 BPM figures from the timing spec appear
  nowhere in the codebase (`grep -i bpm` returns nothing).
- Mid-level tempo shift is unbuilt; `Level.gd:29` still describes it as
  hypothetical.
- `_on_subtick()` (`Level.gd:580`) still returns early on every sub-tick that
  isn't a beat boundary. No animation or audio pulse hangs off it.

**Save-slot delete/reset UI.** `GameState.delete_slot()` exists and works; it
has exactly one occurrence in the codebase — its own definition. Nothing calls
it.

**Never built at all** (each confirmed by grep returning zero hits): scoring;
sound and music (no `AudioStreamPlayer` anywhere); a settings
menu; an accessibility pass; level-complete visual polish; any level curriculum
beyond `GameState.is_level_unlocked()`'s linear gate.

✅ **A five-level tutorial was added 2026-09-10** (ids 901-905, the first five
slots of the map trail — see `dev-progress.md`). It teaches the fall, fire,
placement, picking a block back up, and the 2-wide Wall. Still open around it:
the tutorial is **not gated** — a player can skip it from the map, and
finishing it unlocks nothing that was not already open. Whether it should be
compulsory on a fresh save is undecided.

**No campaign-complete screen.** Unchanged in substance, but the old list
described it at level 20 — it is now level 100. `_on_level_won()` sets the win
button's label to "Level Select" when `_next_level_path()` is empty. Finishing
the game is indistinguishable from finishing any other level.

---

## 🟡 Found by the first real playtest (2026-09-04)

Godot 4.7.2 is now available, so the project has been **run** for the first
time, not just read. It imports cleanly (all 11 SVGs), every script compiles,
and the main scene runs without errors. The two icon fixes above are confirmed
by execution, not just by reference checking.

Two headless tools were added under `game/tools/` to make this repeatable:

- **`smoke_test.gd`** — loads all 100 levels and the block catalog, validates
  ids, sources, win conditions, block references, and that terrain sits inside
  each level's declared playable area. Exits non-zero on failure, so it can
  gate a build.
  `godot --headless --path game --script res://tools/smoke_test.gd`
- **`LevelHarness.tscn`** — runs any level for N beats with no input and
  reports water depth, live cells, fires remaining and win/loss state. With a
  third argument it saves a PNG of the board, which is how the screenshots
  below were produced.
  `godot --headless --path game res://tools/LevelHarness.tscn -- 24 40`

**Water sources outside the playable area — 13 of 19 fixed.** All 19 sat at
`(-1, -4)` on a `grid_radius = 4` board (distance 5), where every other source
in the game (88 of 107) sits exactly on the rim.

This was never a simulation bug. From `(-1, -4)` the down-left diagonal is
off-board and gets skipped, and the fallback lands on the same cell an on-rim
source reaches. It was a rendering bug: `HexBoard._draw_source_marker()` is
called for every `water_sources` entry with no `in_playable_area()` check, so
the marker and its first flow-preview arrow drew detached from the grid.

**Fixed (13 pointy-grid levels)** — 24, 28, 29, 34, 38, 42, 46, 47, 48, 50, 53,
66, 72 — moved to `(0, -4)`. Verified by running all 19 levels for 60 beats
before and after: output is byte-identical, so nothing about the simulation
moved. Confirmed visually too — the marker now sits on a tile.

**⏸ KNOWN — deferred (6 flat-grid levels)** — 55, 56, 59, 60, 61, 62.
Acknowledged and left for later, not an oversight. These need a
design decision, because on a `grid_style = "flat"` board water falls straight
down a column (`Hex.FLAT_DOWN`), so moving the source sideways moves the entire
stream. Both candidate fixes were tested and both change gameplay:

- `(0, -4)` — shifts the stream one column. Measurably different: level 59 goes
  from an edge loss at beat 38 to still running at beat 60, level 55's fire
  stops being extinguished.
- `(-1, -3)` — keeps the column (it's the topmost in-area cell at `q = -1`) but
  starts the water one row lower, shifting every level's timing by a beat.

A third option is to guard the draw call instead of touching the data, but then
those levels show no source marker at all, which is arguably worse than one in
the wrong place. Note these 6 also use `(-1, -4)` as a `source_flow_style` key
(level 56's is `"zigzag"`), so any data fix must update both or the flow style
silently reverts to `"straight"`.

`smoke_test.gd` carries these 6 in its `KNOWN_ISSUES` allowlist: they print
under a KNOWN heading and do not fail the run, so the exit code stays
meaningful and a genuine regression still stands out. **Remove them from that
allowlist when fixing** — a stale entry silently hides the thing it tracks.

---

## 🆕 New items the old list predates

**The solution book: 27 of 100 solutions are confirmed broken.**
> **Superseded — re-measured 2026-09-08: the figure is now 11.** 16 have been
> fixed since this was written. See "Documented solutions: 11 still broken"
> further down this file for the current list and method. The diagnosis below
> (the 2-tile Wall is the sole cause) still holds.

The
2026-08-31 change making the Wall 2 tiles wide was predicted to invalidate the
49 solutions that place one. Every solution has now been replayed against the
real engine (`tools/verify_solutions.gd`), and the damage is narrower than
feared but real:

| | |
|---|---|
| Still win, exact documented measure | **72** |
| Win at a different measure | **0** |
| No longer win | **27** |
| Not machine-readable | **1** (level 22) |

**All 27 failures place a wall. No non-wall solution broke**, and no surviving
solution drifted by even one measure — so the Wall footprint is the only cause,
exactly as predicted. 22 of the 49 wall solutions still work, because a wider
wall only matters where the extra cell dams something.

Broken: 1, 2, 6, 10, 11, 12, 17, 32, 33, 54, 64, 66, 67, 68, 69, 81, 82, 83,
85, 86, 91, 92, 93, 94, 96, 97, 98.

Most time out (the water can no longer reach a pool at all); 67, 68, 69 and 97
now lose by running off an edge. **Level 68 is the worst case** — the wall
placement is *rejected outright*, because neither footprint orientation fits at
`(-1, -1)`. In the real game that tap would do nothing at all, with no feedback,
which is the silent-placement-failure problem below.

Level 22's solution is prose ("dig the 108-cell channel+spurs") and needs
hand-encoding — 108 cells, 324 taps.

`level-solutions.md` and `level-min-times.md` should not be trusted for those 27
levels until they are re-solved. Rerun the check any time with:

```
godot --headless --path game --script res://tools/verify_solutions.gd -- ../level-solutions.md
```

**The Python simulator is gone, and is no longer needed.** It was never in the
repository (`sim/gen100.py`, `sim/retrofit.py`, `sim/verify_shipped.py` lived
outside it) and it existed only because no Godot engine was available -- every
`dev-progress.md` entry says so. Godot 4.7.2 is available now, so verification
runs against the shipping engine instead, via `tools/Sim.gd`. That removes the
divergence risk the port carried: it had already drifted once, when Python's
banker's `round()` disagreed with GDScript's `roundf()` and silently moved every
corridor level's band centre one column on odd rows.

The one thing it still did that nothing replaces is **generating** levels --
solution-first templates with seeded rejection sampling. Worth recovering
`gen100.py` for its templates if it turns up, but note it predates the 2-wide
Wall and would generate levels validated against the wrong footprint.

**The Hydro Electric Power Plant is dead code.**
> **❌ WRONG — corrected 2026-09-09. Eight levels ship a plant:** 7, 13, 18,
> 25, 33, 52, 63 and 82 (`grep -l "hydro_plant_cells = Array" data/levels/`).
> `tests/VerifyHydroBonus.tscn` exercises all eight and passes, checking for
> each that water reaches the plant and that the level can be won with it
> running. The mechanic is live, player-facing and covered by a suite.
>
> This claim did real damage before it was caught: a verifier in the handheld
> audit quoted it back as evidence while assessing the save-write path, and
> the 2026-09-09 water-blocking fix was very nearly scoped on the assumption
> that no level had a plant to break. The thing that caught it was
> `VerifyHydroBonus` failing on level 63. **Run the suites before trusting a
> "never used" claim in this file.**

Fully implemented in
`LevelData.gd`, `HexBoard.gd` (`hydro_plants`, `hydro_ready_at()`,
`try_activate_hydro()`, `_is_inactive_hydro()`) and documented at length.
Its doc comment notes it is pointy-grid only and untested on a flat
grid — that part still stands: all eight levels above are pointy.

**Placement failure is silent.** When neither footprint orientation of a 2-wide
Wall fits, the tap does nothing, with no feedback to the player.

**The mudslide mechanic exists** (added 2026-08-17: water stalled against dirt
collapses 3 tiles) and is absent from the old list entirely. Level 21's
`intro_text` teaches it, so it is player-facing.

**Splitter/Diverter direction arrows have never been looked at.** Added in the
2026-08-31 change set and reasoned about only on paper — specifically whether
two arrows crowd a Splitter tile at real device size.

---

## Needs a live playtest

Unchanged as a category, and still the single largest risk: **no feature in
this project has been confirmed running in a live Godot window.** All
verification to date, including this reconciliation, has been static.

With the two missing icons now in place the project should load, so this list
is finally checkable. The items worth confirming by eye are the
ones the old list named (buffered placement responsiveness, the beat-4 status
reveal, scrolling on tall levels, the Jamboree inventory bar, icon and glyph
rendering, Level Select word-wrap, the loss/intro/win popups, pre-start flow
arrows, the flat grid's pixel geometry on level 20, the sky/grass background at
multiple aspect ratios, town-flood coloring, geyser feed-blocking), plus the new
direction arrows above. Note that popup routing now needs checking at level
**100**, not 20, and that `level_018.tres` — reconstructed from a README
description and never re-verified against the engine — is still unconfirmed.

## Documented solutions: 11 still broken (re-measured 2026-09-08)

Re-run of `tools/verify_solutions.gd` against the current tree:

| | |
|---|---|
| Win on the exact documented measure | **88** |
| Win at a different measure | **0** |
| No longer win | **11** — levels 1, 6, 10, 11, 64, 66, 67, 68, 69, 92, 96 |
| Not machine-readable | **1** — level 22, prose ("dig the 108-cell channel+spurs") |

**This supersedes the "27 of 100" figure earlier in this file**, which was
measured on 2026-09-04; 16 have been fixed since. It also supersedes a
"9 failures" figure briefly recorded here on 2026-09-07, which was produced
by a second, redundant harness whose parser silently skipped the 24
dig-bearing entries — that harness has been deleted in favour of
`tools/verify_solutions.gd`, which is the one to trust.

**All 11 place a wall, and no non-wall solution is broken** — consistent
with the 2026-08-31 change making the Wall 2 tiles wide being the sole
cause. Levels 1, 6, 10 and 11 share one shape: the source sits at `(0,-4)`,
whose only two down-targets are `(-1,-3)` and `(0,-3)`, and a 2-wide wall
placed at `(-1,-3)` covers both and seals the source in. Levels 67, 68 and
69 lose to a bottom-edge overflow instead; on 68 a documented placement is
rejected outright.

Level 1 is the first thing a new player touches, so it is the one to fix
first. Whether the levels or the solution book is the thing that is wrong
has still not been decided.

**⛔ Level 68 is not a broken solution — the level itself cannot be won
(settled 2026-09-10).** Its inventory is one wall, it has no dirt and no
plant, and its geyser activates on contact rather than on a tap, so the
whole solution space is "one wall, one cell, one measure". Enumerating it —
57 legal cells × every placement measure 0–39, plus every place-then-
relocate-once pair — produces **zero wins**; with no block at all the water
runs off the edge at measure 16. `tools/solve_broken.gd` alone does not
settle this (it places everything pre-Start and caps at two placements); the
exhaustive run closed the timed and relocate cases.

So 68 needs a **data fix, not a solution-book fix**: another block in
`starting_inventory`, or a redrawn board. It is also one of the ten par-fork
levels (`par_measures = 24`), so until it is fixed its map spur can never
open. See finding 33 in `handheld-audit.md`.

---

## 🔍 Superseded in part by the handheld audit (2026-09-08)

A full Android/iOS platform audit now lives in **`handheld-audit.md`** — 47
verified findings with a prioritised fix-first list. It supersedes nothing in
this file but goes considerably wider, and several items below appear there with
sharper measurements or corrected severities.

Two defects it found were proven by execution and are **already fixed**:

- **The exported build had an empty block catalog.** A `DirAccess` scan filtered
  on `.tres`, which becomes `.tres.remap` inside a PCK. All 100 levels would have
  shipped with nothing placeable. Now `ResourceLoader.list_directory()`.
- **An RTL system locale blanked the campaign map**, moving all 100 Level Select
  nodes exactly one viewport width off-screen. Now pinned to LTR via
  `internationalization/rendering/root_node_layout_direction=1`.

The first of those is worth remembering as a category, not just a bug: **no test
in this project can see an export-only defect**, because every test scene and
both verification tools run against the source tree. The audit's remaining
export-readiness items are all still open.

## 🎯 Feature backlog (added 2026-09-09)

Three ideas, none started. Each entry records what already exists and where it
would hook in, so picking one up doesn't mean redoing the research.

**Two of the three want the same thing first.** The almost-lost warning asks
"is this run about to lose?" and the early acceleration asks "has this run
already won?" — different questions, one missing capability: a trustworthy
forward simulation of the live board. The only lookahead in shipped code
(`_predict_flow_arrows()`) cannot answer either. Build that once and both
features get much smaller; build them separately and it gets built twice.

### 1. Incorporate the animals

The 15 character assets exist and none of them are in the engine.

**This is not a blank slate — read `story-bible.md` first.** It is an agreed
design (2026-08-31) whose 13 chapters map onto `LevelSelect.GROUPS`
name-for-name and range-for-range, so the chapter→animal mapping is already
decided even though no `.tres` carries a chapter field (derive it from
`GROUPS`, or add one).

**Highest-value first slice**, and the bible calls it ~90% of the
storytelling: replace the 4-box pool status bar with the chapter animal in 5
states. Same data (`pool_fill`, `POOL_BEATS_REQUIRED = 4`), no new mechanics,
and the art already exists as `characters/pool-sequence/s0`–`s4`. The hook is
`HexBoard._draw_pool_status_bar()` (`HexBoard.gd:2530`) — **replace its body
only**. `_draw_status_bar()` (`HexBoard.gd:2541`) is shared with the Geyser
and must keep working.

Second slice: chapter vignettes at group boundaries. The bible's named hook is
the win popup's Next path, `Level._on_win_next_pressed()` (`Level.gd:1097`).

Things worth knowing before starting:

- **Use `characters/svg/`, not `characters/png/`.** The PNGs are 8-bit RGB
  with no alpha and would draw an opaque box over the hex. The SVGs are
  already in the house style (100×100 viewBox, stroke `#0b3d63`, width 5 —
  deliberately matching `game/assets/icons/`).
- **Pipeline**: copy into `game/assets/characters/`, open the editor once to
  generate the `.svg.import` files, then set `svg/scale=3.0` to match the 20
  existing icons. The default `1.0` gives a blurry 100px texture.
- **The 5 pool frames are separate files, not a strip.** `_draw_tile_art()` /
  `_anim_frame()` expect a horizontal sheet, so this needs either a per-frame
  texture array or a re-exported sheet *with* alpha.
- `characters/README.md` flags the sheepdog, the "everyone" crowd glyph and
  the mole as the three weakest reads — redraw before animating.
- If any of this art reaches further from a cell centre than
  `Hex.SIZE * 2 + 48`, widen `_visible_draw_rect()`'s margin or it will pop in
  at the screen edge — and note `BoardSnapshots` cannot catch that (see
  CLAUDE.md).

### 2. Almost-lost warning, with a way out

**Tell the player they are *going* to lose, and give them an action to change
it.** Predictive, not a post-hoc "that was close".

⏳ **The intervention is undecided and the owner will elaborate.** Do not
invent one — what the player actually gets to *do* is the whole feature, and
the rest of this entry is only the groundwork.

There is no precedent anywhere in the codebase: grepping for close-call /
near-miss / tension concepts returns nothing relevant.

What exists to build on:

- **The loss paths are few and precise.** `HexBoard._lose()`
  (`HexBoard.gd:1944`) and `LoseReason = {EDGE, TOWN}` (`HexBoard.gd:589`),
  with exactly four call sites: `HexBoard.gd:1865` (pointy bottom edge,
  `coord.y > grid_radius`), `1876` (town — any water entering a
  `CellState.TOWN` cell, instant, no fill counter), and `1542` / `1622` for
  the flat-grid equivalents.
- **A read-only "would this lose?" predicate already exists**: the flow-preview
  path (`HexBoard.gd:2056-2059`) replicates the same edge tests without
  calling `_lose()`.
- **Timing constrains the design.** Losses fire on beat 2 (WATER), wins on
  beat 4 (STATUS). A warning has to land *before* the water step that kills —
  which is exactly why the 4-step geometric preview isn't enough and why this
  shares the forward-simulation dependency above.

Open: how many measures ahead to warn; whether it is always on or an assist
option; and whether it should also cover a run that can no longer *win* (a
stalled board is a different condition from one about to lose).

### 3. Accelerate once the win is settled

When the water is already on a winning line several tiles out, speed the level
up rather than play out a foregone conclusion at normal pace.

**Wins only.** A doomed run stays at normal speed so the player can watch what
went wrong.

**The mechanism is one variable**: `ticks_per_beat` (`Level.gd:31`, currently
2). Its own doc comment already says a dynamic tempo "would just reassign this
at runtime."

**And it is safe by construction**, which is worth stating because it looks
risky and isn't: the sim runs off a `Timer`, not frames, and `measures_elapsed`
counts beats rather than seconds. Changing `ticks_per_beat` changes wall-clock
speed but **not the measure count** — so outcomes, `par_measures` and the
88/11/1 solution book are all unaffected. Only `level-min-times.md`'s
*seconds* column would need a note.

**The blocker is detection, and it is real.**

- `_predict_flow_arrows()` (`HexBoard.gd:1990`) is **not sufficient**: 4 steps
  deep (`PREVIEW_ARROW_STEPS = 4`, `HexBoard.gd:257`), purely geometric, no
  time dimension, deliberately treats FIRE as never-consuming, counts neither
  pool fill nor fires remaining, and cannot judge a win.
- `FFSim` (`game/tools/Sim.gd`) *is* the right engine — it drives the real
  board, so rule drift is structurally impossible — but it always starts from
  `board.setup()` on a fresh `.tres`, and `tools/` is excluded from every
  export, so it cannot ship as-is.
- Two candidate approaches: add `HexBoard` state snapshot/restore, or add a
  `run_from(board, max_measures)` variant — `Sim.gd`'s phase loop is already
  state-agnostic, it is only the entry point that assumes a fresh board.
- **A speculative run must not touch the live board.** `_try_enter()` writes
  `_pending_terrain` / `flooded_towns` and can emit `level_lost`;
  `_note_dirt_stall()` / `_note_hydro_contact()` mutate; `_process_mudslides()`
  rewrites `cell_terrain` / `dig_progress`.

Open: what "several tiles early" means numerically; whether the speed-up ramps
or snaps; whether the player can cancel it; and how it reads against the 12 Hz
animation heartbeat.

**Decide this alongside the existing tempo work, not separately.** The "Tempo
work — all three items untouched" section above and the unwired 72/80 BPM spec
in `toolset-and-requirements.md` ("Music-driven timing spec") both reassign
this same knob.

## 🚚 Pre-export checklist (added 2026-09-08)

Neither export has been configured — no `export_presets.cfg` is committed
(it is gitignored), so nothing has been built for either platform. Nothing
in the codebase is platform-specific: the only platform API in shipped code
is `OS.is_debug_build()` in `GameState`, and the whole game is core Godot
2D. What follows is what to settle before the first build.

**Standing caveat: nothing has ever run on a GPU.** Every render produced
so far — including all the animation work — was Linux under Xvfb with
llvmpipe software rendering. That verifies drawing *logic*. It says nothing
about how any of it behaves on a phone.

**1. Confirm the Compatibility renderer on iOS.** `project.godot` sets
`renderer/rendering_method.mobile="gl_compatibility"`. Apple deprecated
OpenGL ES, so Godot reaches iOS's Compatibility renderer through ANGLE
(translating GL ES to Metal), a newer and far less travelled path than
Android's. Verify on a device against 4.6 before committing to it. If it is
troublesome, the Mobile (Vulkan/Metal) renderer is the better-trodden iOS
route — but that is a project-level change with its own consequences, not a
flag flip.

**2. Exclude `res://tests/` and `res://tools/` from both exports.** Roughly
140 KB across 20 test files plus the verification tools. Nothing
instantiates them so they are inert, but they are dead weight and they read
`level-solutions.md`, which sits outside `res://` and ships in no build.

**3. Decide texture compression deliberately.** Every texture imports at
`compress/mode=0` (lossless). Mobile usually wants VRAM compression — ETC2
on Android, ASTC on iOS — as a per-platform import override, cutting texture
memory several-fold. Against that: the art is flat colour with hard edges,
which is exactly where block-compression artifacts show worst, and current
texture memory is small enough that this is a choice rather than a
necessity.

**4. Check two specific things on real hardware**, both invisible under
software rendering:
- `HexBoard.SHEET_REGION_INSET` (half a texel) exists to stop a sheet's
  neighbouring frame bleeding in. Filtering differs by GPU and driver, so on
  device you may still see a sliver of the wrong frame, or lose half a pixel
  of art.
- `Hex.SIZE` is solved per level and `canvas_items` stretch renders at the
  device's native resolution, so tiles land at arbitrary fractional sizes.
  If seams appear between adjacent full-tile water cells, that is where.

**5. Check the safe-area insets on a device with a cutout.** Implemented
2026-09-08 (`game/scripts/ui/SafeArea.gd`), and every screen that anchors
anything to an edge now insets it: the level HUD, Level Select's header row
and trail margins, the save-slot Back button, and the board's own top and
bottom margins. It cannot be verified here — desktop Linux reports its whole
screen as safe, so `tests/VerifySafeArea.gd` drives it through the
`FLASH_FLOOD_SAFE_INSETS` simulation hook instead. What a device would prove
that the simulation cannot: that `DisplayServer.get_display_safe_area()`
reports a sane rect on the handset in question, and that it is already
correct when the first scene lays out rather than arriving a frame or two
later. If it turns out to arrive late, the fix is a re-apply on
`NOTIFICATION_APPLICATION_RESUMED` and on the first few frames; every screen
already re-applies on viewport resize.

**6. Measure the redraw cost.** The board repaints on a 12 Hz heartbeat
whenever a level is open — including while the player is still planning,
since every level has fire and fire is animated. 12 redraws a second is the
budget the single-heartbeat design was built around, but it is a
calculation, never measured on a device. If it proves expensive, gating
terrain animation to `started` is a one-line change.

**Not at risk:** the simulation runs off a `Timer`, not off frames, so
thermal throttling, a slow device or a dropped frame cannot desync the beat
cycle or change a level's outcome. Only the visuals would stutter.
