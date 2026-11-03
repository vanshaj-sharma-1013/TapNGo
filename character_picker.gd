extends VBoxContainer

# The menu's character section: the chosen character big in the middle (drag to spin it), and
# a strip of thumbnails below to pick another. The choice is saved and used in every mode.

const CharacterRoster := preload("res://character_roster.gd")
const CharacterView := preload("res://character_view.gd")
const MenuHero := preload("res://menu_hero.gd")
const UiKit := preload("res://ui_kit.gd")

const THUMB_SIZE := 116.0
const THUMB_VIEW := 256

var _hero: Control
var _name_label: Label
var _thumbs: Array[Button] = []


func _ready() -> void:
	add_theme_constant_override("separation", 10)

	_hero = MenuHero.new()
	_hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_hero)

	_name_label = UiKit.title("", 34, UiKit.GOLD)
	add_child(_name_label)

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
	return button


func _select(index: int) -> void:
	if index == GameData.selected_character:
		return
	GameData.selected_character = index
	GameData.save()
	_hero.show_character(index)
	_refresh()


# The chosen thumbnail gets a bright frame in the character's colour.
func _refresh() -> void:
	var chosen := GameData.selected_character
	_name_label.text = CharacterRoster.character_name(chosen).to_upper()
	for i in _thumbs.size():
		var accent: Color = CharacterRoster.get_character(i)["accent"]
		var picked := i == chosen
		var bg := Color(0.12, 0.14, 0.18) if picked else Color(0.07, 0.08, 0.1)
		var border := accent if picked else Color(1, 1, 1, 0.1)
		var style := UiKit.box(bg, border, 22, 5 if picked else 2)
		for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
			_thumbs[i].add_theme_stylebox_override(style_name, style)
