# Flash Flood — Handheld Platform Audit (2026-09-08)

Audit of the shipping code against the target platform: **portrait handheld,
Android primary, iOS port**. 70 findings were raised across 11 dimensions and
each was put to an independent adversarial verifier instructed to refute it;
**47 survived, 23 were killed**. Severities below are the verifiers' corrected
ones, not the finders' claims.

Method and its limits: verification was by reading source, running the engine
headless, building a real PCK, and rendering under Xvfb. **Still nothing has run
on a GPU or a handset**, so every claim about how something *looks or feels on
a device* is marked as such. Two findings were proven by execution and are
flagged ✅ **PROVEN**; those are not inferences.

Twelve further findings never got a verdict — their verifiers died on a usage
limit mid-run. They are listed unverified at the end rather than dropped.

---

## 🔴 Ships broken — the first build does not work

### 1. The exported game has no blocks at all ✅ PROVEN — CRITICAL
`game/scripts/gameplay/Level.gd:464`

`_load_block_catalog()` scans `res://data/blocks/` and filters on
`ends_with(".tres")`. In an exported PCK those directory entries are
`*.tres.remap`, so nothing matches and the catalog is empty. Every one of the
100 levels loads with an empty inventory bar — nothing to place, no level
completable.

Reproduced by building a real PCK with Godot's default export option *Convert
Text Resources to Binary* (on by default for any preset created in the editor):

```
PROBE listing:      ["bomb_catapult.tres.remap", "divert_left.tres.remap", …]
PROBE catalog size: 0   ids: []
```

This is the only `res://` directory scan in shipped code — levels use the
hardcoded `LevelSelect.LEVEL_PATHS`, so they are unaffected. Nothing in the repo
can catch it: all 20 test scenes and both verification tools run against the
source tree, where the `.tres` files are really on disk.

Both candidate fixes were tested against the PCK and both work:

```
FIX-A  ResourceLoader.list_directory("res://data/blocks/")
       -> ["bomb_catapult.tres", "divert_left.tres", …]     # remap-aware
FIX-B  strip a trailing ".remap" before the ".tres" test
       -> catalog size 5
```

Prefer A. Alternatively drop the scan for an explicit const array, matching the
pattern `LevelSelect.LEVEL_PATHS` already uses.

### 2. An RTL system language blanks the campaign map ✅ PROVEN — CRITICAL
`game/scripts/ui/LevelSelect.gd:375`, `game/project.godot`

On a phone set to Arabic, Hebrew, Persian or Urdu, Godot derives the root
layout direction from `OS.get_locale()` — **no translation files are required**
— and every Level Select node shifts by exactly one viewport width:

```
locale=en_US  root_rtl=false   level_1 pos=(322.0, 1132.0)
locale=ar     root_rtl=true    level_1 pos=(1042.0, 1132.0)   # viewport is 720 wide
```

All 100 nodes land off the right edge. The map renders empty and the game is
unplayable past the main menu.

The game has no translations at all (zero `tr()` call sites), so the fix is to
opt out of automatic mirroring. Verified to restore correct positions under
`--language ar`:

```ini
[internationalization]
rendering/root_node_layout_direction=1   ; force LTR
```

### 3. The "Unlock All" debug cheat is a labelled control in release builds — HIGH
`game/scenes/LevelSelect.tscn:55`

The toggle is an unconditional scene node. On a release build it is the only
control on Level Select with words on it (everything else is a bare icon), sitting
in the top-right corner. One tap opens all 100 levels and all ten par-gated
spurs.

The in-code comment claims this is safe because the flag is session-only and never
written to a save. **The verifier corrected this**: only the *flag* is
session-scoped. Any level played while it is on writes real progress through
`mark_level_complete()`, so a curious tap permanently destroys the campaign
progression it was meant not to touch.

Fix: `debug_unlock_toggle.visible = OS.is_debug_build()` in `_ready()`.

### 4. No application icon or splash image exists — MEDIUM
`game/project.godot:9`

