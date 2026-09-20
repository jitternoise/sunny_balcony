# Flash Flood

A hex-grid puzzle game in **Godot 4.6**, portrait mobile, **Android primary /
iOS portable**. The player places blocks to route a once-a-year flood into
pools and onto fires before it runs off the board. 100 authored levels.

The Godot project is `game/`. Design docs live at the repo root.

---

## Read these before starting

| File | What it is |
|---|---|
| `dev-progress.md` | Session log, **newest first**. Prepend a `## Status: … (date)` entry when you finish work. |
| `open-items.md` | What is genuinely outstanding, plus the **pre-export checklist**. |
| `release-checklist.md` | Step-by-step path to both stores, code and non-code, with dated store requirements (2026-09-10). |
| `handheld-audit.md` | Android/iOS platform audit (2026-09-08). 47 verified findings, ranked, with a fix-first list. Findings 33-44 were settled 2026-09-10 -- **33, level 68 being unwinnable, is the most serious thing still open.** |
| `story-bible.md` | The wordless story design. Nothing in the engine implements it yet. |
| `level-solutions.md` | One verified solution per level. |
| `level-min-times.md` | Verified minimum measures per level — the source of `par_measures`. |
| `characters/README.md` | 15 animal concept assets. **Not wired into the engine.** |

---

## Verification — run these, they are fast

```bash
cd game
godot --headless res://tests/SmokeLevel.tscn        # 78 checks, in-level HUD end to end
godot --headless res://tests/VerifyHydroBonus.tscn  # the optional plant bonus, 8 levels
godot --headless res://tests/VerifyLevelMap.tscn    # Level Select map, badges, side paths, decade bands, 84 checks
godot --headless res://tests/VerifySafeArea.tscn    # notch/gesture-bar insets, 27 checks
godot --headless res://tests/VerifySaveIntegrity.tscn # save durability/corruption, 34 checks
godot --headless res://tests/VerifyMultiTouch.tscn  # second-finger handling, 13 checks
godot --headless res://tests/VerifyBoardHeartbeat.tscn # board animates only when visible, 14 checks
godot --headless res://tests/VerifyWaterBlocking.tscn # solid targets block a redirect, 15 checks
godot --headless res://tests/VerifyTutorial.tscn    # the 5 tutorial levels + trail slots, 160 checks
godot --headless res://tests/VerifyGridOpacity.tscn # Options > hex grid opacity slider, 28 checks
godot --headless res://tests/VerifyBackdrops.tscn   # one sky/ground pair per ten levels, 119 checks
godot --headless res://tests/VerifySfx.tscn         # the sound catalogue, its files and recipes, every play(), the wiring, 141 checks
godot --headless res://tests/VerifyMusic.tscn       # one loop per ten levels, crossfade, no restart on the same band, 102 checks
# needs a display (measures laid-out control sizes):
xvfb-run -a --server-args="-screen 0 720x1280x24" \
  godot --resolution 720x1280 res://tests/VerifyTouchTargets.tscn # 48dp targets, 42 checks
xvfb-run -a --server-args="-screen 0 720x1280x24" \
  godot --resolution 720x1280 res://tests/VerifyMapScroll.tscn # map opens on your level, 14 checks
xvfb-run -a --server-args="-screen 0 720x1280x24" \
  godot --resolution 720x1280 res://tests/VerifyUndoAndHeader.tscn # cancel a queued placement, 14 checks
xvfb-run -a --server-args="-screen 0 720x1280x24" \
  godot --resolution 720x1280 res://tests/VerifyBoardCentring.tscn # fitting grids centred, tall ones pinned, insets shrink not scroll, 51 checks
```

⚠️ **Most test scenes write to real save slot 0** (they set
`GameState.current_slot = 0` and complete levels). Running the suites
overwrites your own "Slot 1". `VerifySaveIntegrity` deliberately uses slot 99
to stay clear of it; new tests that touch saves should do the same. Note also
that `user://` is keyed on `config/name`, so a *copy* of the project writes to
the same save directory as the original -- a throwaway harness run from a copy
is not sandboxed.

