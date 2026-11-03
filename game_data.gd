extends Node

# Autoload "GameData": progress and best scores, saved to user://save.json.

const WorldData = preload("res://world_data.gd")
const CharacterRoster = preload("res://character_roster.gd")

const SAVE_PATH := "user://save.json"

# Testing switch: true unlocks every level in the level select.
# Set to false before release so levels unlock in order.
const UNLOCK_ALL_LEVELS := true

const LAYOUT_SPLIT := "split"
const LAYOUT_LEFT := "left"
const LAYOUT_RIGHT := "right"
const BUTTON_SCALE_MIN := 0.6
const BUTTON_SCALE_MAX := 1.0

var best_endless := 0
# Best stars (1-3) per level, keyed "<world>:<level>"; a missing key means not cleared.
var stars := {}

# Settings.
var button_layout := LAYOUT_SPLIT
var button_scale := 0.8
var vibration := true
var screen_shake := true
var muted := false
# Tutorial hints already shown (level numbers).
var seen_hints: Array = []
# World and level the campaign scene will load. Not saved.
var selected_world := 0
var selected_level := 1
# Index into character_roster.gd of the character the player runs as.
var selected_character := 0


func _ready() -> void:
	_load()
	apply_mute()


func apply_mute() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)


func has_seen_hint(hint_id: int) -> bool:
	return seen_hints.has(hint_id)


func mark_hint_seen(hint_id: int) -> void:
	if not seen_hints.has(hint_id):
		seen_hints.append(hint_id)
		save()


# Returns true if `score` is a new personal best.
func submit_endless_score(score: int) -> bool:
	if score > best_endless:
		best_endless = score
		save()
		Cloud.submit_score(score)
		return true
	return false


func stars_for(world: int, level_number: int) -> int:
	return int(stars.get(_star_key(world, level_number), 0))


func world_stars(world: int) -> int:
	var total := 0
	for n in range(1, WorldData.LEVELS_PER_WORLD + 1):
		total += stars_for(world, n)
	return total


func total_stars() -> int:
	var total := 0
	for world in WorldData.WORLD_COUNT:
		total += world_stars(world)
	return total


# A world opens once the one before it has STARS_TO_UNLOCK stars.
func is_world_unlocked(world: int) -> bool:
	return UNLOCK_ALL_LEVELS or world <= 0 or world_stars(world - 1) >= WorldData.STARS_TO_UNLOCK


# Level n opens once level n-1 of the same world has at least one star.
func is_level_unlocked(world: int, level_number: int) -> bool:
	if not is_world_unlocked(world):
		return false
	return UNLOCK_ALL_LEVELS or level_number <= 1 or stars_for(world, level_number - 1) >= 1


# Keeps the best result per level. Returns true if it improved.
func record_stars(world: int, level_number: int, earned: int) -> bool:
	if earned <= stars_for(world, level_number):
		return false
	stars[_star_key(world, level_number)] = earned
	save()
	Cloud.sync_stars(stars)
	return true


func _star_key(world: int, level_number: int) -> String:
	return "%d:%d" % [world, level_number]


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		best_endless = int(data.get("best_endless", 0))
		_load_stars(data)
		var layout := str(data.get("button_layout", LAYOUT_SPLIT))
		button_layout = layout if layout in [LAYOUT_SPLIT, LAYOUT_LEFT, LAYOUT_RIGHT] else LAYOUT_SPLIT
		button_scale = clampf(float(data.get("button_scale", button_scale)), BUTTON_SCALE_MIN, BUTTON_SCALE_MAX)
		vibration = bool(data.get("vibration", true))
		screen_shake = bool(data.get("screen_shake", true))
		muted = bool(data.get("muted", false))
		selected_character = clampi(int(data.get("selected_character", 0)), 0, CharacterRoster.count() - 1)
		seen_hints = []
		var hints = data.get("seen_hints", [])
		if hints is Array:
			for hint in hints:
				seen_hints.append(int(hint))


func _load_stars(data: Dictionary) -> void:
	stars = {}
	var saved = data.get("stars")
	if saved is Dictionary:
		for key in saved:
			var earned := clampi(int(saved[key]), 0, WorldData.STARS_PER_LEVEL)
			if earned > 0:
				stars[str(key)] = earned
		return
	# Older saves only knew how many jungle levels were cleared: give each one star.
	for n in range(1, int(data.get("levels_cleared", 0)) + 1):
		stars[_star_key(WorldData.JUNGLE, n)] = 1


func save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"best_endless": best_endless,
		"stars": stars,
		"button_layout": button_layout,
		"button_scale": button_scale,
		"vibration": vibration,
		"screen_shake": screen_shake,
		"muted": muted,
		"selected_character": selected_character,
		"seen_hints": seen_hints,
	}))
