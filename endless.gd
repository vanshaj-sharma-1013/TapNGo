extends "res://level.gd"

# Endless mode: an infinite lane built from a few fixed hazard patterns.
# Each pattern is deterministic; only the order they appear in is random.
# The world changes every 500 m (WorldData.ENDLESS_SEGMENT_PX): Jungle, Pyramids,
# Cyber Grid, Frostbite Summit, then round again. Every world is open, and the speed
# keeps rising across the loops.
# Score = metres climbed (best progress, so reviving doesn't lower it).

const HAZARD_SCENE := preload("res://hazard.tscn")
const CHECKPOINT_SCENE := preload("res://checkpoint.tscn")
const ZONE_SCENE := preload("res://status_zone.tscn")

# Sweeping-bar patterns, used by every world (drawn in that world's bar skin).
# Each is a list of [dy, phase, speed]: dy is how far ahead (up, <= 0)
# of the pattern's start the bar sits, phase/speed as in hazard.gd.
# Ordered easy -> hard; harder ones unlock as the run goes on.
const PATTERNS := [
	[[0.0, 0.0, 220.0]],
	[[0.0, 100.0, 300.0]],
	[[0.0, 0.0, 260.0], [-300.0, 232.0, -260.0]],
	[[0.0, 0.0, 280.0], [-260.0, 232.0, -300.0], [-520.0, 464.0, 280.0]],
	[[0.0, 0.0, 320.0], [-170.0, 232.0, -320.0]],
	[[0.0, 0.0, 420.0], [-220.0, 300.0, -420.0]],
]

const SPECIAL_CHANCE := 0.4

const SPAWN_AHEAD := 2400.0           # how far above the player hazards exist
const KEEP_BEHIND_CHECKPOINT := 600.0 # keep hazards this far below the respawn point
const CHECKPOINT_EVERY := 3000.0
const CHECKPOINT_CLEARANCE := 250.0   # no hazards this close to a checkpoint
const RUN_UP := 700.0                 # empty lane before the first pattern
const PIXELS_PER_METRE := 50.0
const MAX_DIFFICULTY_DISTANCE := 100000.0  # px at which difficulty tops out (one full loop of worlds)
const MAX_SPEED_SCALE := 1.8
const GAP_EASY := 450.0               # space between patterns at the start...
const GAP_HARD := 260.0               # ...and at max difficulty
const ZONE_WIDTH := 300.0
const BANNER_TIME := 1.6

var cursor_y := 0.0
var next_checkpoint_y := 0.0
var best_progress := 0.0
var spawned: Node2D
var new_best := false
var rng := RandomNumberGenerator.new()
var current_world := WorldData.JUNGLE
var special_patterns: Array = []


# Extra patterns that show off each world's own hazards, by world index. Entries are
# Dictionaries: a hazard (dy, motion, skin, width, x, speed, phase, period) or a zone
# (dy, zone, x); a plain [dy, phase, speed] bar can be mixed in. They are picked now
# and then instead of a bar pattern.
func _make_special_patterns() -> Array:
	return [
		[  # Jungle
			[[0.0, 0.0, 280.0], {"dy": -260.0, "zone": WorldData.ZONE_FIRE, "x": 360.0}],
			[[0.0, 100.0, 300.0], {"dy": -260.0, "zone": WorldData.ZONE_ICE, "x": 150.0}],
		],
		[  # Pyramids
			[
				{"dy": 0.0, "motion": WorldData.MOTION_PENDULUM, "skin": "scarab", "speed": 300.0, "phase": 0.0},
				{"dy": -300.0, "motion": WorldData.MOTION_PENDULUM, "skin": "scarab", "speed": -300.0, "phase": 100.0},
			],
			[{"dy": 0.0, "motion": WorldData.MOTION_BLINK, "skin": "trapdoor", "width": 720.0, "x": 360.0, "period": 3.0, "phase": 0.5}],
			[{"dy": 0.0, "zone": WorldData.ZONE_QUICKSAND, "x": 360.0}, [-300.0, 0.0, 260.0]],
		],
		[  # Cyber Grid
			[{"dy": 0.0, "motion": WorldData.MOTION_BLINK, "skin": "pulse", "width": 720.0, "x": 360.0, "period": 2.4, "phase": 0.0}],
			[{"dy": 0.0, "zone": WorldData.ZONE_GLITCH, "x": 360.0}, [-300.0, 0.0, 320.0]],
		],
		[  # Frostbite Summit
			[
				{"dy": 0.0, "motion": WorldData.MOTION_FALL, "skin": "debris", "width": 144.0, "x": 150.0, "speed": 800.0, "phase": 0.0},
				{"dy": 0.0, "motion": WorldData.MOTION_FALL, "skin": "debris", "width": 144.0, "x": 570.0, "speed": 800.0, "phase": 1.6},
			],
			[{"dy": 0.0, "zone": WorldData.ZONE_FROST, "x": 360.0}, [-300.0, 0.0, 280.0]],
		],
	]


