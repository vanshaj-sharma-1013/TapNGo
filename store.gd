extends Node

# Autoload "Store": in-app purchases. One product for now, the one-time "Remove Ads"
# (a non-consumable in-app product with id PRODUCT_REMOVE_ADS in Google Play Console).
# It removes interstitials only; rewarded ads stay available because the player chooses them.
# store_billing.gd does the Google Play calls and is used only when that plugin is installed.
# In a debug build without the plugin, buying simply succeeds so the flow can be tested.

signal changed

const PRODUCT_REMOVE_ADS := "remove_ads"
const BILLING_ADAPTER := "res://store_billing.gd"
# Shown until Google Play tells us the real, localised price.
const FALLBACK_PRICE := "$1.99"

var remove_ads_price := FALLBACK_PRICE

var _adapter = null
# Called with (ok: bool, message: String) when the running buy / restore finishes.
var _pending := Callable()


func _ready() -> void:
	if OS.get_name() == "Android" and _billing_installed() and ResourceLoader.exists(BILLING_ADAPTER):
		_adapter = load(BILLING_ADAPTER).new()
		add_child(_adapter)
		_adapter.purchased.connect(_on_purchased)
		_adapter.price_found.connect(_on_price_found)
		_adapter.failed.connect(_on_failed)
		_adapter.restore_done.connect(_on_restore_done)
		_adapter.setup([PRODUCT_REMOVE_ADS])


func _billing_installed() -> bool:
	if ClassDB.class_exists("BillingClient"):
		return true
	for entry in ProjectSettings.get_global_class_list():
		if entry["class"] == "BillingClient":
			return true
	return false


func can_purchase() -> bool:
	return _adapter != null or OS.is_debug_build()


func buy_remove_ads(on_result: Callable) -> void:
	if GameData.ads_removed:
		on_result.call(true, "Ads are already removed.")
		return
	if _adapter == null:
		if OS.is_debug_build():
			_on_purchased(PRODUCT_REMOVE_ADS)
			on_result.call(true, "Ads removed (test purchase).")
		else:
			on_result.call(false, "Purchases are not available on this device.")
		return
	_pending = on_result
	_adapter.buy(PRODUCT_REMOVE_ADS)


func restore(on_result: Callable) -> void:
	if _adapter == null:
		on_result.call(GameData.ads_removed, "Ads are removed." if GameData.ads_removed else "Nothing to restore.")
		return
	_pending = on_result
	_adapter.restore()


func _on_purchased(product_id: String) -> void:
	if product_id != PRODUCT_REMOVE_ADS:
		return
	GameData.set_ads_removed(true)
	changed.emit()
	_finish(true, "Ads removed. Thank you!")


func _on_price_found(product_id: String, price: String) -> void:
	if product_id == PRODUCT_REMOVE_ADS:
		remove_ads_price = price
		changed.emit()


func _on_failed(message: String) -> void:
	_finish(false, message)


func _on_restore_done(found_any: bool) -> void:
	if not found_any:
		_finish(false, "No earlier purchase found.")


func _finish(ok: bool, message: String) -> void:
	var done := _pending
	_pending = Callable()
	if done.is_valid():
		done.call(ok, message)
