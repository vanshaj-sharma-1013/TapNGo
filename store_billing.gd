extends Node

# Google Play Billing adapter (the "GodotGooglePlayBilling" plugin). store.gd loads this file
# only when the plugin is installed, because it names the plugin's BillingClient class.

signal purchased(product_id: String)
signal price_found(product_id: String, price: String)
signal failed(message: String)
# Finished checking what the player already owns (used by "Restore purchases").
signal restore_done(found_any: bool)

const RECONNECT_SECONDS := 15.0

var _client: BillingClient
var _product_ids: Array = []
var _restore_hits := 0


func setup(product_ids: Array) -> void:
	_product_ids = product_ids
	_client = BillingClient.new()
	_client.connected.connect(_on_connected)
	_client.disconnected.connect(_reconnect_later)
	_client.connect_error.connect(func(_code, _message) -> void: _reconnect_later())
	_client.query_product_details_response.connect(_on_product_details)
	_client.query_purchases_response.connect(_on_purchases)
	_client.on_purchase_updated.connect(_on_purchase_updated)
	_client.acknowledge_purchase_response.connect(_on_acknowledged)
	_client.start_connection()


func is_ready() -> bool:
	return _client != null and _client.is_ready()


func buy(product_id: String) -> void:
	if not is_ready():
		failed.emit("Store not ready. Try again in a moment.")
		return
	var result: Dictionary = _client.purchase(product_id)
	if int(result.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
		failed.emit("Could not start the purchase.")


func restore() -> void:
	if not is_ready():
		failed.emit("Store not ready. Try again in a moment.")
		return
	_restore_hits = 0
	_client.query_purchases(BillingClient.ProductType.INAPP)


func _reconnect_later() -> void:
	get_tree().create_timer(RECONNECT_SECONDS).timeout.connect(_client.start_connection)


func _on_connected() -> void:
	_client.query_product_details(_product_ids, BillingClient.ProductType.INAPP)
	# Anything bought earlier (or on another device) is granted again here.
	_client.query_purchases(BillingClient.ProductType.INAPP)


func _on_product_details(result: Dictionary) -> void:
	if int(result.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
		return
	for details in result.get("product_details", []):
		var offer: Dictionary = details.get("one_time_purchase_offer_details", {})
		var price := str(offer.get("formatted_price", ""))
		var id := str(details.get("product_id", ""))
		if price != "" and id != "":
			price_found.emit(id, price)


func _on_purchases(result: Dictionary) -> void:
	if int(result.get("response_code", -1)) == BillingClient.BillingResponseCode.OK:
		for purchase in result.get("purchases", []):
			_handle(purchase)
	restore_done.emit(_restore_hits > 0)
	_restore_hits = 0


func _on_purchase_updated(result: Dictionary) -> void:
	if int(result.get("response_code", -1)) == BillingClient.BillingResponseCode.OK:
		for purchase in result.get("purchases", []):
			_handle(purchase)
	else:
		failed.emit("Purchase cancelled.")


func _handle(purchase: Dictionary) -> void:
	if int(purchase.get("purchase_state", 0)) != BillingClient.PurchaseState.PURCHASED:
		return  # pending payments are granted once they complete
	for id in purchase.get("product_ids", []):
		if _product_ids.has(id):
			_restore_hits += 1
			purchased.emit(str(id))
	# Google refunds a purchase that is not acknowledged within 3 days.
	if not purchase.get("is_acknowledged", false):
		_client.acknowledge_purchase(purchase["purchase_token"])


func _on_acknowledged(result: Dictionary) -> void:
	if int(result.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
		push_warning("Billing: acknowledge failed: %s" % result.get("debug_message", ""))
