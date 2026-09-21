extends RefCounted
class_name Characters

## The animal at every pool: one per ten levels, the same bands as the sky
## (Backdrop.PALETTES) and the music (Music.TRACKS), indexed by the one
## band formula, Backdrop.index_for_level(). A pool's animal acts out the
## pool filling in five poses, one per beat of pool_fill (0..4): lying by
## the dry basin, head up, standing, at the edge, drinking. HexBoard draws
## it; this table only says which animal a level gets and where its art is.
##
## The story bible's thirteen chapter animals do not divide into ten, so a
## band takes the animal of the chapter that owns most of it, with two
## owner's calls (toad over salmon for 11-20, the village dog over the ants
## for 41-50) and the Jamboree band showing two animals at once instead of
## the crowd glyph. The player bird and the mother are not pool animals and
## are not here.
##
## Art: assets/characters/<slug>_<pose>.svg, five files per slug, every one
## written by tools/gen_characters.py from that animal's parts -- never
## hand-edited. VerifyCharacters holds this table, the directory and the
## generator's records together.

const DIR := "res://assets/characters/"
const POSES := 5

## One entry per Backdrop.PALETTES index. `slugs` is normally one animal;
## the Jamboree band has two, drawn side by side. A band whose art is not
## drawn yet points at the tortoise, the one animal with poses today.
const CAST: Array[Dictionary] = [
	{"name": "Beaver", "slugs": ["tortoise"]},               # 1-10   TODO(art): beaver
	{"name": "Toad", "slugs": ["tortoise"]},                 # 11-20  TODO(art): toad
	{"name": "Otter", "slugs": ["tortoise"]},                # 21-30  TODO(art): otter
	{"name": "Tortoise", "slugs": ["tortoise"]},             # 31-40
	{"name": "Sheepdog", "slugs": ["tortoise"]},             # 41-50  TODO(art): sheepdog
	{"name": "Bison", "slugs": ["tortoise"]},                # 51-60  TODO(art): bison
	{"name": "Flamingo", "slugs": ["tortoise"]},             # 61-70  TODO(art): flamingo
	{"name": "Badger", "slugs": ["tortoise"]},               # 71-80  TODO(art): badger
	{"name": "Everyone", "slugs": ["tortoise", "tortoise"]}, # 81-90  TODO(art): tortoise + flamingo
	{"name": "Wild horse", "slugs": ["tortoise"]},           # 91-100 TODO(art): horse
]

## Loaded pose textures by path, so a level asks the disk once per pose
## and a band's five (or ten) textures are all the board ever holds.
static var _cache: Dictionary = {}


## Which band a level is in -- Backdrop's formula, never a second one.
static func index_for_level(level_id: int) -> int:
	return Backdrop.index_for_level(level_id)


static func for_level(level_id: int) -> Dictionary:
	return CAST[index_for_level(level_id)]


static func pose_path(slug: String, pose: int) -> String:
	return "%s%s_%d.svg" % [DIR, slug, pose]


## The texture for one pose of one animal, or null (with a warning, once)
## when its file is missing or not imported -- a half-drawn cast shows no
## animal at that pool rather than crashing the level.
static func pose_texture(slug: String, pose: int) -> Texture2D:
	var path := pose_path(slug, pose)
	if _cache.has(path):
		return _cache[path]
	var texture: Texture2D = null
	if ResourceLoader.exists(path, "Texture2D"):
		texture = load(path) as Texture2D
	if texture == null:
		push_warning("Characters: no pose art at %s" % path)
	_cache[path] = texture
	return texture


static func poses_for(slug: String) -> Array[Texture2D]:
	var poses: Array[Texture2D] = []
	for pose in range(POSES):
		poses.append(pose_texture(slug, pose))
	return poses


## One Array[Texture2D] of POSES entries per slug of the level's band.
static func poses_for_level(level_id: int) -> Array:
	var sets: Array = []
	for slug: String in for_level(level_id)["slugs"]:
		sets.append(poses_for(slug))
	return sets
