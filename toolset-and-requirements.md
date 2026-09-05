# Flash Flood — Game Requirements & Minimum Toolset

## Game summary
- 2D, single-player, offline puzzle game
- Target platform: Android (primary), iOS portability desired but not required
- Campaign structure: main menu → level select → level
- Limited save slots, linear progression (completing a level unlocks the next)
- 100 levels, all fixed/hand-designed (no procedural generation)
- Size target: aim for <10MB, but not a hard ceiling
- RAM usage: keep small
- Minimal sound and music

## Core mechanic
- Each level is a hexagonal grid
- Game runs on a discrete tick system (not continuous physics)
- Water sources at the top of the screen
- Player places blocks (up to 20 distinct types, multiple copies of each, limited per level) to divert water into pools or rivers
- Fires on the grid must be extinguished by water
- Lose conditions: any water reaches the bottom of the screen, OR any water reaches a "town" cell (see below)
- Win condition: all fires extinguished AND every pool's status bar fully lit (see below)

## Water movement pattern
- Water does **not** fall straight down by default. The natural (unblocked) fall pattern is a **zigzag**: down-left, then down-right, then down-left, alternating every tick.
- **Per-stream alternation**: each water source/stream tracks its own alternation state independently (its own "next direction" counter). Multiple sources on the same level can be out of phase with each other — there is no single global parity for the whole board.
- **First step**: a stream's first move is down-left (then down-right, then down-left, ...).
- **Blocked-step resolution**: on each tick, the stream first tries its current required diagonal (down-left or down-right per its own alternation). If that hex is blocked (by a **Wall** block or the grid edge), it tries the *other* diagonal that same tick instead. If both diagonals are blocked, the water stays in place that tick (pools up there) rather than moving. Alternation state still advances normally for the next tick regardless of which direction was actually taken (or attempted).
- **Only a Wall blocks natural fall.** Diverter and Splitter blocks are pass-throughs: natural-falling water lands on them fine (not treated as "blocked"), and that block's own behavior then decides the exit direction the following tick, same as always. (An earlier implementation mistakenly treated any placed block as an obstacle to natural fall, which silently broke Diverters/Splitters entirely — fixed.)
- Straight-down is no longer a "natural fall" option — it's only ever the result of block redirection, same as any other direction blocks can steer water into.
- **Inherent leftward drift**: because every stream's first move is down-left, an uncorrected stream drifts steadily toward the grid's left edge and overflows/loses after roughly `2 * grid_radius` ticks. A single well-placed Diverter-Right early in a stream's path counteracts this and can lock it into a stable, non-drifting vertical corridor indefinitely — the primary reusable technique for level design so far.
- Design implication: level layouts (fire/pool/town placement) must account for this drift and the safe-tick-window before edge overflow; see the level-authoring methodology note below.

## Pool status bar
- When water first connects to a pool (i.e. flows into that cell), a status bar of **4 boxes** pops up above it. It stays hidden until that first connection.
- Every beat the water is connected to the pool, one box changes color. A pool finishes once all 4 boxes have changed color — this is the win condition for that pool (fixed at 4 for every pool on every level, not a per-level configurable count).
- **Progress is preserved, not reset**: if the water stream is diverted away or dries up before all 4 boxes are lit, the boxes already lit stay lit. Reconnecting later continues from where it left off rather than restarting from zero.
- Implication for level design: a pool can be "topped up" across multiple separate connection windows rather than needing one unbroken 4-beat stream.

## Towns (instant-loss hazard)
- A town is a set of axial hex coordinates (`LevelData.town_cells`) marking a hazard on the grid. Authoring convention: a town is exactly 4 hex cells that are all edge-adjacent to each other (one connected blob), in whatever shape fits the level — this isn't enforced in code, any number of cells works mechanically, but 4-connected is the intended shape.
- **Any water reaching any town cell ends the level in an immediate loss**, exactly like water reaching the bottom edge.
- Blocks cannot be placed on a town cell (same restriction as fire/pool cells).
- Rendered as a distinct earthy-brown cell with a small house icon (square + triangle roof) so it reads clearly as "avoid this" at a glance, separate from fire (red) and pool (blue) coloring.
- Towns don't interact with the zigzag/Wall/Diverter rules specially — they're just another terrain type checked at the same point fire/pool terrain is checked when water tries to enter a cell.

## Music-driven timing spec
- Whole game runs in 4/4 time
- Water progression (one hex per beat) is locked to tempo:
  - **Standard levels: 72 BPM** — beat interval = 60/72 s = 0.8333 s (833.33 ms) — this is when water advances one hex
  - **Fast levels: 80 BPM** — beat interval = 60/80 s = 0.75 s (750 ms) — this is when water advances one hex
- Sub-tick rate: **4 sub-ticks per beat**, used for animation/effects/audio cues only — gameplay (water hex advance) fires only on the beat (every 4th sub-tick), not every sub-tick
  - Standard (72 BPM): sub-tick interval = 0.8333/4 = 0.20833 s (208.33 ms, exact fraction 5/24 s); 16 sub-ticks per measure
  - Fast (80 BPM): sub-tick interval = 0.75/4 = 0.1875 s (187.5 ms, exact fraction 3/16 s); 16 sub-ticks per measure
- Implementation: one Godot `Timer` running at the sub-tick rate; a counter (0–3) tracks position within the beat — on wraparound (every 4th fire) call the existing water-move `_on_tick()`; every fire calls a lighter `_on_subtick()` for animation/audio/visual pulse
- Use exact fractions for `Timer.wait_time` (e.g. `60.0 / (72.0 * 4.0)`, `60.0 / (80.0 * 4.0)`) rather than rounded millisecond decimals, to avoid float drift accumulating over a long level
- **Not yet wired in**: the delivered project currently uses a flat `TICK_INTERVAL` constant (0.6s) in `Level.gd`, not this beat-locked sub-tick system. Still an open task.

