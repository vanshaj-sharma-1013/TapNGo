extends RefCounted

# The worlds: Jungle, Pyramids, Cyber Grid and Frostbite Summit. Each has its own art
# folder (assets/themes/<id>/), movement rules and hazards. Use it through preload and
# call the static functions:
#   const WorldData = preload("res://world_data.gd")
#   WorldData.world_name(WorldData.PYRAMIDS)

const JUNGLE := 0
const PYRAMIDS := 1
const CYBER := 2
const FROST := 3

const WORLD_COUNT := 4
const LEVELS_PER_WORLD := 50
const STARS_PER_LEVEL := 3
# Stars needed in a world (out of LEVELS_PER_WORLD * STARS_PER_LEVEL) to unlock the next one.
const STARS_TO_UNLOCK := 50
# Endless mode switches to the next world every 500 m (50 px per metre).
const ENDLESS_SEGMENT_PX := 25000.0

# How a hazard moves (hazard.gd).
const MOTION_SWEEP := 0     # slides left and right across the lane
const MOTION_PENDULUM := 1  # swings like a pendulum around the lane centre
const MOTION_FIXED := 2     # never moves: a wall
const MOTION_BLINK := 3     # fixed full-lane row that is deadly only while ON
const MOTION_FALL := 4      # a chunk that falls onto its spot, then disappears

# Zone kinds (status_zone.gd).
const ZONE_FIRE := 0
const ZONE_ICE := 1
const ZONE_QUICKSAND := 2
const ZONE_GLITCH := 3
const ZONE_FROST := 4

# Per world:
#   speed_mult:    forward speed multiplier
#   steer_accel:   sideways acceleration in px/s^2 (0 = instant steering)
#   stop_slide:    seconds the player keeps sliding after letting go (0 = stops at once)
#   min_open_time: a sweeping bar must leave the lane open at least this long (fairness)
#   par_allowance: 3 stars need a finish within length / speed * (1 + this)
#   ground_tint:   multiplies the floor art so hazards stand out
#   ground_crop:   share of the floor tile trimmed off each side (default 8/720, for art with
#                  a light rim). Use 0 for a seamless tile, since trimming would break the seam.
#   hazards:       rows the level generator can place: skin, motion, first level, weight
#   walls_from:    first level with fixed walls (they use the "wall" skin)
#   zones:         [zone kinds] that appear from level zones_from
#   curve:         difficulty at the start / end of the world (see LevelData._curve_spec)
const WORLDS := [
	{
		"id": "jungle", "name": "Jungle",
		"speed_mult": 1.0, "steer_accel": 0.0, "stop_slide": 0.0,
		"min_open_time": 0.5, "par_allowance": 0.5,
		"ground_tint": Color(0.55, 0.6, 0.55), "accent": Color("3ddc84"),
		"hazards": [{"skin": "bar", "motion": MOTION_SWEEP, "from": 1, "weight": 1.0}],
		"walls_from": 8,
		"zones": [ZONE_FIRE, ZONE_ICE], "zones_from": 6,
		# Levels 2-10 are written out in level_data.gd SPECS; the curve continues from level 10.
		"curve_from": 10,
		"curve_start": {"count": 16, "spacing": 363.0, "speed_min": 340.0, "speed_max": 480.0, "zones": 2, "fixed": 5},
		"curve_end": {"count": 34, "spacing": 275.0, "speed_min": 520.0, "speed_max": 650.0, "zones": 4, "fixed": 10},
	},
	{
		"id": "sun-baked-pyramids", "name": "Sun-Baked Pyramids",
		"speed_mult": 1.0, "steer_accel": 1500.0, "stop_slide": 0.0,
		"min_open_time": 0.6, "par_allowance": 0.5,
		# The sandstone floor is as bright as the obstacles, so it is darkened a lot.
		"ground_tint": Color(0.5, 0.46, 0.44), "ground_crop": 0.0, "accent": Color("f2c14e"),
		"hazards": [
			{"skin": "pillar", "motion": MOTION_SWEEP, "from": 1, "weight": 3.0},
			{"skin": "scarab", "motion": MOTION_PENDULUM, "from": 3, "weight": 2.0},
			{"skin": "trapdoor", "motion": MOTION_BLINK, "from": 8, "weight": 1.0},
		],
		"walls_from": 12,
		"zones": [ZONE_QUICKSAND], "zones_from": 5,
		"curve_from": 1,
		"curve_start": {"count": 12, "spacing": 410.0, "speed_min": 230.0, "speed_max": 330.0, "zones": 2, "fixed": 2},
		"curve_end": {"count": 34, "spacing": 285.0, "speed_min": 450.0, "speed_max": 600.0, "zones": 4, "fixed": 8},
	},
	{
		"id": "cyber-grid", "name": "Cyber Grid",
		"speed_mult": 1.2, "steer_accel": 0.0, "stop_slide": 0.0,
		"min_open_time": 0.5, "par_allowance": 0.5,
		"ground_tint": Color(1.0, 1.0, 1.0), "ground_crop": 0.0, "accent": Color("ff2e93"),
		"hazards": [
			{"skin": "laser", "motion": MOTION_SWEEP, "from": 1, "weight": 3.0},
			{"skin": "pulse", "motion": MOTION_BLINK, "from": 4, "weight": 1.5},
		],
		"walls_from": 15,
		"zones": [ZONE_GLITCH], "zones_from": 7,
		"curve_from": 1,
		# Spacing is 1.2x the other worlds: the player moves 1.2x faster, so rows keep the same timing.
		"curve_start": {"count": 12, "spacing": 490.0, "speed_min": 300.0, "speed_max": 420.0, "zones": 2, "fixed": 2},
		"curve_end": {"count": 34, "spacing": 340.0, "speed_min": 540.0, "speed_max": 700.0, "zones": 4, "fixed": 8},
	},
	{
		"id": "frostbite-summit", "name": "Frostbite Summit",
		"speed_mult": 1.0, "steer_accel": 0.0, "stop_slide": 0.25,
		"min_open_time": 0.6, "par_allowance": 0.5,
		"ground_tint": Color(0.85, 0.9, 1.0), "ground_crop": 0.0, "accent": Color("7fd6ff"),
		"hazards": [
			{"skin": "frozen", "motion": MOTION_SWEEP, "from": 1, "weight": 3.0},
			{"skin": "debris", "motion": MOTION_FALL, "from": 3, "weight": 2.0},
		],
		"walls_from": 14,
		"zones": [ZONE_FROST], "zones_from": 6,
		"curve_from": 1,
		"curve_start": {"count": 12, "spacing": 420.0, "speed_min": 240.0, "speed_max": 340.0, "zones": 2, "fixed": 2},
		"curve_end": {"count": 34, "spacing": 290.0, "speed_min": 470.0, "speed_max": 620.0, "zones": 4, "fixed": 8},
	},
]


static func world(index: int) -> Dictionary:
	return WORLDS[clampi(index, 0, WORLD_COUNT - 1)]


static func id(index: int) -> String:
	return world(index)["id"]


static func world_name(index: int) -> String:
	return world(index)["name"]


# Highest stars a world can give.
static func max_world_stars() -> int:
	return LEVELS_PER_WORLD * STARS_PER_LEVEL
