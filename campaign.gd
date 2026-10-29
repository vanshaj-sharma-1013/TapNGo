extends "res://level.gd"

# Runs levels 1-10: builds the chosen level from level_data.gd.

const LevelData = preload("res://level_data.gd")

const HAZARD_SCENE := preload("res://hazard.tscn")
const CHECKPOINT_SCENE := preload("res://checkpoint.tscn")
const FINISH_SCENE := preload("res://finish_line.tscn")
const ZONE_SCENE := preload("res://status_zone.tscn")


func _ready() -> void:
	level_number = GameData.selected_level
	super()


func _setup_world() -> void:
	var data: Dictionary = LevelData.get_level(level_number)

	var hazards := Node2D.new()
	hazards.name = "Hazards"
	add_child(hazards)
	for entry in data["hazards"]:
		var hazard = HAZARD_SCENE.instantiate()
		hazard.position = Vector2(0.0, entry["y"])
		hazard.phase = entry["phase"]
		hazard.hazard_speed = entry["speed"]
		hazard.width = entry["width"]
		hazard.sweeps = entry.get("sweeps", true)
		hazard.fixed_x = entry.get("x", 360.0)
		hazards.add_child(hazard)
		# Level 1 is hand-tuned and left as it was, so only check generated sweeping bars.
		if level_number > 1 and hazard.sweeps and LevelData.open_time(entry["width"], entry["speed"]) < LevelData.WARN_OPEN_TIME:
			push_warning("Level %d: bar at y=%d leaves only %.2fs to slip past" % [
				level_number, entry["y"], LevelData.open_time(entry["width"], entry["speed"])])

	for entry in data["zones"]:
		var zone = ZONE_SCENE.instantiate()
		zone.position = Vector2(entry["x"], entry["y"])
		zone.kind = entry["kind"]
		zone.width = LevelData.ZONE_WIDTH
		add_child(zone)

	for y in data["checkpoints"]:
		var checkpoint = CHECKPOINT_SCENE.instantiate()
		checkpoint.position = Vector2(0.0, y)
		checkpoint.reached.connect(_on_checkpoint_reached)
		add_child(checkpoint)

	finish_line = FINISH_SCENE.instantiate()
	finish_line.position = Vector2(0.0, data["finish_y"])
	finish_line.reached.connect(_on_finished)
	add_child(finish_line)

	_set_hud("Level %d" % level_number)


func _hint_text() -> String:
	match level_number:
		1:
			return "Hold anywhere to move forward.\nUse the side buttons to steer."
		6:
			return "Fire burns you in 10 seconds.\nIce puts it out, but freezes and slows you."
		8:
			return "Walls never move.\nSteer through the gaps."
	return ""


func _finish_options() -> Array:
	var options := super()
	if level_number < LevelData.LEVEL_COUNT:
		options.push_front(["Next Level", _next_level])
	return options


func _next_level() -> void:
	GameData.selected_level = level_number + 1
	_restart()
