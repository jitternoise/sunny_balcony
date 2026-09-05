# Flash Flood — Level Difficulty Summary

Two lines per level, generated from the level data, the verified solution
book and `tools/solution_space.gd`. Line 1 is what the level is made of;
line 2 is how hard it is, where *winning placements* is the number of
different placements that actually solve it — the lower that is, the more
the player is hunting one exact answer.

Eleven levels are omitted from the placement count (pure-dig or 3-block
solutions, which the counter skips); those show `n/a`.

---

**1. Drift Correction**  
Radius 4, 1 source, 1 fire, 1 pool. Tools: 2x divert-right, 1x divert-left, 1x wall.  
**BROKEN** — 0 winning placements; unsolvable as shipped. Its documented 8-measure solution no longer wins.  

**2. Pure Zigzag**  
Radius 4, 1 source, 1 fire, 1 pool. Tools: 1x wall.  
**Medium-hard** — 2 winning placements (TIGHT, the answer is nearly unique); wins in 12 measures.  

**3. New Corridor**  
Radius 4, 1 source, 1 fire, 1 pool. Tools: 1x divert-right.  
**Hard** — 1 winning placement (KNIFE, exactly one answer exists); wins in 9 measures.  

**4. Off-Center Flow**  
Radius 4, 1 source, 1 fire, 1 pool. Tools: 1x divert-right.  
**Medium-hard** — 2 winning placements (TIGHT, the answer is nearly unique); wins in 12 measures.  

**5. Forced Redirect**  
Radius 4, 1 source, 1 fire, 1 pool. Tools: 1x wall.  
**Hard** — 1 winning placement (KNIFE, exactly one answer exists); wins in 8 measures.  

**6. Hole in the Grid**  
Radius 4, 1 source, 1 fire, 1 pool. Tools: 1x wall.  
**BROKEN** — 0 winning placements; unsolvable as shipped. Its documented 12-measure solution no longer wins.  

**7. Splitter Branch**  
Radius 4, 1 source, 1 fire, 1 pool. Tools: 1x splitter.  
**Hard** — 1 winning placement (KNIFE, exactly one answer exists); wins in 8 measures.  

**8. Double Flames**  
Radius 4, 1 source, 2 fires, 1 pool. Tools: 1x wall.  
**Medium-hard** — 2 winning placements (TIGHT, the answer is nearly unique); wins in 13 measures.  

**9. Twin Sources**  
Radius 4, 2 sources, 2 fires, 2 pools. Tools: 1x divert-left.  
**Medium-hard** — 3 winning placements (TIGHT, the answer is nearly unique); wins in 12 measures.  

**10. Twin Flames**  
Radius 4, 1 source, 2 fires, 1 pool. Tools: 1x wall, 1x divert-right.  
**BROKEN** — 0 winning placements; unsolvable as shipped. Its documented 11-measure solution no longer wins.  

**11. Grand Convergence**  
Radius 4, 2 sources, 4 fires, 3 pools. Tools: 1x wall, 1x splitter, 1x divert-right.  
**BROKEN** — 0 winning placements; unsolvable as shipped. Its documented 11-measure solution no longer wins.  

**12. Town Alert**  
Radius 4, 1 source, 1 fire, 1 pool, 4-cell town. Tools: 1x wall, 1x divert-right.  
**Hard** — 1 winning placement (KNIFE, exactly one answer exists); wins in 8 measures.  

**13. Long Corridor**  
Radius 8, 1 source, 3 fires, 1 pool. Tools: 1x wall.  
**Medium-hard** — 3 winning placements (TIGHT, the answer is nearly unique); wins in 22 measures.  

**14. Corridor Wall**  
Radius 9, 1 source, 2 fires, 1 pool. Tools: 1x wall.  
**Medium-hard** — 3 winning placements (TIGHT, the answer is nearly unique); wins in 21 measures.  

