extends RefCounted

# Level definitions. Use it through preload and call the static functions:
#   const LevelData = preload("res://level_data.gd")
#   LevelData.get_level(WorldData.PYRAMIDS, 3)
#
# A level is a Dictionary:
#   hazards:     [{y, motion, skin, phase, speed, width, ...}, ...]  see hazard.gd.
#                motion is one of WorldData.MOTION_*; extra keys by motion:
#                x (fixed / blink / fall), period + duty (blink: seconds, share ON).
#   checkpoints: [y, ...]
#   finish_y:    float
#   zones:       [{kind, x, y}, ...]  fixed patches (WorldData.ZONE_*, x = centre)
#
# Jungle level 1 is written out by hand. Every other level is built from a fixed seed,
# so it is "random" but identical on every run. Jungle levels 2-10 use SPECS below;
# everything after that follows the world's difficulty curve (WorldData.WORLDS).

const WorldData = preload("res://world_data.gd")

const LANE_WIDTH := 720.0
const PLAYER_RADIUS := 24.0
const FIRST_HAZARD_Y := 700.0
const FINISH_DISTANCE := 450.0  # lane past the last bar before the finish line
const SEED_BASE := 20260
const WORLD_SEED_STRIDE := 10000
# Every sweeping bar must leave the player at least this long to slip past (see open_time).
# Worlds with looser steering ask for more (WorldData "min_open_time").
const MIN_OPEN_TIME := 0.5
# Bar widths dealt out in generated levels. The widest is 256px (level 1's size).
const WIDTHS := [96.0, 160.0, 208.0, 256.0]

const ZONE_JITTER := 40.0
# Gap between a fixed wall and the lane edge when it sits on the left or right.
const FIXED_SIDE_GAP := 110.0
# Patches are 300px wide in the 720px lane, centred on the left, middle or right,
# so there is always room to steer around them.
const ZONE_WIDTH := 300.0
const ZONE_CENTRES := [150.0, 360.0, 570.0]

# Blinking rows (trapdoors, pulse barriers) span the whole lane: the player waits for the
# gap. ON is the deadly share of each cycle, so the safe time is (1 - ON) * period.
const BLINK_DUTY := 0.45
const BLINK_PERIOD_EASY := 3.2
const BLINK_PERIOD_HARD := 1.9
const FALL_WIDTH := 144.0
const FALL_SPEED := 800.0
const FALL_OFFSET_MAX := 3.0

const LEVEL_1 := {
	"hazards": [
		{"y": 700.0, "phase": 232.0, "speed": 220.0, "width": 256.0},
		{"y": 250.0, "phase": 72.0, "speed": -260.0, "width": 256.0},
		{"y": -300.0, "phase": 372.0, "speed": 300.0, "width": 256.0},
		{"y": -750.0, "phase": 172.0, "speed": -340.0, "width": 256.0},
		{"y": -1100.0, "phase": 322.0, "speed": 320.0, "width": 256.0},
		{"y": -1600.0, "phase": 122.0, "speed": -380.0, "width": 256.0},
		{"y": -2000.0, "phase": 272.0, "speed": 420.0, "width": 256.0},
		{"y": -2300.0, "phase": 172.0, "speed": -440.0, "width": 256.0},
	],
	"checkpoints": [-100.0, -1300.0],
	"finish_y": -2500.0,
	"zones": [],
}

# Jungle levels 2-10.
# count: bars in the level, spacing: px between bars, widths: sizes dealt out
# evenly, speed: min/max px/s, zones: how many patches of EACH kind, fixed: walls.
const SPECS := {
	2: {"count": 8, "spacing": 436.0, "widths": [96.0, 160.0, 256.0], "speed": Vector2(220.0, 320.0), "zones": 0},
	3: {"count": 9, "spacing": 419.0, "widths": WIDTHS, "speed": Vector2(240.0, 340.0), "zones": 0},
	4: {"count": 10, "spacing": 406.0, "widths": WIDTHS, "speed": Vector2(260.0, 380.0), "zones": 0},
	5: {"count": 11, "spacing": 395.0, "widths": WIDTHS, "speed": Vector2(280.0, 420.0), "zones": 0},
	6: {"count": 12, "spacing": 386.0, "widths": WIDTHS, "speed": Vector2(300.0, 420.0), "zones": 2},
	7: {"count": 13, "spacing": 379.0, "widths": WIDTHS, "speed": Vector2(310.0, 440.0), "zones": 2},
	8: {"count": 14, "spacing": 373.0, "widths": WIDTHS, "speed": Vector2(320.0, 450.0), "zones": 2, "fixed": 3},
	9: {"count": 15, "spacing": 368.0, "widths": WIDTHS, "speed": Vector2(330.0, 470.0), "zones": 2, "fixed": 4},
	10: {"count": 16, "spacing": 363.0, "widths": WIDTHS, "speed": Vector2(340.0, 480.0), "zones": 2, "fixed": 5},
}


