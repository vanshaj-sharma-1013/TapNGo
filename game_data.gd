extends Node

# Autoload "GameData": progress and best scores, saved to user://save.json.

const WorldData = preload("res://world_data.gd")
const CharacterRoster = preload("res://character_roster.gd")
const TrailStyles = preload("res://trail_styles.gd")
const Potions = preload("res://potions.gd")

const SAVE_PATH := "user://save.json"

# Testing switch: true unlocks every level in the level select.
# Set to false before release so levels unlock in order.
const UNLOCK_ALL_LEVELS := true

const LAYOUT_SPLIT := "split"
const LAYOUT_LEFT := "left"
const LAYOUT_RIGHT := "right"
const BUTTON_SCALE_MIN := 0.6
const BUTTON_SCALE_MAX := 1.0

# Coins. A level pays COINS_PER_STAR per star, but only for stars not earned before (replaying
# for the same stars pays nothing). Endless pays 1 coin per METRES_PER_COIN metres beyond the
# best distance ever reached, so a total of best_endless / METRES_PER_COIN coins can ever come
# from it.
const COINS_PER_STAR := 10
const METRES_PER_COIN := 10

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

# Coin balance and what it bought. Characters and trails are stored by id; the free ones
# (price 0) are always owned and never listed here.
var coins := 0
var owned_characters: Array = []
var owned_trails: Array = []
var selected_trail := TrailStyles.DEFAULT_ID
# Potions in the bag: potion id -> how many.
var potions := {}
# Coins paid by the last record_stars() / submit_endless_score() call, for the result screens.
var last_award := 0
# True when _load() paid out progress from an older save; it is written back right away.
var _migrated := false

# Daily reward calendar (see daily_rewards.gd): how far into the 7-day cycle the player is and
# the day number (days since 1970, local time) of the last claim; -1 = never claimed.
var daily_streak := 0
var daily_last_day := -1
# True once the daily popup was offered this app session. Not saved.
var daily_prompt_shown := false

# True after the "Remove Ads" purchase. Removes interstitials only; rewarded ads stay opt-in.
var ads_removed := false


func _ready() -> void:
	_load()
	if _migrated:
		save()
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
	last_award = 0
	if score > best_endless:
		# Whole 10 m steps only; the difference of the two step counts never loses a remainder
		# (195 m -> 205 m pays 1 coin, 199 m -> 205 m pays 1 coin, 200 m -> 209 m pays 0).
		last_award = _metre_coins(score) - _metre_coins(best_endless)
		coins += last_award
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
	last_award = 0
	var before := stars_for(world, level_number)
	if earned <= before:
		return false
	last_award = (earned - before) * COINS_PER_STAR
	coins += last_award
	stars[_star_key(world, level_number)] = earned
	save()
	Cloud.sync_stars(stars)
	return true


@warning_ignore("integer_division")
func _metre_coins(metres: int) -> int:
	return maxi(metres, 0) / METRES_PER_COIN


func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount
	save()


# Returns false (and changes nothing) if the player can't afford it.
func spend_coins(amount: int) -> bool:
	if amount < 0 or coins < amount:
		return false
	coins -= amount
	save()
	return true


func owns_character(index: int) -> bool:
	var info := CharacterRoster.get_character(index)
	return int(info.get("price", 0)) == 0 or owned_characters.has(info["id"])


# Buys a character with coins. Reward-only characters (price < 0) can't be bought.
func buy_character(index: int) -> bool:
	var info := CharacterRoster.get_character(index)
	var price := int(info.get("price", 0))
	if owns_character(index) or price < 0 or coins < price:
		return false
	coins -= price
	owned_characters.append(info["id"])
	save()
	return true


func grant_character(index: int) -> void:
	var info := CharacterRoster.get_character(index)
	if not owns_character(index):
		owned_characters.append(info["id"])
		save()


func potion_count(id: String) -> int:
	return int(potions.get(id, 0))


func buy_potion(id: String) -> bool:
	var info := Potions.get_potion(id)
	if info.is_empty() or coins < int(info["price"]):
		return false
	coins -= int(info["price"])
	potions[id] = potion_count(id) + 1
	save()
	return true


func add_potion(id: String, amount := 1) -> void:
	if not Potions.get_potion(id).is_empty() and amount > 0:
		potions[id] = potion_count(id) + amount
		save()


# Takes one potion out of the bag. Returns false if there is none.
func use_potion(id: String) -> bool:
	if potion_count(id) <= 0:
		return false
	potions[id] = potion_count(id) - 1
	save()
	return true


func owns_trail(id: String) -> bool:
	return TrailStyles.get_trail(id)["price"] == 0 or owned_trails.has(id)


func buy_trail(id: String) -> bool:
	var price: int = TrailStyles.get_trail(id)["price"]
	if owns_trail(id) or price < 0 or coins < price:
		return false
	coins -= price
	owned_trails.append(id)
	save()
	return true


func grant_trail(id: String) -> void:
	if not owns_trail(id):
		owned_trails.append(id)
		save()


func select_trail(id: String) -> void:
	if owns_trail(id):
		selected_trail = id
		save()


func set_ads_removed(removed: bool) -> void:
	if ads_removed != removed:
		ads_removed = removed
		save()


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
		_load_shop(data)
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


func _load_shop(data: Dictionary) -> void:
	owned_characters = _string_list(data.get("owned_characters", []))
	owned_trails = _string_list(data.get("owned_trails", []))
	var trail := str(data.get("selected_trail", TrailStyles.DEFAULT_ID))
	selected_trail = trail if owns_trail(trail) else TrailStyles.DEFAULT_ID
	potions = {}
	var saved_potions = data.get("potions", {})
	if saved_potions is Dictionary:
		for id in Potions.ids():
			if int(saved_potions.get(id, 0)) > 0:
				potions[id] = int(saved_potions[id])
	daily_streak = clampi(int(data.get("daily_streak", 0)), 0, 7)
	daily_last_day = int(data.get("daily_last_day", -1))
	ads_removed = bool(data.get("ads_removed", false))
	if data.has("coins"):
		coins = maxi(int(data["coins"]), 0)
	else:
		# A save from before coins existed: pay out everything already earned, once.
		coins = total_stars() * COINS_PER_STAR + _metre_coins(best_endless)
		# Someone already running as a paid character keeps it.
		var worn := clampi(int(data.get("selected_character", 0)), 0, CharacterRoster.count() - 1)
		if not owns_character(worn):
			owned_characters.append(CharacterRoster.get_character(worn)["id"])
		_migrated = true


func _string_list(value) -> Array:
	var list: Array = []
	if value is Array:
		for item in value:
			list.append(str(item))
	return list


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
		"coins": coins,
		"owned_characters": owned_characters,
		"owned_trails": owned_trails,
		"selected_trail": selected_trail,
		"potions": potions,
		"daily_streak": daily_streak,
		"daily_last_day": daily_last_day,
		"ads_removed": ads_removed,
		"seen_hints": seen_hints,
	}))
