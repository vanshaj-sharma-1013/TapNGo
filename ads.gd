extends Node

# Autoload "Ads": the single place the game talks to ads. It decides WHEN ads may show
# (the rules below); ads_admob.gd decides HOW (the AdMob plugin). Without the plugin, or
# off Android, it falls back to stubs: debug builds grant rewards at once so the game can be
# tested in the editor, release builds report "no ad available".
#
# Rewarded ads are always opt-in (revive, daily-streak recovery, chests).
# Interstitials never run on their own timer. They show only:
#   - when the same campaign level was failed 3 times in a row (on the next Restart tap), or
#   - when going back to the menu after a long stretch without any ad.
# Never within MIN_SECONDS_BETWEEN_INTERSTITIALS of the last ad, never for fails before
# level 3, and never once the player bought Remove Ads.

const ADMOB_ADAPTER := "res://ads_admob.gd"

const FAILS_FOR_INTERSTITIAL := 3
const FIRST_INTERSTITIAL_LEVEL := 3
const LONG_SESSION_SECONDS := 600.0
const MIN_SECONDS_BETWEEN_INTERSTITIALS := 120.0

var _adapter = null
# Seconds played since the last full-screen ad of any kind (or since launch).
var _since_last_ad := 0.0
var _ad_showing := false

var _fail_world := -1
var _fail_level := -1
var _fail_count := 0
var _fail_pending := false


func _ready() -> void:
	if OS.get_name() == "Android" and _admob_installed() and ResourceLoader.exists(ADMOB_ADAPTER):
		_adapter = load(ADMOB_ADAPTER).new()
		add_child(_adapter)
		_adapter.setup()


func _process(delta: float) -> void:
	_since_last_ad += delta


func _admob_installed() -> bool:
	if ClassDB.class_exists("MobileAds"):
		return true
	for entry in ProjectSettings.get_global_class_list():
		if entry["class"] == "MobileAds":
			return true
	return false


# ---- Rewarded ----

# Calls on_rewarded only if the player watched the ad to the end. Otherwise on_failed(reason)
# runs, with reason "unavailable" (no ad could be shown) or "skipped" (closed early).
func show_rewarded(on_rewarded: Callable, on_failed := Callable()) -> void:
	_play("rewarded", on_rewarded, on_failed)


# The price of an Endless revive goes up each time. tier = which revive this is (1, 2, 3):
#   1: a rewarded ad
#   2: a rewarded interstitial (the longer, higher-paying format)
#   3: a rewarded interstitial and then a rewarded ad. If the second one has no fill, the
#      first one counts, so a player is never stuck after already watching an ad.
func show_revive_ad(tier: int, on_rewarded: Callable, on_failed := Callable()) -> void:
	if tier <= 1:
		_play("rewarded", on_rewarded, on_failed)
	elif tier == 2:
		_play("rewarded_interstitial", on_rewarded, on_failed)
	else:
		var second := func() -> void:
			_play("rewarded", on_rewarded, func(reason: String) -> void:
				if reason == "unavailable":
					on_rewarded.call()
				else:
					_fail(on_failed, reason))
		_play("rewarded_interstitial", second, on_failed)


func _play(kind: String, on_rewarded: Callable, on_failed: Callable) -> void:
	if _ad_showing:
		return
	if _adapter == null:
		if OS.is_debug_build():
			on_rewarded.call()
		else:
			_fail(on_failed, "unavailable")
		return
	_ad_showing = true
	_adapter.show(kind, func(result: String) -> void:
		_ad_showing = false
		_since_last_ad = 0.0
		if result == "earned":
			on_rewarded.call()
		else:
			_fail(on_failed, result))


func _fail(on_failed: Callable, reason: String) -> void:
	if on_failed.is_valid():
		on_failed.call(reason)


# ---- Interstitials ----

# A campaign attempt ended in a crash that was not revived (the player is about to retry).
func on_level_failed(world: int, level_number: int) -> void:
	if world == _fail_world and level_number == _fail_level:
		_fail_count += 1
	else:
		_fail_world = world
		_fail_level = level_number
		_fail_count = 1
	if _fail_count >= FAILS_FOR_INTERSTITIAL and level_number >= FIRST_INTERSTITIAL_LEVEL:
		_fail_count = 0
		_fail_pending = true


# Clearing a level ends the bad streak.
func on_level_cleared() -> void:
	_fail_count = 0
	_fail_pending = false
	_fail_level = -1


# Call instead of reloading a level: shows the owed interstitial first (if any), then runs `then`.
func before_restart(then: Callable) -> void:
	_interstitial_if(_fail_pending, then)


# Call instead of leaving for the menu: also counts a long ad-free session.
func before_menu(then: Callable) -> void:
	_interstitial_if(_fail_pending or _since_last_ad >= LONG_SESSION_SECONDS, then)


func _interstitial_if(wanted: bool, then: Callable) -> void:
	if not wanted or GameData.ads_removed or _ad_showing or _since_last_ad < MIN_SECONDS_BETWEEN_INTERSTITIALS:
		then.call()
		return
	_fail_pending = false
	if _adapter == null:
		print("[Ads] interstitial would show here")
		_since_last_ad = 0.0
		then.call()
		return
	_ad_showing = true
	_adapter.show("interstitial", func(_result: String) -> void:
		_ad_showing = false
		_since_last_ad = 0.0
		then.call())