**15. Corridor Split**  
Radius 10, 1 source, 3 fires, 2 pools. Tools: 1x splitter.  
**Medium** — 5 winning placements (OK, forgiving); wins in 21 measures.  

**16. Town Detour**  
Radius 10, 1 source, 2 fires, 1 pool, 4-cell town. Tools: 1x divert-right.  
**Medium-hard** — 2 winning placements (TIGHT, the answer is nearly unique); wins in 23 measures.  

**17. Everything at Once**  
Radius 12, 1 source, 4 fires, 2 pools, 4-cell town. Tools: 1x divert-right, 1x splitter, 1x wall.  
**n/a** — solution `wall (2, -7) + divert-right (1, 0) + splitter (-2, 7)`, wins in 29 measures. Placement breadth not measured.  

**18. Geyser Awakens**  
Radius 6, 1 source, 1 fire, 2 pools, 1 geyser. Tools: 1x wall.  
**Hard** — 1 winning placement (KNIFE, exactly one answer exists); wins in 18 measures.  

**19. Jamboree**  
Radius 10, 1 source, 2 fires, 1 pool, 4-cell town. Tools: Jamboree budget of 3, any block.  
**Medium** — 7 winning placements (OK, forgiving); wins in 25 measures.  

**20. Straight & Zigzag**  
Radius 4, 2 sources, 2 fires, 2 pools, flat grid. Tools: 1x divert-right.  
**Medium-hard** — 3 winning placements (TIGHT, the answer is nearly unique); wins in 13 measures.  

**21. Dig the River**  
Radius 4, 1 source, 1 fire, 1 pool, 41 dirt cells. Tools: no blocks — digging only.  
**n/a** — solution `dig (-1,-1),(-1,0),(-1,2),(-1,3)`, wins in 12 measures. Placement breadth not measured.  

**22. The Great Cascade**  
Radius 50, 1 source, 0 fires, 11 pools, corridor ±2, 474 dirt cells, 10 preset blocks. Tools: no blocks — digging only.  
**n/a** — solution `dig the 108-cell channel+spurs`, wins in 103 measures. Placement breadth not measured.  

**23. Diverter Drills I**  
Radius 4, 1 source, 1 fire, 1 pool. Tools: 1x divert-right.  
**Medium-hard** — 2 winning placements (TIGHT, the answer is nearly unique); wins in 12 measures.  

**24. Diverter Drills II**  
Radius 4, 1 source, 2 fires, 1 pool. Tools: 1x divert-left.  
**Hard** — 1 winning placement (KNIFE, exactly one answer exists); wins in 13 measures.  

**25. Diverter Drills III**  
Radius 4, 1 source, 1 fire, 1 pool. Tools: 1x divert-left.  
**Medium-hard** — 2 winning placements (TIGHT, the answer is nearly unique); wins in 12 measures.  

**26. Diverter Drills IV**  
Radius 4, 1 source, 2 fires, 1 pool. Tools: 1x divert-right.  
**Medium-hard** — 2 winning placements (TIGHT, the answer is nearly unique); wins in 13 measures.  

**27. Diverter Drills V**  
Radius 4, 1 source, 1 fire, 1 pool. Tools: 1x divert-right, 1x divert-left.  
**Easy** — 55 winning placements (OK, forgiving); wins in 12 measures.  

**28. Diverter Drills VI**  
Radius 4, 1 source, 2 fires, 1 pool. Tools: 2x divert-left.  
**Easy** — 56 winning placements (OK, forgiving); wins in 13 measures.  

**29. Diverter Drills VII**  
Radius 4, 1 source, 1 fire, 1 pool. Tools: 1x divert-left, 1x divert-right.  
**Easy** — 55 winning placements (OK, forgiving); wins in 12 measures.  

**30. Diverter Drills VIII**  
Radius 4, 1 source, 2 fires, 1 pool. Tools: 2x divert-right.  
**Easy** — 57 winning placements (OK, forgiving); wins in 13 measures.  