static func get_level(world: int, level_number: int) -> Dictionary:
	var n := clampi(level_number, 1, WorldData.LEVELS_PER_WORLD)
	if world == WorldData.JUNGLE and n == 1:
		return LEVEL_1
	return _generate(world, n)


# Seconds a bar of this width and speed leaves the player's lane clear each time
# it swings out to the side. Too small and the gap is unfair.
static func open_time(width: float, speed: float) -> float:
	var span := LANE_WIDTH / 2.0 - width - PLAYER_RADIUS  # clear px on each side
	if span <= 0.0:
		return 0.0
	return 2.0 * span / absf(speed)


# Fastest a bar of this width may sweep and still be fair.
static func max_speed(width: float, min_open_time := MIN_OPEN_TIME) -> float:
	var span := LANE_WIDTH / 2.0 - width - PLAYER_RADIUS
	return 2.0 * maxf(span, 0.0) / min_open_time


# campaign.gd warns about generated bars that leave less than this (a hair under the target).
static func warn_open_time(world: int) -> float:
	return float(WorldData.world(world)["min_open_time"]) - 0.01


# Settings for a generated level: count, spacing, widths, speed, zones, fixed.
static func _spec(world: int, n: int) -> Dictionary:
	if world == WorldData.JUNGLE and n <= 10:
		return SPECS[n]
	var data := WorldData.world(world)
	var from: int = data["curve_from"]
	var t := clampf(float(n - from) / float(WorldData.LEVELS_PER_WORLD - from), 0.0, 1.0)
	var a: Dictionary = data["curve_start"]
	var b: Dictionary = data["curve_end"]
	return {
		"count": roundi(lerpf(a["count"], b["count"], t)),
		"spacing": lerpf(a["spacing"], b["spacing"], t),
		"widths": WIDTHS,
		"speed": Vector2(lerpf(a["speed_min"], b["speed_min"], t), lerpf(a["speed_max"], b["speed_max"], t)),
		"zones": roundi(lerpf(a["zones"], b["zones"], t)) if n >= data["zones_from"] else 0,
		"fixed": roundi(lerpf(a["fixed"], b["fixed"], t)) if n >= data["walls_from"] else 0,
	}


