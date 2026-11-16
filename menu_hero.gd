extends Control

# The menu's 3D character: faces the player, spins on its own, and can be orbited, zoomed and slid.

const CharacterView := preload("res://character_view.gd")

const VIEW_SIZE := 1536
# The render covers this many times the character's frame, so zooming never meets the picture's edge.
const EXTENT := 2.4
const DRAG_RADIANS_PER_PIXEL := 0.012

var _view: Node2D
var _dragging := false
var _panning := false


func _ready() -> void:
	clip_contents = false   # a zoomed-in character may spill past the box instead of being cut off
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
	_view.view_extent = EXTENT
	_view.character = index
	add_child(_view)
	_view.play(&"idle")
	_fit()


# Centres the render and scales it to the space available.
func _fit() -> void:
	if _view == null:
		return
	_view.position = size / 2.0
	var s := minf(size.x, size.y) / VIEW_SIZE * 1.15 * EXTENT
	_view.scale = Vector2.ONE * s


# One finger / left mouse: orbit (sideways = spin, up/down = tilt). Two fingers: pinch to zoom and
# drag to slide up/down. Mouse: wheel zooms, right/middle drag slides, double click resets.
var _touches := {}
var _pinch_dist := 0.0


func _gui_input(event: InputEvent) -> void:
	if _view == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			if mb.pressed and mb.double_click:
				_view.reset_view()
		elif mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_view.zoom_by(1.12)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_view.zoom_by(1.0 / 1.12)
	elif event is InputEventMouseMotion:
		var rel: Vector2 = event.relative
		if _panning:
			_view.pan_by(rel / VIEW_SCREEN())
		elif _dragging and _touches.size() < 2:
			_orbit(rel)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
		_pinch_dist = 0.0
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if _touches.size() >= 2:
			var pts := _touches.values()
			var d: float = (pts[0] - pts[1]).length()
			if _pinch_dist > 0.0 and d > 0.0:
				_view.zoom_by(d / _pinch_dist)
			_pinch_dist = d
			_view.pan_by(sd.relative * 0.5 / VIEW_SCREEN())
		# One finger orbits through the emulated mouse events above.


func _orbit(rel: Vector2) -> void:
	_view.rotate_by(rel.x * DRAG_RADIANS_PER_PIXEL)
	_view.pitch_by(rel.y * DRAG_RADIANS_PER_PIXEL)


func VIEW_SCREEN() -> float:
	return maxf(minf(size.x, size.y) * 1.15, 1.0)