**31. Wall Work I**  
Radius 4, 1 source, 1 fire, 1 pool. Tools: 1x wall.  
**Medium-hard** — 3 winning placements (TIGHT, the answer is nearly unique); wins in 12 measures.  

**32. Wall Work II**  
Radius 4, 1 source, 2 fires, 1 pool. Tools: 1x wall.  
**Hard** — 1 winning placement (KNIFE, exactly one answer exists); wins in 13 measures.  

**33. Wall Work III**  
Radius 4, 1 source, 1 fire, 1 pool. Tools: 1x wall.  
**Medium-hard** — 2 winning placements (TIGHT, the answer is nearly unique); wins in 12 measures.  

**34. Wall Work IV**  
Radius 4, 1 source, 2 fires, 1 pool. Tools: 1x wall.  
**Hard** — 1 winning placement (KNIFE, exactly one answer exists); wins in 13 measures.  

**35. Wall Work V**  
Radius 4, 1 source, 1 fire, 1 pool. Tools: 1x divert-right, 1x wall.  
**Medium** — 4 winning placements (OK, forgiving); wins in 12 measures.  

**36. Wall Work VI**  
Radius 4, 1 source, 2 fires, 1 pool. Tools: 2x divert-left.  
**Medium** — 4 winning placements (OK, forgiving); wins in 13 measures.  

**37. Wall Work VII**  
Radius 4, 1 source, 1 fire, 1 pool. Tools: 1x divert-left, 1x wall.  
**Easy** — 56 winning placements (OK, forgiving); wins in 12 measures.  

**38. Wall Work VIII**  
Radius 4, 1 source, 2 fires, 1 pool. Tools: 1x wall, 1x divert-left.  
**Medium-hard** — 3 winning placements (TIGHT, the answer is nearly unique); wins in 13 measures.  

**39. Split Networks I**  
Radius 4, 1 source, 1 fire, 2 pools. Tools: 1x splitter.  
**Medium-hard** — 2 winning placements (TIGHT, the answer is nearly unique); wins in 12 measures.  

**40. Split Networks II**  
Radius 4, 1 source, 2 fires, 2 pools. Tools: 1x splitter.  
**Medium-hard** — 2 winning placements (TIGHT, the answer is nearly unique); wins in 13 measures.  

**41. Split Networks III**  
Radius 4, 1 source, 3 fires, 2 pools. Tools: 1x splitter.  
**Medium-hard** — 2 winning placements (TIGHT, the answer is nearly unique); wins in 13 measures.  

**42. Split Networks IV**  
Radius 4, 1 source, 1 fire, 2 pools. Tools: 1x splitter.  
**Medium-hard** — 2 winning placements (TIGHT, the answer is nearly unique); wins in 12 measures.  

**43. Split Networks V**  
Radius 4, 1 source, 2 fires, 1 pool. Tools: 2x divert-left.  
**Easy** — 55 winning placements (OK, forgiving); wins in 13 measures.  

**44. Split Networks VI**  
Radius 4, 1 source, 3 fires, 2 pools. Tools: 1x splitter, 1x divert-left.  
**Easy** — 54 winning placements (OK, forgiving); wins in 14 measures.  

**45. Split Networks VII**  
Radius 4, 1 source, 1 fire, 2 pools. Tools: 1x splitter, 1x divert-left.  
**Easy** — 55 winning placements (OK, forgiving); wins in 12 measures.  

**46. Split Networks VIII**  
Radius 4, 1 source, 2 fires, 1 pool. Tools: 2x divert-right.  
**Easy** — 56 winning placements (OK, forgiving); wins in 13 measures.  

**47. Town Defense I**  
Radius 4, 1 source, 1 fire, 1 pool, 4-cell town. Tools: 1x divert-left.  
**Hard** — 1 winning placement (KNIFE, exactly one answer exists); wins in 12 measures.  

