extends Control

# A row of stars drawn as shapes (no font needed): `filled` bright ones, the rest dim.
# Used on the level-complete panel and under each level button.

const FILLED_COLOR := Color("ffd23f")
const EMPTY_COLOR := Color(1.0, 1.0, 1.0, 0.22)
const OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.6)

var filled := 0
var total := 3
var star_size := 28.0


func _init(filled_count := 0, size_px := 28.0, total_count := 3) -> void:
	filled = filled_count
	star_size = size_px
	total = total_count
	custom_minimum_size = Vector2(star_size * total * 1.15, star_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var step := size.x / total
	for i in total:
		var centre := Vector2(step * (i + 0.5), size.y / 2.0)
		var outline := _star_points(centre, star_size * 0.5)
		draw_colored_polygon(outline, FILLED_COLOR if i < filled else EMPTY_COLOR)
		draw_polyline(outline + PackedVector2Array([outline[0]]), OUTLINE_COLOR, 2.0)


# Five-pointed star: outer and inner points alternate.
func _star_points(centre: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 10:
		var r := radius if i % 2 == 0 else radius * 0.45
		var angle := -PI / 2.0 + i * PI / 5.0
		points.append(centre + Vector2(cos(angle), sin(angle)) * r)
	return points