Nothing in the repo supplies one, and the pre-export checklist in
`open-items.md` never mentions it. Both stores would ship Godot's blue robot,
with no adaptive-icon layers and no themed/monochrome variant for Android 13+.

### 5. Android toolchain unconfigured; APK is not an accepted artifact — HIGH *(known)*
`.gitignore:9`

`export_presets.cfg` is gitignored so target SDK, package name, signing,
architectures and the `tests/`+`tools/` exclusion are all unset and
unreviewable. Google Play requires an AAB. The verifier softened one claim: the
finder's assertion that a default-template artifact *will* be refused on
target-API grounds is not established, so treat that part as unconfirmed.

---

## 💾 Save data — silent, unrecoverable loss

Three auditors found this independently; merged here.

### 6. Saves are written in place with no temp file, no fsync, no error check — HIGH
`game/scripts/autoload/GameState.gd:110`

`save_current_slot()` opens the real path `WRITE` (truncating it), calls
`store_string`, and closes. The return value of `store_string` is discarded and
`close()` is never checked.

The verifier materially **widened** this. The finders led with "a kill between
truncate and write", a sub-millisecond window. The real hole is that there is no
`fsync` and the write is in place: after `close()` the JSON sits in the page
cache for the writeback interval — typically 5–30 s on ext4/f2fs — while the
inode is already truncated on disk. Any power loss in those tens of seconds
gives a zero-length or partial file. That window is thousands of times wider
than the one described. A third route needs no power event at all: `ENOSPC` on a
nearly-full handset writes a short file and returns normally.

Demonstrated against the real autoload — 56 levels of progress, then an
interrupted write:

```
saved. bytes=249
after interrupted write: exists=true bytes=0
reloaded -> highest_unlocked_level=1 completed=0
SaveSlotSelect would label slot 0: continue
```

The verifier also **shrank** one claim: `mark_hydro_bonus()` cannot fire, since
0 of 100 levels set `hydro_plant_cells`, and only 10 set `par_measures`. So it is
one rewrite per win on 89 levels and two on the 10 fork levels — not three.
Batching the win-path writes buys much less than the finder implied; the atomic
rename plus fsync is where all the value is.

Fix: write `slot_N.save.tmp`, check the error, close, then
`DirAccess.rename_absolute()` over the real path.

### 7. A damaged save is indistinguishable from a new game, then laundered into one — HIGH
`game/scripts/autoload/GameState.gd:76`

On a parse failure `load_slot()` `push_error()`s and returns, leaving
`highest_unlocked_level = 1` and an empty `completed_levels`. The menu still
reads "Slot 1 (continue)". The player sees a campaign reset to level 1 with no
explanation — `push_error` goes to a logcat nobody is reading. They replay level
1, win, and `mark_level_complete()` writes the reset state back. The loss is now
permanent and indistinguishable from legitimate progress.

Fix: set a `load_failed` flag on parse failure and refuse to write over that slot
until the player is shown the problem. Keep a `.bak` and fall back to it.

### 8. Populated slots are indistinguishable, and New Game cannot start one — LOW *(known)*
`game/scripts/ui/SaveSlotSelect.gd:51`, `game/scripts/ui/MainMenu.gd:35`

The payload carries no timestamp and no name, so all three slots read
"Slot N (continue)". `current_slot` is never persisted, so an Android background
kill — routine, not exceptional — returns the player to three identical buttons.
`GameState.delete_slot()` still has zero callers, so once all three slots exist
there is no way to start fresh.

---

## 👆 Touch input — single-finger assumptions on a multi-touch device

Four auditors converged here. `InputEventScreenTouch.index` and
`InputEventScreenDrag.index` are never read anywhere in the project.

### 9. A second finger hijacks the press state machine — HIGH
`game/scripts/gameplay/Level.gd:650`

A supporting thumb resting on the glass — one-handed play on any of the 38
levels whose board is taller than the screen — emits a press that overwrites
`_press_pos` and `_press_active`. The scrolling finger's gesture is stolen.