**48. Town Defense II**  
Radius 4, 1 source, 2 fires, 1 pool, 4-cell town. Tools: 1x divert-left.  
**Hard** — 1 winning placement (KNIFE, exactly one answer exists); wins in 13 measures.  

**49. Town Defense III**  
Radius 4, 1 source, 1 fire, 1 pool, 4-cell town. Tools: 1x divert-left.  
**Hard** — 1 winning placement (KNIFE, exactly one answer exists); wins in 12 measures.  

**50. Town Defense IV**  
Radius 4, 1 source, 2 fires, 1 pool, 4-cell town. Tools: 1x divert-left.  
**Hard** — 1 winning placement (KNIFE, exactly one answer exists); wins in 13 measures.  

**51. Town Defense V**  
Radius 4, 1 source, 1 fire, 1 pool, 4-cell town. Tools: 2x divert-left.  
**Easy** — 56 winning placements (OK, forgiving); wins in 12 measures.  

**52. Town Defense VI**  
Radius 4, 1 source, 2 fires, 1 pool, 4-cell town. Tools: 1x divert-right, 1x wall.  
**Easy** — 51 winning placements (OK, forgiving); wins in 13 measures.  

**53. Town Defense VII**  
Radius 4, 1 source, 1 fire, 1 pool, 4-cell town. Tools: 1x divert-right, 1x wall.  
**Medium-hard** — 2 winning placements (TIGHT, the answer is nearly unique); wins in 12 measures.  

**54. Town Defense VIII**  
Radius 4, 1 source, 2 fires, 1 pool, 4-cell town. Tools: 2x wall.  
**Medium-hard** — 2 winning placements (TIGHT, the answer is nearly unique); wins in 13 measures.  

**55. Flat Fields I**  
Radius 4, 1 source, 1 fire, 1 pool, flat grid. Tools: 1x divert-left.  
**Medium** — 4 winning placements (OK, forgiving); wins in 12 measures.  

**56. Flat Fields II**  
Radius 4, 1 source, 2 fires, 1 pool, flat grid. Tools: 1x wall.  
**Medium** — 7 winning placements (OK, forgiving); wins in 22 measures.  

**57. Flat Fields III**  
Radius 4, 1 source, 1 fire, 1 pool, flat grid. Tools: 1x wall.  
**Medium** — 5 winning placements (OK, forgiving); wins in 19 measures.  

**58. Flat Fields IV**  
Radius 4, 1 source, 2 fires, 1 pool, flat grid. Tools: 1x divert-left.  
**Medium** — 4 winning placements (OK, forgiving); wins in 13 measures.  

**59. Flat Fields V**  
Radius 4, 2 sources, 1 fire, 1 pool, flat grid. Tools: 1x wall.  
**Medium** — 13 winning placements (OK, forgiving); wins in 17 measures.  

**60. Flat Fields VI**  
Radius 4, 2 sources, 2 fires, 1 pool, flat grid. Tools: 1x divert-left, 1x wall.  
**Easy** — 60 winning placements (OK, forgiving); wins in 18 measures.  

**61. Flat Fields VII**  
Radius 4, 2 sources, 1 fire, 1 pool, flat grid. Tools: 1x divert-right, 1x wall.  
**Easy** — 69 winning placements (OK, forgiving); wins in 18 measures.  

**62. Flat Fields VIII**  
Radius 4, 2 sources, 2 fires, 2 pools, flat grid. Tools: 1x divert-right, 1x divert-left.  
**Easy** — 52 winning placements (OK, forgiving); wins in 12 measures.  

**63. Geyser Country I**  
Radius 4, 1 source, 1 fire, 1 pool, 1 geyser. Tools: 1x divert-left.  
**Medium** — 4 winning placements (OK, forgiving); wins in 14 measures.  

**64. Geyser Country II**  
Radius 4, 1 source, 2 fires, 2 pools, 1 geyser. Tools: 1x wall.  
**BROKEN** — 0 winning placements; unsolvable as shipped. Its documented 15-measure solution no longer wins.  

