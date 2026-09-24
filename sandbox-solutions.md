# Sandbox level solutions

One verified solution per sandbox level (`game/data/sandbox/`). These levels
are not on the Level Select map yet: the owner decides where each mechanic
first appears in the campaign. Open one with the launcher:

```bash
cd game
LEVEL=tunnel_1 godot --path . --resolution 720x1280 res://tests/PlayLevel.tscn
```

Each line uses the same format as `level-solutions.md`, with the level's
file name in place of its number. `tests/VerifyTunnels.tscn` replays each
line. It checks that the bare run does not win, that the solution wins in
exactly the stated number of measures, and that water passes through the
tunnel on the way. The note under each line lists the other winning
placements, found by trying every placement the inventory allows.

- **tunnel_1** — divert-left (2, -3) | win 10
  - Teaches the tile. The town fills the board's waist, so the only way
    past it is underground. One Diverter steers the stream into the mouth,
    and it comes up two cells lower beside the lake,
    at (-1, 2): off the middle of the lake's top edge, where its animal
    stands, so the spring's glyph and arrow stay clear of it. A Diverter-Left at
    (1, -1) also wins in 10. Bare run: the stream reaches the town, a loss
    at measure 4. The route's one stepping stone sits on the edge between
    the town and (-1, 1), so (-1, 1) is open ground rather than carved
    out (a stone over a carved cell floats on the backdrop grass); no
    stream can reach it, and opening it changed no winner.
- **tunnel_2** — divert-left (3, -3) | win 16
  - Teaches that the delay matters. On the bare run the right-hand stream
    puts the fire out at once, then runs off the board one beat before the
    left-hand lake fills (a loss at 10). The tunnel runs from the bottom of
    the board back up to the top right: six beats underground, five
    stepping stones. Sending the
    stream into it keeps that water off the board long enough, and when it
    comes back down it lands on the fire. A Diverter-Left at (1, 1) also
    wins, in 10: the fire still goes out early, but the leftover water
    after it goes underground and loops instead of running off. No
    surface-only placement or pair wins.
- **tunnel_3** — divert-right (-2, 0) + wall (-1, 2) | win 12
  - Teaches the tunnel with a Wall and a Diverter. The exit comes up in a
    walled cellar where the spring's first fall, down-left, leads into a
    town. A Diverter-Right puts the stream into the mouth. The Wall, two
    tiles wide, closes the spring's down-left cell (its right-hand half
    sits there; anchoring it one cell further right mirrors it onto the
    same two cells), so the spring falls right into the lake. A
    Diverter-Right at (-1, -2) also wins in 12. Neither block wins alone.
    Bare run: the stream runs off the bottom, a loss at 9. (-1, 1), under
    the route's first stepping stone, is open ground for the same reason
    as tunnel_1's; opening it changed no winner.
