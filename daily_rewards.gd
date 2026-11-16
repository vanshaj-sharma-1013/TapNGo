extends RefCounted

# The 7-day login calendar. Open the game once a day to move along it:
#   - A claim on the day after the last claim continues the streak.
#   - Missing exactly one day can be repaired by watching a rewarded ad ("missed" state);
#     otherwise the calendar starts again at day 1. Missing two or more days always restarts.
#   - After day 7 the calendar loops back to day 1.
# Days are local calendar days. A phone clock moved backwards never grants a second claim.

const TrailStyles := preload("res://trail_styles.gd")
const CharacterRoster := preload("res://character_roster.gd")

const CYCLE := 7

# kind "coins": amount. kind "trail": a trail id (coins `fallback` if the player already owns it).
# kind "character": the first reward-only character (roster price -1) not owned yet;
# `fallback` coins if there is none (add one to character_roster.gd with "price": -1).
const REWARDS := [
	{"kind": "coins", "amount": 50},
	{"kind": "coins", "amount": 75},
	{"kind": "coins", "amount": 125},
	{"kind": "coins", "amount": 100},
	{"kind": "coins", "amount": 150},
	{"kind": "coins", "amount": 200},
	{"kind": "character", "fallback": 400},
]


# Days since 1970 in the phone's local time.
static func today() -> int:
	var now := Time.get_datetime_dict_from_system()
	var midnight := Time.get_unix_time_from_datetime_dict({
		"year": now["year"], "month": now["month"], "day": now["day"],
		"hour": 0, "minute": 0, "second": 0,
	})
	return int(floor(midnight / 86400.0))


# {state, day, streak}
#   state "claimed": nothing to claim today.
#   state "ready":   claim `day` (1-7) now. `reset` is true when a long break restarted the calendar.
#   state "missed":  one day was skipped. Claim `day` after an ad, or start over at day 1.
static func status() -> Dictionary:
	var streak := GameData.daily_streak
	var next_day := streak % CYCLE + 1
	var last := GameData.daily_last_day
	if last < 0:
		return {"state": "ready", "day": 1, "streak": 0}
	var gap := today() - last
	if gap <= 0:
		return {"state": "claimed", "day": streak, "streak": streak}
	if gap == 1:
		return {"state": "ready", "day": next_day, "streak": streak}
	if gap == 2:
		return {"state": "missed", "day": next_day, "streak": streak}
	return {"state": "ready", "day": 1, "streak": 0, "reset": streak > 0}


# Claims today's reward and returns {day, text}. With state "missed", `recovered` says whether
# the ad was watched (keep the streak) or not (start over at day 1). Returns {} if there is
# nothing to claim.
static func claim(recovered := false) -> Dictionary:
	var info := status()
	if info["state"] == "claimed":
		return {}
	var day: int = 1 if (info["state"] == "missed" and not recovered) else info["day"]
	var text := _give(REWARDS[day - 1])
	GameData.daily_streak = day
	GameData.daily_last_day = today()
	GameData.save()
	return {"day": day, "text": text}


# Short label for the calendar tile.
static func describe(day: int) -> String:
	var reward: Dictionary = REWARDS[day - 1]
	match reward["kind"]:
		"coins":
			return "%d coins" % reward["amount"]
		"trail":
			return "Rare trail"
		_:
			return "New character" if _reward_character() >= 0 else "%d coins" % reward["fallback"]


static func _reward_character() -> int:
	for i in CharacterRoster.count():
		if CharacterRoster.price(i) < 0 and not GameData.owns_character(i):
			return i
	return -1


# Hands out the reward and returns what to tell the player.
static func _give(reward: Dictionary) -> String:
	match reward["kind"]:
		"coins":
			GameData.add_coins(reward["amount"])
			return "+%d coins" % reward["amount"]
		"trail":
			if GameData.owns_trail(reward["id"]):
				GameData.add_coins(reward["fallback"])
				return "+%d coins (you already own the trail)" % reward["fallback"]
			GameData.grant_trail(reward["id"])
			return "New trail: %s" % TrailStyles.get_trail(reward["id"])["name"]
		_:
			var index := _reward_character()
			if index < 0:
				GameData.add_coins(reward["fallback"])
				return "+%d coins" % reward["fallback"]
			GameData.grant_character(index)
			return "Unlocked %s!" % CharacterRoster.character_name(index)
