extends Node

# Autoload "Controls": turns touches / mouse / keyboard into three questions
# for the player: is_forward(), steer() and is_pressed(zone).
#
# Screen zones: two side buttons in the bottom corners (steer left / right) and
# everywhere else (forward). Each finger is tracked on its own, so one finger
# can hold "forward" while another taps a side button.
#
# Desktop testing: left-click anywhere = forward, W / Up / Space = forward,
# A / D or Left / Right = steer.

const ZONE_NONE := ""
const ZONE_LEFT := "left"
const ZONE_RIGHT := "right"
const ZONE_FORWARD := "forward"

const BASE_BUTTON_SIZE := 190.0
const BUTTON_MARGIN := 28.0
# Space between the two buttons when both sit on the same side.
const BUTTON_GAP := 24.0
# Touches land slightly outside the drawn button and still count.
const BUTTON_TOUCH_GROW := 16.0

var _touch_zones := {}  # finger index -> zone
var _mouse_zone := ZONE_NONE

# Screen area (e.g. the pause button) where a touch must not count as "forward".
var blocked_rect := Rect2()


# Forgets every held finger, e.g. when the game pauses and releases can't be seen.
func release_all() -> void:
	_touch_zones.clear()
	_mouse_zone = ZONE_NONE


# Drawn rectangle of a side button (zone is ZONE_LEFT or ZONE_RIGHT).
func button_rect(zone: String) -> Rect2:
	return layout_rect(zone, GameData.button_layout, GameData.button_scale, get_viewport().get_visible_rect().size)


# Where a side button sits for a given layout and size. Also used by the settings preview.
func layout_rect(zone: String, layout: String, button_scale: float, view: Vector2) -> Rect2:
	var size := BASE_BUTTON_SIZE * button_scale
	var y := view.y - BUTTON_MARGIN - size
	var x := BUTTON_MARGIN
	match layout:
		GameData.LAYOUT_LEFT:
			# Both on the left: steer-left, then steer-right next to it.
			x = BUTTON_MARGIN if zone == ZONE_LEFT else BUTTON_MARGIN + size + BUTTON_GAP
		GameData.LAYOUT_RIGHT:
			# Both on the right, steer-right in the outer corner.
			x = view.x - BUTTON_MARGIN - size if zone == ZONE_RIGHT else view.x - BUTTON_MARGIN - size * 2.0 - BUTTON_GAP
		_:
			x = BUTTON_MARGIN if zone == ZONE_LEFT else view.x - BUTTON_MARGIN - size
	return Rect2(x, y, size, size)


func is_forward() -> bool:
	return is_pressed(ZONE_FORWARD) \
			or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_SPACE)


# -1 = left, 0 = none, 1 = right. Pressing both cancels out.
func steer() -> float:
	var direction := 0.0
	if is_pressed(ZONE_LEFT) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction -= 1.0
	if is_pressed(ZONE_RIGHT) or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction += 1.0
	return direction


func is_pressed(zone: String) -> bool:
	return _mouse_zone == zone or _touch_zones.values().has(zone)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_zones[event.index] = _zone_at(event.position)
		else:
			_touch_zones.erase(event.index)
	elif event is InputEventScreenDrag:
		_slide(_touch_zones, event.index, event.position)
	# Touches also arrive as emulated mouse events; ignore those, the touch events above cover them.
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_mouse_zone = _zone_at(event.position) if event.pressed else ZONE_NONE
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		if _mouse_zone == ZONE_LEFT or _mouse_zone == ZONE_RIGHT:
			var zone := _zone_at(event.position)
			if zone == ZONE_LEFT or zone == ZONE_RIGHT:
				_mouse_zone = zone


func _notification(what: int) -> void:
	# Don't leave a button stuck on if the app loses focus mid-press.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		release_all()


# A finger that starts on a side button can slide to the other one without lifting.
func _slide(zones: Dictionary, index: int, position: Vector2) -> void:
	var current: String = zones.get(index, ZONE_NONE)
	if current == ZONE_LEFT or current == ZONE_RIGHT:
		var zone := _zone_at(position)
		if zone == ZONE_LEFT or zone == ZONE_RIGHT:
			zones[index] = zone


func _zone_at(position: Vector2) -> String:
	if blocked_rect.has_point(position):
		return ZONE_NONE
	if button_rect(ZONE_LEFT).grow(BUTTON_TOUCH_GROW).has_point(position):
		return ZONE_LEFT
	if button_rect(ZONE_RIGHT).grow(BUTTON_TOUCH_GROW).has_point(position):
		return ZONE_RIGHT
	return ZONE_FORWARD
