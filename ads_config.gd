extends RefCounted

# AdMob ad unit ids. While USE_TEST_ADS is true the game only ever shows Google's test ads
# (safe to tap). Before release: create three ad units in the AdMob console, paste them into
# LIVE, and set USE_TEST_ADS to false. Never tap your own live ads.
const USE_TEST_ADS := true

const TEST := {
	"rewarded": "ca-app-pub-3940256099942544/5224354917",
	"interstitial": "ca-app-pub-3940256099942544/1033173712",
	"rewarded_interstitial": "ca-app-pub-3940256099942544/5354046379",
}

const LIVE := {
	"rewarded": "",
	"interstitial": "",
	"rewarded_interstitial": "",
}


# "" means "not configured": the ad is treated as unavailable.
static func unit_id(kind: String) -> String:
	var id: String = (TEST if USE_TEST_ADS else LIVE).get(kind, "")
	if id == "":
		push_warning("ads_config.gd: no ad unit id for '%s'" % kind)
	return id
