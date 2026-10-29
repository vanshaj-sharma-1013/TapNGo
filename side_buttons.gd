extends Control

# Draws the two steering buttons. Input is handled by the Controls autoload,
# so this node ignores the mouse and only reflects what is pressed.

const NEON_CYAN := Color("00e5ff")

var _left_down := false
var _right_down := false
var _settings_key := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	var left := Controls.steer() < 0.0
	var right := Controls.steer() > 0.0
	var settings_key := "%s%s" % [GameData.button_layout, GameData.button_scale]
	if left != _left_down or right != _right_down or settings_key != _settings_key:
		_left_down = left
		_right_down = right
		_settings_key = settings_key
		queue_redraw()


func _draw() -> void:
	_draw_button(Controls.button_rect(Controls.ZONE_LEFT), -1.0, _left_down)
	_draw_button(Controls.button_rect(Controls.ZONE_RIGHT), 1.0, _right_down)


func _draw_button(rect: Rect2, direction: float, down: bool) -> void:
	var fill := Color(NEON_CYAN, 0.35 if down else 0.10)
	var outline := Color(NEON_CYAN, 1.0 if down else 0.5)
	draw_rect(rect, fill)
	draw_rect(rect, outline, false, 4.0)

	# Arrow pointing left (direction = -1) or right (direction = 1), scaled with the button.
	var k := rect.size.x / Controls.BASE_BUTTON_SIZE
	var c := rect.get_center()
	var tip := c + Vector2(direction * 44.0 * k, 0.0)
	var back_top := c + Vector2(-direction * 36.0 * k, -48.0 * k)
	var back_bottom := c + Vector2(-direction * 36.0 * k, 48.0 * k)
	draw_colored_polygon(PackedVector2Array([tip, back_top, back_bottom]), outline)
