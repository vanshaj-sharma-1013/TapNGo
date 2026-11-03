extends RefCounted

# Loads a world's art. Use it through preload and call the static functions:
#   const WorldArt = preload("res://world_art.gd")
#   WorldArt.texture(WorldData.PYRAMIDS, "hazards/quicksand")
#
# A picture is looked up as res://assets/themes/<world id>/<path>.png. When the file
# isn't there yet, a simple placeholder is drawn in code instead, so a new world is
# playable before its art exists. Put the real PNG at the same path and it replaces
# the placeholder with no code change.

const WorldData = preload("res://world_data.gd")

static var _cache := {}


static func texture(world: int, path: String) -> Texture2D:
	var key := "%d:%s" % [world, path]
	if _cache.has(key):
		return _cache[key]
	var file := "res://assets/themes/%s/%s.png" % [WorldData.id(world), path]
	var tex: Texture2D
	if ResourceLoader.exists(file):
		tex = load(file)
	elif path.begins_with("level_objects/"):
		# Checkpoints and the finish gate are the jungle's until a world has its own.
		tex = texture(WorldData.JUNGLE, path)
	else:
		tex = _placeholder(world, path)
	_cache[key] = tex
	return tex


# The world's wide scenic picture (environment/backdrop.jpg), used on the world and level
# selection screens. Null if the world has none.
static func backdrop(world: int) -> Texture2D:
	var file := "res://assets/themes/%s/environment/backdrop.jpg" % WorldData.id(world)
	return load(file) if ResourceLoader.exists(file) else null


# [left cap, tiling middle, right cap] for a bar skin, e.g. ("logs", "log").
static func bar_pieces(world: int, folder: String, prefix: String) -> Array:
	return [
		texture(world, "%s/%s_left" % [folder, prefix]),
		texture(world, "%s/%s_mid" % [folder, prefix]),
		texture(world, "%s/%s_right" % [folder, prefix]),
	]


# --- Placeholders -------------------------------------------------------------------

static func _placeholder(world: int, path: String) -> Texture2D:
	var image: Image
	var name := path.get_file()
	if path == "environment/ground_tile":
		image = _ground(world)
	elif path == "environment/edge_left":
		image = _edge(world)
	elif path == "environment/edge_right":
		image = _edge(world)
		image.flip_x()
	elif name.ends_with("_left") or name.ends_with("_mid") or name.ends_with("_right"):
		image = _bar_piece(world, path)
	elif path.begins_with("hazards/"):
		image = _hazard_picture(world, name)
	else:
		image = Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
		image.fill(Color.MAGENTA)  # a missing picture should be easy to spot
	return ImageTexture.create_from_image(image)


static func _new_image(width: int, height: int, color: Color) -> Image:
	var image := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return image