The verifier **broadened** this: it is not a scroll bug and needs no dragging at
all. The `is_release` branch at `Level.gd:701` is unguarded by `_press_active`,
so **any unmatched touch-up places or deletes a block at its own coordinates**.
A stray thumb lift anywhere on the board mutates it.

Fix: latch an owning pointer index on first press; ignore every touch/drag whose
`index` differs until it releases.

### 10. A second touch during a catapult aim cancels the shot and strands a ghost overlay — HIGH
`game/scripts/gameplay/Level.gd:676`

Charging a catapult is a ~700 ms motionless hold — the worst possible moment for
a stray contact. The verifier found it **worse than reported**: the foreign
pointer's release does not merely cancel the aim, it places a block. The aim
overlay is never cleared, so a ghost aim stays drawn on the board.

### 11. Every touch target is below both platforms' minimum — MEDIUM
`game/scenes/Level.tscn:60`, `MainMenu.tscn`, `SaveSlotSelect.tscn`

With `canvas_items` stretch, 1 viewport unit ≈ 0.57 dp on a Pixel 7 (411 dp
wide). Start / Pause / Back are 56 units = **31 dp ≈ 4.95 mm**; the main menu's
Continue / New Game / Quit are 47 units = **27 dp ≈ 4 mm**. Android's minimum is
48 dp, Apple's 44 pt. The verifier noted the finders missed MainMenu — the very
first screen a player touches — and that the shortfall is screen-width dependent,
easing on wide devices.

Pause is also the only route to Retry, so the smallest targets gate recovery.

### 12. `DRAG_THRESHOLD` silently eats taps on boards that cannot scroll — MEDIUM
`game/scripts/gameplay/Level.gd:153`

A 20-unit threshold is 30 device px ≈ 1.76 mm on a 1080×2400 panel — well inside
a normal thumb roll. On the 62 levels where `max_scroll_down` is 0 the drag
branch can only ever destroy a tap; there is nothing to scroll. Nothing on
screen changes, so the player reads it as an unresponsive game. The verifier
noted 62/100 is the count at the 720×1280 design viewport; on a real 20:9
handset the taller logical viewport makes it worse.

Fix: skip the drag branch entirely when `max_scroll_down <= 0`, and express the
threshold in physical units.

---

## 🔋 Performance, battery and thermals

### 13. `_draw()` has no viewport culling — HIGH
`game/scripts/gameplay/HexBoard.gd:2170`

Level 22 (radius-50 corridor, 505 cells) issues ~1064 GL draw calls to paint
~75 visible cells; ~425 cells are off-screen geometry. Two auditors found this
from CPU and GPU angles. Compounding it: the 12 Hz heartbeat throttles *CPU*
repaints only — the GPU re-submits the whole command list every vsync, so on a
120 Hz phone that is ~53,000 draw calls/second for a board the player is
staring at motionless.

Fix: a per-cell band test against the viewport cuts level 22 to ~170 calls.

### 14. No `max_fps` is set — MEDIUM *(known)*
`game/project.godot:29`

Nothing in this game animates faster than 12 Hz. The verifier corrected one
detail: vsync is not unconfigured — it resolves to enabled (1) by default. Set
`application/run/max_fps` explicitly.

### 15. The board repaints while paused and behind full-screen popups — MEDIUM *(known)*
`game/scripts/gameplay/HexBoard.gd:2067`

`HexBoard._process()` has no pause, `game_over` or visibility gate. The verifier
corrected the finders: the board is **not** frozen while paused — fire frames
derive from a wall-clock counter, so it keeps animating under an opaque popup
nobody can see, while Godot's wake lock holds the display at full brightness
indefinitely.

### 16. Returning to Level Select stalls the main thread 130–200 ms — MEDIUM
`game/scripts/ui/LevelSelect.gd:330`