```bash

# the solution book — THIS is the authoritative one, from the repo root:
godot --headless --path game --script res://tools/verify_solutions.gd -- ../level-solutions.md
```

**Do not write another solution verifier.** One already exists at
`game/tools/verify_solutions.gd`. A previous session missed it, built a
duplicate whose parser silently skipped the 24 dig-bearing entries, and
reported 9 broken solutions when the real figure was 11. Current expected
result: **92 exact / 7 broken / 1 prose (level 22)**. The 7 (64, 66, 67,
68, 69, 92, 96) are all wall placements broken by the 2026-08-31 change
making the Wall 2 tiles wide. Every level in 1-50 has a verified solution.

**Levels 1-50 are at most 6 hexes wide** (owner's rule, 2026-09-16). A
former radius-4 hexagon is now a radius-5 grid with rows +-5 and every
offset column outside -3..2 in `blocked_cells`, its terrain slid sideways
to fit. `HexBoard.bottom_row` (the lowest playable row) is what the edge
loss tests against, NOT `grid_radius`, so blocking the bottom row is safe.
Level 20 (flat grid) keeps its radius-4 hexagon and blocks columns q = -4,
-3 and 4 instead, because the flat grid's loss test is `_cube_distance()`.

### Safe-area insets are simulated here, never real

Desktop Linux reports its whole screen as safe, so nothing on this machine
produces a notch. `scripts/ui/SafeArea.gd` reads
`FLASH_FLOOD_SAFE_INSETS="left,top,right,bottom"` (screen pixels) and
pretends; everything downstream of the parse behaves as it does on a phone.
It works on the snapshot harnesses too:

```bash
FLASH_FLOOD_SAFE_INSETS="0,110,0,80" SHOT_DIR=/tmp/notch \
  godot --resolution 720x1280 res://tests/BoardSnapshots.tscn
```

Insets are applied per screen, not project-wide: backgrounds stay full-bleed
and only the content moves, so an inset never reads as a dark band down the
edge. **Do not inset a scene root** that has a ColorRect background under
it -- that is the letterboxing this project spent four commits removing.

**An inset shrinks a board that fits; it never makes it scroll.** Tile size
is solved from the grid's width, so a narrow column gets big tiles and a
tall board: the 4-wide tutorials have 12 px of slack at 720x1280 and would
scroll 145 px behind a 96 px cutout + 72 px gesture bar. `_fit_hex_layout()`
shrinks any board that fits the plain band but not the inset one until it
fits again; a board that scrolls anyway (level 18, 20, the corridors) keeps
its full-size tiles. `VerifyBoardCentring` pins both halves -- it needs
xvfb, so a Mac session cannot run it; run it here after any layout change.

### Drawing changes need the snapshot net

The simulation suites never render, so they cannot see a visual regression.

```bash
SHOT_DIR=/tmp/before  godot --resolution 720x1280 res://tests/BoardSnapshots.tscn   # before your change
SHOT_DIR=/tmp/after   godot --resolution 720x1280 res://tests/BoardSnapshots.tscn   # after
godot --headless --script res://tests/CompareSnapshots.gd -- /tmp/before /tmp/after
```

Ten levels covering fire, pool, town, geyser, dirt, hydro, presets, both grid
orientations, a corridor and a jamboree budget. Captured with
`Engine.time_scale` at zero so animated tiles render a fixed frame and two
runs are comparable. **No baseline is committed** — capture `before` from a
clean tree yourself.

Headless needs a display for anything that renders: `xvfb-run -a
--server-args="-screen 0 720x1280x24" godot --resolution 720x1280 …`

**A GDScript parse error HANGS a headless run instead of failing it.** The
process never returns, and because stdout is block-buffered through a pipe,
killing it shows **no output at all** -- no banner, no error, nothing. It
looks like a deadlock in your own code and is not.

Two ways to see what actually happened:

```bash
timeout 60 stdbuf -o0 godot --headless --path game res://tests/Foo.tscn > /tmp/o 2>&1; tail /tmp/o
```

`stdbuf -o0` is the important half -- without it a hung run tells you nothing.

The commonest cause of that parse error is a **`class_name` that is not
registered yet**: add a script with one, run a scene that uses it, and every
reference is an undeclared identifier. `godot --headless --import --path game`
registers it. Same rule as the asset note above, but the symptom is a hang
rather than a missing texture, so it is easy to blame the wrong thing --
including stale Godot processes, which do pile up from the timeouts and are a
red herring.

**`--headless` also ignores `--resolution`.** It reports a square 1280x1280
viewport whatever you pass, so anything that depends on viewport SIZE — not
just on rendering — measures the wrong thing and does so silently. Board
layout is the big one: `HexBoard.max_scroll_down` is 0 on 62 of 100 levels at
the real 720x1280, and non-zero on all 100 under headless. Use `xvfb-run` for
any viewport-dependent measurement, and sanity-check by printing
`get_viewport().get_visible_rect().size` before trusting a number.

---

## Architecture, in one pass

- **`scripts/gameplay/HexBoard.gd`** — the simulation *and* the renderer. All
  board drawing is one custom `_draw()`; there is no TileMap.
- **`scripts/gameplay/Level.gd`** — wires the beat clock, HUD, popups and
  input to the board.
- **`scripts/autoload/GameState.gd`** — save slots, progress, and the two
  optional-reward records (`hydro_bonus_levels`, `par_levels`).
- **`scripts/ui/LevelSelect.gd`** + **`LevelMap.gd`** — the campaign map.
- **`scripts/autoload/Sfx.gd`** — every sound effect, by name, and the one
  place that plays them. `Sfx.SOUNDS` is the catalogue; the files are
  `assets/sfx/<name>.wav`, all synthesised by `tools/gen_sfx.py` (nothing
  is recorded); `Sfx.play(&"name")` from presentation code only. The board
  reports what happened through `HexBoard.board_event(kind, coord)` and
  `Level.BOARD_SOUNDS` says how each kind sounds. `VerifySfx` fails the
  moment the catalogue, the directory, the recipes and the `play()` calls
  disagree, so a sound cannot be half-added or half-removed.
- **`scripts/autoload/Music.gd`** — one background loop per ten levels, the
  same bands as `Backdrop.PALETTES`; `Music.TRACKS[i]` is
  `assets/music/<name>.wav`, composed by `tools/gen_music.py` (8 bars at
  100 BPM = 19.2 s, two of the sim's beats per music beat, seamless
  loop). `play_for_level()` is a no-op for the band already playing and
  crossfades otherwise; a level plays its band, the map plays the band it
  opens on, the main menu the meadow. `VerifyMusic` holds the catalogue,
  the directory, the generator's songs and the palettes together.
- **`scripts/gameplay/Backdrop.gd`** — the sky/ground colour pair behind a
  level, one per ten levels (`PALETTES`, `for_level()`), plus the HUD text
  outline derived from the ground. `Level._apply_backdrop()` paints it.
  `Level.tscn` is authored in the first pair; the tutorials use it too. A
  ground hue must stay clear of the tile palette (fire, lakebed, dirt,
  geyser, water, the amber preview) and clearly lighter than an empty cell
  -- `VerifyBackdrops` holds every pair to that. The map uses the same
  table: `LevelSelect._backdrop_stops()` turns the trail into colour stops
  (`LevelMap.bands`), `LevelMap._draw_bands()` paints the ground under the
  trail with a fade between decades, and the header bar shows the sky of
  the band at the middle of the screen (`_update_header_sky()`).

**Beat cycle.** One measure = 4 beats = 1.2 s (`SUBTICK_INTERVAL` 0.15 ×
`ticks_per_beat` 2 × 4). Beats are PLACEMENT → WATER → TERRAIN → STATUS. The
sim runs off a `Timer`, **not** off frames, so frame rate cannot change a
level's outcome. Keep it that way.

**Tile drawing is table-driven.** `_resolve_tile_state()` is the single place
terrain precedence lives; `TILE_VISUALS` is the single place each state's
appearance lives. To animate a tile type, add a sheet to its table entry — do
not add a branch. A state with no sheet falls back to its static icon. Two
states draw themselves instead: a geyser (no art yet) and a **pool**, whose
look is per-lake state — `_draw_basin()` fills the cracked lakebed with the
stream's water sheet clipped at a waterline set by `pool_fill`, and rims only
the lake's outer edges. A lake cell also skips the per-cell border.

**Tutorial hints.** `LevelData.hint_cells` draws a dashed amber outline on a
cell until a block sits there. Only the tutorials set it; list the Wall's
ANCHOR cell, never both halves.

**One animation heartbeat** (`ANIM_TICK_FPS`, 12). A redraw repaints the whole
board, so independent per-type rates would multiply repaints. Derive every
frame from that counter; let slower tiles repeat frames. It runs only while
the board is actually visible — `Level._update_board_animation()` calls
`board.set_process()` from `Level._process()` every frame, so a new popup is
covered automatically. Add a full-screen panel? Add it to that check, or it
will repaint a board nobody can see and hold the screen awake.

**`_draw()` culls to the screen.** `_visible_draw_rect()` gives the visible
band in board coordinates and the cell and water loops skip anything outside
it — level 22 draws 85 cells, not 505. If you add drawing that reaches
further from a cell centre than the current margin (`Hex.SIZE * 2 + 48`,
already ~2x the tight bound), widen the margin or the art will pop in at the
screen edge. `BoardSnapshots` cannot catch that: it only captures unscrolled,
pre-Start boards. Check a scrolled, mid-simulation board by hand.

---

## Conventions that have already bitten someone

- **The inventory bar has one fixed tile order, `Level.BLOCK_ORDER`.** A
  level's `starting_inventory` is a Dictionary, so it iterates in whatever
  order the author typed it -- level 1 lists `divert_right` before
  `divert_left` -- and a Jamboree level shows the whole catalog
  alphabetically. Ordering the bar by either put the same block in a
  different place from level to level. Buttons are spread by expanding
  spacers (`_make_bar_spacer()`), so the bar's children alternate
  spacer/button: **`get_child(0)` is not the first button.**
- **The Wall is 2 tiles wide.** Placing one covers the tapped cell *and* a
  neighbour. This invalidated 11 documented solutions and is the single most
  common source of "why doesn't this level win any more". Tutorial 5 exists
  to teach exactly this.
- **A trail slot is not a level number.** The five tutorial levels sit below
  level 1 on the map, so slot 5 is level 1 and slot 104 is level 100. Use
  `LevelSelect.slot_of_level()` / `level_of_slot()`; indexing `points[]` by a
  level number puts the bonus spurs five nodes off. The tutorial ids are
  901-905 (`GameState.TUTORIAL_ID_FIRST`), deliberately outside the campaign
  so that adding them did not renumber 100 levels and invalidate every save.
  They are always unlocked and never advance `highest_unlocked_level`.
- **"Solid to water" is two different tests, on purpose.** `_is_wall()` is
  what *natural fall* asks, and counts an activated geyser as solid.
  `_is_solid_block()` is what the two *block-redirect* loops ask, and does
  not — level 63 feeds its Hydro Plant with a stream routed through its
  geyser's cell. Collapsing the two makes that plant unreachable. Run
  `VerifyHydroBonus` on any water-routing change; it is the only thing that
  catches this.
- **Full-tile art needs both grid orientations.** 9 levels use
  `grid_style = "flat"`; a pointy-top tile pokes its corners through a
  flat-top cell. Centred glyphs need only one version.
- **So does any glyph that points somewhere.** A Diverter exits at 60°/120°
  on a pointy grid and at 30°/150° on a flat one (`Hex.axial_to_pixel()`), so
  one arrow cannot be right on both. `BlockData.icon_flat` holds the second
  drawing and **every draw site must call `BlockData.glyph(flat)`, never
  `.icon`** -- there are four: `_tile_visual()`, the ghost placement, the
  under-water redraw, and `HexTileIcon`. Blocks with a centred glyph leave
  `icon_flat` unset and `glyph()` falls back.
- **Popups must be `mouse_filter = STOP`** on both the root and the `Dim`
  rect, or taps fall through and place blocks behind the popup.
- **Drop emulated input.** Godot synthesises a mouse event from every touch
  and dispatches that copy *first*. `Level.gd` discards
  `InputEvent.DEVICE_ID_EMULATION`; without it one finger fires twice.
- **The board is single-pointer.** One pointer owns a press (`_press_index`,
  `MOUSE_POINTER` for a mouse) and only its drags and its release act on the
  board. Every press/drag/release path must keep that check: without it a
  second finger overwrites the press origin, and an unmatched touch-up runs
  the full tap path and places a block wherever it lifted.
- **`HexBoard.gd` must never name an autoload.** `tools/verify_solutions.gd`
  compiles it under `--script`, where there are no autoloads, so a bare
  `Settings`, `GameState` or `Sfx` is "Identifier not found" -- a compile
  error, which hangs the verifier instead of failing it. Look the node up
  at runtime (`get_node_or_null("/root/Settings")`, see `_settings`) and
  cope with null. The grid opacity slider is the one thing the board reads
  from Settings today. **Sounds never go in the board at all:** it emits
  `board_event(kind, coord)` (terrain events held to the STATUS beat, when
  the change is first drawn) and `Level.gd` plays them.
- **Adding or removing a sound touches four places, and `VerifySfx` checks
  all four:** a recipe in `tools/gen_sfx.py` (run it, then
  `godot --headless --import --path game`), the `.wav` + `.import` it
  writes, an entry in `Sfx.SOUNDS`, and the `Sfx.play(&"name")` /
  `Level.BOARD_SOUNDS` sites. Buttons need nothing: `Sfx.hook_buttons()`
  gives every button under a screen the tap, and a button with a sound of
  its own is named in the `except` list (Start, Pause, Resume).
- **Check `git branch -r` before choosing a base.** Two sessions once
  branched from the same commit and built the same feature independently.
- **Never write a save file in place.** `GameState.save_current_slot()` builds
  a temp, verifies it parses back, copies the outgoing save to `.bak`, then
  renames the temp over the primary. Godot exposes no fsync, so an in-place
  truncate-then-write could leave a zero-byte file for tens of seconds of
  writeback; that file then read as a new game and the next win made it
  permanent. Keep the rename, and keep `load_failed` refusing to overwrite a
  save that could not be read.

---

## Standing caveats

- **Nothing has ever run on a GPU or a device.** Every render so far is Linux
  / Xvfb / llvmpipe software rendering. That verifies drawing logic and
  nothing about how it behaves on a phone.
- **No export presets are committed** (`export_presets.cfg` is gitignored) and
  neither export has been configured. See the pre-export checklist in
  `open-items.md` — the iOS Compatibility renderer reaching Metal through
  ANGLE is the open question.
- **All the audio is synthesised, and none of it has been *heard*.** The
  18 effects (`Sfx`, `SFX` bus) and the 10 music loops (`Music`, `Music`
  bus; the Options menu mutes each) were composed in numpy and judged by
  waveform, spectrogram and numbers on a machine with no audio out.
  `tools/gen_sfx.py` and `tools/gen_music.py` are where to re-tune one;
  `story-bible.md` argues music becomes load-bearing once the story layer
  goes wordless, so expect these loops to be replaced or reworked. The
  Options menu also holds the hex grid opacity slider
  (`Settings.grid_opacity`, `[display]` in `user://settings.cfg`), which
  thins an EMPTY cell's fill only.
- **Music WAVs must keep `edit/loop_mode=2` in their `.import`.** 2 is
  Forward; 1 is Disabled, and the default 0 ("detect") is Disabled too for
  a WAV without loop markers -- so a fresh import plays once and stops.
  `Music._ready()` forces a forward loop on any stream that arrives without
  one as a fallback, and `VerifyMusic` checks the `.import` text itself.
- **Exclude `tests/` and `tools/` from any export.** They are inert but ship
  otherwise, and they read files outside `res://`.