# Floor tile. The outer 8px are cropped away by the background, so details stay inside.
static func _ground(world: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + world
	match world:
		WorldData.PYRAMIDS:
			var image := _new_image(128, 128, Color("c9a45c"))
			for line in [32, 64, 96]:
				image.fill_rect(Rect2i(0, line, 128, 2), Color("8f6f35"))
				image.fill_rect(Rect2i(line, 0, 2, 128), Color("a8853f"))
			for i in 14:  # tiny hieroglyph marks
				image.fill_rect(Rect2i(rng.randi_range(12, 112), rng.randi_range(12, 112), rng.randi_range(2, 6), 3), Color("7a5a1e"))
			return image
		WorldData.CYBER:
			var image := _new_image(128, 128, Color("04040c"))
			for line in [24, 56, 88, 120]:
				image.fill_rect(Rect2i(0, line, 128, 2), Color(0.0, 0.9, 1.0, 0.55))
				image.fill_rect(Rect2i(line, 0, 2, 128), Color(0.0, 0.9, 1.0, 0.55))
			image.fill_rect(Rect2i(0, 72, 128, 2), Color(1.0, 0.18, 0.58, 0.6))
			return image
		WorldData.FROST:
			var image := _new_image(128, 128, Color("10204a"))
			for i in 260:
				image.set_pixel(rng.randi_range(0, 127), rng.randi_range(0, 127), Color(0.8, 0.92, 1.0, rng.randf_range(0.25, 0.8)))
			return image
	var jungle := _new_image(128, 128, Color("2f6b2f"))
	for i in 120:
		jungle.set_pixel(rng.randi_range(0, 127), rng.randi_range(0, 127), Color("3f8a3f"))
	return jungle


# Lane edge strip; the left side is the outer side. The right edge is this one flipped.
static func _edge(world: int) -> Image:
	match world:
		WorldData.PYRAMIDS:
			var image := _new_image(50, 128, Color("a8853f"))
			for y in [0, 32, 64, 96]:
				image.fill_rect(Rect2i(0, y, 50, 3), Color("5e4519"))
			image.fill_rect(Rect2i(46, 0, 4, 128), Color("e8cf8a"))
			return image
		WorldData.CYBER:
			var image := _new_image(50, 128, Color("0a0a1a"))
			image.fill_rect(Rect2i(10, 0, 3, 128), Color(0.0, 0.9, 1.0, 0.7))
			image.fill_rect(Rect2i(24, 0, 2, 128), Color(1.0, 0.18, 0.58, 0.7))
			image.fill_rect(Rect2i(44, 0, 6, 128), Color("00e5ff"))
			return image
		WorldData.FROST:
			var image := _new_image(50, 128, Color("9ad4f2"))
			for y in [10, 50, 90]:
				image.fill_rect(Rect2i(8, y, 30, 6), Color("e8f8ff"))
			image.fill_rect(Rect2i(44, 0, 6, 128), Color("ffffff"))
			return image
	var jungle := _new_image(50, 128, Color("1f4d1f"))
	jungle.fill_rect(Rect2i(44, 0, 6, 128), Color("5fae5f"))
	return jungle


static func _skin_colors(world: int, skin: String) -> Array:
	match skin:
		"pillar": return [Color("c9a45c"), Color("7a5a1e")]
		"scarab": return [Color("2f9e8a"), Color("d4af37")]
		"laser": return [Color("14102a"), Color("ff2e93")]
		"frozen": return [Color("bfe9ff"), Color("4aa8d8")]
		"wall":
			match world:
				WorldData.PYRAMIDS: return [Color("8b6b3d"), Color("4a3517")]
				WorldData.CYBER: return [Color("1a1a33"), Color("00e5ff")]
				WorldData.FROST: return [Color("6b86a8"), Color("2d4560")]
	return [Color("8a8a8a"), Color("444444")]


# One of the three pieces of a bar. Caps are 64x64 and the middle 128x64, like the jungle art.
static func _bar_piece(world: int, path: String) -> Image:
	var name := path.get_file()
	var skin := path.get_base_dir()  # e.g. "pillars" or "walls"
	var colors := _skin_colors(world, _skin_for_folder(skin))
	var fill: Color = colors[0]
	var edge: Color = colors[1]
	var is_mid := name.ends_with("_mid")
	var width := 128 if is_mid else 64
	var image := _new_image(width, 64, fill)
	image.fill_rect(Rect2i(0, 0, width, 6), edge)
	image.fill_rect(Rect2i(0, 58, width, 6), edge)
	if name.ends_with("_left"):
		image.fill_rect(Rect2i(0, 0, 6, 64), edge)
	elif name.ends_with("_right"):
		image.fill_rect(Rect2i(width - 6, 0, 6, 64), edge)
	if _skin_for_folder(skin) == "laser":
		image.fill_rect(Rect2i(0, 28, width, 8), Color("00e5ff"))
	elif is_mid:
		image.fill_rect(Rect2i(30, 8, 3, 48), edge)
		image.fill_rect(Rect2i(94, 8, 3, 48), edge)
	return image


static func _skin_for_folder(folder: String) -> String:
	match folder:
		"pillars": return "pillar"
		"scarabs": return "scarab"
		"lasers": return "laser"
		"frozen": return "frozen"
		"walls": return "wall"
	return folder


# Single pictures in hazards/: patches (drawn 300x120), trapdoors / pulse barriers
# (stretched over a full-lane row) and falling debris.
static func _hazard_picture(world: int, name: String) -> Image:
	match name:
		"quicksand": return _puddle(Color("d9a441"), Color("8a5a1a"))
		"glitch": return _puddle(Color("ff2e93"), Color("00e5ff"))
		"frost_patch": return _puddle(Color("e8f8ff"), Color("7fd6ff"))
		"trapdoor_on": return _spikes(Color("4a3517"), Color("f0e6c8"))
		"trapdoor_off": return _slot(Color("2a1d0c"), Color("8a6a35"))
		"pulse_on": return _slot(Color("ff2e93"), Color("00e5ff"), true)
		"pulse_off": return _slot(Color("0a0a1a"), Color(1.0, 0.18, 0.58, 0.5))
		"debris": return _rock()
	var image := _new_image(16, 16, Color.MAGENTA)
	return image


# Ellipse in the middle of a 750x300-shaped picture, with transparent margins like the
# jungle patches. Made at a third of the size: it is stretched when drawn.
static func _puddle(fill: Color, edge: Color) -> Image:
	var image := _new_image(250, 100, Color(0, 0, 0, 0))
	var centre := Vector2(125.0, 50.0)
	var radius := Vector2(68.0, 28.0)
	for y in 100:
		for x in 250:
			var d := Vector2((x - centre.x) / radius.x, (y - centre.y) / radius.y).length()
			if d < 1.0:
				image.set_pixel(x, y, edge if d > 0.82 else fill)
	return image


# Spiked floor trap: dark base with a row of light teeth.
static func _spikes(base: Color, tooth: Color) -> Image:
	var image := _new_image(128, 64, base)
	for t in 8:
		var x0 := t * 16
		for row in 40:
			var half := int((40 - row) * 8.0 / 40.0)
			image.fill_rect(Rect2i(x0 + 8 - half, 12 + row, maxi(half * 2, 1), 1), tooth)
	return image


static func _slot(fill: Color, edge: Color, glow := false) -> Image:
	var image := _new_image(128, 64, fill)
	image.fill_rect(Rect2i(0, 0, 128, 5), edge)
	image.fill_rect(Rect2i(0, 59, 128, 5), edge)
	if glow:
		image.fill_rect(Rect2i(0, 28, 128, 8), Color.WHITE)
	return image


static func _rock() -> Image:
	var image := _new_image(96, 96, Color(0, 0, 0, 0))
	for y in 96:
		for x in 96:
			var d := Vector2(x - 48.0, y - 48.0).length()
			if d < 44.0:
				image.set_pixel(x, y, Color("5b7088") if d > 36.0 else Color("a9c4de"))
	return image