**65. Geyser Country III**  
Radius 4, 1 source, 1 fire, 1 pool, 1 geyser. Tools: 1x wall.  
**Hard** — 1 winning placement (KNIFE, exactly one answer exists); wins in 14 measures.  

**66. Geyser Country IV**  
Radius 4, 1 source, 2 fires, 2 pools, 1 geyser. Tools: 1x wall.  
**BROKEN** — 0 winning placements; unsolvable as shipped. Its documented 15-measure solution no longer wins.  

**67. Geyser Country V**  
Radius 6, 1 source, 1 fire, 2 pools, corridor ±2, 1 geyser. Tools: 1x wall.  
**BROKEN** — 0 winning placements; unsolvable as shipped. Its documented 18-measure solution no longer wins.  

**68. Geyser Country VI**  
Radius 6, 1 source, 2 fires, 1 pool, corridor ±2, 1 geyser. Tools: 1x wall.  
**BROKEN** — 0 winning placements; unsolvable as shipped. Its documented 19-measure solution no longer wins.  

**69. Geyser Country VII**  
Radius 6, 1 source, 1 fire, 2 pools, corridor ±2, 1 geyser. Tools: 1x wall.  
**BROKEN** — 0 winning placements; unsolvable as shipped. Its documented 19-measure solution no longer wins.  

**70. Geyser Country VIII**  
Radius 6, 1 source, 2 fires, 1 pool, corridor ±2, 1 geyser. Tools: 1x wall.  
**Medium** — 5 winning placements (OK, forgiving); wins in 19 measures.  

**71. Big Digs I**  
Radius 4, 1 source, 1 fire, 1 pool, 48 dirt cells. Tools: no blocks — digging only.  
**n/a** — solution `dig 5 cells: [(-1, -2), (-1, -1), (-1, 0), (-1, 2), (-2, 3)]`, wins in 12 measures. Placement breadth not measured.  

**72. Big Digs II**  
Radius 4, 1 source, 2 fires, 1 pool, 47 dirt cells. Tools: no blocks — digging only.  
**n/a** — solution `dig 4 cells: [(-1, -2), (-1, -1), (-1, 0), (-2, 2)]`, wins in 13 measures. Placement breadth not measured.  

**73. Big Digs III**  
Radius 4, 1 source, 1 fire, 1 pool, 48 dirt cells. Tools: no blocks — digging only.  
**n/a** — solution `dig 5 cells: [(0, -2), (-1, -1), (-1, 0), (-1, 1), (-2, 2)]`, wins in 12 measures. Placement breadth not measured.  

**74. Big Digs IV**  
Radius 6, 1 source, 1 fire, 1 pool, corridor ±2, 53 dirt cells. Tools: no blocks — digging only.  
**n/a** — solution `dig 9 cells: [(2, -4), (1, -3), (0, -2), (-1, -1), (-2, 1), (-2, 2), (-3, 3), (-3, 4), (-3, 5)]`, wins in 16 measures. Placement breadth not measured.  

**75. Big Digs V**  
Radius 8, 1 source, 2 fires, 1 pool, corridor ±2, 72 dirt cells. Tools: no blocks — digging only.  
**n/a** — solution `dig 12 cells: [(3, -6), (3, -5), (3, -4), (3, -3), (3, -2), (3, -1), (2, 0), (0, 2), (-1, 3), (-2, 4), (-2, 5), (-3, 6)]`, wins in 21 measures. Placement breadth not measured.  

**76. Big Digs VI**  
Radius 10, 1 source, 3 fires, 1 pool, corridor ±2, 91 dirt cells. Tools: no blocks — digging only.  
**n/a** — solution `dig 15 cells: [(3, -8), (3, -7), (3, -5), (3, -4), (2, -3), (1, -2), (1, -1), (1, 0), (1, 2), (-1, 4), (-1, 5), (-1, 6), (-2, 7), (-2, 8), (-3, 9)]`, wins in 26 measures. Placement breadth not measured.  

