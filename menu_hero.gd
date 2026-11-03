extends Control

# The menu's 3D character: faces the player, spins on its own, and can be dragged round 360 degrees.

const CharacterView := preload("res://character_view.gd")

const VIEW_SIZE := 640
const DRAG_RADIANS_PER_PIXEL := 0.012

var _view: Node2D
var _dragging := false


func _ready() -> void:
	clip_contents = true
	custom_minimum_size = Vector2(0, 200)
	resized.connect(_fit)
	show_character(GameData.selected_character)


# Replaces the model with the roster character at `index`.
func show_character(index: int) -> void:
	if _view != null:
		_view.queue_free()
	_view = CharacterView.new()
	_view.view_size = VIEW_SIZE
	_view.face_camera = true
	_view.free_rotate = true
	_view.character = index
	add_child(_view)
	_view.play(&"idle")
	_fit()


# Centres the render and scales it to the space available.
func _fit() -> void:
	if _view == null:
		return
	_view.position = size / 2.0
	var s := minf(size.x, size.y) / VIEW_SIZE * 1.15
	_view.scale = Vector2.ONE * s


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventScreenTouch:
		_dragging = event.pressed
	elif _dragging and event is InputEventMouseMotion:
		_view.rotate_by(event.relative.x * DRAG_RADIANS_PER_PIXEL)
	elif _dragging and event is InputEventScreenDrag:
		_view.rotate_by(event.relative.x * DRAG_RADIANS_PER_PIXEL)
