extends "res://level.gd"

# Endless mode: an infinite lane built from a few fixed hazard patterns.
# Each pattern is deterministic; only the order they appear in is random.
# Score = metres climbed (best progress, so reviving doesn't lower it).

const HAZARD_SCENE := preload("res://hazard.tscn")
const CHECKPOINT_SCENE := preload("res://checkpoint.tscn")

# Each pattern is a list of [dy, phase, speed]: dy is how far ahead (up, <= 0)
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

const SPAWN_AHEAD := 2400.0           # how far above the player hazards exist
const KEEP_BEHIND_CHECKPOINT := 600.0 # keep hazards this far below the respawn point
const CHECKPOINT_EVERY := 3000.0
const CHECKPOINT_CLEARANCE := 250.0   # no hazards this close to a checkpoint
const RUN_UP := 700.0                 # empty lane before the first pattern
const PIXELS_PER_METRE := 50.0
const MAX_DIFFICULTY_DISTANCE := 20000.0  # px at which difficulty tops out
const MAX_SPEED_SCALE := 1.8
const GAP_EASY := 450.0               # space between patterns at the start...
const GAP_HARD := 260.0               # ...and at max difficulty

var start_y := 0.0
var cursor_y := 0.0
var next_checkpoint_y := 0.0
var best_progress := 0.0
var spawned: Node2D
var new_best := false
var rng := RandomNumberGenerator.new()


func _setup_world() -> void:
	Cloud.start_run()
	rng.randomize()
	start_y = player.global_position.y
	cursor_y = start_y - RUN_UP
	next_checkpoint_y = start_y - CHECKPOINT_EVERY
	spawned = Node2D.new()
	spawned.name = "Spawned"
	add_child(spawned)
	_spawn_ahead()
	_update_hud()


func _physics_process(_delta: float) -> void:
	best_progress = maxf(best_progress, start_y - player.global_position.y)
	_spawn_ahead()
	_despawn_behind()
	_update_hud()


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
		var pattern: Array = PATTERNS[_pick_pattern_index(difficulty)]
		var length := _pattern_length(pattern)

		# If this pattern would run into the next checkpoint, put the checkpoint down first.
		if cursor_y - length - CHECKPOINT_CLEARANCE < next_checkpoint_y:
			_spawn_checkpoint(next_checkpoint_y)
			cursor_y = minf(cursor_y, next_checkpoint_y - CHECKPOINT_CLEARANCE)
			next_checkpoint_y -= CHECKPOINT_EVERY
			continue

		var speed_scale := lerpf(1.0, MAX_SPEED_SCALE, difficulty)
		for entry in pattern:
			_spawn_hazard(cursor_y + entry[0], entry[1], entry[2] * speed_scale)
		cursor_y -= length + lerpf(GAP_EASY, GAP_HARD, difficulty)


func _pick_pattern_index(difficulty: float) -> int:
	# Starts with the first 2 patterns and unlocks one more every quarter of the ramp.
	var pool_size := 2 + int(difficulty * (PATTERNS.size() - 2 + 0.999))
	return rng.randi_range(0, pool_size - 1)


func _pattern_length(pattern: Array) -> float:
	var length := 0.0
	for entry in pattern:
		length = maxf(length, -entry[0])
	return length


func _spawn_hazard(y: float, phase: float, speed: float) -> void:
	var hazard = HAZARD_SCENE.instantiate()
	hazard.position = Vector2(0.0, y)
	hazard.phase = phase
	hazard.hazard_speed = speed
	spawned.add_child(hazard)


func _spawn_checkpoint(y: float) -> void:
	var checkpoint = CHECKPOINT_SCENE.instantiate()
	checkpoint.position = Vector2(0.0, y)
	checkpoint.reached.connect(_on_checkpoint_reached)
	spawned.add_child(checkpoint)


# Frees everything well behind the respawn point; revives never land past it.
func _despawn_behind() -> void:
	var cutoff := respawn_point.y + KEEP_BEHIND_CHECKPOINT
	for node in spawned.get_children():
		if node.global_position.y > cutoff:
			node.queue_free()
