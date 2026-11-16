extends VBoxContainer

# The shop screen's body (menu.gd puts the header with the coin balance above it): a row of
# category tabs, and under it the cards of the open category. Everything costs coins except
# the "Offers" tab, whose content (the Remove Ads purchase) menu.gd supplies.
# After any purchase `changed` fires and the menu rebuilds the screen, so the coin pill updates.

signal changed

const CharacterRoster := preload("res://character_roster.gd")
const CharacterView := preload("res://character_view.gd")
const TrailStyles := preload("res://trail_styles.gd")
const Potions := preload("res://potions.gd")
const UiKit := preload("res://ui_kit.gd")

const TABS := [
	["characters", "CHARACTERS"],
	["potions", "POTIONS"],
	["trails", "TRAILS"],
	["offers", "OFFERS"],
]
const CARD_BG := Color(0.03, 0.07, 0.13, 0.88)
const THUMB := 250.0
const THUMB_VIEW := 256

# Remembered while the screen is rebuilt after a purchase.
static var tab := "characters"
static var scroll_pos := 0

# Set by the menu before the shop is added to the tree.
var notice := ""
var offers_builder := Callable()

var _scroll: ScrollContainer


func _ready() -> void:
	add_theme_constant_override("separation", 14)

	if notice != "":
		var note := Label.new()
		note.text = notice
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_font_size_override("font_size", 26)
		note.add_theme_color_override("font_color", UiKit.GOLD)
		add_child(note)

	add_child(_make_tabs())

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 16)
	_scroll.add_child(list)

	match tab:
		"potions":
			_fill_potions(list)
		"trails":
			_fill_trails(list)
		"offers":
			if offers_builder.is_valid():
				list.add_child(offers_builder.call())
		_:
			_fill_characters(list)

	# Come back to where the player was scrolled to, once the list has its size.
	_scroll.get_v_scroll_bar().value_changed.connect(func(value: float) -> void: scroll_pos = int(value))
	_restore_scroll.call_deferred()


func _restore_scroll() -> void:
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = scroll_pos


func _make_tabs() -> Control:
	var tray := PanelContainer.new()
	tray.add_theme_stylebox_override("panel", UiKit.box(Color(0.04, 0.05, 0.07, 0.92), Color(1, 1, 1, 0.08), 30, 2, -1, 8.0, 8.0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	tray.add_child(row)
	for entry in TABS:
		var button := Button.new()
		button.text = entry[1]
		button.toggle_mode = true
		button.button_pressed = entry[0] == tab
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, 72.0)
		button.add_theme_font_size_override("font_size", 22)
		UiKit.style_segment(button)
		button.pressed.connect(_open_tab.bind(entry[0]))
		row.add_child(button)
	return tray


func _open_tab(id: String) -> void:
	if id == tab:
		return
	tab = id
	scroll_pos = 0
	changed.emit()


# ---- Characters -------------------------------------------------------------------------------

func _fill_characters(list: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	list.add_child(grid)
	for i in CharacterRoster.count():
		grid.add_child(_character_card(i))


func _character_card(index: int) -> Control:
	var info := CharacterRoster.get_character(index)
	var accent: Color = info["accent"]
	var owned := GameData.owns_character(index)
	var equipped := owned and GameData.selected_character == index

	var card := UiKit.card(CARD_BG, Color(accent, 0.9 if equipped else 0.4), 26, 14.0, 14.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)

	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0.0, THUMB)
	stage.clip_contents = true
	column.add_child(stage)
	var glow := ColorRect.new()
	glow.color = Color(accent, 0.12)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(glow)
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var view := CharacterView.new()
	view.view_size = THUMB_VIEW
	view.face_camera = true
	view.still = true
	view.character = index
	stage.add_child(view)
	# The stage is as wide as the card allows; centre the picture in it once that is known.
	stage.resized.connect(func() -> void:
		view.position = stage.size / 2.0
		view.scale = Vector2.ONE * minf(stage.size.x, stage.size.y) / THUMB_VIEW * 1.08)
	if not owned:
		var shade := ColorRect.new()
		shade.color = Color(0.0, 0.0, 0.0, 0.5)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(shade)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var lock := UiKit.LockIcon.new(52.0)
		lock.position = Vector2(8.0, 8.0)
		stage.add_child(lock)

	var name_label := UiKit.title(str(info["name"]).to_upper(), 28, accent.lightened(0.3))
	column.add_child(name_label)

	var button := Button.new()
	button.custom_minimum_size = Vector2(0.0, 72.0)
	button.add_theme_font_size_override("font_size", 26)
	column.add_child(button)
	var price := CharacterRoster.price(index)
	if equipped:
		button.text = "EQUIPPED"
		button.disabled = true
		UiKit.style_button(button, "dark")
	elif owned:
		button.text = "EQUIP"
		UiKit.style_button(button, "blue")
		button.pressed.connect(func() -> void:
			GameData.selected_character = index
			GameData.save()
			changed.emit())
	elif price < 0:
		button.text = "DAILY REWARD"
		button.disabled = true
		UiKit.style_button(button, "dark")
	elif GameData.coins < price:
		button.text = "%d  (NEED %d MORE)" % [price, price - GameData.coins]
		button.disabled = true
		UiKit.style_button(button, "dark")
	else:
		button.text = "BUY  %d" % price
		UiKit.style_button(button, "yellow")
		button.pressed.connect(func() -> void:
			if GameData.buy_character(index):
				GameData.selected_character = index
				GameData.save()
				changed.emit())
	return card


# ---- Potions ----------------------------------------------------------------------------------

func _fill_potions(list: VBoxContainer) -> void:
	list.add_child(_caption("Potions are kept in your bag. Tap them during a run; the Revive Potion is offered when you crash."))
	for potion in Potions.POTIONS:
		list.add_child(_potion_card(potion))


func _potion_card(potion: Dictionary) -> Control:
	var id: String = potion["id"]
	var color: Color = potion["color"]
	var price: int = potion["price"]
	var card := UiKit.card(CARD_BG, Color(color, 0.55), 24, 16.0, 14.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)

	# The flask sits on a soft disc in the potion's colour.
	var disc := PanelContainer.new()
	disc.add_theme_stylebox_override("panel", UiKit.box(Color(color, 0.16), Color(color, 0.5), 40, 2, -1, 8.0, 8.0))
	disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	disc.add_child(Potions.PotionIcon.new(id, 88.0))
	row.add_child(disc)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 4)
	row.add_child(text)
	var name_label := Label.new()
	name_label.text = potion["name"]
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", color.lightened(0.35))
	text.add_child(name_label)
	var desc := Label.new()
	desc.text = potion["desc"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 20)
	desc.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	text.add_child(desc)
	var owned := Label.new()
	owned.text = "In bag: %d" % GameData.potion_count(id)
	owned.add_theme_font_size_override("font_size", 22)
	owned.add_theme_color_override("font_color", UiKit.GREEN if GameData.potion_count(id) > 0 else Color(1, 1, 1, 0.45))
	text.add_child(owned)

	var buy := Button.new()
	buy.custom_minimum_size = Vector2(150.0, 84.0)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.add_theme_font_size_override("font_size", 26)
	buy.text = "BUY\n%d" % price
	if GameData.coins >= price:
		UiKit.style_button(buy, "yellow")
		buy.pressed.connect(func() -> void:
			if GameData.buy_potion(id):
				changed.emit())
	else:
		buy.disabled = true
		UiKit.style_button(buy, "dark")
	row.add_child(buy)
	return card


