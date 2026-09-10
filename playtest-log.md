# Flash Flood — Playtest Log

One entry per level, pre-filled with what is already known about it so your
impressions land next to the facts.

## How to use this

Launch with `./play.sh`. Every level is already unlocked (`debug_unlock_all`
defaults to `OS.is_debug_build()`, true for any non-exported run), so you can
jump straight to any node on the map.

**Play in save Slot 2 or Slot 3.** Most test scenes set `current_slot = 0` and
complete levels, so anything run from `CLAUDE.md`'s verification list wipes
Slot 1 out from under you.

Fill in what you have an opinion about and leave the rest. The fields:

- **verdict** — `ok` / `tweak` / `rework` / `broken`. The only one worth
  filling on every level; the rest is optional colour.
- **difficulty** — 1–5 as *you* found it, not as designed.
- **measures** — what the win popup reports.
- **notes** — confusion, dead time, a shape that reads wrong, a moment that
  landed.

Add a second row rather than overwriting a verdict if you replay a level after
a change — the old row is the record of whether the change helped.

### What this pass can and cannot tell you

Desktop Linux, llvmpipe software rendering, a mouse. Enough to judge
**difficulty, pacing, teaching and clarity** — which is what this log is for.

It says nothing about touch or frame rate. The findings that need a thumb (the
sub-48dp cells flagged below, the catapult's press-and-hold) will not
reproduce here whatever you feel, so don't record a verdict on those from this
pass.

### Legend

- ⛔ **unwinnable** — do not spend time; the level is broken, not you.
- ⚠️ **solution broken** — the entry in `level-solutions.md` no longer wins,
  so don't trust it when stuck. 11 levels, all wall placements invalidated by
  the 2-wide Wall.
- ⏱ **par N** — a fork level. Finishing within N measures opens its map spur.
  Nothing in the game tells the player this (finding 36), so treat "did I
  even know I was being timed?" as a real observation here.
- 📏 — the hex's narrow cross-section in dp, measured at 720×1280. Under 48 is
  below the touch-target minimum this project holds every other control to.
  62 levels are. Irrelevant with a mouse; it is here so you know which levels
  to distrust once there is a device.

⚠️ **The "fastest known" figures are stale on the 11 broken levels** — they
were measured when the Wall was 1 tile wide. Marked inline where that applies.

---


## Riverbed Basics (levels 1–12)

### 1. Drift Correction  —  ⚠️ solution broken · 📏 36dp

`pointy r4 · 1 fire · pool (-1,0)x4 · source (0,-4)`

- kit: divert_right x2; divert_left x1; wall x1
- intro says: *Water zigzags naturally as it falls, and drifts to the left over time. Use your blocks to guide it past the fire and into the pool before it drifts off the edge.*
- fastest known: **8 measures** (9.6 s)  — *stale, measured before the Wall widened*
- documented solution: `Wall (-1,-3)` | win 8  ⚠️ **no longer wins**

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 2. Pure Zigzag  —  📏 36dp

`pointy r4 · 1 fire · pool (-3,4)x4 · source (0,-4)`

- kit: wall x1
- intro says: *Just watch the zigzag carry the stream through the fire -- then catch it: the pool sits off the natural path, and one block placed near the end steers the water home.*
- fastest known: **12 measures** (14.4 s)
- documented solution: `wall (-4, 1)` | win 12

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 3. New Corridor  —  📏 36dp

`pointy r4 · 1 fire · pool (-2,1)x4 · source (0,-4)`

- kit: divert_right x1
- intro says: *Same idea as before, a new path to correct. Redirect the water so it reaches the fire and pool instead of drifting off the edge.*
- fastest known: **9 measures** (10.8 s)
- documented solution: `Diverter-Right (-1,-2)` | win 9

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 4. Off-Center Flow  —  📏 36dp

`pointy r4 · 1 fire · pool (-2,4)x4 · source (1,-4)`

- kit: divert_right x1
- intro says: *The source has moved off-center. The zigzag still finds the fire on its own -- but you'll need one block near the bottom to guide the stream into the pool.*
- fastest known: **12 measures** (14.4 s)
- documented solution: `divert-right (-2, 2)` | win 12

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 5. Forced Redirect  —  📏 36dp

`pointy r4 · 1 fire · pool (-3,0)x4 · source (0,-4)`

- kit: wall x1
- intro says: *A Wall doesn't let water pass through -- it bounces off onto the other diagonal instead. Use it to force the stream onto a new path toward the fire and pool.*
- fastest known: **8 measures** (9.6 s)
- documented solution: `Wall (-1,-2)` | win 8

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 6. Hole in the Grid  —  ⚠️ solution broken · 📏 36dp

`pointy r4 · 1 fire · pool (-3,4)x4 · source (0,-4)`

- kit: wall x1
- intro says: *A hole in the grid bounces the water like a Wall would. Add a Wall of your own to finish the route to the fire and pool.*
- fastest known: **12 measures** (14.4 s)  — *stale, measured before the Wall widened*
- documented solution: `wall (-1, -3)` | win 12  ⚠️ **no longer wins**

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 7. Splitter Branch  —  📏 36dp

`pointy r4 · 1 fire · pool (-3,1)x4 · 1 hydro plant · source (0,-4)`

- kit: splitter x1
- intro says: *A Splitter sends water down both directions at once. Place it well and one placement can reach both the fire and the pool.*
- fastest known: **8 measures** (9.6 s)
- documented solution: `Splitter (-1,-2)` | win 8

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 8. Double Flames  —  ⏱ par 17 · 📏 36dp

`pointy r4 · 2 fires · pool (-4,4)x4 · source (0,-4)`

- kit: wall x1
- intro says: *Two fires and a pool, none of them on the natural path. One early Wall bounces the stream onto a route that finds all three.*
- fastest known: **13 measures** (15.6 s)
- documented solution: `wall (-1, -2)` | win 13

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 9. Twin Sources  —  📏 36dp

`pointy r4 · 2 fires · pool (-3,4)x4; (-4,4)x4 · source (0,-4); (2,-4)`

- kit: divert_left x1
- intro says: *Two independent streams, two fires, two pools. The fires are free -- the pools take one well-placed diverter.*
- fastest known: **12 measures** (14.4 s)
- documented solution: `divert-left (-1, 1)` | win 12

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 10. Twin Flames  —  ⚠️ solution broken · 📏 36dp

`pointy r4 · 2 fires · pool (-2,2)x4 · source (0,-4)`

- kit: wall x1; divert_right x1
- intro says: *Blocks can't be placed on the water source itself -- but a well-placed Wall on the stream's first landing bounces it onto a stable path through both fires and into the pool.*
- fastest known: **11 measures** (13.2 s)  — *stale, measured before the Wall widened*
- documented solution: `Wall (-1,-3)` | win 11  ⚠️ **no longer wins**

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 11. Grand Convergence  —  ⚠️ solution broken · 📏 36dp

`pointy r4 · 4 fires · pool (-2,2)x4; (-1,1)x4; (0,1)x4 · source (0,-4); (2,-4)`

- kit: wall x1; splitter x1; divert_right x1
- intro says: *Two sources, several fires and pools. Bounce one stream onto a stable path and branch the other to cover everything -- combine what you've learned.*
- fastest known: **11 measures** (13.2 s)  — *stale, measured before the Wall widened*
- documented solution: `Wall (-1,-3) + Splitter (1,-2)` | win 11  ⚠️ **no longer wins**

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 12. Town Alert  —  📏 36dp

`pointy r4 · 1 fire · pool (-1,0)x4 · 4 towns · source (0,-4)`

- kit: wall x1; divert_right x1
- intro says: *A town sits on the water's natural path -- reaching it ends the level immediately. Bounce the stream onto a new path before it gets there, then let the corrected flow reach the fire and pool.*
- fastest known: **8 measures** (9.6 s)
- documented solution: `divert-right (-1, -2)` | win 8

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |


## Long Corridors (levels 13–17)

### 13. Long Corridor

`pointy r8 · 3 fires · pool (-5,8)x4 · 1 hydro plant · source (4,-8)`

- kit: wall x1
- intro says: *A long corridor -- drag or scroll to see all of it. One Wall partway down bends the stream through every fire and into the pool.*
- fastest known: **22 measures** (26.4 s)
- documented solution: `wall (3, -6)` | win 22

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 14. Corridor Wall

`pointy r9 · 2 fires · pool (-4,7)x4 · source (5,-9)`

- kit: wall x1
- intro says: *A tall scrolling corridor with one Wall to place. Use it to shift the water's path partway down toward the fires and pool below.*
- fastest known: **21 measures** (25.2 s)
- documented solution: `Wall (1,-1)` | win 21

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 15. Corridor Split

`pointy r10 · 3 fires · pool (-4,6)x4; (-3,6)x4 · source (5,-10)`

- kit: splitter x1
- intro says: *A scrolling corridor that needs to serve two parallel destinations. One well-placed Splitter branches the single stream to cover both.*
- fastest known: **21 measures** (25.2 s)
- documented solution: `Splitter (1,-3)` | win 21

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 16. Town Detour

`pointy r10 · 2 fires · pool (-3,8)x4 · 4 towns · source (5,-10)`

- kit: divert_right x1
- intro says: *A town blocks part of this long corridor -- redirect the water permanently onto a path that avoids it for good, then let it reach the fires and pool further down.*
- fastest known: **23 measures** (27.6 s)
- documented solution: `Diverter-Right (1,-2)` | win 23

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 17. Everything at Once

`pointy r12 · 4 fires · pool (-5,11)x4; (-4,11)x4 · 4 towns · source (6,-12)`

- kit: divert_right x1; splitter x1; wall x1
- intro says: *The hardest corridor yet -- a Wall, a town to steer around, and a Splitter, all down one long scrolling path. Combine everything you've learned.*
- fastest known: **29 measures** (34.8 s)
- documented solution: `wall (2, -7) + divert-right (1, 0) + splitter (-2, 7)` | win 29

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |


## Special Waters (levels 18–20)

### 18. Geyser Awakens  —  ⏱ par 23 · 📏 25dp

`pointy r6 · 1 fire · pool (-2,-2)x4; (-6,6)x4 · 1 geyser · 1 hydro plant · source (0,-6)`

- kit: wall x1
- intro says: *A dormant Geyser wakes after a few beats of water contact and becomes a second source. Place your Wall well -- every pool must fill, on both streams.*
- fastest known: **18 measures** (21.6 s)
- documented solution: `wall (-1, -2)` | win 18

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 19. Jamboree

`pointy r10 · 2 fires · pool (-6,10)x4 · 4 towns · source (5,-10)`

- kit: **jamboree — 3 placements, any block type.** The whole catalog is offered including the Bomb Catapult; no dirt on this board, so a catapult can only act as a 1-cell solid.
- intro says: *A Jamboree level: instead of a fixed set of blocks, you get 3 total placements to spend on any block type, in any combination. Use them to steer the water around the town and down to the fires and pool.*
- fastest known: **25 measures** (30.0 s)
- documented solution: `Diverter-Left (-1,1)` | win 25

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 20. Straight & Zigzag  —  📏 40dp

`flat r4 · 2 fires · pool (3,0)x4; (0,4)x4 · source (0,-4); (2,-4)`

- kit: divert_right x1
- intro says: *The rotated flat grid: one stream falls straight down, the other zigzags. One diverter catches what the zigzag keeps missing.*
- fastest known: **13 measures** (15.6 s)
- documented solution: `divert-right (2, 0)` | win 13

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |


## Dig the River (levels 21–22)

### 21. Dig the River  —  📏 36dp

`pointy r4 · 1 fire · pool (-1,4)x4 · 41 dirt cells · source (0,-4)`

- kit: *nothing to place*
- intro says: *The land below is packed dirt -- water can't flow through it, so the river backs up and waits. Tap a dirt hex 3 times to dig it open, and carve a channel that leads the river all the way down to the pool. But don't dawdle: water pressing on dirt too long triggers a mudslide -- 3 tiles collapse and the river carves its own path. And a channel dug to the bottom edge spills the river off the board!*
- fastest known: **12 measures** (14.4 s)
- documented solution: `dig (-1,-1),(-1,0),(-1,2),(-1,3)` | win 12

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 22. The Great Cascade  —  ⚠️ prose solution only

`pointy r50 · corridor ±2 · 0 fires · 11 pools ×4 each · 474 dirt cells · source (25,-50)`

- kit: *nothing to place*
- already on the board: 10 splitters, fixed in place
- intro says: *A hundred rows of packed dirt, ten splitters fixed in the riverbed, and eleven pools waiting to be filled. Dig the main channel down through every splitter, and branch a side channel off each one to its pool -- the splitters feed both sides at once. Careful near the bottom: only the last pool should touch the bottom row. And do not leave the river waiting -- water pressing on dirt too long triggers a mudslide, collapsing 3 tiles and carving a path you did not choose.*
- fastest known: **103 measures** (123.6 s)
- documented solution: prose only — *dig the 108-cell channel+spurs*

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |


## Diverter Drills (levels 23–30)

### 23. Diverter Drills I  —  📏 36dp

`pointy r4 · 1 fire · pool (-3,4)x4 · source (0,-4)`

- kit: divert_right x1
- intro says: *Steer the stream with diverters -- redirect it through every fire and into the pool.*
- fastest known: **12 measures** (14.4 s)
- documented solution: `divert-right (-2, 0)` | win 12

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 24. Diverter Drills II  —  📏 36dp

`pointy r4 · 2 fires · pool (-4,4)x4 · source (0,-4)`

- kit: divert_left x1
- intro says: *Steer the stream with diverters -- redirect it through every fire and into the pool.*
- fastest known: **13 measures** (15.6 s)
- documented solution: `divert-left (-1, -3)` | win 13

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 25. Diverter Drills III  —  📏 36dp

`pointy r4 · 1 fire · pool (-4,4)x4 · 1 hydro plant · source (0,-4)`

- kit: divert_left x1
- intro says: *Steer the stream with diverters -- redirect it through every fire and into the pool.*
- fastest known: **12 measures** (14.4 s)
- documented solution: `divert-left (-2, -1)` | win 12

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 26. Diverter Drills IV  —  📏 36dp

`pointy r4 · 2 fires · pool (-2,4)x4 · source (1,-4)`

- kit: divert_right x1
- intro says: *Steer the stream with diverters -- redirect it through every fire and into the pool.*
- fastest known: **13 measures** (15.6 s)
- documented solution: `divert-right (0, -2)` | win 13

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 27. Diverter Drills V  —  📏 36dp

`pointy r4 · 1 fire · pool (-4,4)x4 · source (1,-4)`

- kit: divert_right x1; divert_left x1
- intro says: *Steer the stream with diverters -- redirect it through every fire and into the pool.*
- fastest known: **12 measures** (14.4 s)
- documented solution: `divert-right (0, -2) + divert-left (0, -3)` | win 12

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 28. Diverter Drills VI  —  ⏱ par 17 · 📏 36dp

`pointy r4 · 2 fires · pool (-4,4)x4 · source (0,-4)`

- kit: divert_left x2
- intro says: *Steer the stream with diverters -- redirect it through every fire and into the pool.*
- fastest known: **13 measures** (15.6 s)
- documented solution: `divert-left (-3, 2) + divert-left (-2, -1)` | win 13

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 29. Diverter Drills VII  —  📏 36dp

`pointy r4 · 1 fire · pool (-3,4)x4 · source (0,-4)`

- kit: divert_left x1; divert_right x1
- intro says: *Steer the stream with diverters -- redirect it through every fire and into the pool.*
- fastest known: **12 measures** (14.4 s)
- documented solution: `divert-left (-4, 4) + divert-right (-1, -2)` | win 12

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 30. Diverter Drills VIII  —  📏 36dp

`pointy r4 · 2 fires · pool (-2,4)x4 · source (1,-4)`

- kit: divert_right x2
- intro says: *Steer the stream with diverters -- redirect it through every fire and into the pool.*
- fastest known: **13 measures** (15.6 s)
- documented solution: `divert-right (-1, -1) + divert-right (-1, 0)` | win 13

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |


## Wall Work (levels 31–38)

### 31. Wall Work I  —  📏 36dp

`pointy r4 · 1 fire · pool (-4,4)x4 · source (1,-4)`

- kit: wall x1
- intro says: *A Wall bounces water onto its other diagonal. Use the bounce to reach what the drift would miss.*
- fastest known: **12 measures** (14.4 s)
- documented solution: `wall (-2, 2)` | win 12

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 32. Wall Work II  —  📏 36dp

`pointy r4 · 2 fires · pool (-2,4)x4 · source (1,-4)`

- kit: wall x1
- intro says: *A Wall bounces water onto its other diagonal. Use the bounce to reach what the drift would miss.*
- fastest known: **13 measures** (15.6 s)
- documented solution: `wall (-3, 1)` | win 13

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 33. Wall Work III  —  📏 36dp

`pointy r4 · 1 fire · pool (-2,4)x4 · 1 hydro plant · source (1,-4)`

- kit: wall x1
- intro says: *A Wall bounces water onto its other diagonal. Use the bounce to reach what the drift would miss.*
- fastest known: **12 measures** (14.4 s)
- documented solution: `wall (-4, 3)` | win 12

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 34. Wall Work IV  —  📏 36dp

`pointy r4 · 2 fires · pool (-4,4)x4 · source (0,-4)`

- kit: wall x1
- intro says: *A Wall bounces water onto its other diagonal. Use the bounce to reach what the drift would miss.*
- fastest known: **13 measures** (15.6 s)
- documented solution: `wall (-1, -2)` | win 13

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 35. Wall Work V  —  📏 36dp

`pointy r4 · 1 fire · pool (-3,4)x4 · source (1,-4)`

- kit: divert_right x1; wall x1
- intro says: *A Wall bounces water onto its other diagonal. Use the bounce to reach what the drift would miss.*
- fastest known: **12 measures** (14.4 s)
- documented solution: `divert-right (-1, 0) + wall (-1, 2)` | win 12

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 36. Wall Work VI  —  📏 36dp

`pointy r4 · 2 fires · pool (-4,4)x4 · source (1,-4)`

- kit: divert_left x2
- intro says: *A Wall bounces water onto its other diagonal. Use the bounce to reach what the drift would miss.*
- fastest known: **13 measures** (15.6 s)
- documented solution: `divert-left (0, -3) + divert-left (-3, 1)` | win 13

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 37. Wall Work VII  —  📏 36dp

`pointy r4 · 1 fire · pool (-4,4)x4 · source (1,-4)`

- kit: divert_left x1; wall x1
- intro says: *A Wall bounces water onto its other diagonal. Use the bounce to reach what the drift would miss.*
- fastest known: **12 measures** (14.4 s)
- documented solution: `divert-left (-3, 3) + wall (0, -2)` | win 12

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 38. Wall Work VIII  —  ⏱ par 17 · 📏 36dp

`pointy r4 · 2 fires · pool (-4,4)x4 · source (0,-4)`

- kit: wall x1; divert_left x1
- intro says: *A Wall bounces water onto its other diagonal. Use the bounce to reach what the drift would miss.*
- fastest known: **13 measures** (15.6 s)
- documented solution: `wall (-2, -1) + divert-left (-3, 3)` | win 13

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |


## Split Networks (levels 39–46)

### 39. Split Networks I  —  📏 36dp

`pointy r4 · 1 fire · pool (-3,4)x4; (-4,4)x4 · source (0,-4)`

- kit: splitter x1
- intro says: *One stream isn't enough here. Split it and serve every pool at once.*
- fastest known: **12 measures** (14.4 s)
- documented solution: `splitter (-2, 0)` | win 12

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 40. Split Networks II  —  📏 36dp

`pointy r4 · 2 fires · pool (-3,4)x4; (-4,4)x4 · source (1,-4)`

- kit: splitter x1
- intro says: *One stream isn't enough here. Split it and serve every pool at once.*
- fastest known: **13 measures** (15.6 s)
- documented solution: `splitter (-3, 3)` | win 13

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 41. Split Networks III  —  📏 36dp

`pointy r4 · 3 fires · pool (-3,4)x4; (-4,4)x4 · source (1,-4)`

- kit: splitter x1
- intro says: *One stream isn't enough here. Split it and serve every pool at once.*
- fastest known: **13 measures** (15.6 s)
- documented solution: `splitter (-1, -1)` | win 13

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 42. Split Networks IV  —  📏 36dp

`pointy r4 · 1 fire · pool (-3,4)x4; (-4,4)x4 · source (0,-4)`

- kit: splitter x1
- intro says: *One stream isn't enough here. Split it and serve every pool at once.*
- fastest known: **12 measures** (14.4 s)
- documented solution: `splitter (-2, 0)` | win 12

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 43. Split Networks V  —  📏 36dp

`pointy r4 · 2 fires · pool (-4,4)x4 · source (0,-4)`

- kit: divert_left x2
- intro says: *One stream isn't enough here. Split it and serve every pool at once.*
- fastest known: **13 measures** (15.6 s)
- documented solution: `divert-left (-2, 0) + divert-left (-3, 1)` | win 13

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 44. Split Networks VI  —  📏 36dp

`pointy r4 · 3 fires · pool (-3,4)x4; (-4,4)x4 · source (1,-4)`

- kit: splitter x1; divert_left x1
- intro says: *One stream isn't enough here. Split it and serve every pool at once.*
- fastest known: **14 measures** (16.8 s)
- documented solution: `splitter (-2, 1) + divert-left (-2, 2)` | win 14

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 45. Split Networks VII  —  📏 36dp

`pointy r4 · 1 fire · pool (-3,4)x4; (-2,3)x4 · source (1,-4)`

- kit: splitter x1; divert_left x1
- intro says: *One stream isn't enough here. Split it and serve every pool at once.*
- fastest known: **12 measures** (14.4 s)
- documented solution: `splitter (-1, 0) + divert-left (-2, 4)` | win 12

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 46. Split Networks VIII  —  📏 36dp

`pointy r4 · 2 fires · pool (-3,4)x4 · source (0,-4)`

- kit: divert_right x2
- intro says: *One stream isn't enough here. Split it and serve every pool at once.*
- fastest known: **13 measures** (15.6 s)
- documented solution: `divert-right (-4, 3) + divert-right (-1, -2)` | win 13

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |


## Town Defense (levels 47–54)

### 47. Town Defense I  —  📏 36dp

`pointy r4 · 1 fire · pool (-4,4)x4 · 4 towns · source (0,-4)`

- kit: divert_left x1
- intro says: *A town sits in harm's way -- reroute the water before it gets there, then finish the job.*
- fastest known: **12 measures** (14.4 s)
- documented solution: `divert-left (-3, 1)` | win 12

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 48. Town Defense II  —  ⏱ par 17 · 📏 36dp

`pointy r4 · 2 fires · pool (-4,4)x4 · 4 towns · source (0,-4)`

- kit: divert_left x1
- intro says: *A town sits in harm's way -- reroute the water before it gets there, then finish the job.*
- fastest known: **13 measures** (15.6 s)
- documented solution: `divert-left (-1, -3)` | win 13

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 49. Town Defense III  —  📏 36dp

`pointy r4 · 1 fire · pool (-4,4)x4 · 4 towns · source (0,-4)`

- kit: divert_left x1
- intro says: *A town sits in harm's way -- reroute the water before it gets there, then finish the job.*
- fastest known: **12 measures** (14.4 s)
- documented solution: `divert-left (-1, -3)` | win 12

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 50. Town Defense IV  —  📏 36dp

`pointy r4 · 2 fires · pool (-4,4)x4 · 4 towns · source (0,-4)`

- kit: divert_left x1
- intro says: *A town sits in harm's way -- reroute the water before it gets there, then finish the job.*
- fastest known: **13 measures** (15.6 s)
- documented solution: `divert-left (-3, 1)` | win 13

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 51. Town Defense V  —  📏 36dp

`pointy r4 · 1 fire · pool (-4,4)x4 · 4 towns · source (1,-4)`

- kit: divert_left x2
- intro says: *A town sits in harm's way -- reroute the water before it gets there, then finish the job.*
- fastest known: **12 measures** (14.4 s)
- documented solution: `divert-left (-1, -1) + divert-left (0, -2)` | win 12

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 52. Town Defense VI  —  📏 36dp

`pointy r4 · 2 fires · pool (-4,4)x4 · 4 towns · 1 hydro plant · source (0,-4)`

- kit: divert_right x1; wall x1
- intro says: *A town sits in harm's way -- reroute the water before it gets there, then finish the job.*
- fastest known: **13 measures** (15.6 s)
- documented solution: `divert-right (-3, 1) + wall (-2, 0)` | win 13

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 53. Town Defense VII  —  📏 36dp

`pointy r4 · 1 fire · pool (-4,4)x4 · 4 towns · source (0,-4)`

- kit: divert_right x1; wall x1
- intro says: *A town sits in harm's way -- reroute the water before it gets there, then finish the job.*
- fastest known: **12 measures** (14.4 s)
- documented solution: `divert-right (-1, -2) + wall (-2, 2)` | win 12

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 54. Town Defense VIII  —  📏 36dp

`pointy r4 · 2 fires · pool (-3,4)x4 · 4 towns · source (1,-4)`

- kit: wall x2
- intro says: *A town sits in harm's way -- reroute the water before it gets there, then finish the job.*
- fastest known: **13 measures** (15.6 s)
- documented solution: `wall (-1, -3) + wall (0, 0)` | win 13

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |


## Flat Fields (levels 55–62)

### 55. Flat Fields I  —  📏 40dp

`flat r4 · 1 fire · pool (-2,4)x4 · source (-1,-4)`

- kit: divert_left x1
- intro says: *The rotated flat grid: water can run straight down. Redirect it where straight isn't good enough.*
- fastest known: **12 measures** (14.4 s)
- documented solution: `divert-left (-1, 0)` | win 12

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 56. Flat Fields II  —  📏 40dp

`flat r4 · 2 fires · pool (0,4)x4 · source (-1,-4)`

- kit: wall x1
- intro says: *The rotated flat grid: water can run straight down. Redirect it where straight isn't good enough.*
- fastest known: **22 measures** (26.4 s)
- documented solution: `wall (0, -3)` | win 22

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 57. Flat Fields III  —  📏 40dp

`flat r4 · 1 fire · pool (0,4)x4 · source (1,-4)`

- kit: wall x1
- intro says: *The rotated flat grid: water can run straight down. Redirect it where straight isn't good enough.*
- fastest known: **19 measures** (22.8 s)
- documented solution: `wall (1, -3)` | win 19

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 58. Flat Fields IV  —  ⏱ par 17 · 📏 40dp

`flat r4 · 2 fires · pool (0,4)x4 · source (1,-4)`

- kit: divert_left x1
- intro says: *The rotated flat grid: water can run straight down. Redirect it where straight isn't good enough.*
- fastest known: **13 measures** (15.6 s)
- documented solution: `divert-left (1, -2)` | win 13

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 59. Flat Fields V  —  📏 40dp

`flat r4 · 1 fire · pool (0,4)x4 · source (-1,-4); (2,-4)`

- kit: wall x1
- intro says: *The rotated flat grid: water can run straight down. Redirect it where straight isn't good enough.*
- fastest known: **17 measures** (20.4 s)
- documented solution: `wall (-1, 3)` | win 17

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 60. Flat Fields VI  —  📏 40dp

`flat r4 · 2 fires · pool (0,4)x4 · source (-1,-4); (2,-4)`

- kit: divert_left x1; wall x1
- intro says: *The rotated flat grid: water can run straight down. Redirect it where straight isn't good enough.*
- fastest known: **18 measures** (21.6 s)
- documented solution: `divert-left (-1, 3) + wall (-1, 0)` | win 18

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 61. Flat Fields VII  —  📏 40dp

`flat r4 · 1 fire · pool (0,4)x4 · source (-1,-4); (2,-4)`

- kit: divert_right x1; wall x1
- intro says: *The rotated flat grid: water can run straight down. Redirect it where straight isn't good enough.*
- fastest known: **18 measures** (21.6 s)
- documented solution: `divert-right (1, -3) + wall (-1, -3)` | win 18

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 62. Flat Fields VIII  —  📏 40dp

`flat r4 · 2 fires · pool (2,0)x4; (-2,4)x4 · source (-1,-4); (2,-4)`

- kit: divert_right x1; divert_left x1
- intro says: *The rotated flat grid: water can run straight down. Redirect it where straight isn't good enough.*
- fastest known: **12 measures** (14.4 s)
- documented solution: `divert-right (1, 1) + divert-left (-1, -1)` | win 12

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |


## Geyser Country (levels 63–70)

### 63. Geyser Country I  —  📏 36dp

`pointy r4 · 1 fire · pool (-4,4)x4 · 1 geyser · 1 hydro plant · source (0,-4)`

- kit: divert_left x1
- intro says: *Wake the dormant geyser, then manage TWO streams at once.*
- fastest known: **14 measures** (16.8 s)
- documented solution: `divert-left (-1, -2)` | win 14

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 64. Geyser Country II  —  ⚠️ solution broken · 📏 36dp

`pointy r4 · 2 fires · pool (-4,4)x4; (-3,4)x4 · 1 geyser · source (0,-4)`

- kit: wall x1
- intro says: *Wake the dormant geyser, then manage TWO streams at once.*
- fastest known: **15 measures** (18.0 s)  — *stale, measured before the Wall widened*
- documented solution: `wall (-1, -3)` | win 15  ⚠️ **no longer wins**

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 65. Geyser Country III  —  📏 36dp

`pointy r4 · 1 fire · pool (-4,4)x4 · 1 geyser · source (1,-4)`

- kit: wall x1
- intro says: *Wake the dormant geyser, then manage TWO streams at once.*
- fastest known: **14 measures** (16.8 s)
- documented solution: `wall (0, -2)` | win 14

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 66. Geyser Country IV  —  ⚠️ solution broken · 📏 36dp

`pointy r4 · 2 fires · pool (-4,4)x4; (-3,4)x4 · 1 geyser · source (0,-4)`

- kit: wall x1
- intro says: *Wake the dormant geyser, then manage TWO streams at once.*
- fastest known: **15 measures** (18.0 s)  — *stale, measured before the Wall widened*
- documented solution: `wall (-2, -1)` | win 15  ⚠️ **no longer wins**

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 67. Geyser Country V  —  ⚠️ solution broken

`pointy r6 · corridor ±2 · 1 fire · pool (-2,6)x4; (-5,6)x4 · 1 geyser · source (3,-6)`

- kit: wall x1
- intro says: *Wake the dormant geyser, then manage TWO streams at once.*
- fastest known: **18 measures** (21.6 s)  — *stale, measured before the Wall widened*
- documented solution: `wall (0, -1)` | win 18  ⚠️ **no longer wins**

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 68. Geyser Country VI  —  ⛔ **UNWINNABLE — skip it** · ⏱ par 24

`pointy r6 · corridor ±2 · 2 fires · pool (-3,6)x4 · 1 geyser · source (2,-6)`

- kit: wall x1
- intro says: *Wake the dormant geyser, then manage TWO streams at once.*
- fastest known: **19 measures** (22.8 s)  — *stale, measured before the Wall widened*
- documented solution: `wall (-1, -1)` | win 19  ⚠️ **no longer wins**

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 69. Geyser Country VII  —  ⚠️ solution broken

`pointy r6 · corridor ±2 · 1 fire · pool (-2,6)x4; (-5,6)x4 · 1 geyser · source (3,-6)`

- kit: wall x1
- intro says: *Wake the dormant geyser, then manage TWO streams at once.*
- fastest known: **19 measures** (22.8 s)  — *stale, measured before the Wall widened*
- documented solution: `wall (-3, 5)` | win 19  ⚠️ **no longer wins**

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 70. Geyser Country VIII

`pointy r6 · corridor ±2 · 2 fires · pool (-4,6)x4 · 1 geyser · source (3,-6)`

- kit: wall x1
- intro says: *Wake the dormant geyser, then manage TWO streams at once.*
- fastest known: **19 measures** (22.8 s)
- documented solution: `wall (-1, 2)` | win 19

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |


## Big Digs (levels 71–78)

### 71. Big Digs I  —  📏 36dp

`pointy r4 · 1 fire · pool (-3,4)x4 · 48 dirt cells · source (1,-4)`

- kit: *nothing to place*
- intro says: *Packed dirt everywhere. Tap to dig the river's channel -- and don't let it wait long enough to mudslide.*
- fastest known: **12 measures** (14.4 s)
- documented solution: `dig 5 cells: [(-1, -2), (-1, -1), (-1, 0), (-1, 2), (-2, 3)]` | win 12

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 72. Big Digs II  —  📏 36dp

`pointy r4 · 2 fires · pool (-2,4)x4 · 47 dirt cells · source (0,-4)`

- kit: *nothing to place*
- intro says: *Packed dirt everywhere. Tap to dig the river's channel -- and don't let it wait long enough to mudslide.*
- fastest known: **13 measures** (15.6 s)
- documented solution: `dig 4 cells: [(-1, -2), (-1, -1), (-1, 0), (-2, 2)]` | win 13

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 73. Big Digs III  —  📏 36dp

`pointy r4 · 1 fire · pool (-3,4)x4 · 48 dirt cells · source (1,-4)`

- kit: *nothing to place*
- intro says: *Packed dirt everywhere. Tap to dig the river's channel -- and don't let it wait long enough to mudslide.*
- fastest known: **12 measures** (14.4 s)
- documented solution: `dig 5 cells: [(0, -2), (-1, -1), (-1, 0), (-1, 1), (-2, 2)]` | win 12

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 74. Big Digs IV

`pointy r6 · corridor ±2 · 1 fire · pool (-3,6)x4 · 53 dirt cells · source (3,-6)`

- kit: *nothing to place*
- intro says: *Packed dirt everywhere. Tap to dig the river's channel -- and don't let it wait long enough to mudslide.*
- fastest known: **16 measures** (19.2 s)
- documented solution: `dig 9 cells: [(2, -4), (1, -3), (0, -2), (-1, -1), (-2, 1), (-2, 2), (-3, 3), (-3, 4), (-3, 5)]` | win 16

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 75. Big Digs V

`pointy r8 · corridor ±2 · 2 fires · pool (-3,8)x4 · 72 dirt cells · source (4,-8)`

- kit: *nothing to place*
- intro says: *Packed dirt everywhere. Tap to dig the river's channel -- and don't let it wait long enough to mudslide.*
- fastest known: **21 measures** (25.2 s)
- documented solution: `dig 12 cells: [(3, -6), (3, -5), (3, -4), (3, -3), (3, -2), (3, -1), (2, 0), (0, 2), (-1, 3), (-2, 4), (-2, 5), (-3, 6)]` | win 21

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 76. Big Digs VI

`pointy r10 · corridor ±2 · 3 fires · pool (-4,10)x4 · 91 dirt cells · source (5,-10)`

- kit: *nothing to place*
- intro says: *Packed dirt everywhere. Tap to dig the river's channel -- and don't let it wait long enough to mudslide.*
- fastest known: **26 measures** (31.2 s)
- documented solution: `dig 15 cells: [(3, -8), (3, -7), (3, -5), (3, -4), (2, -3), (1, -2), (1, -1), (1, 0), (1, 2), (-1, 4), (-1, 5), (-1, 6), (-2, 7), (-2, 8), (-3, 9)]` | win 26

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 77. Big Digs VII

`pointy r12 · corridor ±2 · 1 fire · pool (-8,12)x4 · 113 dirt cells · source (6,-12)`

- kit: *nothing to place*
- intro says: *Packed dirt everywhere. Tap to dig the river's channel -- and don't let it wait long enough to mudslide.*
- fastest known: **28 measures** (33.6 s)
- documented solution: `dig 21 cells: [(4, -10), (4, -9), (4, -8), (4, -7), (4, -6), (3, -5), (3, -4), (3, -3), (2, -2), (1, -1), (0, 0), (-1, 1), (-2, 2), (-3, 3), (-4, 4), (-4, 6), (-4, 7), (-4, 8), (-5, 9), (-6, 10), (-7, 11)]` | win 28

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 78. Big Digs VIII  —  ⏱ par 42

`pointy r14 · corridor ±2 · 2 fires · pool (-5,14)x4 · 132 dirt cells · source (7,-14)`

- kit: *nothing to place*
- intro says: *Packed dirt everywhere. Tap to dig the river's channel -- and don't let it wait long enough to mudslide.*
- fastest known: **33 measures** (39.6 s)
- documented solution: `dig 24 cells: [(6, -12), (6, -11), (5, -9), (4, -8), (4, -7), (4, -6), (3, -5), (3, -3), (3, -2), (2, -1), (1, 0), (0, 1), (0, 2), (-1, 3), (-1, 4), (-1, 5), (-2, 6), (-2, 7), (-2, 8), (-3, 9), (-3, 10), (-4, 11), (-4, 12), (-5, 13)]` | win 33

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |


## Jamboree Runs (levels 79–86)

### 79. Jamboree Runs I

`pointy r8 · corridor ±2 · 1 fire · pool (-2,8)x4; (-3,8)x4 · source (5,-8)`

- kit: **jamboree — 2 placements, any block type.** The whole catalog is offered including the Bomb Catapult; no dirt on this board, so a catapult can only act as a 1-cell solid.
- intro says: *A shared budget of placements, any block types you like. Spend them well.*
- fastest known: **20 measures** (24.0 s)
- documented solution: `splitter (0, 2)` | win 20

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 80. Jamboree Runs II

`pointy r9 · corridor ±2 · 2 fires · pool (-5,9)x4 · source (5,-9)`

- kit: **jamboree — 3 placements, any block type.** The whole catalog is offered including the Bomb Catapult; no dirt on this board, so a catapult can only act as a 1-cell solid.
- intro says: *A shared budget of placements, any block types you like. Spend them well.*
- fastest known: **23 measures** (27.6 s)
- documented solution: `divert-left (0, 1) + divert-left (-3, 6)` | win 23

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 81. Jamboree Runs III

`pointy r10 · corridor ±2 · 3 fires · pool (-4,10)x4 · source (5,-10)`

- kit: **jamboree — 2 placements, any block type.** The whole catalog is offered including the Bomb Catapult; no dirt on this board, so a catapult can only act as a 1-cell solid.
- intro says: *A shared budget of placements, any block types you like. Spend them well.*
- fastest known: **26 measures** (31.2 s)
- documented solution: `wall (-6, 9)` | win 26

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 82. Jamboree Runs IV

`pointy r8 · corridor ±2 · 1 fire · pool (-4,8)x4 · 1 hydro plant · source (3,-8)`

- kit: **jamboree — 3 placements, any block type.** The whole catalog is offered including the Bomb Catapult; no dirt on this board, so a catapult can only act as a 1-cell solid.
- intro says: *A shared budget of placements, any block types you like. Spend them well.*
- fastest known: **20 measures** (24.0 s)
- documented solution: `splitter (0, -2) + wall (-6, 8)` | win 20

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 83. Jamboree Runs V

`pointy r9 · corridor ±2 · 2 fires · pool (-4,9)x4 · source (4,-9)`

- kit: **jamboree — 2 placements, any block type.** The whole catalog is offered including the Bomb Catapult; no dirt on this board, so a catapult can only act as a 1-cell solid.
- intro says: *A shared budget of placements, any block types you like. Spend them well.*
- fastest known: **23 measures** (27.6 s)
- documented solution: `wall (-6, 8)` | win 23

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 84. Jamboree Runs VI

`pointy r10 · corridor ±2 · 3 fires · pool (-7,10)x4 · source (4,-10)`

- kit: **jamboree — 3 placements, any block type.** The whole catalog is offered including the Bomb Catapult; no dirt on this board, so a catapult can only act as a 1-cell solid.
- intro says: *A shared budget of placements, any block types you like. Spend them well.*
- fastest known: **26 measures** (31.2 s)
- documented solution: `divert-left (2, -7) + wall (-3, 4)` | win 26

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 85. Jamboree Runs VII

`pointy r8 · corridor ±2 · 1 fire · pool (-2,8)x4 · source (5,-8)`

- kit: **jamboree — 2 placements, any block type.** The whole catalog is offered including the Bomb Catapult; no dirt on this board, so a catapult can only act as a 1-cell solid.
- intro says: *A shared budget of placements, any block types you like. Spend them well.*
- fastest known: **20 measures** (24.0 s)
- documented solution: `wall (-2, 3)` | win 20

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 86. Jamboree Runs VIII

`pointy r9 · corridor ±2 · 2 fires · pool (-4,9)x4; (-6,9)x4 · source (4,-9)`

- kit: **jamboree — 3 placements, any block type.** The whole catalog is offered including the Bomb Catapult; no dirt on this board, so a catapult can only act as a 1-cell solid.
- intro says: *A shared budget of placements, any block types you like. Spend them well.*
- fastest known: **22 measures** (26.4 s)
- documented solution: `catapult (-4, 7) + splitter (2, -5)` | win 22

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |


## The Gauntlet (levels 87–100)

### 87. The Gauntlet I

`pointy r10 · corridor ±2 · 1 fire · pool (-3,10)x4; (-4,10)x4 · 10 dirt cells · source (5,-10)`

- kit: divert_right x1; divert_left x1
- already on the board: splitter (0,2)
- intro says: *Everything at once: fixed splitters, dirt to dig, hazards to dodge. The river won't wait.*
- fastest known: **24 measures** (28.8 s)
- documented solution: `divert-right (3, -6) + divert-left (2, -2) + dig 4 cells: [(-2, 6), (-1, 6), (-3, 7), (-2, 7)]` | win 24

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 88. The Gauntlet II  —  ⏱ par 34

`pointy r11 · corridor ±2 · 2 fires · pool (-6,11)x4; (-7,11)x4 · 4 towns · 10 dirt cells · source (6,-11)`

- kit: wall x1
- already on the board: splitter (0,-2)
- intro says: *Everything at once: fixed splitters, dirt to dig, hazards to dodge. The river won't wait.*
- fastest known: **27 measures** (32.4 s)
- documented solution: `wall (3, -5) + dig 2 cells: [(1, -4), (1, -3)]` | win 27

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 89. The Gauntlet III

`pointy r12 · corridor ±2 · 3 fires · pool (-6,12)x4; (-4,12)x4 · 1 geyser · 10 dirt cells · source (6,-12)`

- kit: divert_left x1
- already on the board: splitter (-4,7)
- intro says: *Everything at once: fixed splitters, dirt to dig, hazards to dodge. The river won't wait.*
- fastest known: **41 measures** (49.2 s)
- documented solution: `divert-left (-5, 9) + dig 2 cells: [(-2, 3), (-2, 4)]` | win 41

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 90. The Gauntlet IV

`pointy r13 · corridor ±2 · 1 fire · pool (-5,13)x4 · 4 towns · 10 dirt cells · source (7,-13)`

- kit: **jamboree — 2 placements, any block type.** The whole catalog is offered including the Bomb Catapult; 10 dirt cells, so a catapult shot can actually do something.
- already on the board: splitter (2,-1)
- intro says: *Everything at once: fixed splitters, dirt to dig, hazards to dodge. The river won't wait.*
- fastest known: **30 measures** (36.0 s)
- documented solution: `divert-right (2, -3) + dig 2 cells: [(-2, 6), (-2, 7)]` | win 30

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 91. The Gauntlet V

`pointy r14 · corridor ±2 · 2 fires · pool (-5,14)x4; (-6,14)x4 · 10 dirt cells · source (7,-14)`

- kit: divert_left x1; wall x1
- already on the board: splitter (-3,8)
- intro says: *Everything at once: fixed splitters, dirt to dig, hazards to dodge. The river won't wait.*
- fastest known: **33 measures** (39.6 s)
- documented solution: `divert-left (-3, 6) + wall (-3, 3) + dig 4 cells: [(-4, 10), (-3, 10), (-5, 11), (-4, 11)]` | win 33

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 92. The Gauntlet VI  —  ⚠️ solution broken

`pointy r15 · corridor ±2 · 3 fires · pool (-6,15)x4; (-8,15)x4 · 4 towns · 1 geyser · 10 dirt cells · source (8,-15)`

- kit: wall x1
- already on the board: splitter (6,-12); splitter (2,-4)
- intro says: *Everything at once: fixed splitters, dirt to dig, hazards to dodge. The river won't wait.*
- fastest known: **37 measures** (44.4 s)  — *stale, measured before the Wall widened*
- documented solution: `wall (0, 0) + dig 4 cells: [(3, -8), (4, -8), (3, -7), (4, -7)]` | win 37  ⚠️ **no longer wins**

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 93. The Gauntlet VII

`pointy r16 · corridor ±2 · 1 fire · pool (-6,16)x4; (-7,16)x4 · 10 dirt cells · source (8,-16)`

- kit: wall x1; divert_left x1
- already on the board: splitter (0,2); splitter (-3,9)
- intro says: *Everything at once: fixed splitters, dirt to dig, hazards to dodge. The river won't wait.*
- fastest known: **35 measures** (42.0 s)
- documented solution: `wall (-2, 1) + divert-left (-4, 10) + dig 4 cells: [(-5, 12), (-4, 12), (-6, 13), (-5, 13)]` | win 35

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 94. The Gauntlet VIII

`pointy r17 · corridor ±2 · 2 fires · pool (-8,17)x4; (-9,17)x4 · 4 towns · 20 dirt cells · source (9,-17)`

- kit: **jamboree — 3 placements, any block type.** The whole catalog is offered including the Bomb Catapult; 20 dirt cells, so a catapult shot can actually do something.
- already on the board: splitter (2,-4); splitter (0,-1)
- intro says: *Everything at once: fixed splitters, dirt to dig, hazards to dodge. The river won't wait.*
- fastest known: **38 measures** (45.6 s)
- documented solution: `wall (3, -6) + wall (4, -7) + dig 6 cells: [(7, -13), (6, -12), (-4, 7), (-3, 7), (-5, 8), (-4, 8)]` | win 38

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 95. The Gauntlet IX

`pointy r18 · corridor ±2 · 3 fires · pool (-10,18)x4 · 1 geyser · 20 dirt cells · source (9,-18)`

- kit: divert_left x1; divert_right x1
- already on the board: splitter (-1,1); splitter (5,-11)
- intro says: *Everything at once: fixed splitters, dirt to dig, hazards to dodge. The river won't wait.*
- fastest known: **41 measures** (49.2 s)
- documented solution: `divert-left (-7, 13) + divert-right (1, -3) + dig 6 cells: [(7, -14), (6, -13), (-3, 4), (-2, 4), (-4, 5), (-3, 5)]` | win 41

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 96. The Gauntlet X  —  ⚠️ solution broken

`pointy r19 · corridor ±2 · 1 fire · pool (-8,19)x4; (-9,19)x4 · 4 towns · 20 dirt cells · source (10,-19)`

- kit: wall x1; divert_right x1
- already on the board: splitter (-5,11); splitter (4,-7)
- intro says: *Everything at once: fixed splitters, dirt to dig, hazards to dodge. The river won't wait.*
- fastest known: **42 measures** (50.4 s)  — *stale, measured before the Wall widened*
- documented solution: `wall (-6, 13) + divert-right (-9, 17) + dig 8 cells: [(1, -2), (2, -2), (1, -1), (2, -1), (-4, 9), (-3, 9), (-5, 10), (-4, 10)]` | win 42  ⚠️ **no longer wins**

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 97. The Gauntlet XI

`pointy r20 · corridor ±2 · 2 fires · pool (-8,20)x4; (-9,20)x4; (-11,20)x4 · 20 dirt cells · source (10,-20)`

- kit: wall x1; divert_right x1
- already on the board: splitter (-5,12); splitter (3,-7); splitter (0,-3)
- intro says: *Everything at once: fixed splitters, dirt to dig, hazards to dodge. The river won't wait.*
- fastest known: **44 measures** (52.8 s)
- documented solution: `wall (-9, 13) + divert-right (3, -6) + dig 8 cells: [(6, -13), (6, -12), (-8, 14), (-6, 14), (-5, 14), (-9, 15), (-7, 15), (-6, 15)]` | win 44

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 98. The Gauntlet XII  —  ⏱ par 58

`pointy r20 · corridor ±2 · 3 fires · pool (-8,20)x4 · 4 towns · 1 geyser · 20 dirt cells · source (10,-20)`

- kit: **jamboree — 2 placements, any block type.** The whole catalog is offered including the Bomb Catapult; 20 dirt cells, so a catapult shot can actually do something.
- already on the board: splitter (-2,6); splitter (-3,10); splitter (4,-6)
- intro says: *Everything at once: fixed splitters, dirt to dig, hazards to dodge. The river won't wait.*
- fastest known: **46 measures** (55.2 s)
- documented solution: `wall (-12, 19) + dig 6 cells: [(5, -9), (5, -8), (0, 2), (1, 2), (-1, 3), (0, 3)]` | win 46

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 99. The Gauntlet XIII

`pointy r20 · corridor ±2 · 1 fire · pool (-8,20)x4; (-9,20)x4; (-10,20)x4 · 20 dirt cells · source (10,-20)`

- kit: wall x1; divert_right x1
- already on the board: splitter (4,-8); splitter (-3,8); splitter (5,-11)
- intro says: *Everything at once: fixed splitters, dirt to dig, hazards to dodge. The river won't wait.*
- fastest known: **44 measures** (52.8 s)
- documented solution: `wall (-4, 8) + divert-right (-9, 16) + dig 12 cells: [(-4, 5), (-3, 5), (-2, 5), (-4, 6), (-3, 6), (-2, 6), (-6, 9), (-4, 9), (-3, 9), (-6, 10), (-4, 10), (-3, 10)]` | win 44

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

### 100. The Gauntlet XIV

`pointy r20 · corridor ±2 · 2 fires · pool (-9,20)x4; (-10,20)x4 · 4 towns · 20 dirt cells · source (10,-20)`

- kit: divert_right x1
- already on the board: splitter (-3,7); splitter (7,-14); splitter (-4,8)
- intro says: *Everything at once: fixed splitters, dirt to dig, hazards to dodge. The river won't wait.*
- fastest known: **45 measures** (54.0 s)
- documented solution: `divert-right (-3, 6) + dig 8 cells: [(4, -9), (5, -9), (4, -8), (5, -8), (1, -2), (2, -2), (0, -1), (1, -1)]` | win 45

| verdict | difficulty | measures | notes |
|---|---|---|---|
|  |  |  |  |

---

## Cross-level notes

Things that are not about one level — a mechanic that never lands, a group
that drags, art that reads wrong everywhere. Add as you go.

-

## Levels to revisit

-
