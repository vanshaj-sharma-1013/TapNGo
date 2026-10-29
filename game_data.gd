extends Node

# Autoload "GameData": progress and best scores, saved to user://save.json.

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
var levels_cleared := 0

# Settings.
var button_layout := LAYOUT_SPLIT
var button_scale := 0.8
var vibration := true
var screen_shake := true
var muted := false
# Tutorial hints already shown (level numbers).
var seen_hints: Array = []
# Level the campaign scene will load. Not saved.
var selected_level := 1


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


func is_level_unlocked(level_number: int) -> bool:
	return UNLOCK_ALL_LEVELS or level_number <= levels_cleared + 1


func mark_level_cleared(level_number: int) -> void:
	if level_number > levels_cleared:
		levels_cleared = level_number
		save()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		best_endless = int(data.get("best_endless", 0))
		levels_cleared = int(data.get("levels_cleared", 0))
		var layout := str(data.get("button_layout", LAYOUT_SPLIT))
		button_layout = layout if layout in [LAYOUT_SPLIT, LAYOUT_LEFT, LAYOUT_RIGHT] else LAYOUT_SPLIT
		button_scale = clampf(float(data.get("button_scale", button_scale)), BUTTON_SCALE_MIN, BUTTON_SCALE_MAX)
		vibration = bool(data.get("vibration", true))
		screen_shake = bool(data.get("screen_shake", true))
		muted = bool(data.get("muted", false))
		seen_hints = []
		var hints = data.get("seen_hints", [])
		if hints is Array:
			for hint in hints:
				seen_hints.append(int(hint))


func save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"best_endless": best_endless,
		"levels_cleared": levels_cleared,
		"button_layout": button_layout,
		"button_scale": button_scale,
		"vibration": vibration,
		"screen_shake": screen_shake,
		"muted": muted,
		"seen_hints": seen_hints,
	}))