static func _generate(world: int, n: int) -> Dictionary:
	var data := WorldData.world(world)
	var spec := _spec(world, n)
	var count: int = spec["count"]
	var spacing: float = spec["spacing"]
	var widths: Array = spec["widths"]
	var speed_range: Vector2 = spec["speed"]
	var zones_per_kind: int = spec["zones"]
	var min_open: float = data["min_open_time"]
	var seed_value := SEED_BASE + world * WORLD_SEED_STRIDE + n

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# Which kind of row goes where, and the extras of blinking / falling rows, use their
	# own rngs so they never change the bars' numbers.
	var kind_rng := RandomNumberGenerator.new()
	kind_rng.seed = seed_value + 3000

	# Deal the widths out evenly, then shuffle, so every level mixes small and big bars.
	var width_deck: Array = []
	for i in count:
		width_deck.append(widths[i % widths.size()])
	_shuffle(width_deck, rng)

	var pool := _row_pool(data, n)
	var hazards: Array = []
	var sweeper_indices: Array = []  # rows in `hazards` that move sideways (can become walls)
	for i in count:
		var width: float = width_deck[i]
		var speed := minf(rng.randf_range(speed_range.x, speed_range.y), max_speed(width, min_open))
		if rng.randf() < 0.5:
			speed = -speed
		var phase := rng.randf_range(0.0, 2.0 * (LANE_WIDTH - width))
		var y := FIRST_HAZARD_Y - i * spacing

		var row: Dictionary = _pick_row(pool, kind_rng)
		var motion: int = row["motion"]
		match motion:
			WorldData.MOTION_BLINK:
				var level_t := float(n - 1) / float(WorldData.LEVELS_PER_WORLD - 1)
				var period := lerpf(BLINK_PERIOD_EASY, BLINK_PERIOD_HARD, level_t) + kind_rng.randf_range(-0.15, 0.15)
				hazards.append({
					"y": y, "motion": motion, "skin": row["skin"], "width": LANE_WIDTH, "x": LANE_WIDTH / 2.0,
					"period": period, "duty": BLINK_DUTY, "offset": kind_rng.randf_range(0.0, period),
				})
			WorldData.MOTION_FALL:
				# Two chunks in different lanes, so the third lane is always clear.
				var lanes: Array = [0, 1, 2]
				_shuffle(lanes, kind_rng)
				for k in 2:
					hazards.append({
						"y": y, "motion": motion, "skin": row["skin"], "width": FALL_WIDTH,
						"x": ZONE_CENTRES[lanes[k]], "speed": FALL_SPEED,
						"phase": kind_rng.randf_range(0.0, FALL_OFFSET_MAX),
					})
			_:
				sweeper_indices.append(hazards.size())
				hazards.append({"y": y, "motion": motion, "skin": row["skin"], "phase": phase, "speed": speed, "width": width})

	# Checkpoints sit midway between two bars, a third and two thirds of the way up.
	var checkpoint_gaps: Array = [int(count / 3.0) - 1, 2 * int(count / 3.0) - 1]
	var checkpoints: Array = []
	for gap in checkpoint_gaps:
		checkpoints.append(_gap_y(gap, spacing))

	# Patches go in other gaps, at a fixed but shuffled spot in each.
	var zones: Array = []
	var zone_kinds: Array = data["zones"]
	if zones_per_kind > 0:
		var free_gaps: Array = []
		for gap in count - 1:
			if not checkpoint_gaps.has(gap):
				free_gaps.append(gap)
		_shuffle(free_gaps, rng)
		for i in mini(zones_per_kind * zone_kinds.size(), free_gaps.size()):
			zones.append({
				"kind": zone_kinds[i / zones_per_kind],
				"y": _gap_y(free_gaps[i], spacing) + rng.randf_range(-ZONE_JITTER, ZONE_JITTER),
				"x": ZONE_CENTRES[rng.randi_range(0, ZONE_CENTRES.size() - 1)],
			})

	# Some bars stop moving and become fixed walls the player must steer around. A separate
	# rng keeps the rest of the level unchanged.
	var fixed_count: int = spec.get("fixed", 0)
	if fixed_count > 0:
		var pick := RandomNumberGenerator.new()
		pick.seed = seed_value + 1000
		var indices: Array = sweeper_indices.duplicate()
		_shuffle(indices, pick)
		for k in mini(fixed_count, indices.size()):
			var bar: Dictionary = hazards[indices[k]]
			var half: float = bar["width"] / 2.0
			# Left, middle or right: a wall always leaves a wide way round.
			var centres := [half + FIXED_SIDE_GAP, LANE_WIDTH / 2.0, LANE_WIDTH - half - FIXED_SIDE_GAP]
			bar["motion"] = WorldData.MOTION_FIXED
			bar["skin"] = "wall"
			bar["x"] = centres[pick.randi_range(0, 2)]

	return {
		"hazards": hazards,
		"checkpoints": checkpoints,
		"finish_y": FIRST_HAZARD_Y - (count - 1) * spacing - FINISH_DISTANCE,
		"zones": zones,
	}


# The kinds of row this level may use: the world's list, limited to those introduced by level n.
static func _row_pool(data: Dictionary, n: int) -> Array:
	var pool: Array = []
	for row in data["hazards"]:
		if n >= row["from"]:
			pool.append(row)
	return pool


static func _pick_row(pool: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	for row in pool:
		total += row["weight"]
	var roll := rng.randf() * total
	for row in pool:
		roll -= row["weight"]
		if roll <= 0.0:
			return row
	return pool[pool.size() - 1]


# y of the point midway between bar `gap` and the next one up.
static func _gap_y(gap: int, spacing: float) -> float:
	return FIRST_HAZARD_Y - (gap + 0.5) * spacing


# Fisher-Yates with the caller's seeded rng, so the order is repeatable.
static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp
