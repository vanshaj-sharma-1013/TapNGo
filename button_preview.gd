extends Control

# Settings preview: the bottom strip of the game screen at half size, showing where
# the two steering buttons will sit with the current layout and size.

const NEON_CYAN := Color("00e5ff")
const SCREEN := Vector2(720.0, 1280.0)
const STRIP_HEIGHT := 400.0
const PREVIEW_SCALE := 0.5


func _ready() -> void:
	custom_minimum_size = Vector2(SCREEN.x, STRIP_HEIGHT) * PREVIEW_SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.45))
	draw_rect(Rect2(Vector2.ZERO, size), Color(NEON_CYAN, 0.4), false, 2.0)
	_draw_button(Controls.ZONE_LEFT, -1.0)
	_draw_button(Controls.ZONE_RIGHT, 1.0)


func _draw_button(zone: String, direction: float) -> void:
	var full := Controls.layout_rect(zone, GameData.button_layout, GameData.button_scale, SCREEN)
	# Shift the strip to the top of the preview and shrink it.
	var rect := Rect2((full.position - Vector2(0.0, SCREEN.y - STRIP_HEIGHT)) * PREVIEW_SCALE, full.size * PREVIEW_SCALE)
	draw_rect(rect, Color(NEON_CYAN, 0.12))
	draw_rect(rect, Color(NEON_CYAN, 0.7), false, 2.0)
	var k := rect.size.x / Controls.BASE_BUTTON_SIZE
	var c := rect.get_center()
	var tip := c + Vector2(direction * 44.0 * k, 0.0)
	var back_top := c + Vector2(-direction * 36.0 * k, -48.0 * k)
	var back_bottom := c + Vector2(-direction * 36.0 * k, 48.0 * k)
	draw_colored_polygon(PackedVector2Array([tip, back_top, back_bottom]), Color(NEON_CYAN, 0.8))
