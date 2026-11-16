extends Control

# The daily login popup: a 7-day calendar, a CLAIM button, and (after exactly one missed day)
# "watch an ad to keep your streak". See daily_rewards.gd for the rules.

signal closed

const DailyRewards := preload("res://daily_rewards.gd")
const UiKit := preload("res://ui_kit.gd")

var _card_box: VBoxContainer


func _ready() -> void:
	theme = preload("res://ui_theme.tres")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.02, 0.06, 0.8)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var card := UiKit.card(Color(0.03, 0.06, 0.12, 0.97), Color(UiKit.GOLD, 0.6))
	center.add_child(card)
	_card_box = VBoxContainer.new()
	_card_box.custom_minimum_size.x = 600.0
	_card_box.add_theme_constant_override("separation", 18)
	card.add_child(_card_box)
	_build()


func _build() -> void:
	for child in _card_box.get_children():
		_card_box.remove_child(child)
		child.queue_free()

	var info := DailyRewards.status()
	_card_box.add_child(UiKit.title("DAILY REWARD", 54, UiKit.GOLD))
	_card_box.add_child(_note(_message(info)))

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_card_box.add_child(grid)
	# Days already ticked off in this week's calendar.
	var done: int = info["day"] if info["state"] == "claimed" else info["day"] - 1
	for day in range(1, DailyRewards.CYCLE + 1):
		grid.add_child(_tile(day, done, info))

	match info["state"]:
		"ready":
			_add_button("CLAIM", "warn", _on_claim.bind(false))
		"missed":
			_add_button("WATCH AD: KEEP MY STREAK", "purple", _on_recover)
			_add_button("START OVER AT DAY 1", "dark", _on_claim.bind(false))
		_:
			_add_button("CLOSE", "dark", _close)
	if info["state"] != "claimed":
		_add_button("LATER", "dark", _close, 76)


func _message(info: Dictionary) -> String:
	match info["state"]:
		"claimed":
			return "Come back tomorrow for day %d." % (info["day"] % DailyRewards.CYCLE + 1)
		"missed":
			return "You missed a day! Your streak is at day %d." % info["streak"]
		_:
			if info.get("reset", false):
				return "Your streak ended. A new week starts today."
			return "Day %d reward is ready!" % info["day"]


func _tile(day: int, done: int, info: Dictionary) -> Control:
	var is_next: bool = info["state"] != "claimed" and day == info["day"]
	var claimed := day <= done
	var accent := UiKit.GREEN if claimed else (UiKit.GOLD if is_next else Color(0.5, 0.62, 0.7))
	var tile := UiKit.card(Color(accent, 0.14 if (claimed or is_next) else 0.06), Color(accent, 0.85 if is_next else 0.45), 18, 8.0, 10.0)
	tile.custom_minimum_size = Vector2(132.0, 150.0)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 6)
	tile.add_child(column)

	var day_label := Label.new()
	day_label.text = "DAY %d" % day
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_label.add_theme_font_size_override("font_size", 20)
	day_label.add_theme_color_override("font_color", accent)
	column.add_child(day_label)

	var icon := UiKit.Icon.new("check" if claimed else _icon_for(day), 46.0, accent)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(icon)

	var reward := Label.new()
	reward.text = DailyRewards.describe(day)
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward.add_theme_font_size_override("font_size", 18)
	column.add_child(reward)
	return tile


func _icon_for(day: int) -> String:
	return "coin" if DailyRewards.REWARDS[day - 1]["kind"] == "coins" else "crown"


func _note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	return label


func _add_button(text: String, kind: String, on_pressed: Callable, height := 96) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, height)
	button.add_theme_font_size_override("font_size", 32)
	UiKit.style_button(button, kind)
	button.pressed.connect(on_pressed)
	_card_box.add_child(button)


func _on_recover() -> void:
	Ads.show_rewarded(_on_claim.bind(true), _on_recover_failed)


func _on_recover_failed(reason: String) -> void:
	_card_box.add_child(_note("No ad available right now. Try again in a moment." if reason == "unavailable" \
			else "Watch the whole ad to keep your streak."))


func _on_claim(recovered: bool) -> void:
	var result := DailyRewards.claim(recovered)
	if result.is_empty():
		_close()
		return
	for child in _card_box.get_children():
		_card_box.remove_child(child)
		child.queue_free()
	_card_box.add_child(UiKit.title("DAY %d CLAIMED" % result["day"], 50, UiKit.GREEN))
	var reward := UiKit.title(result["text"], 44, UiKit.GOLD)
	reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_box.add_child(reward)
	_card_box.add_child(_note("Come back tomorrow to keep your streak going."))
	_add_button("NICE!", "warn", _close)


func _close() -> void:
	closed.emit()
	queue_free()