`_build_map()` re-parses all 100 level `.tres` files and builds 100 buttons on
the main thread, after every single level. The verifier measured the StyleBox
churn at 0.87 ms — a red herring — so the cost is the 100 disk loads. Cache the
`LevelData` refs, or store the three fields the map actually reads in one
manifest.

### 17. Per-repaint heap churn — LOW
`game/scripts/gameplay/HexBoard.gd:2131`

A 3-element Array is allocated per dirt cell per repaint (474 on level 22). The
verifier reproduced the 3.13 ms figure but **corrected the cause**: 81% of it is
trigonometry, not allocation. Hoisting the array is still right, but cache the
hex geometry if you want the win.

---

## 📐 Layout and legibility on a real handset

### 18. The board is pinned to the top of the screen — MEDIUM
`game/scripts/gameplay/HexBoard.gd:820`

On 53 of 100 levels every tappable hex sits above the midpoint of a 20:9 phone,
with the bottom third dead and no way to drag the board down. Right-handed
one-handed play on a 6.7" handset means reaching past the middle of the screen
for every tap. Fix: centre the grid in the available band when it is shorter
than the screen.

### 19. Level Select re-scrolls to level 1 on every entry — MEDIUM
`game/scripts/ui/LevelSelect.gd:350`

After finishing level 47, the next level is 2.45 screen-heights above the
viewport — every time, including on every cold start. Scroll to the highest
unlocked node instead.

### 20. HUD text is white on sky blue at 1.7:1 — MEDIUM
`game/scenes/Level.tscn:45`

`StatusLabel` and `BudgetLabel` are pure white, 16 units (~9sp on a real phone),
with no outline, at 1.73:1 and 2.75:1 contrast. On the 12 shared-budget levels
`BudgetLabel` is the *only* place the remaining block count appears. Washes out
completely in daylight. `LevelSelect._build_group_label()` already does the
right thing with an outline — copy it.

### 21. Popup text is ~9sp behind 60% translucency — MEDIUM
`game/scenes/Level.tscn:195`

The intro popups are the game's only teaching surface, and level 21's mudslide
mechanic is taught nowhere else. Board art shows through the text.

### 22. Board sizing solves for width only — LOW
`game/scripts/gameplay/HexBoard.gd:784`

On an unfolded Pixel Fold (1840×2208 inner, so a 1066×1280 viewport) the tile
inflates from 46.3 to 68.5 px and nine flat-grid levels overflow the bottom of
the screen. Solve both axes and take the smaller.

### 23. Any viewport reshape resets the scroll to the top — LOW
`game/scripts/gameplay/HexBoard.gd:751`

Folding/unfolding mid-flood, Android split-screen, or iPad Slide Over throws the
player back to the top of a board they were watching. The verifier corrected one
claim: the level *can* be paused back into place; it does not keep ticking.

### 24. Level Select's header bar clips the top node's badge — LOW
`game/scenes/LevelSelect.tscn:34`

---

## 🖥 Rendering on hardware that is not llvmpipe

### 25. Hex borders render 1–2 device px unevenly — MEDIUM ✅ FIXED 2026-09-09
`game/scripts/gameplay/HexBoard.gd:2250`

`draw_polyline` without `antialiased=true` at canvas scale 1.5 (1080×2400 — the
modal Android resolution) gives identical cells visibly different outline
weights. The verifier disproved the finders' claim that 1440×3120 is immune:
captured at scale 2.0, level 1 still shows 386 width-1 runs mixed with width-2.
Every screenshot ever taken of this project is at scale 1.0, where the artifact
cannot occur.

Reproduced at 1080×2400: **192 runs of 1 px, 353 of 2 px and 208 of 3 px** for
what should be a uniform line, across only **3 distinct luminance values** —
hard-edged, no gradient at all. `antialiased=true` on all 16 stroke calls gives
22 tones and smooth diagonals (verticals were always fine; they sit on the
pixel grid).

**MSAA 2D is not a substitute** — measured, not assumed. With
`rendering/anti_aliasing/quality/msaa_2d=1` and no per-call flag the output is
byte-identical to plain: still 3 tones, still 193 draw calls. Godot's 2D MSAA
does not touch line primitives in the Compatibility renderer.