# ---- Trails -----------------------------------------------------------------------------------

func _fill_trails(list: VBoxContainer) -> void:
	list.add_child(_caption("The streak that follows your runner."))
	for trail in TrailStyles.TRAILS:
		list.add_child(_trail_card(trail))


func _trail_card(trail: Dictionary) -> Control:
	var id: String = trail["id"]
	var colors: Array = trail["colors"]
	var owned := GameData.owns_trail(id)
	var equipped := owned and GameData.selected_trail == id
	var price: int = trail["price"]
	var card := UiKit.card(CARD_BG, Color(colors[colors.size() - 1], 0.9 if equipped else 0.4), 24, 16.0, 14.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)

	var gradient := GradientTexture2D.new()
	gradient.gradient = TrailStyles.make_gradient(id)
	gradient.fill_from = Vector2(0.0, 0.5)
	gradient.fill_to = Vector2(1.0, 0.5)
	gradient.width = 160
	gradient.height = 24
	var swatch := TextureRect.new()
	swatch.texture = gradient
	swatch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	swatch.stretch_mode = TextureRect.STRETCH_SCALE
	swatch.custom_minimum_size = Vector2(170.0, 30.0)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(swatch)

	var name_label := Label.new()
	name_label.text = str(trail["name"]) + ("   RARE" if trail.get("rare", false) else "")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 26)
	row.add_child(name_label)

	var button := Button.new()
	button.custom_minimum_size = Vector2(190.0, 72.0)
	button.add_theme_font_size_override("font_size", 24)
	row.add_child(button)
	if equipped:
		button.text = "EQUIPPED"
		button.disabled = true
		UiKit.style_button(button, "dark")
	elif owned:
		button.text = "EQUIP"
		UiKit.style_button(button, "blue")
		button.pressed.connect(func() -> void:
			GameData.select_trail(id)
			changed.emit())
	elif price < 0:
		button.text = "DAILY REWARD"
		button.disabled = true
		UiKit.style_button(button, "dark")
	elif GameData.coins < price:
		button.text = "%d COINS" % price
		button.disabled = true
		UiKit.style_button(button, "dark")
	else:
		button.text = "BUY  %d" % price
		UiKit.style_button(button, "yellow")
		button.pressed.connect(func() -> void:
			if GameData.buy_trail(id):
				GameData.select_trail(id)
				changed.emit())
	return card


func _caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	return label
