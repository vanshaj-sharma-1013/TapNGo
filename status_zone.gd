extends Area2D

# A fixed fire or ice patch, always on. It covers only part of the lane (see
# width) so the player can steer around it with the side buttons.
# The node's position is the patch's centre.

enum Kind { FIRE, ICE }

const FIRE_FRAMES := [
	preload("res://assets/themes/jungle/hazards/fire_patch_00.png"),
	preload("res://assets/themes/jungle/hazards/fire_patch_01.png"),
	preload("res://assets/themes/jungle/hazards/fire_patch_02.png"),
]
const ICE_TEXTURE := preload("res://assets/themes/jungle/hazards/ice_patch.png")
const FIRE_FRAME_MS := 150

@export var kind := Kind.FIRE
@export var width := 300.0
@export var height := 120.0

var _frame := 0


func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, height)
	$CollisionShape2D.shape = shape
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(kind == Kind.FIRE)  # only fire is animated


func _process(_delta: float) -> void:
	var frame := (Time.get_ticks_msec() / FIRE_FRAME_MS) % FIRE_FRAMES.size()
	if frame != _frame:
		_frame = frame
		queue_redraw()


func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			if kind == Kind.FIRE:
				body.ignite()
			else:
				body.freeze()


func _draw() -> void:
	var texture: Texture2D = FIRE_FRAMES[_frame] if kind == Kind.FIRE else ICE_TEXTURE
	draw_texture_rect(texture, Rect2(-width / 2.0, -height / 2.0, width, height), false)
