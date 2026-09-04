# Flash Flood — Breakable & Delayed Tiles (Design Brainstorm)

Companion to `icon-system.md`. Visual reference: `breakable-tiles-onepager.html`
(icon for every tile below, plus 4-panel explainers showing both lifecycles —
breaking down and building up).

## The core idea

A breakable tile behaves like a normal block or terrain piece, but only for a
limited number of ticks — then it collapses into something else (usually open
terrain, sometimes a burst of water, sometimes an exposed hazard). This turns
placement from a purely spatial puzzle ("where do I put this") into a spatial
*and* temporal one ("where, and for how long do I need it to hold").

Two decay rules cover every idea below:

- **Timer-based** — the tick counter decrements every tick after placement,
  whether or not water ever touches the tile. Forces pre-planning: the player
  has to place it with the right lead time relative to when the flood actually
  arrives.
- **Contact-based** — the counter only decrements on ticks where water is
  actively pressing against the tile. Rewards rerouting flow away from it to
  extend its life, and punishes brute-forcing water straight at it.

A third pattern, **chain-based**, links several breakable tiles together so
one early failure accelerates its neighbors — useful for a single climactic
"the whole levee gives way" level rather than a teaching moment.

A fourth pattern runs the whole idea in reverse: a **delayed-appearance**
tile starts dormant and only becomes active after N ticks, instead of
starting active and expiring. The Beaver Dam below is the one example of
this so far — mechanically it's the same counter system, just triggering the
opposite transition (`EMPTY` → active block, instead of active block →
`EMPTY`).

## Tile catalog

### Sandbag Wall — Timer
Behaves exactly like a Wall (fully blocks, water backs up against it) but
crumbles into open terrain after a fixed number of ticks regardless of water
contact. The baseline breakable tile — introduces the whole mechanic without
any extra rules layered on top.
- Suggested fuse: 4–6 ticks
- Breaks into: `EMPTY`

### Ice Dam — Timer
Same behavior as the Sandbag Wall, themed as melting, with a much shorter
fuse. Works well as the very first breakable tile a player encounters — it
fails fast enough inside a single attempt to be self-explanatory without a
tutorial popup.
- Suggested fuse: 2–3 ticks
- Breaks into: `EMPTY`

### Rope Bridge Diverter — Timer
A Diverter-Left/Right that only redirects for a set number of ticks, then goes
slack and lets water fall straight through on its natural path again. More
interesting than a wall breaking, because the *direction* of flow changes
mid-level, not just whether an obstacle exists.
- Suggested fuse: 3–5 ticks
- Breaks into: natural fall (no redirect)

### Mud Levee — Contact
Only counts down on ticks where water is actively pressing against it — sits
indefinitely if left alone. Rewards players who reroute flow away from it
early to preserve it for later, and punishes aiming everything straight at it.
- Suggested threshold: 3–4 contact ticks
- Breaks into: `EMPTY`

### Reed Debris Catch — Contact
Acts like a Splitter, but "clogs" a little more with each pass. Once it hits
its contact threshold it bursts, releasing everything it had been diverting
as one sudden surge in a single direction — a way to create a delayed second
wave of water without needing a second source or a Geyser.
- Suggested threshold: 3 contact ticks
- Breaks into: single-direction surge + permanently open fork

### Sandbag Row (Chain Levee) — Chain
Several adjacent breakable walls, linked: if one breaks early (e.g. from
being overloaded), it docks ticks off its neighbors' remaining counters too,
simulating a levee failure cascading sideways. Best used sparingly, in a
climactic level, rather than as an early teaching tile.
- Suggested fuse: 5 ticks each, −2 ticks to neighbors on break

### Sandcastle Town Shield — Timer
A temporary answer to the open design question in `dev-progress.md` about
whether towns deserve their own block: protects a town cell from instant-loss,
but only for a fixed number of ticks. Forces the player to have a permanent
redirect solution ready before the shield expires, rather than treating it as
a full fix.
- Suggested fuse: 6–8 ticks
- Breaks into: exposed Town (hazard becomes live again)

### Beaver Dam — Grows, Contact
The mirror of every other tile above: placed dormant, so water flows straight
through the cell untouched at first. Builds up in stages only on ticks where
water is actually flowing over it (a beaver needs the current to work with),
so — like the Mud Levee — rerouting water away from it stalls its progress
rather than speeding it up. Once it finishes building it behaves exactly like
a placed Diverter-Left/Right, permanently redirecting water to one side from
then on. Good for "the flood itself builds the obstacle" levels — a puzzle
where the correct early play is to *let* water hit a spot so the dam forms in
time to redirect a later, bigger wave.
- Suggested build time: 4 contact ticks
- Becomes: `DIVERT_LEFT` or `DIVERT_RIGHT` (level-authored choice of side)

## Implementation sketch

Maps cleanly onto the existing `BlockData`/`TickBehavior` pattern in
`scripts/resources/BlockData.gd`:

- Two new exported fields: `breaks_after_ticks: int = 0` (0 = doesn't break)
  and `break_into: TickBehavior` (or a simple flag meaning "revert to plain
  `EMPTY` terrain").
- A per-cell counter dictionary in `HexBoard.gd`, the same pattern already
  used for `active_geysers` — increment/check once per `tick()`.
- Timer vs. contact tiles are the same system with a different increment
  rule: timer tiles increment every `tick()` regardless; contact tiles
  increment only on ticks where `_try_enter()` lands on that cell.
- Chain tiles just need each break event to look up its linked neighbor
  cells and dock their counters directly.
- Visual wear (crack overlays, as shown in the explainer panel) can key off
  `ticks_remaining / breaks_after_ticks` to drive 2–3 generic wear stages
  without needing bespoke art per tile per stage.
- **Beaver Dam runs this inverted**: `appears_after_ticks: int` and
  `appear_into: TickBehavior` (a Diverter). Before the counter hits its
  target, the cell behaves as plain `EMPTY` in the simulation; once it hits
  the target, `_resolve_block_targets()` starts treating that cell as if a
  Diverter block had been placed there. Since it's contact-based like the
  Mud Levee, it reuses the same "only increments on `_try_enter()`" hook —
  no new counter machinery needed, just a second dictionary
  (`growing_dams`, alongside `active_geysers`) and one more branch in the
  cell-behavior lookup.

## Open questions / not decided yet

- Should a broken breakable-diverter/splitter leave a visual "wreckage"
  terrain behind, or revert to a totally plain empty cell?
- Does breaking play a sound/screen-shake cue, given the game's beat-locked
  tick timing?
- Should the player get any advance warning of a *contact-based* tile's
  remaining life (a visible countdown), or is watching the crack stages the
  only signal, matching how Town's danger is meant to be felt rather than
  shown?
- Chain Levee's neighbor-linking radius/rule isn't specified yet (is it every
  adjacent breakable tile, or only ones explicitly placed as part of the same
  "row"?).
