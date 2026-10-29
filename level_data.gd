extends RefCounted

# Level definitions. Use it through preload and call the static functions:
#   const LevelData = preload("res://level_data.gd")
#   LevelData.get_level(3)
#
# A level is a Dictionary:
#   hazards:     [{y, phase, speed, width}, ...]  sweeping bars (see hazard.gd).
#                A bar with sweeps = false and an x is a fixed wall instead.
#   checkpoints: [y, ...]
#   finish_y:    float
#   zones:       [{kind, x, y}, ...]  fixed fire / ice patches (x = centre)
#
# Level 1 is written out by hand. Levels 2-10 are built from a fixed seed, so
# they are "random" but identical on every run.

const LEVEL_COUNT := 10

const LANE_WIDTH := 720.0
const PLAYER_RADIUS := 24.0
const FIRST_HAZARD_Y := 700.0
const FINISH_DISTANCE := 450.0  # lane past the last bar before the finish line
const SEED_BASE := 20260
# Every bar must leave the player at least this long to slip past (see open_time).
const MIN_OPEN_TIME := 0.5
const WARN_OPEN_TIME := 0.49  # campaign.gd warns about generated bars below this
# Bar widths dealt out in levels 3-10. The widest is 256px (level 1's size).
const WIDTHS := [96.0, 160.0, 208.0, 256.0]

const FIRE := 0
const ICE := 1
const ZONE_JITTER := 40.0
# Gap between a fixed wall and the lane edge when it sits on the left or right.
const FIXED_SIDE_GAP := 110.0
# Patches are 300px wide in the 720px lane, centred on the left, middle or right,
# so there is always room to steer around them.
const ZONE_WIDTH := 300.0
const ZONE_CENTRES := [150.0, 360.0, 570.0]

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

# count: bars in the level, spacing: px between bars, widths: sizes dealt out
# evenly, speed: min/max px/s, zones: how many fire patches AND how many ice patches.
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


static func get_level(level_number: int) -> Dictionary:
	var n := clampi(level_number, 1, LEVEL_COUNT)
	if n == 1:
		return LEVEL_1
	return _generate(n)


# Seconds a bar of this width and speed leaves the player's lane clear each time
# it swings out to the side. Too small and the gap is unfair.
static func open_time(width: float, speed: float) -> float:
	var span := LANE_WIDTH / 2.0 - width - PLAYER_RADIUS  # clear px on each side
	if span <= 0.0:
		return 0.0
	return 2.0 * span / absf(speed)


# Fastest a bar of this width may sweep and still be fair.
static func max_speed(width: float) -> float:
	var span := LANE_WIDTH / 2.0 - width - PLAYER_RADIUS
	return 2.0 * maxf(span, 0.0) / MIN_OPEN_TIME


static func _generate(n: int) -> Dictionary:
	var spec: Dictionary = SPECS[n]
	var count: int = spec["count"]
	var spacing: float = spec["spacing"]
	var widths: Array = spec["widths"]
	var speed_range: Vector2 = spec["speed"]
	var zones_per_kind: int = spec["zones"]

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED_BASE + n

	# Deal the widths out evenly, then shuffle, so every level mixes small and big bars.
	var width_deck: Array = []
	for i in count:
		width_deck.append(widths[i % widths.size()])
	_shuffle(width_deck, rng)

	var hazards: Array = []
	for i in count:
		var width: float = width_deck[i]
		var speed := minf(rng.randf_range(speed_range.x, speed_range.y), max_speed(width))
		if rng.randf() < 0.5:
			speed = -speed
		hazards.append({
			"y": FIRST_HAZARD_Y - i * spacing,
			"phase": rng.randf_range(0.0, 2.0 * (LANE_WIDTH - width)),
			"speed": speed,
			"width": width,
		})

	# Checkpoints sit midway between two bars, a third and two thirds of the way up.
	var checkpoint_gaps: Array = [int(count / 3.0) - 1, 2 * int(count / 3.0) - 1]
	var checkpoints: Array = []
	for gap in checkpoint_gaps:
		checkpoints.append(_gap_y(gap, spacing))

	# Fire and ice patches go in other gaps, at a fixed but shuffled spot in each.
	var zones: Array = []
	if zones_per_kind > 0:
		var free_gaps: Array = []
		for gap in count - 1:
			if not checkpoint_gaps.has(gap):
				free_gaps.append(gap)
		_shuffle(free_gaps, rng)
		for i in zones_per_kind * 2:
			var is_fire := i < zones_per_kind
			zones.append({
				"kind": FIRE if is_fire else ICE,
				"y": _gap_y(free_gaps[i], spacing) + rng.randf_range(-ZONE_JITTER, ZONE_JITTER),
				"x": ZONE_CENTRES[rng.randi_range(0, ZONE_CENTRES.size() - 1)],
			})

	# From level 8 on, some bars stop sweeping and become fixed walls the player
	# must steer around. A separate rng keeps the rest of the level unchanged.
	var fixed_count: int = spec.get("fixed", 0)
	if fixed_count > 0:
		var pick := RandomNumberGenerator.new()
		pick.seed = SEED_BASE + n + 1000
		var indices: Array = []
		for i in count:
			indices.append(i)
		_shuffle(indices, pick)
		for k in fixed_count:
			var bar: Dictionary = hazards[indices[k]]
			var half: float = bar["width"] / 2.0
			# Left, middle or right: a wall always leaves a wide way round.
			var centres := [half + FIXED_SIDE_GAP, LANE_WIDTH / 2.0, LANE_WIDTH - half - FIXED_SIDE_GAP]
			bar["sweeps"] = false
			bar["x"] = centres[pick.randi_range(0, 2)]

	return {
		"hazards": hazards,
		"checkpoints": checkpoints,
		"finish_y": FIRST_HAZARD_Y - (count - 1) * spacing - FINISH_DISTANCE,
		"zones": zones,
	}


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
