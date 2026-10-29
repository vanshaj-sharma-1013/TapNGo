extends Node2D

# Scrolling jungle floor with foliage along both lane edges. The camera only moves
# up and down, so tiles are redrawn only when the first visible row changes.

const GROUND := preload("res://assets/themes/jungle/environment/ground_tile.png")
const EDGE_LEFT := preload("res://assets/themes/jungle/environment/edge_left.png")
const EDGE_RIGHT := preload("res://assets/themes/jungle/environment/edge_right.png")

# Art is drawn at 4x and shown at 0.4x, like everything else.
const ART_SCALE := 0.4
const LANE_WIDTH := 720.0

# The ground art has a light ~6px rim, which shows as grid lines when tiled, so only
# the inside of the tile is used.
const GROUND_CROP := 8.0
# Dims the floor so the hazards stand out against it.
const GROUND_DIM := Color(0.55, 0.6, 0.55)

var _ground_src := Rect2(GROUND_CROP, GROUND_CROP, GROUND.get_width() - 2.0 * GROUND_CROP, GROUND.get_height() - 2.0 * GROUND_CROP)
var _tile := _ground_src.size.y * ART_SCALE  # ground and edge strips share this height
var _first_row := 0x7fffffff


func _ready() -> void:
	z_index = -100
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(_delta: float) -> void:
	var top := -get_viewport().get_canvas_transform().origin.y
	var row := floori(top / _tile) - 1
	if row != _first_row:
		_first_row = row
		queue_redraw()


func _draw() -> void:
	var rows := ceili(get_viewport_rect().size.y / _tile) + 3
	var ground_w := _ground_src.size.x * ART_SCALE
	var edge_w := EDGE_LEFT.get_width() * ART_SCALE
	for i in rows:
		var y := (_first_row + i) * _tile
		var x := 0.0
		while x < LANE_WIDTH:
			# A little overlap hides sub-pixel gaps between tiles.
			draw_texture_rect_region(GROUND, Rect2(x, y, ground_w + 1.0, _tile + 1.0), _ground_src, GROUND_DIM)
			x += ground_w
		draw_texture_rect(EDGE_LEFT, Rect2(0.0, y, edge_w, _tile + 1.0), false, GROUND_DIM)
		draw_texture_rect(EDGE_RIGHT, Rect2(LANE_WIDTH - edge_w, y, edge_w, _tile + 1.0), false, GROUND_DIM)
