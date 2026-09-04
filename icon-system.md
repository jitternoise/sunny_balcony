# Flash Flood — Icon & Terrain Visual System

Companion to `toolset-and-requirements.md` and `dev-progress.md`. Defines the icon/color
language to replace the current flat-colored placeholder hexagons. See
`icon-sheet.html` (rendered reference) and the individual `icon_*.svg` files (drop-in
assets — Godot imports SVG natively) for the actual glyphs.

## Design rule
Every block/terrain type gets a distinct **silhouette**, not just a color — a player
scanning a busy board should be able to tell types apart even before color registers.
All glyphs share one dark outline weight (~`#1E2530`) so they sit consistently against
any hex fill.

## Hue split: cool = tool, warm = consequence
- **Block types the player places** (Wall, Diverter-Left/Right, Splitter) sit outside the
  water-blue family so they never get mistaken for board hazards: Wall reads as a
  neutral stone gray-brown (a rock, not a tool color at all — it's terrain the player
  drops in), Diverters are orange, Splitter is violet.
- **Terrain already on the board** (Fire, Town) lives in warm/earth tones, since these
  are consequences the player reacts to, not choices they make.
- **Pool and Source** are the exception — they stay water-blue because they're
  water-family, not danger-family, even though they're fixed terrain.
- **Blocked/unplayable cells** are neutral gray hatch — explicitly *not* in either hue
  family, so they read as "outside the puzzle" rather than a third kind of danger.

## Per-type notes
- **Wall** — boulder/rock glyph, stone gray-brown with a highlight facet and shadow
  facet plus crack lines for volume. Only block that stops natural fall, so it reads as
  the physically "solid" one.
- **Diverter-Right / Diverter-Left** — mirrored orange chevrons that physically point the
  exit direction. No legend needed; the icon *is* the rule.
- **Splitter** — one stem forking into two arrows, explaining "sends water both ways" on
  sight.
- **Fire** — warm gradient flame on a dark ember tile, the hottest-looking cell on the
  board on purpose.
- **Pool** — basin + 4 corner tabs that echo the in-HUD 4-box status bar, so the cell
  previews its own win condition before the bar even appears.
- **Town** — earthy brown house glyph, deliberately the *calmest*-looking hazard. The
  danger is what it means (instant loss), not how it looks — the loss-screen sting is
  what should carry the emotional weight, not the tile art.
- **Water Source** — a river glyph: three converging wavy strands flowing into a
  baked-in down-left arrow, teaching "first move is always down-left" every level
  without a tutorial popup.

## Files delivered this session
- `icon-sheet.html` — visual reference sheet (palette, all glyphs on hex tiles, one
  sample board mockup).
- `icon_wall.svg`, `icon_diverter_left.svg`, `icon_diverter_right.svg`,
  `icon_splitter.svg`, `icon_fire.svg`, `icon_pool.svg`, `icon_town.svg`,
  `icon_source.svg`, `icon_blocked.svg` — standalone 100×100 viewBox SVGs, ready to
  import into Godot as `Texture2D` resources for each `BlockData`/terrain sprite slot.

## Open follow-ups
- No motion/animation direction defined yet (e.g. the beat-synced pulse idea discussed
  earlier) — these are static glyphs only.
- Geyser terrain (from the newer, currently-unmatched project version) has no icon yet —
  add one if/when that version's scripts are re-uploaded and the level editor is
  extended to match.
- Icons are unstyled outside their SVG — no drop shadow / selection-state (e.g.
  "currently selected in inventory tray") treatment defined yet.
