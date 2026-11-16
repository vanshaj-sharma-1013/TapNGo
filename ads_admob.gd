extends Node

# AdMob adapter for the Poing Studios "AdMob" Godot plugin. ads.gd loads this file only when
# the plugin is installed, because it names the plugin's classes (MobileAds, RewardedAd...) and
# would not parse without it. Nothing else in the game touches the plugin.
#
# show(kind, on_done) plays one ad. kind is "rewarded", "interstitial" or "rewarded_interstitial".
# on_done(result) is called after the ad is closed (not while it is still on screen) with:
#   "earned"      the player watched a rewarded ad to the end
#   "skipped"     a rewarded ad was closed early
#   "closed"      an interstitial was shown and closed
#   "unavailable" nothing was loaded, or it failed to show

const AdsConfig := preload("res://ads_config.gd")

const RETRY_SECONDS := 30.0

var _ads := {}          # kind -> loaded ad object
var _loading := {}      # kind -> true while a request is in flight
var _on_done := Callable()
var _earned := false


func setup() -> void:
	MobileAds.initialize()
	for kind in ["rewarded", "interstitial", "rewarded_interstitial"]:
		_load(kind)


func is_ready(kind: String) -> bool:
	return _ads.has(kind)


func show(kind: String, on_done: Callable) -> void:
	# No rewarded interstitial in stock: a plain rewarded ad is the next best thing.
	if kind == "rewarded_interstitial" and not _ads.has(kind):
		kind = "rewarded"
	if not _ads.has(kind):
		_load(kind)
		on_done.call("unavailable")
		return

	var ad = _ads[kind]
	_on_done = on_done
	_earned = false

	var content_callback := FullScreenContentCallback.new()
	content_callback.on_ad_dismissed_full_screen_content = func() -> void:
		_finish(kind, "closed" if kind == "interstitial" else ("earned" if _earned else "skipped"))
	content_callback.on_ad_failed_to_show_full_screen_content = func(_error) -> void:
		_finish(kind, "unavailable")
	ad.full_screen_content_callback = content_callback

	if kind == "interstitial":
		ad.show()
	else:
		var listener := OnUserEarnedRewardListener.new()
		listener.on_user_earned_reward = func(_item) -> void:
			_earned = true
		ad.show(listener)


func _finish(kind: String, result: String) -> void:
	if _ads.has(kind):
		_ads[kind].destroy()
		_ads.erase(kind)
	_load(kind)  # have the next one ready
	var done := _on_done
	_on_done = Callable()
	if done.is_valid():
		done.call(result)


func _load(kind: String) -> void:
	var unit_id := AdsConfig.unit_id(kind)
	if unit_id == "" or _ads.has(kind) or _loading.get(kind, false):
		return
	_loading[kind] = true
	match kind:
		"rewarded":
			var callback := RewardedAdLoadCallback.new()
			callback.on_ad_loaded = func(ad: RewardedAd) -> void: _loaded(kind, ad)
			callback.on_ad_failed_to_load = func(error: LoadAdError) -> void: _load_failed(kind, error)
			RewardedAdLoader.new().load(unit_id, AdRequest.new(), callback)
		"interstitial":
			var callback := InterstitialAdLoadCallback.new()
			callback.on_ad_loaded = func(ad: InterstitialAd) -> void: _loaded(kind, ad)
			callback.on_ad_failed_to_load = func(error: LoadAdError) -> void: _load_failed(kind, error)
			InterstitialAdLoader.new().load(unit_id, AdRequest.new(), callback)
		"rewarded_interstitial":
			var callback := RewardedInterstitialAdLoadCallback.new()
			callback.on_ad_loaded = func(ad: RewardedInterstitialAd) -> void: _loaded(kind, ad)
			callback.on_ad_failed_to_load = func(error: LoadAdError) -> void: _load_failed(kind, error)
			RewardedInterstitialAdLoader.new().load(unit_id, AdRequest.new(), callback)


func _loaded(kind: String, ad) -> void:
	_loading.erase(kind)
	_ads[kind] = ad


# Try again later so a failed request doesn't leave the slot empty for the whole session.
func _load_failed(kind: String, error) -> void:
	_loading.erase(kind)
	push_warning("AdMob %s failed to load: %s" % [kind, error.message])
	get_tree().create_timer(RETRY_SECONDS).timeout.connect(_load.bind(kind))