**77. Big Digs VII**  
Radius 12, 1 source, 1 fire, 1 pool, corridor ±2, 113 dirt cells. Tools: no blocks — digging only.  
**n/a** — solution `dig 21 cells: [(4, -10), (4, -9), (4, -8), (4, -7), (4, -6), (3, -5), (3, -4), (3, -3), (2, -2), (1, -1), (0, 0), (-1, 1), (-2, 2), (-3, 3), (-4, 4), (-4, 6), (-4, 7), (-4, 8), (-5, 9), (-6, 10), (-7, 11)]`, wins in 28 measures. Placement breadth not measured.  

**78. Big Digs VIII**  
Radius 14, 1 source, 2 fires, 1 pool, corridor ±2, 132 dirt cells. Tools: no blocks — digging only.  
**n/a** — solution `dig 24 cells: [(6, -12), (6, -11), (5, -9), (4, -8), (4, -7), (4, -6), (3, -5), (3, -3), (3, -2), (2, -1), (1, 0), (0, 1), (0, 2), (-1, 3), (-1, 4), (-1, 5), (-2, 6), (-2, 7), (-2, 8), (-3, 9), (-3, 10), (-4, 11), (-4, 12), (-5, 13)]`, wins in 33 measures. Placement breadth not measured.  

**79. Jamboree Runs I**  
Radius 8, 1 source, 1 fire, 2 pools, corridor ±2. Tools: Jamboree budget of 2, any block.  
**Medium** — 6 winning placements (OK, forgiving); wins in 20 measures.  

**80. Jamboree Runs II**  
Radius 9, 1 source, 2 fires, 1 pool, corridor ±2. Tools: Jamboree budget of 3, any block.  
**Easy** — 425 winning placements (OK, forgiving); wins in 23 measures.  

**81. Jamboree Runs III**  
Radius 10, 1 source, 3 fires, 1 pool, corridor ±2. Tools: Jamboree budget of 2, any block.  
**Medium** — 15 winning placements (OK, forgiving); wins in 26 measures.  

**82. Jamboree Runs IV**  
Radius 8, 1 source, 1 fire, 1 pool, corridor ±2. Tools: Jamboree budget of 3, any block.  
**Easy** — 35 winning placements (OK, forgiving); wins in 20 measures.  

**83. Jamboree Runs V**  
Radius 9, 1 source, 2 fires, 1 pool, corridor ±2. Tools: Jamboree budget of 2, any block.  
**Medium** — 8 winning placements (OK, forgiving); wins in 23 measures.  

**84. Jamboree Runs VI**  
Radius 10, 1 source, 3 fires, 1 pool, corridor ±2. Tools: Jamboree budget of 3, any block.  
**Easy** — 455 winning placements (OK, forgiving); wins in 26 measures.  

**85. Jamboree Runs VII**  
Radius 8, 1 source, 1 fire, 1 pool, corridor ±2. Tools: Jamboree budget of 2, any block.  
**Medium** — 18 winning placements (OK, forgiving); wins in 20 measures.  

**86. Jamboree Runs VIII**  
Radius 9, 1 source, 2 fires, 2 pools, corridor ±2. Tools: Jamboree budget of 3, any block.  
**Medium** — 14 winning placements (OK, forgiving); wins in 22 measures.  

**87. The Gauntlet I**  
Radius 10, 1 source, 1 fire, 2 pools, corridor ±2, 10 dirt cells, 1 preset blocks. Tools: 1x divert-right, 1x divert-left.  
**Easy** — 80 winning placements (OK, forgiving); wins in 24 measures.  

