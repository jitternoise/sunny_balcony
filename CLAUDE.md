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
godot --headless res://tests/VerifyLevelMap.tscn    # Level Select map, badges, side paths
godot --headless res://tests/VerifySafeArea.tscn    # notch/gesture-bar insets, 27 checks
godot --headless res://tests/VerifySaveIntegrity.tscn # save durability/corruption, 34 checks
godot --headless res://tests/VerifyMultiTouch.tscn  # second-finger handling, 13 checks
godot --headless res://tests/VerifyBoardHeartbeat.tscn # board animates only when visible, 14 checks
godot --headless res://tests/VerifyWaterBlocking.tscn # solid targets block a redirect, 15 checks
# needs a display (measures laid-out control sizes):
xvfb-run -a --server-args="-screen 0 720x1280x24" \
  godot --resolution 720x1280 res://tests/VerifyTouchTargets.tscn # 48dp targets, 30 checks
xvfb-run -a --server-args="-screen 0 720x1280x24" \
  godot --resolution 720x1280 res://tests/VerifyMapScroll.tscn # map opens on your level, 14 checks
xvfb-run -a --server-args="-screen 0 720x1280x24" \
  godot --resolution 720x1280 res://tests/VerifyUndoAndHeader.tscn # cancel a queued placement, 14 checks
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
result: **88 exact / 11 broken / 1 prose (level 22)**. The 11 are all wall
placements, broken by the 2026-08-31 change making the Wall 2 tiles wide.

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

**Beat cycle.** One measure = 4 beats = 1.2 s (`SUBTICK_INTERVAL` 0.15 ×
`ticks_per_beat` 2 × 4). Beats are PLACEMENT → WATER → TERRAIN → STATUS. The
sim runs off a `Timer`, **not** off frames, so frame rate cannot change a
level's outcome. Keep it that way.

**Tile drawing is table-driven.** `_resolve_tile_state()` is the single place
terrain precedence lives; `TILE_VISUALS` is the single place each state's
appearance lives. To animate a tile type, add a sheet to its table entry — do
not add a branch. A state with no sheet falls back to its static icon.

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

- **The Wall is 2 tiles wide.** Placing one covers the tapped cell *and* a
  neighbour. This invalidated 11 documented solutions and is the single most
  common source of "why doesn't this level win any more".
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
- **No audio at all.** `story-bible.md` argues it becomes load-bearing once
  the story layer goes wordless.
- **Exclude `tests/` and `tools/` from any export.** They are inert but ship
  otherwise, and they read files outside `res://`.
