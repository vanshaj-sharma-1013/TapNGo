extends Area2D

# A hazard across the lane. How it moves is its `motion` (WorldData.MOTION_*):
#   sweep:    a bar sliding left and right
#   pendulum: a bar swinging around the lane centre
#   fixed:    a wall that never moves
#   blink:    a full-lane row that is deadly only while ON (trapdoor spikes, pulse barrier)
#   fall:     a chunk that drops onto its spot, rests a moment, then vanishes
# Every position is a pure function of the time since the level started: no
# randomness, so the same pattern plays out the same way every run.

const WorldData = preload("res://world_data.gd")
const WorldArt = preload("res://world_art.gd")

const LANE_WIDTH := 720.0
# Art is drawn at 4x and shown at 0.4x, like the character.
const ART_SCALE := 0.4
# Fixed walls are 96px tall in the art, so their hitbox is that tall too.
const WALL_HEIGHT := 96.0 * ART_SCALE

const BLINK_HEIGHT := 56.0
const BLINK_WARN_TIME := 0.35  # the row flashes red this long before it turns ON

const FALL_HEIGHT := 110.0
const FALL_BAND := 640.0       # how far above its spot the chunk starts
const FALL_REST_TIME := 0.3    # lies where it landed, still deadly
const FALL_HIDDEN_TIME := 1.4  # gone before the next drop
const FALL_WARN_TIME := 0.9    # the landing shadow shows this long before the drop starts
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.5)

# Skins made of [left cap, tiling middle, right cap]: skin -> [folder, file prefix].
const BAR_SKINS := {
	"wall": ["walls", "wall"],
	"pillar": ["pillars", "pillar"],
	"scarab": ["scarabs", "scarab"],
	"laser": ["lasers", "laser"],
	"frozen": ["frozen", "frozen"],
}

@export var hazard_speed := 300.0  # px/s; negative starts the sweep moving left. Fall speed for chunks.
@export var phase := 0.0           # starting offset: px along the sweep, or seconds for blink / fall
@export var width := 256.0         # bar width; wider bars leave less room to slip past
@export var motion := WorldData.MOTION_SWEEP
@export var skin := "bar"          # "bar" is the jungle's logs and bamboo
@export var world := WorldData.JUNGLE
@export var fixed_x := 360.0       # centre of a fixed, blinking or falling hazard
@export var period := 2.0          # blink: seconds per cycle
@export var duty := 0.45           # blink: share of the cycle spent ON

var time := 0.0
# The level holds hazards still during its 3-2-1 intro.
var running := true

var _pieces: Array = []
var _base_y := 0.0
var _on := true         # blink: currently deadly
# Both start "on" so the first update switches the collision off if it should be.
var _chunk_shown := true  # fall: the chunk is on screen (and deadly)
var _warning := false     # fall: the landing shadow shows
var _drawn_last_frame := false


func _ready() -> void:
	# Each hazard gets its own shape, since the scene's shape is shared by every instance.
	var collision := $CollisionShape2D
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, (collision.shape as RectangleShape2D).size.y)
	match motion:
		WorldData.MOTION_FIXED:
			shape.size.y = WALL_HEIGHT
		WorldData.MOTION_BLINK:
			shape.size.y = BLINK_HEIGHT
		WorldData.MOTION_FALL:
			shape.size.y = FALL_HEIGHT
	collision.shape = shape
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_base_y = position.y

	if motion == WorldData.MOTION_FIXED:
		skin = "wall"
	if motion != WorldData.MOTION_BLINK and motion != WorldData.MOTION_FALL:
		_pieces = _bar_pieces()

	match motion:
		WorldData.MOTION_FIXED:
			position.x = fixed_x
			set_physics_process(false)
		WorldData.MOTION_BLINK:
			position.x = fixed_x
			_update_blink()
		WorldData.MOTION_FALL:
			position.x = fixed_x
			_update_fall()
		WorldData.MOTION_PENDULUM:
			_update_pendulum()
		_:
			_update_x()


func _physics_process(delta: float) -> void:
	if not running:
		return
	time += delta
	match motion:
		WorldData.MOTION_PENDULUM:
			_update_pendulum()
		WorldData.MOTION_BLINK:
			_update_blink()
		WorldData.MOTION_FALL:
			_update_fall()
		_:
			_update_x()


func _bar_pieces() -> Array:
	if skin == "bar":
		# Logs and bamboo alternate, picked from the bar's y so every run looks the same.
		if hash(int(position.y)) % 2 == 0:
			return WorldArt.bar_pieces(world, "logs", "log")
		return WorldArt.bar_pieces(world, "bamboo", "bamboo")
	var names: Array = BAR_SKINS.get(skin, BAR_SKINS["wall"])
	return WorldArt.bar_pieces(world, names[0], names[1])


func _update_x() -> void:
	# The bar's centre sweeps between half a width from each lane edge.
	position.x = width / 2.0 + pingpong(phase + hazard_speed * time, LANE_WIDTH - width)


# Swings between the same limits as a sweep. hazard_speed is the peak speed.
func _update_pendulum() -> void:
	var amplitude := (LANE_WIDTH - width) / 2.0
	var omega := hazard_speed / amplitude
	position.x = LANE_WIDTH / 2.0 + amplitude * sin(phase / amplitude + omega * time)


func _update_blink() -> void:
	var t := fposmod(time + phase, period)
	var on := t < period * duty
	if on != _on:
		_on = on
		$CollisionShape2D.set_deferred("disabled", not on)
		queue_redraw()
	# Flash red just before the row turns ON again.
	var warn := not on and t > period - BLINK_WARN_TIME
	modulate = Color(1.0, 0.45, 0.45) if warn and int(time * 14.0) % 2 == 0 else Color.WHITE


func _update_fall() -> void:
	var fall_time := FALL_BAND / hazard_speed
	var cycle := fall_time + FALL_REST_TIME + FALL_HIDDEN_TIME
	var t := fposmod(time + phase, cycle)
	var shown := t < fall_time + FALL_REST_TIME
	position.y = _base_y - FALL_BAND * (1.0 - t / fall_time) if t < fall_time else _base_y
	var warning := shown or t > cycle - FALL_WARN_TIME
	if shown != _chunk_shown:
		_chunk_shown = shown
		$CollisionShape2D.set_deferred("disabled", not shown)
	_warning = warning
	# Redraw while anything is on screen, and once more when it disappears.
	if shown or warning or _drawn_last_frame:
		queue_redraw()
	_drawn_last_frame = shown or warning


func _draw() -> void:
	var size: Vector2 = ($CollisionShape2D.shape as RectangleShape2D).size
	match motion:
		WorldData.MOTION_BLINK:
			_draw_blink(size)
		WorldData.MOTION_FALL:
			_draw_fall(size)
		_:
			_draw_bar(size)


# Drawn from the collision shape so what you see is exactly what hurts. The art
# is used whole and uncropped: the two end caps, with the middle piece repeated
# a whole number of times (each copy nudged a few percent wider or narrower so
# they fill the gap exactly, with no cut tile and no seam).
func _draw_bar(size: Vector2) -> void:
	var left: Texture2D = _pieces[0]
	var mid: Texture2D = _pieces[1]
	var right: Texture2D = _pieces[2]
	var top := -size.y / 2.0
	var cap_w := left.get_width() * ART_SCALE
	var x0 := -size.x / 2.0

	var inner := size.x - cap_w * 2.0
	var copies := maxi(1, roundi(inner / (mid.get_width() * ART_SCALE)))
	var tile_w := inner / copies

	draw_texture_rect(left, Rect2(x0, top, cap_w, size.y), false)
	for i in copies:
		draw_texture_rect(mid, Rect2(x0 + cap_w + i * tile_w, top, tile_w, size.y), false)
	draw_texture_rect(right, Rect2(x0 + size.x - cap_w, top, cap_w, size.y), false)


# A row of tiles across the lane: the "on" picture while deadly, the "off" one while safe.
func _draw_blink(size: Vector2) -> void:
	var tex := WorldArt.texture(world, "hazards/%s_%s" % [skin, "on" if _on else "off"])
	var tile_w := size.y * 2.0  # the pictures are 2:1
	var copies := maxi(1, roundi(size.x / tile_w))
	var step := size.x / copies
	for i in copies:
		draw_texture_rect(tex, Rect2(-size.x / 2.0 + i * step, -size.y / 2.0, step, size.y), false)


# The chunk, plus a shadow on the spot it will land on.
func _draw_fall(size: Vector2) -> void:
	if not _warning and not _chunk_shown:
		return
	var landing := _base_y - position.y  # local y of the landing spot
	draw_set_transform(Vector2(0.0, landing), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, size.x / 2.0, SHADOW_COLOR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _chunk_shown:
		draw_texture_rect(WorldArt.texture(world, "hazards/%s" % skin), Rect2(-size.x / 2.0, -size.y / 2.0, size.x, size.y), false)