Cost, measured: draw calls **193 → 369** on level 22 (+91%), frame time +11%
under llvmpipe. That is still far below the ~1064 before culling, but it is
half the culling win given back.

### 26. Tile art is 128 px against a drawn size of 58–374 px — MEDIUM
`game/scripts/gameplay/HexBoard.gd:2652`

The SVGs got a 3× import scale; the five PNG sheets (each 768×128 = six 128 px
frames, RGBA, `mipmaps/generate=false`) got nothing.

> **Re-measured 2026-09-09, and the premise was half wrong.** The title used to
> say "magnified 1.3–2.0×". Sweeping `Hex.SIZE` across all 100 levels and
> multiplying out the FILL draw size (`Hex.SIZE * 2`) against the 128 px source:
>
> | canvas scale | drawn px | magnified | minified |
> |---|---|---|---|
> | 1.0 (720-wide) | 58–187 | 1 | **99** |
> | 1.5 (1080-wide, modal) | 86–281 | 47 | **53** |
> | 2.0 (1440-wide) | 115–374 | **99** | 1 |
>
> So on the commonest Android resolution it is a near-even split, and on
> small-celled levels the art is *minified*, not magnified. Smallest cell is
> level 18 (`Hex.SIZE` 28.8), largest level 16 (93.5).

**Still open, and deliberately not fixed here**, because neither half is safely
actionable without a device or an artist:

- The **magnified** half needs higher-resolution source art. There is no vector
  source for the water or fire sheets anywhere in the repo — only the PNGs — so
  re-authoring at 256 px per frame is art work, not a settings change.
- The **minified** half is what mipmaps would fix, and they are one import flag.
  But mipmapping a *horizontal sprite sheet* blends neighbouring frames at
  coarser mips, which is precisely what `SHEET_REGION_INSET` (half a texel)
  exists to hold off — at mip 1 that inset is half of what it needs to be. And
  Godot's canvas default filter ignores mipmaps anyway, so it is a two-part
  change whose failure mode is cross-frame bleed that **cannot be validated
  without a GPU**. The minification is at most 1.5×, so the shimmer it would
  cure is mild; the bleed it might cause is not.

If this is picked up: re-author the five sheets at 256 px per frame *with
padding between frames*, then mipmaps become safe and both halves are solved at
once.

### 27. The visual regression net never renders water — LOW
`game/tests/BoardSnapshots.gd:4`

All 10 snapshots are captured pre-Start, where `water_cells` is provably empty.
The four water sheets are the only full-tile edge-to-edge art in the game and
are exactly what the pre-export checklist flags for seams — and they are the one
thing the net cannot see. Add a post-Start capture.

---

## ♿ Accessibility

### 28. Dig progress is conveyed by colour alone — MEDIUM
`game/scripts/gameplay/HexBoard.gd:203`

The four dig states are distinguished by fill colour only — all six dirt states
register `"icon": null`. The open/blocked step is 1.34:1, and the lightness ramp
inverts at the last tap. Level 22 is 505 dirt cells and a 324-tap solve. The
3-tap rule is stated in one level's intro, which cannot be re-read without
leaving the level.

### 29. Deuteranopia collapses three warm tile fills — LOW
`game/data/blocks/divert_left.tres:12`

Fire, Diverter-Left and Bomb Catapult simulate to one yellow (ΔE 8, 1.19:1). The
verifier downgraded this from medium: the glyphs still separate them, so it is a
loss of redundancy, not of identification. Separate by lightness, not hue.

---

## 🎮 Gameplay correctness

### 30. Diverters and Splitters push water onto walls, which deletes it — MEDIUM
`game/scripts/gameplay/HexBoard.gd:1362`

Neither redirect loop checks `_is_wall`. Plugging a diverter's mouth with a Wall
— a natural move, since `wall.tres` documents walls as backing water up — makes
the water vanish instead. The verifier corrected the finders' "the only way out
is Retry": `remove_block` works mid-simulation.