## Level-authoring methodology (learned this session, worth reusing for the remaining ~88 levels)
- Manual hex-coordinate math is error-prone; design and verify levels with a small headless Godot test harness instead: build `LevelData` objects programmatically, run candidate source/radius/block-placement combos in a "trace-only" mode (with a permanently-unreachable dummy pool target so the level never vacuously wins early) to see exactly which cells are reachable, then commit fire/pool/town placement based on the observed trace.
- Always trace WITH the real fire/pool/town cells in place (not blank placeholders) before finalizing — consuming a cell (fire/pool/town) changes a stream's exact tick timing versus an empty trace, so a design that looks right in a bare trace can behave differently once real terrain is added.
- Re-run a full regression (load the actual `.tres` files, not just the programmatic design) after any core simulation change — this caught real bugs twice this session (the "any block obstructs natural fall" bug, and the "consumed-by-fire block target treated as stuck" bug).

## Minimum toolset

**Engine:** Godot 4.x
- Free, open source, no revenue-based licensing
- Native dual export to Android and iOS from one project
- 2D-first, well suited to grid/puzzle games
- Built-in hexagonal TileMap support (offset/axial coordinates) — covers the hex grid without a custom library

**Language:** GDScript (built into Godot; no need for C#)

**Simulation architecture:**
- Tick loop: `Timer` node or a manual accumulator in `_process`, firing a custom `_on_tick()`
- Grid state: `Dictionary` keyed by hex coordinate → cell state (empty, water, block type, pool, fire, town)
- Water/fire behavior resolved as tick-based rules, not physics — deterministic, no physics engine (Box2D etc.) needed
- Each water stream needs its own alternation-state field (next direction: down-left or down-right) alongside its position, per the zigzag rule above
- Each pool needs a cumulative "connected beats" counter (capped at 4) alongside its fill-terrain state, per the status bar rule above
- Town cells are checked at the same "water tries to enter this cell" point as fire/pool terrain, triggering an instant loss

**Data-driven block system (important given up to 20 types × multiples):**
- Each block type defined as a Godot `Resource` (id, sprite, tick-behavior, per-level placement limit)
- Tick loop dispatches generically off the resource rather than hardcoded per-type branches
- New block types added as new resource files, not core-logic changes

**Level data:**
- Each of the 100 levels modeled as its own Resource/scene: grid layout, water source positions, fire positions, pool cell locations (fixed 4-beat requirement, not per-pool configurable), town cell locations, starting block inventory (type + count)

**Save system:**
- Godot's built-in `FileAccess`/`ConfigFile`, one file per save slot
- Each save stores: `highest_unlocked_level` (or array of completed level IDs), and any per-level stats if added later

**UI:**
- Standard Godot `Control` nodes for main menu, level select (grid/list, locked/unlocked state), save slot picker, and an inventory/palette tray (block type + remaining count, tap-to-select then tap-to-place)
- Per-pool 4-box status bar, appears on first connection, drawn above the pool cell
- Town cells rendered with a distinct color + simple house icon

**Art tooling:** Any 2D art tool — Aseprite (pixel art) or Krita/Inkscape (free) — Godot just imports PNG/SVG

**Audio:**
- Godot's built-in `AudioStreamPlayer`/`AudioStreamPlayer2D`
- Audacity for editing/trimming clips
- Use `.ogg` (Vorbis) for music/longer sounds to help the size budget; short SFX can stay as small `.wav` files

**Build/export:**
- Android SDK + signing keystore (Godot's exporter produces the .apk/.aab)
- Optimization for size: release export template, single-architecture build, compressed textures
- Xcode + a Mac, only if/when the iOS export is pursued (Apple platform requirement, not Godot-specific)

## Android vs iOS: what actually differs

From a **code** perspective, almost nothing — one codebase, same GDScript, scenes and
`.tres` data. The complete set of platform-sensitive code is implemented and written up
in `game/README.md` → "Platform handling (Android / iOS)": the Android Back button
(routed per-screen instead of quitting the app), the Main Menu's Quit button (hidden on
iOS, where a visible one is an App Store rejection risk), and the duplicate mouse events
Godot synthesizes from touch (a touchscreen issue on both platforms, not a difference
between them). Saves, the renderer setting and the safe-area situation need no branch.

The real divergence is in **delivery**, not source:

| | Android | iOS |
| --- | --- | --- |
| Build machine | any OS + Android SDK | **Mac + Xcode required** — Godot emits an Xcode project; you build, sign and upload from there |
| Account | $25 one-off | $99/year |
| Signing | your own keystore | certificates + provisioning profiles |
| Review | largely automated, hours | human review, days, can reject |
| Compliance | Play Data Safety form | `PrivacyInfo.xcprivacy` privacy manifest |
| Architecture | build arm64-only for the size budget | arm64 only anyway |

Both compliance declarations are near-empty for this game — offline, no analytics, no
ads, no IAP, no networking — but both are mandatory.

The reason the port stays cheap is the "Explicitly not needed" list below. Native
plugins are where Android (Java/Kotlin AAR) and iOS (`.xcframework` + Objective-C) fork
into two separate codebases needing their own GDExtension glue. This project uses none.

## Explicitly not needed
No backend/server, no database, no networking library, no analytics SDK, no ads/IAP SDK, no physics engine, no external hex-grid or save-sync libraries.

## Open items for later
- Exact win/lose UI feedback and level-complete flow
- Whether save slots track per-level completion detail (stars, time) or just unlock progress
- Final call on Android SDK target/min API version
- Wiring the beat-locked sub-tick timing system into the tick timer (currently a flat 0.6s interval)
