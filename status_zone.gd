extends Area2D

# A fixed patch on the lane, always on. What it does to the player depends on its kind:
# fire burns, ice freezes and slows, quicksand slows, a glitch zone swaps left and right,
# a frost patch pushes the player along the lane. It covers only part of the lane (see
# width) so the player can steer around it with the side buttons.
# The node's position is the patch's centre.

const WorldData = preload("res://world_data.gd")
const WorldArt = preload("res://world_art.gd")

const FIRE_FRAME_COUNT := 3
const FIRE_FRAME_MS := 150
# Shrinks the painted area a little so stray sparks and snowflakes don't widen the effect.
const PUDDLE_INSET := 0.9
const OUTLINE_POINTS := 24

@export var kind := WorldData.ZONE_FIRE
@export var world := WorldData.JUNGLE
@export var width := 300.0
@export var height := 120.0

var _frames: Array = []
var _frame := 0


func _ready() -> void:
	_frames = _load_frames()
	$CollisionPolygon2D.polygon = _puddle_outline()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(kind == WorldData.ZONE_FIRE)  # only fire is animated


func _load_frames() -> Array:
	match kind:
		WorldData.ZONE_FIRE:
			var frames: Array = []
			for i in FIRE_FRAME_COUNT:
				frames.append(WorldArt.texture(world, "hazards/fire_patch_%02d" % i))
			return frames
		WorldData.ZONE_ICE:
			return [WorldArt.texture(world, "hazards/ice_patch")]
		WorldData.ZONE_QUICKSAND:
			return [WorldArt.texture(world, "hazards/quicksand")]
		WorldData.ZONE_GLITCH:
			return [WorldArt.texture(world, "hazards/glitch")]
	return [WorldArt.texture(world, "hazards/frost_patch")]


# The art has transparent margins, so the effect area is an ellipse fitted to the
# painted part of the picture, not the whole width x height box it is drawn into.
func _puddle_outline() -> PackedVector2Array:
	var used := Rect2()
	for texture: Texture2D in _frames:
		var painted := texture.get_image().get_used_rect()
		var to_box := Vector2(width, height) / Vector2(texture.get_size())
		var rect := Rect2(Vector2(painted.position) * to_box, Vector2(painted.size) * to_box)
		used = rect if used.size == Vector2.ZERO else used.merge(rect)

	var centre := used.get_center() - Vector2(width, height) / 2.0
	var radius := used.size / 2.0 * PUDDLE_INSET
	var points := PackedVector2Array()
	for i in OUTLINE_POINTS:
		var angle := TAU * i / OUTLINE_POINTS
		points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _process(_delta: float) -> void:
	var frame := (Time.get_ticks_msec() / FIRE_FRAME_MS) % _frames.size()
	if frame != _frame:
		_frame = frame
		queue_redraw()


func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if not body.is_in_group("player"):
			continue
		match kind:
			WorldData.ZONE_FIRE:
				body.ignite()
			WorldData.ZONE_ICE:
				body.freeze()
			WorldData.ZONE_QUICKSAND:
				body.mire()
			WorldData.ZONE_GLITCH:
				body.scramble()
			WorldData.ZONE_FROST:
				body.slip()


func _draw() -> void:
	var texture: Texture2D = _frames[_frame]
	draw_texture_rect(texture, Rect2(-width / 2.0, -height / 2.0, width, height), false)