### 31. A pending placement cannot be cancelled — MEDIUM
`game/scripts/gameplay/Level.gd:859`

Tapping a just-placed block does not remove it while it is still queued, so the
undo affordance is dead for a full measure — exactly the second in which the
player notices the mistake.

### 32. The mudslide fires at 12 s, not the documented ~3 s — LOW
`game/scripts/gameplay/HexBoard.gd:238`

`MUDSLIDE_BEATS_REQUIRED` counts WATER beats, which land once per measure. Level
21's intro tells the player otherwise. The verifier confirmed the mechanism but
found three of the finder's supporting arguments wrong and lowered the severity.

---

## ⏸ Raised but never verified

Twelve findings lost their verifier to a usage limit. They are **unconfirmed** —
some may be wrong — but they cluster in areas nothing else covered, and two claim
critical severity:

| Claim | Anchor |
|---|---|
| Level 68 is unwinnable at all, so its par can never be earned *(CRITICAL claimed)* | `level_068.tres:24` |
| The RTL safe-area left inset is applied to the right edge and vice versa | `SafeArea.gd:57` |
| Earning par opens a spur whose node is permanently disabled | `LevelSelect.gd:371` |
| The par mechanic is explained only in a tooltip — unreachable on a touchscreen | `LevelSelect.gd:372` |
| Par is a timed challenge with no timer anywhere in the HUD | `Level.gd:916` |
| The Bomb Catapult is reachable from level 19 but taught nowhere | `Level.gd:509` |
| Once promoted to aiming there is no way out of a catapult press | `Level.gd:681` |
| The catapult needs a 300 ms motionless hold; 1.4 mm of drift converts it | `Level.gd:689` |
| 62 of 100 levels have hex cells below 48 dp; level 18 is 4.4 mm wide | `HexBoard.gd:784` |
| On all 62 small-cell levels `DRAG_THRESHOLD` can only destroy taps | `Level.gd:153` |
| Start / Pause / Back are 31 dp, and Pause is the only route to Retry | `Level.tscn:54` |
| 100 level strings are baked into `.tres` with zero `tr()` call sites | `LevelData.gd:17` |

Level 68 is already tracked in `open-items.md` as a broken *documented solution*
whose wall placement is rejected outright; the stronger claim that **no**
solution exists was never checked. `tools/solve_broken.gd` exists to settle it.

---

## Fix in this order before the first device build

1. **Block catalog `.remap` fix** — one line; without it the build is unplayable. *(#1)*
2. **`root_node_layout_direction=1`** — one line; without it RTL locales get a blank map. *(#2)*
3. **Hide the Unlock All toggle behind `OS.is_debug_build()`** — one line, prevents permanent progress loss. *(#3)*
4. **Atomic save via temp-file + rename, and check the write errors** — the only data-loss defect. *(#6, #7)*
5. **Latch a pointer index in the input state machine** — kills the whole multitouch class, including the unmatched touch-up that mutates the board. *(#9, #10)*
6. **Skip the drag branch when the board cannot scroll** — one line, fixes dropped taps on 62 levels. *(#12)*
7. **Cull `_draw()` to the viewport and set `max_fps`** — the single biggest battery and thermal item. *(#13, #14)*
8. **Gate `HexBoard._process()` on paused / game_over / visibility.** *(#15)*
9. **Outline the two HUD labels and raise the base font size** — legibility outdoors. *(#20, #21)*
10. **Raise touch targets toward 48 dp, starting with MainMenu and the Pause row.** *(#11)*

Items 1–3 and 6 are one-liners. Item 4 is contained to one file.

**Not settled by any of this:** whether the Compatibility renderer reaches Metal
cleanly through ANGLE on iOS, whether `DisplayServer.get_display_safe_area()`
reports a sane rect before first layout on a real handset, and how any of the
above actually performs on a GPU. Those still need a device.
