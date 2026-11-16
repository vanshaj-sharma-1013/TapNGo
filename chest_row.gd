extends VBoxContainer

# "Bust or Boom": three closed boxes shown after a strong Endless run. Watching a rewarded ad
# lets the player open ONE box. Hidden behind the boxes (shuffled each time) are x5, x2 and x1;
# the prize is that multiple of the run's base coins, paid on top of the coins already earned.
# The leaderboard score is never touched, only coins.

const UiKit := preload("res://ui_kit.gd")

const MULTIPLIERS := [5, 2, 1]
const BOX_SIZE := 150.0

var _base_coins := 0
var _order: Array = []
var _boxes: Array[Button] = []
var _ad_button: Button
var _hint: Label
var _unlocked := false
var _picked := false


# base_coins: what a x1 box pays.
func _init(base_coins: int) -> void:
	_base_coins = maxi(base_coins, 1)
	_order = MULTIPLIERS.duplicate()
	_order.shuffle()
	add_theme_constant_override("separation", 14)


func _ready() -> void:
	add_child(UiKit.title("BUST OR BOOM", 40, UiKit.GOLD))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	add_child(row)
	for i in _order.size():
		var box := Button.new()
		box.text = "?"
		box.custom_minimum_size = Vector2(BOX_SIZE, BOX_SIZE)
		box.add_theme_font_size_override("font_size", 64)
		UiKit.style_button(box, "yellow")
		box.disabled = true
		box.pressed.connect(_pick.bind(i))
		row.add_child(box)
		_boxes.append(box)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 28)
	_hint.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	_hint.text = "Open one box for up to %d bonus coins" % (_base_coins * MULTIPLIERS.max())
	add_child(_hint)

	_ad_button = Button.new()
	_ad_button.text = "WATCH AD TO OPEN"
	_ad_button.custom_minimum_size = Vector2(0.0, 90.0)
	_ad_button.add_theme_font_size_override("font_size", 32)
	UiKit.style_button(_ad_button, "purple")
	UiKit.add_button_icon(_ad_button, "play", 36.0, Color.WHITE)
	_ad_button.pressed.connect(_on_ad_pressed)
	add_child(_ad_button)


func _on_ad_pressed() -> void:
	_ad_button.disabled = true
	Ads.show_rewarded(_unlock, _on_ad_failed)


func _unlock() -> void:
	_unlocked = true
	_ad_button.visible = false
	_hint.text = "Pick a box!"
	for box in _boxes:
		box.disabled = false


func _on_ad_failed(reason: String) -> void:
	_ad_button.disabled = false
	_hint.text = "No ad available right now. Try again in a moment." if reason == "unavailable" \
			else "Watch the whole ad to open a box."


func _pick(index: int) -> void:
	if not _unlocked or _picked:
		return
	_picked = true
	var won: int = _order[index] * _base_coins
	GameData.add_coins(won)
	for i in _boxes.size():
		var box := _boxes[i]
		box.disabled = true
		box.text = "x%d" % _order[i]
		box.add_theme_font_size_override("font_size", 52)
		if i != index:
			box.modulate = Color(1, 1, 1, 0.45)
	var label := "BOOM!" if _order[index] == MULTIPLIERS.max() else ("BUST" if _order[index] == 1 else "NICE!")
	_hint.text = "%s  +%d coins" % [label, won]
	_hint.add_theme_color_override("font_color", UiKit.GOLD)