**88. The Gauntlet II**  
Radius 11, 1 source, 2 fires, 2 pools, corridor ±2, 4-cell town, 10 dirt cells, 1 preset blocks. Tools: 1x wall.  
**Medium-hard, long** — 3 winning placements (TIGHT, the answer is nearly unique); wins in 27 measures.  

**89. The Gauntlet III**  
Radius 12, 1 source, 3 fires, 2 pools, corridor ±2, 1 geyser, 10 dirt cells, 1 preset blocks. Tools: 1x divert-left.  
**Easy, long** — 91 winning placements (OK, forgiving); wins in 41 measures.  

**90. The Gauntlet IV**  
Radius 13, 1 source, 1 fire, 1 pool, corridor ±2, 4-cell town, 10 dirt cells, 1 preset blocks. Tools: Jamboree budget of 2, any block.  
**Medium** — 18 winning placements (OK, forgiving); wins in 30 measures.  

**91. The Gauntlet V**  
Radius 14, 1 source, 2 fires, 2 pools, corridor ±2, 10 dirt cells, 1 preset blocks. Tools: 1x divert-left, 1x wall.  
**Easy, long** — 120 winning placements (OK, forgiving); wins in 33 measures.  

**92. The Gauntlet VI**  
Radius 15, 1 source, 3 fires, 2 pools, corridor ±2, 4-cell town, 1 geyser, 10 dirt cells, 2 preset blocks. Tools: 1x wall.  
**BROKEN** — 0 winning placements; unsolvable as shipped. Its documented 37-measure solution no longer wins.  

**93. The Gauntlet VII**  
Radius 16, 1 source, 1 fire, 2 pools, corridor ±2, 10 dirt cells, 2 preset blocks. Tools: 1x wall, 1x divert-left.  
**Easy** — 137 winning placements (OK, forgiving); wins in 35 measures.  

**94. The Gauntlet VIII**  
Radius 17, 1 source, 2 fires, 2 pools, corridor ±2, 4-cell town, 20 dirt cells, 2 preset blocks. Tools: Jamboree budget of 3, any block.  
**Easy, long** — 589 winning placements (OK, forgiving); wins in 38 measures.  

**95. The Gauntlet IX**  
Radius 18, 1 source, 3 fires, 1 pool, corridor ±2, 1 geyser, 20 dirt cells, 2 preset blocks. Tools: 1x divert-left, 1x divert-right.  
**Easy, long** — 151 winning placements (OK, forgiving); wins in 41 measures.  

**96. The Gauntlet X**  
Radius 19, 1 source, 1 fire, 2 pools, corridor ±2, 4-cell town, 20 dirt cells, 2 preset blocks. Tools: 1x wall, 1x divert-right.  
**BROKEN** — 0 winning placements; unsolvable as shipped. Its documented 42-measure solution no longer wins.  

**97. The Gauntlet XI**  
Radius 20, 1 source, 2 fires, 3 pools, corridor ±2, 20 dirt cells, 3 preset blocks. Tools: 1x wall, 1x divert-right.  
**Easy, long** — 57 winning placements (OK, forgiving); wins in 44 measures.  

**98. The Gauntlet XII**  
Radius 20, 1 source, 3 fires, 1 pool, corridor ±2, 4-cell town, 1 geyser, 20 dirt cells, 3 preset blocks. Tools: Jamboree budget of 2, any block.  
**Easy, long** — 751 winning placements (OK, forgiving); wins in 46 measures.  

**99. The Gauntlet XIII**  
Radius 20, 1 source, 1 fire, 3 pools, corridor ±2, 20 dirt cells, 3 preset blocks. Tools: 1x wall, 1x divert-right.  
**Easy, long** — 67 winning placements (OK, forgiving); wins in 44 measures.  

**100. The Gauntlet XIV**  
Radius 20, 1 source, 2 fires, 2 pools, corridor ±2, 4-cell town, 20 dirt cells, 3 preset blocks. Tools: 1x divert-right.  
**Medium, long** — 10 winning placements (OK, forgiving); wins in 45 measures.  
