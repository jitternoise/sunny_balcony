# Flash Flood — Open Items

Compiled from `claude/dev-progress.md` (2026-08-10 session). Nothing in this project has been visually confirmed in a live Godot window yet — all verification to date has been headless/simulated only. That's the single biggest thread running through every item below.

## Top priority: live Godot playtest

No feature built this session has actually been run in a live Godot engine. Needs hands-on confirmation of:

- Buffered block placement (feels responsive, not laggy) and whether the beat-4-deferred status-bar reveal reads as intentional rather than a rendering delay (new 4-beat tick cycle)
- `level_018.tres` (reconstructed from a README description, never re-verified against the real engine)
- Scrolling drag/mouse-wheel input on the tall levels
- Jamboree inventory bar UI ("Tiles left: N" label, all buttons disabling together)
- Icon/glyph rendering for blocks and Fire/Pool/Town/Source terrain
- Level Select name buttons and word-wrap layout
- Loss popup, level-intro popup, and win popup (confirm "Next" correctly advances and shows the next level's intro popup; confirm level 20 correctly routes to Level Select instead)
- Pre-start flow-preview arrows (render, fade, vanish on Start, reappear on Retry)
- Flat grid orientation's pixel rendering (`level_020.tres` — hex corner angles, source-marker arrows)
- Sky/grass background split across all four scenes, at multiple aspect ratios
- Town-flood light-blue color change on loss
- Geyser's automatic feed-blocking after activation

## Deliverables / packaging

- Rebuild and deliver a fresh project zip — the last one shared is stale and predates the win popup, intro popup, flow-preview arrows, town-flood color, the array-type crash fix, geyser feed-blocking, and the new 4-beat tick cycle.
- Extend `claude/level-editor.html` to support `geyser_cells`, `total_block_budget`, the new `grid_style`/`source_flow_style` flat-grid fields, and the new `intro_text` field — it currently only matches the original 17-level/pointy-top/no-Geyser/no-Jamboree feature set.

## Content

- Author the remaining ~80 levels (currently 20 of ~100) using the level editor, once it's updated to support Geyser/Jamboree/flat-grid/intro_text.
- A Geyser-specific icon SVG hasn't been made yet — still uses a procedural placeholder while every other terrain/block type has real icon art.

## Tempo / rhythm system

- Map the real 72/80 BPM "Music-driven timing spec" tempo values onto `ticks_per_beat` per level — currently the constant/tempo split just reproduces the old flat 0.6s-per-beat feel, not the documented BPM figures.
- Design the mid-level tempo-shift mechanic that was discussed alongside the beat-cycle work but not yet built.
- Wire actual per-sub-tick animation/audio pulses — `_on_subtick()` fires on every constant tick but currently no-ops on sub-ticks that don't land on a beat boundary.

## Open design questions (not yet asked for, but flagged)

- Should towns get their own dedicated block type (e.g. a "town shield") instead of staying a fixed-terrain hazard?
- Should an active geyser get a distinct "erupting" visual instead of reusing the plain source marker/arrow?
- Should a Jamboree level's inventory bar preview how many placements are left per block type, not just the one shared counter?
- Should the flat grid's Diverter-Right get a distinct icon/label, since the same block now resolves to a different geometric direction depending on `grid_style`?
- Should the grass/sky background get texture/detail (clouds, grass blades) beyond flat color blocks?

## Not yet built at all

- Scoring system
- Level curriculum beyond linear unlock
- End-game / campaign-complete screen (winning level 20 currently just labels the win popup's button "Level Select" — no special "you finished the game" messaging)
- Pause handling
- Accessibility pass
- Sound/music wiring (no `AudioStreamPlayer` nodes yet)
- Settings menu
- Level-complete visual polish
- Save-slot delete/reset UI (backend function exists, not wired to a button)