func _setup_world() -> void:
	Cloud.start_run()
	rng.randomize()
	special_patterns = _make_special_patterns()
	cursor_y = start_y - RUN_UP
	next_checkpoint_y = start_y - CHECKPOINT_EVERY
	spawned = Node2D.new()
	spawned.name = "Spawned"
	add_child(spawned)
	_spawn_ahead()
	_update_hud()


# The floor changes world as the player climbs, so it asks which world each row is in.
func _make_background() -> Node2D:
	return WorldBackground.new(WorldData.JUNGLE, _world_at_y)


# World of the lane at height y: a new one every ENDLESS_SEGMENT_PX climbed.
func _world_at_y(y: float) -> int:
	var climbed := start_y - y
	if climbed < 0.0:
		return WorldData.JUNGLE
	return int(climbed / WorldData.ENDLESS_SEGMENT_PX) % WorldData.WORLD_COUNT


func _physics_process(_delta: float) -> void:
	best_progress = maxf(best_progress, start_y - player.global_position.y)
	_update_world()
	_spawn_ahead()
	_despawn_behind()
	_update_hud()


# Switches the player's movement rules (and says so) when they cross into another world.
func _update_world() -> void:
	var here := _world_at_y(player.global_position.y)
	if here == current_world:
		return
	current_world = here
	player.apply_world(here)
	_show_banner("WORLD: %s" % WorldData.world_name(here).to_upper(), 0.3, 52, WorldData.world(here)["accent"], BANNER_TIME)


func _intro_title() -> String:
	return "Endless"


func _crash_title() -> String:
	return "Crashed!\nScore %d\nBest %d" % [_score(), GameData.best_endless]


func _on_run_crashed() -> void:
	new_best = GameData.submit_endless_score(_score()) or new_best


# The revive is spent: show the result instead of restarting blindly.
func _on_final_crash() -> void:
	var title := "Game Over\nScore %d\nBest %d" % [_score(), GameData.best_endless]
	if new_best:
		title += "\nNEW BEST!"
	_show_panel(title, [
		["Play Again", _restart],
		["Menu", _go_to_menu],
	])


# The respawn point may be in an earlier world than where the player died.
func _grant_revive() -> void:
	super()
	current_world = _world_at_y(respawn_point.y)
	player.apply_world(current_world)


func _score() -> int:
	return int(best_progress / PIXELS_PER_METRE)


func _difficulty() -> float:
	return clampf(best_progress / MAX_DIFFICULTY_DISTANCE, 0.0, 1.0)


func _update_hud() -> void:
	_set_hud("%d m    Best %d" % [_score(), maxi(GameData.best_endless, _score())])


