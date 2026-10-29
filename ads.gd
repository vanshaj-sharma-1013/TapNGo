extends Node

# Autoload "Ads": the single place the game talks to ads.
# No ad plugin is installed yet, so the show_* functions are stubs. When you add
# one (for example an AdMob plugin for Godot), call it inside _show_rewarded()
# and _show_interstitial() and nothing else in the game needs to change.

# Interstitial rules from GAME_DESIGN.md: only on the level-clear screen,
# none before level 3, at most one every 4 cleared levels.
const FIRST_INTERSTITIAL_LEVEL := 3
const LEVELS_BETWEEN_INTERSTITIALS := 4

var _levels_since_interstitial := 0


# Calls on_rewarded only if the player finished watching the ad.
func show_rewarded(on_rewarded: Callable) -> void:
	_show_rewarded(on_rewarded)


# Call when a level is cleared, after its result screen is up.
func on_level_cleared(level_number: int) -> void:
	_levels_since_interstitial += 1
	if level_number >= FIRST_INTERSTITIAL_LEVEL and _levels_since_interstitial >= LEVELS_BETWEEN_INTERSTITIALS:
		_levels_since_interstitial = 0
		_show_interstitial()


func _show_rewarded(on_rewarded: Callable) -> void:
	# TODO: replace with the plugin's rewarded-ad call and invoke on_rewarded
	# from its "user earned reward" callback. The stub grants the reward at once.
	on_rewarded.call()


func _show_interstitial() -> void:
	# TODO: replace with the plugin's interstitial call.
	print("[Ads] interstitial would show here")
