extends RefCounted
class_name Backdrop

## The sky and ground behind a level: one pair of colours per ten levels,
## so the campaign visibly moves on as the player does. Levels 1-10 keep
## the spring meadow every screen used to share, and the tutorials (which
## sit below level 1 on the map) share it too.
##
## Choosing a pair: the sky carries the mood -- nothing but the HUD is
## drawn on it, so it can go anywhere. The ground is the hard part. It
## shows around the board, and through every EMPTY cell once the player
## thins the grid (Settings.grid_opacity), so its hue has to stay clear
## of the things drawn on the board: fire's orange-red, the lakebed's tan,
## the browns of dirt and towns, the purple of a geyser, water's blue,
## and the amber of the flow preview and hint outline. That leaves greens,
## sages, teals and slates, plus the pale salt of the finale -- and every
## one must stay clearly lighter than an empty cell's dark fill, which
## VerifyBackdrops holds it to.
##
## Named loosely after the story bible's chapters (story-bible.md); the
## chapters are not ten levels each, so the names are a mood, not a map.
## The pool animal (Characters.CAST) and the music share these bands; the
## chapter labels on the Level Select map do not.

const DECADE := 10
const FIRST_LEVEL := 1
const LAST_LEVEL := 100

## Each band also says what moves in it (AmbientBackdrop draws it):
##   cloud  -- the clouds' tint, blended into the sky by depth
##   clouds -- how many drift across (0 for a clear sky)
##   shadow -- how dark a near cloud's shadow is on the ground, as a blend
##             toward the HUD outline colour; 0 for no sun. Kept small: the
##             ground under a shadow must stay as clear of an empty cell as
##             the ground itself (VerifyAmbience)
##   birds  -- whether a flock crosses now and then
##   stars  -- only on a sky dark enough to show them
const PALETTES: Array[Dictionary] = [
	{"name": "Spring meadow", "sky": Color(0.53, 0.81, 0.92), "ground": Color(0.30, 0.69, 0.31),   # 1-10
		"cloud": Color(1.0, 1.0, 1.0), "clouds": 5, "shadow": 0.14, "birds": true, "stars": false},
	{"name": "Deep valley", "sky": Color(0.70, 0.87, 0.95), "ground": Color(0.20, 0.56, 0.38),     # 11-20
		"cloud": Color(1.0, 1.0, 1.0), "clouds": 6, "shadow": 0.14, "birds": true, "stars": false},
	{"name": "Morning riverbank", "sky": Color(0.96, 0.86, 0.68), "ground": Color(0.45, 0.66, 0.30), # 21-30
		"cloud": Color(1.0, 0.98, 0.93), "clouds": 4, "shadow": 0.12, "birds": true, "stars": false},
	{"name": "Dry season", "sky": Color(0.92, 0.82, 0.64), "ground": Color(0.58, 0.64, 0.34),      # 31-40
		"cloud": Color(1.0, 0.97, 0.90), "clouds": 2, "shadow": 0.10, "birds": false, "stars": false},
	{"name": "Evening pines", "sky": Color(0.74, 0.70, 0.88), "ground": Color(0.22, 0.50, 0.46),   # 41-50
		"cloud": Color(0.98, 0.88, 0.94), "clouds": 4, "shadow": 0.10, "birds": true, "stars": false},
	{"name": "Golden plains", "sky": Color(0.99, 0.82, 0.52), "ground": Color(0.52, 0.58, 0.30),   # 51-60
		"cloud": Color(1.0, 0.95, 0.85), "clouds": 4, "shadow": 0.12, "birds": true, "stars": false},
	{"name": "Geyser country", "sky": Color(0.96, 0.74, 0.72), "ground": Color(0.38, 0.56, 0.54),  # 61-70
		"cloud": Color(1.0, 0.93, 0.92), "clouds": 5, "shadow": 0.12, "birds": false, "stars": false},
	{"name": "Badger dusk", "sky": Color(0.40, 0.42, 0.60), "ground": Color(0.36, 0.40, 0.46),     # 71-80
		"cloud": Color(0.58, 0.59, 0.76), "clouds": 3, "shadow": 0.0, "birds": false, "stars": true},
	{"name": "Jamboree sunset", "sky": Color(0.98, 0.62, 0.44), "ground": Color(0.40, 0.52, 0.36), # 81-90
		"cloud": Color(1.0, 0.84, 0.74), "clouds": 4, "shadow": 0.08, "birds": true, "stars": false},
	{"name": "The Pan", "sky": Color(0.82, 0.88, 0.94), "ground": Color(0.80, 0.80, 0.74),         # 91-100
		"cloud": Color(1.0, 1.0, 1.0), "clouds": 3, "shadow": 0.10, "birds": false, "stars": false},
]

## The HUD's labels are white with a dark outline that used to be a fixed
## deep green (0.14, 0.30, 0.13). It is now the ground's hue scaled down
## to this luminance -- the old green's, near enough -- so the outline is
## as dark on the salt pan as on the meadow, and reads on every sky. A
## fixed darkening would not do that: 55% off a pale ground is a mid grey.
const OUTLINE_LUMINANCE := 0.22
const OUTLINE_ALPHA := 0.9


## Which palette a level uses. Levels 1-100 step through PALETTES ten at a
## time; anything else -- the tutorials at 901-905, the reserved bonus ids
## -- gets the first, the meadow.
static func index_for_level(level_id: int) -> int:
	if level_id < FIRST_LEVEL or level_id > LAST_LEVEL:
		return 0
	@warning_ignore("integer_division")
	return mini((level_id - FIRST_LEVEL) / DECADE, PALETTES.size() - 1)


static func for_level(level_id: int) -> Dictionary:
	return PALETTES[index_for_level(level_id)]


static func outline_for(ground: Color) -> Color:
	var luminance := ground.get_luminance()
	var outline := ground * (OUTLINE_LUMINANCE / luminance) if luminance > 0.0 else Color.BLACK
	outline.a = OUTLINE_ALPHA
	return outline