func _spawn_ahead() -> void:
	var limit_y: float = player.global_position.y - SPAWN_AHEAD
	while cursor_y > limit_y:
		var difficulty := _difficulty()
		var world_index := _world_at_y(cursor_y)
		var pattern: Array = _pick_pattern(world_index, difficulty)
		var length := _pattern_length(pattern)

		# If this pattern would run into the next checkpoint, put the checkpoint down first.
		if cursor_y - length - CHECKPOINT_CLEARANCE < next_checkpoint_y:
			_spawn_checkpoint(next_checkpoint_y)
			cursor_y = minf(cursor_y, next_checkpoint_y - CHECKPOINT_CLEARANCE)
			next_checkpoint_y -= CHECKPOINT_EVERY
			continue

		var speed_scale := lerpf(1.0, MAX_SPEED_SCALE, difficulty)
		for entry in pattern:
			_spawn_entry(entry, cursor_y, world_index, speed_scale)
		cursor_y -= length + lerpf(GAP_EASY, GAP_HARD, difficulty)


func _pick_pattern(world_index: int, difficulty: float) -> Array:
	var specials: Array = special_patterns[world_index]
	if rng.randf() < SPECIAL_CHANCE:
		return specials[rng.randi_range(0, specials.size() - 1)]
	return PATTERNS[_pick_pattern_index(difficulty)]


func _pick_pattern_index(difficulty: float) -> int:
	# Starts with the first 2 patterns and unlocks one more every quarter of the ramp.
	var pool_size := 2 + int(difficulty * (PATTERNS.size() - 2 + 0.999))
	return rng.randi_range(0, pool_size - 1)


func _pattern_length(pattern: Array) -> float:
	var length := 0.0
	for entry in pattern:
		length = maxf(length, -_entry_dy(entry))
	return length


func _entry_dy(entry) -> float:
	return entry["dy"] if entry is Dictionary else entry[0]


# Builds one item of a pattern at `base_y`: a bar, a special hazard or a zone.
func _spawn_entry(entry, base_y: float, world_index: int, speed_scale: float) -> void:
	var y := base_y + _entry_dy(entry)
	if entry is Array:
		_spawn_hazard(y, world_index, {"phase": entry[1], "speed": entry[2] * speed_scale})
	elif entry.has("zone"):
		_spawn_zone(y, world_index, entry)
	else:
		var props: Dictionary = entry.duplicate()
		if props.has("speed") and props["motion"] != WorldData.MOTION_FALL:
			props["speed"] = props["speed"] * speed_scale
		_spawn_hazard(y, world_index, props)


func _spawn_hazard(y: float, world_index: int, props: Dictionary) -> void:
	var hazard = HAZARD_SCENE.instantiate()
	hazard.position = Vector2(0.0, y)
	hazard.world = world_index
	hazard.motion = props.get("motion", WorldData.MOTION_SWEEP)
	# Plain bars wear the world's own bar skin.
	hazard.skin = props.get("skin", WorldData.world(world_index)["hazards"][0]["skin"])
	hazard.phase = props.get("phase", 0.0)
	hazard.hazard_speed = props.get("speed", 0.0)
	hazard.width = props.get("width", 256.0)
	hazard.fixed_x = props.get("x", 360.0)
	hazard.period = props.get("period", 2.0)
	spawned.add_child(hazard)


func _spawn_zone(y: float, world_index: int, entry: Dictionary) -> void:
	var zone = ZONE_SCENE.instantiate()
	zone.position = Vector2(entry["x"], y)
	zone.kind = entry["zone"]
	zone.world = world_index
	zone.width = ZONE_WIDTH
	spawned.add_child(zone)


func _spawn_checkpoint(y: float) -> void:
	var checkpoint = CHECKPOINT_SCENE.instantiate()
	checkpoint.position = Vector2(0.0, y)
	checkpoint.world = _world_at_y(y)
	checkpoint.reached.connect(_on_checkpoint_reached)
	spawned.add_child(checkpoint)


# Frees everything well behind the respawn point; revives never land past it.
func _despawn_behind() -> void:
	var cutoff := respawn_point.y + KEEP_BEHIND_CHECKPOINT
	for node in spawned.get_children():
		if node.global_position.y > cutoff:
			node.queue_free()
