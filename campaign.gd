extends "res://level.gd"

# Runs the campaign levels: builds the chosen level of the chosen world from level_data.gd.

const LevelData = preload("res://level_data.gd")

const HAZARD_SCENE := preload("res://hazard.tscn")
const CHECKPOINT_SCENE := preload("res://checkpoint.tscn")
const FINISH_SCENE := preload("res://finish_line.tscn")
const ZONE_SCENE := preload("res://status_zone.tscn")


func _ready() -> void:
	world = GameData.selected_world
	level_number = GameData.selected_level
	super()


func _setup_world() -> void:
	var data: Dictionary = LevelData.get_level(world, level_number)
	var check_gaps := not (world == WorldData.JUNGLE and level_number == 1)  # level 1 is hand-tuned

	var hazards := Node2D.new()
	hazards.name = "Hazards"
	add_child(hazards)
	for entry in data["hazards"]:
		var hazard = HAZARD_SCENE.instantiate()
		hazard.position = Vector2(0.0, entry["y"])
		hazard.world = world
		hazard.motion = entry.get("motion", WorldData.MOTION_SWEEP)
		hazard.skin = entry.get("skin", "bar")
		hazard.phase = entry.get("phase", entry.get("offset", 0.0))
		hazard.hazard_speed = entry.get("speed", 0.0)
		hazard.width = entry["width"]
		hazard.fixed_x = entry.get("x", 360.0)
		hazard.period = entry.get("period", 2.0)
		hazard.duty = entry.get("duty", 0.45)
		hazards.add_child(hazard)
		# Only check generated bars that move sideways.
		var sideways: bool = hazard.motion == WorldData.MOTION_SWEEP or hazard.motion == WorldData.MOTION_PENDULUM
		if check_gaps and sideways and LevelData.open_time(entry["width"], entry["speed"]) < LevelData.warn_open_time(world):
			push_warning("%s level %d: bar at y=%d leaves only %.2fs to slip past" % [
				WorldData.world_name(world), level_number, entry["y"], LevelData.open_time(entry["width"], entry["speed"])])

	for entry in data["zones"]:
		var zone = ZONE_SCENE.instantiate()
		zone.position = Vector2(entry["x"], entry["y"])
		zone.kind = entry["kind"]
		zone.world = world
		zone.width = LevelData.ZONE_WIDTH
		add_child(zone)

	for y in data["checkpoints"]:
		var checkpoint = CHECKPOINT_SCENE.instantiate()
		checkpoint.position = Vector2(0.0, y)
		checkpoint.world = world
		checkpoint.reached.connect(_on_checkpoint_reached)
		add_child(checkpoint)

	finish_line = FINISH_SCENE.instantiate()
	finish_line.set("world", world)
	finish_line.position = Vector2(0.0, data["finish_y"])
	finish_line.reached.connect(_on_finished)
	add_child(finish_line)

	_set_hud("%s  %d" % [WorldData.world_name(world), level_number])


func _intro_title() -> String:
	return "%s\nLevel %d" % [WorldData.world_name(world), level_number]


# One-time hints, each shown the first time its hazard appears. The hint id is saved in
# GameData, so ids are unique across worlds (world * 100 + level).
func _hint_text() -> String:
	if world == WorldData.JUNGLE:
		match level_number:
			1:
				return "Hold anywhere to move forward.\nUse the side buttons to steer."
			6:
				return "Fire burns you in 10 seconds.\nIce puts it out, but freezes and slows you."
			8:
				return "Walls never move.\nSteer through the gaps."
	elif world == WorldData.PYRAMIDS:
		match level_number:
			1:
				return "Sand makes steering loose.\nSteer early and let go in time."
			3:
				return "Scarab blades swing across the lane."
			5:
				return "Quicksand slows you down."
			8:
				return "Spiked trapdoors open and shut.\nWait for the spikes to drop."
	elif world == WorldData.CYBER:
		match level_number:
			1:
				return "Everything is faster here."
			4:
				return "Pulse barriers blink on and off.\nCross them while they are dark."
			7:
				return "Glitch zones swap left and right\nfor 2 seconds."
	elif world == WorldData.FROST:
		match level_number:
			1:
				return "Ice makes you slide when you let go.\nStop early."
			3:
				return "Avalanche! Watch the shadows\nto see where rocks land."
			6:
				return "Frost patches push you\nforward or back."
	return ""


func _hint_id() -> int:
	return world * 100 + level_number


func _finish_options() -> Array:
	var options := super()
	if level_number < WorldData.LEVELS_PER_WORLD:
		options.push_front(["Next Level", _next_level])
	return options


func _next_level() -> void:
	GameData.selected_level = level_number + 1
	_restart()
