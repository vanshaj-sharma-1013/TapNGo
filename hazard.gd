extends Area2D

# A bar that sweeps left and right across the lane. Its x is a pure function of
# the time since it was created: no randomness, so the same pattern plays out
# the same way every run.

const LANE_WIDTH := 720.0
# Art is drawn at 4x and shown at 0.4x, like the character.
const ART_SCALE := 0.4
# Fixed walls are 96px tall in the art, so their hitbox is that tall too.
const WALL_HEIGHT := 96.0 * ART_SCALE

# Danger cue drawn around every bar so it reads against the jungle floor.
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.5)
const OUTLINE_COLOR := Color("ffd23f")  # sweeping bars
const WALL_OUTLINE_COLOR := Color("ff3b3b")  # fixed walls

# Each skin is [left cap, tiling middle, right cap].
const LOG_SKIN := [
	preload("res://assets/themes/jungle/logs/log_left.png"),
	preload("res://assets/themes/jungle/logs/log_mid.png"),
	preload("res://assets/themes/jungle/logs/log_right.png"),
]
const BAMBOO_SKIN := [
	preload("res://assets/themes/jungle/bamboo/bamboo_left.png"),
	preload("res://assets/themes/jungle/bamboo/bamboo_mid.png"),
	preload("res://assets/themes/jungle/bamboo/bamboo_right.png"),
]
const WALL_SKIN := [
	preload("res://assets/themes/jungle/walls/wall_left.png"),
	preload("res://assets/themes/jungle/walls/wall_mid.png"),
	preload("res://assets/themes/jungle/walls/wall_right.png"),
]

@export var hazard_speed := 300.0  # px/s; negative starts the sweep moving left
@export var phase := 0.0           # starting offset along the sweep, in px
@export var width := 256.0         # bar width; wider bars leave less room to slip past
# A bar with sweeps = false never moves: it is a wall the player must steer around.
@export var sweeps := true
@export var fixed_x := 360.0       # centre of a fixed wall

var time := 0.0
# The level holds sweeping bars still during its 3-2-1 intro.
var running := true
var _skin: Array = LOG_SKIN


func _ready() -> void:
	# Each bar gets its own shape, since the scene's shape is shared by every instance.
	var collision := $CollisionShape2D
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, (collision.shape as RectangleShape2D).size.y)
	if sweeps:
		# Logs and bamboo alternate, picked from the bar's y so every run looks the same.
		_skin = LOG_SKIN if hash(int(position.y)) % 2 == 0 else BAMBOO_SKIN
	else:
		_skin = WALL_SKIN
		shape.size.y = WALL_HEIGHT
	collision.shape = shape
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if sweeps:
		_update_x()
	else:
		position.x = fixed_x
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not running:
		return
	time += delta
	_update_x()


func _update_x() -> void:
	# The bar's centre sweeps between half a width from each lane edge.
	position.x = width / 2.0 + pingpong(phase + hazard_speed * time, LANE_WIDTH - width)


func _draw() -> void:
	# Drawn from the collision shape so what you see is exactly what hurts. The art
	# is used whole and uncropped: the two end caps, with the middle piece repeated
	# a whole number of times (each copy nudged a few percent wider or narrower so
	# they fill the gap exactly, with no cut tile and no seam).
	var size: Vector2 = ($CollisionShape2D.shape as RectangleShape2D).size
	var left: Texture2D = _skin[0]
	var mid: Texture2D = _skin[1]
	var right: Texture2D = _skin[2]
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
