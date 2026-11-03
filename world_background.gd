extends Node2D

# Scrolling floor with a strip along both lane edges, in the style of a world. The
# camera only moves up and down, so tiles are redrawn only when the first visible row
# changes. Endless mode passes `world_at_y` (y -> world), so the floor changes as the
# player climbs from one world to the next.

const WorldData = preload("res://world_data.gd")
const WorldArt = preload("res://world_art.gd")

# Art is drawn at 4x and shown at 0.4x, like everything else.
const ART_SCALE := 0.4
const LANE_WIDTH := 720.0
# The jungle floor art has a light ~6px rim, which shows as grid lines when tiled, so a
# little of each tile's border is cropped (this fraction of its size, 8 of 720px).
const GROUND_CROP := 8.0 / 720.0
# Floor and edge strips are laid out with the jungle art's measurements, whatever the
# size of a world's pictures, so rows from different worlds line up.
const TILE := 704.0 * ART_SCALE
const GROUND_W := 704.0 * ART_SCALE
const EDGE_W := 200.0 * ART_SCALE

var world := 0
var world_at_y := Callable()

var _first_row := 0x7fffffff
var _snow: CPUParticles2D
var _time := 0.0


func _init(start_world := 0, world_lookup := Callable()) -> void:
	world = start_world
	world_at_y = world_lookup


func _ready() -> void:
	z_index = -100
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_snow = _make_snow()
	add_child(_snow)


func _process(delta: float) -> void:
	_time += delta
	var top := -get_viewport().get_canvas_transform().origin.y
	var centre_world := _world_at(top + get_viewport_rect().size.y * 0.5)

	var row := floori(top / TILE) - 1
	if row != _first_row:
		_first_row = row
		queue_redraw()

	# Snow follows the top of the view; falling flakes stay with the screen.
	_snow.position = Vector2(LANE_WIDTH / 2.0, top - 40.0)
	_snow.emitting = centre_world == WorldData.FROST
	# The grid pulses slowly.
	var glow := 0.85 + 0.15 * sin(_time * 2.5) if centre_world == WorldData.CYBER else 1.0
	modulate = Color(glow, glow, glow)


func _world_at(y: float) -> int:
	return world_at_y.call(y) if world_at_y.is_valid() else world


func _draw() -> void:
	var rows := ceili(get_viewport_rect().size.y / TILE) + 3
	for i in rows:
		var y := (_first_row + i) * TILE
		var row_world := _world_at(y + TILE / 2.0)
		var rules := WorldData.world(row_world)
		var tint: Color = rules["ground_tint"]
		var ground := WorldArt.texture(row_world, "environment/ground_tile")
		var crop := ground.get_size() * float(rules.get("ground_crop", GROUND_CROP))
		var source := Rect2(crop, ground.get_size() - crop * 2.0)
		var x := 0.0
		while x < LANE_WIDTH:
			# A little overlap hides sub-pixel gaps between tiles.
			draw_texture_rect_region(ground, Rect2(x, y, GROUND_W + 1.0, TILE + 1.0), source, tint)
			x += GROUND_W
		draw_texture_rect(WorldArt.texture(row_world, "environment/edge_left"), Rect2(0.0, y, EDGE_W, TILE + 1.0), false, tint)
		draw_texture_rect(WorldArt.texture(row_world, "environment/edge_right"), Rect2(LANE_WIDTH - EDGE_W, y, EDGE_W, TILE + 1.0), false, tint)


func _make_snow() -> CPUParticles2D:
	var snow := CPUParticles2D.new()
	snow.emitting = false
	snow.local_coords = true
	snow.amount = 70
	snow.lifetime = 9.0
	snow.preprocess = 4.0
	snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow.emission_rect_extents = Vector2(LANE_WIDTH / 2.0, 1.0)
	snow.direction = Vector2(0.15, 1.0)
	snow.spread = 12.0
	snow.gravity = Vector2.ZERO
	snow.initial_velocity_min = 90.0
	snow.initial_velocity_max = 170.0
	snow.scale_amount_min = 2.0
	snow.scale_amount_max = 5.0
	snow.color = Color(1.0, 1.0, 1.0, 0.8)
	snow.z_index = 50
	return snow
