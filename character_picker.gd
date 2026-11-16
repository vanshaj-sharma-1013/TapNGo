extends VBoxContainer

# The menu's character section: the viewed character big in the middle (drag to spin it), and
# a strip of thumbnails below to pick another. Owned characters become the saved choice used in
# every mode; locked ones can be previewed and bought with coins (character_roster.gd "price").

signal coins_changed

const CharacterRoster := preload("res://character_roster.gd")
const CharacterView := preload("res://character_view.gd")
const MenuHero := preload("res://menu_hero.gd")
const UiKit := preload("res://ui_kit.gd")

const THUMB_SIZE := 116.0
const THUMB_VIEW := 256

var _hero: Control
var _name_label: Label
var _buy_button: Button
var _thumbs: Array[Button] = []
# The character on show. Differs from GameData.selected_character while previewing a locked one.
var _viewing := 0


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_viewing = GameData.selected_character

	_hero = MenuHero.new()
	_hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_hero)

	_name_label = UiKit.title("", 34, UiKit.GOLD)
	add_child(_name_label)

	_buy_button = Button.new()
	_buy_button.custom_minimum_size = Vector2(0.0, 76.0)
	_buy_button.add_theme_font_size_override("font_size", 30)
	_buy_button.pressed.connect(_buy)
	add_child(_buy_button)

	# Dark rounded tray holding the thumbnails; it scrolls sideways when there are many.
	var tray := PanelContainer.new()
	tray.add_theme_stylebox_override("panel", UiKit.box(Color(0.04, 0.05, 0.07, 0.92), Color(1, 1, 1, 0.08), 30, 2, -1, 14.0, 14.0))
	add_child(tray)
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = THUMB_SIZE + 8.0
	tray.add_child(scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	scroll.add_child(row)
	for i in CharacterRoster.count():
		var thumb := _make_thumb(i)
		row.add_child(thumb)
		_thumbs.append(thumb)
	_refresh()


func _make_thumb(index: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(THUMB_SIZE, THUMB_SIZE)
	button.clip_contents = true
	button.pressed.connect(_select.bind(index))

	var view := CharacterView.new()
	view.view_size = THUMB_VIEW
	view.face_camera = true
	view.still = true
	view.character = index
	view.position = Vector2.ONE * THUMB_SIZE / 2.0
	view.scale = Vector2.ONE * THUMB_SIZE / THUMB_VIEW * 1.08
	button.add_child(view)

	if not GameData.owns_character(index):
		var shade := ColorRect.new()
		shade.color = Color(0.0, 0.0, 0.0, 0.55)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(shade)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var lock := UiKit.LockIcon.new(44.0)
		lock.position = Vector2.ONE * (THUMB_SIZE - 44.0) / 2.0
		button.add_child(lock)
	return button


func _select(index: int) -> void:
	if index == _viewing:
		return
	_viewing = index
	_hero.show_character(index)
	if GameData.owns_character(index):
		GameData.selected_character = index
		GameData.save()
	_refresh()


func _buy() -> void:
	if not GameData.buy_character(_viewing):
		return
	GameData.selected_character = _viewing
	GameData.save()
	# Rebuild the thumbnail without its padlock and the coin counter around us.
	var old := _thumbs[_viewing]
	var fresh := _make_thumb(_viewing)
	old.get_parent().add_child(fresh)
	old.get_parent().move_child(fresh, old.get_index())
	old.queue_free()
	_thumbs[_viewing] = fresh
	_refresh()
	coins_changed.emit()


# The viewed thumbnail gets a bright frame in the character's colour; a locked one shows its price.
func _refresh() -> void:
	var viewed := _viewing
	var owned := GameData.owns_character(viewed)
	_name_label.text = CharacterRoster.character_name(viewed).to_upper()

	_buy_button.visible = not owned
	if not owned:
		var price := CharacterRoster.price(viewed)
		if price < 0:
			_buy_button.text = "DAY 7 DAILY REWARD"
			_buy_button.disabled = true
			UiKit.style_button(_buy_button, "dark")
		elif GameData.coins < price:
			_buy_button.text = "%d COINS  (NEED %d MORE)" % [price, price - GameData.coins]
			_buy_button.disabled = true
			UiKit.style_button(_buy_button, "dark")
		else:
			_buy_button.text = "UNLOCK FOR %d COINS" % price
			_buy_button.disabled = false
			UiKit.style_button(_buy_button, "yellow")

	for i in _thumbs.size():
		var accent: Color = CharacterRoster.get_character(i)["accent"]
		var picked := i == viewed
		var bg := Color(0.12, 0.14, 0.18) if picked else Color(0.07, 0.08, 0.1)
		var border := accent if picked else Color(1, 1, 1, 0.1)
		var style := UiKit.box(bg, border, 22, 5 if picked else 2)
		for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
			_thumbs[i].add_theme_stylebox_override(style_name, style)
