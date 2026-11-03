extends Control

const WorldData = preload("res://world_data.gd")
const WorldArt := preload("res://world_art.gd")
const WorldBackground := preload("res://world_background.gd")
const StarRow := preload("res://star_row.gd")
const ButtonPreview := preload("res://button_preview.gd")
const UiKit := preload("res://ui_kit.gd")
const CharacterPicker := preload("res://character_picker.gd")
const UI_THEME := preload("res://ui_theme.tres")
const MENU_BACKGROUND := preload("res://assets/ui/menu_background.jpg")
const LOGO_DARK := preload("res://assets/logo/logo_dark.jpg")

const NEON_CYAN := UiKit.CYAN
const ERROR_COLOR := Color("ff6b6b")
const CAMPAIGN_SCENE := "res://campaign.tscn"
const ENDLESS_SCENE := "res://endless.tscn"
const LEVEL_COLUMNS := 5
const LEVELS_PER_PAGE := 25
const BACK_BUTTON_SIZE := 84.0
const RESEND_COOLDOWN_MS := 45000

# Every screen is rebuilt inside `host`. `content` is the column that the _add_* helpers fill:
# a centred one for the simple form screens, or a full-screen one from _full_layout().
var host: Control
var content: VBoxContainer
var preview: Control
var size_label: Label
# True while a sign-in or similar request is in flight, so taps don't stack up.
var busy := false
# A problem from signup (e.g. the code email failed) to show on the verify screen.
var pending_notice := ""
# When the verify screen may send another code (Time.get_ticks_msec()).
var resend_ready_ms := 0


func _ready() -> void:
	theme = UI_THEME
	_add_background()

	host = Control.new()
	add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_show_main()


# The painted night scene behind every menu screen, with a light dark wash so the cards stand out.
func _add_background() -> void:
	var picture := TextureRect.new()
	picture.texture = MENU_BACKGROUND
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.0, 0.02, 0.06, 0.35), Color(0.0, 0.0, 0.03, 0.7)])
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	var shade := TextureRect.new()
	shade.texture = texture
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _show_main() -> void:
	_clear()
	var page := _full_layout(14)

	# Nothing to play until the player has logged in (or chosen guest).
	if not Cloud.can_play():
		page.add_child(_make_logo())
		_add_expander()
		var ring := UiKit.Icon.new("person", 110.0, Color(UiKit.CYAN, 0.75))
		ring.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		page.add_child(ring)
		var note := _add_note("Verify your email to play" if Cloud.is_signed_in() else "Log in to play")
		note.add_theme_color_override("font_color", UiKit.TEXT_DIM)
		_add_expander()
		_add_icon_button("VERIFY EMAIL" if Cloud.is_signed_in() else "LOG IN", "person", _show_account, 100, "primary")
		_add_icon_button("SETTINGS", "gear", _show_settings, 88)
		return

	# Top bar: who is playing, and how many stars they have.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	page.add_child(top)
	var chip := _make_button(Cloud.shown_name(), _show_account, 76)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.alignment = HORIZONTAL_ALIGNMENT_LEFT
	chip.clip_text = true  # a long name must not stretch the bar
	chip.add_theme_font_size_override("font_size", 28)
	for style_name in ["normal", "hover", "pressed"]:
		(chip.get_theme_stylebox(style_name) as StyleBoxFlat).content_margin_left = 82.0
	var avatar := UiKit.Avatar.new(Cloud.shown_name(), 52.0)
	avatar.anchor_top = 0.5
	avatar.anchor_bottom = 0.5
	avatar.offset_left = 14.0
	avatar.offset_right = 66.0
	avatar.offset_top = -26.0
	avatar.offset_bottom = 26.0
	chip.add_child(avatar)
	top.add_child(chip)
	top.add_child(_stars_pill())

	var logo := _make_logo()
	page.add_child(logo)
	# Slow glow pulse on the logo.
	var pulse := logo.create_tween().set_loops()
	pulse.tween_property(logo, "modulate", Color(1.25, 1.25, 1.25, 1.0), 1.2).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(logo, "modulate", Color.WHITE, 1.2).set_trans(Tween.TRANS_SINE)

	var picker := CharacterPicker.new()
	picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(picker)

	var play := _add_icon_button("PLAY", "play", _show_worlds, 112, "warn")
	play.add_theme_font_size_override("font_size", 56)
	var endless := _add_button("ENDLESS     Best %d m" % GameData.best_endless,
			func(): get_tree().change_scene_to_file(ENDLESS_SCENE), 84, "blue")
	endless.add_theme_font_size_override("font_size", 32)

	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 14)
	page.add_child(nav)
	for item in [["RANKS", "trophy", _show_leaderboard], ["BADGES", "shield", _show_achievements],
			["OPTIONS", "gear", _show_settings], ["PROFILE", "person", _show_account]]:
		nav.add_child(_nav_tile(item[0], item[1], item[2]))


# "TAP-N-GO" in three colours.
func _make_logo() -> Control:
	# The picture is a square with the wordmark across the middle: crop to the wordmark.
	var atlas := AtlasTexture.new()
	atlas.atlas = LOGO_DARK
	atlas.region = Rect2(30.0, 380.0, 964.0, 200.0)
	var logo := TextureRect.new()
	logo.texture = atlas
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(0.0, 150.0)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The picture has a dark background; the shader fades dark pixels out so only the lettering shows.
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = smoothstep(0.12, 0.42, max(max(c.r, c.g), c.b));
	COLOR = vec4(c.rgb, a) * COLOR;
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	logo.material = material
	return logo


func _stars_pill() -> Control:
	var total := GameData.total_stars()
	var most := WorldData.WORLD_COUNT * WorldData.max_world_stars()
	return UiKit.pill("%d / %d" % [total, most], UiKit.GOLD, StarRow.new(1, 30.0, 1))


# Back button, title, and a spacer the size of the back button so the title stays centred.
func _header(title_text: String, back: Callable, right: Control = null) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var back_button := _make_button("", back, BACK_BUTTON_SIZE)
	back_button.custom_minimum_size.x = BACK_BUTTON_SIZE
	UiKit.add_button_icon(back_button, "back", 40.0, UiKit.CYAN)
	(back_button.get_child(0) as Control).offset_left = (BACK_BUTTON_SIZE - 40.0) / 2.0 - 3.0
	(back_button.get_child(0) as Control).offset_right = (BACK_BUTTON_SIZE + 40.0) / 2.0 - 3.0
	row.add_child(back_button)

	var label := UiKit.title(title_text, 44 if title_text.length() <= 14 else 30, Color(0.85, 0.95, 1.0))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)

	if right != null:
		row.add_child(right)
	else:
		var spacer := Control.new()
		spacer.custom_minimum_size.x = BACK_BUTTON_SIZE
		row.add_child(spacer)
	return row


func _centered(child: Control) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(child)
	return row


func _show_worlds() -> void:
	_clear()
	var page := _full_layout(16)
	page.add_child(_header("SELECT WORLD", _show_main, _stars_pill()))

	# Four tall cards can be taller than the screen on small phones, so the list scrolls.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 18)
	scroll.add_child(list)
	for world in WorldData.WORLD_COUNT:
		list.add_child(_world_card(world))


# One tappable card per world: its floor art, name, and how close the player is to finishing
# it (or to unlocking it).
func _world_card(world: int) -> Button:
	var rules := WorldData.world(world)
	var accent: Color = rules["accent"]
	var unlocked := GameData.is_world_unlocked(world)
	var stars := GameData.world_stars(world)
	var most := WorldData.max_world_stars()

	var card := Button.new()
	card.custom_minimum_size = Vector2(0.0, 230.0)
	card.disabled = not unlocked
	for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		card.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	card.pressed.connect(_show_levels.bind(world))

	var picture := WorldArt.backdrop(world)
	var tint: Color = Color.WHITE if picture != null else rules["ground_tint"]
	var frame := accent
	if not unlocked:
		tint = tint.darkened(0.6)
		frame = Color(0.4, 0.46, 0.52, 0.8)
	if picture == null:
		picture = WorldArt.texture(world, "environment/ground_tile")
	var art := UiKit.RoundedImage.new(picture, tint, frame)
	# Let the scenery show through; the name still gets a dark left side to sit on.
	art.shade_left = 0.7
	art.shade_right = 0.05
	card.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	card.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 10)
	row.add_child(info)

	var name_label := UiKit.title(WorldData.world_name(world).to_upper(), 40, Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(name_label)

	if unlocked:
		var percent_row := HBoxContainer.new()
		percent_row.add_theme_constant_override("separation", 10)
		percent_row.add_child(StarRow.new(1, 30.0, 1))
		var percent := Label.new()
		percent.text = "%d%%" % roundi(100.0 * stars / most)
		percent.add_theme_font_size_override("font_size", 30)
		percent.add_theme_color_override("font_color", UiKit.GOLD)
		percent_row.add_child(percent)
		info.add_child(percent_row)
		info.add_child(UiKit.progress(stars, most, accent))
		if stars >= most:
			var done := UiKit.Icon.new("unlock", 64.0, UiKit.GREEN)
			done.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(done)
	else:
		var have := GameData.world_stars(world - 1)
		var caption := Label.new()
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.add_theme_font_size_override("font_size", 24)
		caption.add_theme_color_override("font_color", Color(0.9, 0.96, 1.0))
		caption.text = "Locked: %d / %d stars in %s" % [have, WorldData.STARS_TO_UNLOCK, WorldData.world_name(world - 1)]
		info.add_child(caption)
		info.add_child(UiKit.progress(have, WorldData.STARS_TO_UNLOCK, Color(0.6, 0.68, 0.74)))
		var lock := UiKit.Icon.new("lock", 72.0, Color(0.92, 0.96, 1.0))
		lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(lock)

	UiKit.ignore_mouse(card)
	return card


# The first level the player has not cleared yet (the last one once they have cleared them all).
func _current_level(world: int) -> int:
	for n in range(1, WorldData.LEVELS_PER_WORLD + 1):
		if GameData.stars_for(world, n) == 0:
			return n
	return WorldData.LEVELS_PER_WORLD


# `page` -1 opens on the page that holds the player's current level.
func _show_levels(world: int, page := -1) -> void:
	_clear()
	var layout := _full_layout(18)
	_add_world_backdrop(world)
	var accent: Color = WorldData.world(world)["accent"]
	var stars_label := "%d / %d" % [GameData.world_stars(world), WorldData.max_world_stars()]
	var pill := UiKit.pill(stars_label, UiKit.GOLD, StarRow.new(1, 30.0, 1))
	layout.add_child(_header(WorldData.world_name(world).to_upper(), _show_worlds, pill))

	var pages := ceili(float(WorldData.LEVELS_PER_WORLD) / LEVELS_PER_PAGE)
	var current := _current_level(world)
	if page < 0:
		page = floori((current - 1) / float(LEVELS_PER_PAGE))
	page = clampi(page, 0, pages - 1)

	var grid := GridContainer.new()
	grid.columns = LEVEL_COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	layout.add_child(grid)
	for i in LEVELS_PER_PAGE:
		var n := page * LEVELS_PER_PAGE + i + 1
		if n > WorldData.LEVELS_PER_WORLD:
			break
		grid.add_child(_level_card(world, n, current))

	_add_expander()

	var pager := HBoxContainer.new()
	pager.alignment = BoxContainer.ALIGNMENT_CENTER
	pager.add_theme_constant_override("separation", 20)
	layout.add_child(pager)
	var previous := _make_button("<", _show_levels.bind(world, page - 1), 72)
	previous.custom_minimum_size.x = 90.0
	previous.disabled = page == 0
	pager.add_child(previous)
	pager.add_child(UiKit.PageDots.new(pages, page, accent))
	var next := _make_button(">", _show_levels.bind(world, page + 1), 72)
	next.custom_minimum_size.x = 90.0
	next.disabled = page >= pages - 1
	pager.add_child(next)


# The world's own scenery behind the level grid, dimmed so the buttons stay readable. It covers
# the menu background while this screen is shown.
func _add_world_backdrop(world: int) -> void:
	var picture := WorldArt.backdrop(world)
	if picture == null:
		return
	var backdrop := TextureRect.new()
	backdrop.texture = picture
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.modulate = Color(0.5, 0.5, 0.5)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(backdrop)
	host.move_child(backdrop, 0)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _level_card(world: int, n: int, current: int) -> Button:
	var unlocked := GameData.is_level_unlocked(world, n)
	var button := Button.new()
	button.text = str(n)
	button.custom_minimum_size = Vector2(0.0, 132.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 44)
	button.disabled = not unlocked
	# The level to play next stands out in orange.
	UiKit.style_button(button, "warn" if unlocked and n == current else "dark")
	button.pressed.connect(_start_level.bind(world, n))

	# Earned stars (or a padlock) along the bottom of the card.
	var footer: Control
	if unlocked:
		footer = StarRow.new(GameData.stars_for(world, n), 22.0)
	else:
		footer = UiKit.Icon.new("lock", 30.0, Color(0.7, 0.78, 0.84))
	var footer_size := footer.custom_minimum_size
	footer.anchor_left = 0.5
	footer.anchor_right = 0.5
	footer.anchor_top = 1.0
	footer.anchor_bottom = 1.0
	footer.offset_left = -footer_size.x / 2.0
	footer.offset_right = footer_size.x / 2.0
	footer.offset_top = -footer_size.y - 14.0
	footer.offset_bottom = -14.0
	button.add_child(footer)
	return button


func _show_settings() -> void:
	_clear()
	var page := _full_layout(16)
	page.add_child(_header("SETTINGS", _show_main))
	_add_gap(8.0)

	_add_toggle("Sound", not GameData.muted, _on_sound_toggled)
	_add_toggle("Vibration", GameData.vibration, _on_vibration_toggled)
	_add_toggle("Screen shake", GameData.screen_shake, _on_shake_toggled)

	_add_caption("BUTTON LAYOUT")
	var layout_row := HBoxContainer.new()
	layout_row.add_theme_constant_override("separation", 12)
	content.add_child(layout_row)
	var group := ButtonGroup.new()
	for option in [["SPLIT", GameData.LAYOUT_SPLIT], ["LEFT", GameData.LAYOUT_LEFT], ["RIGHT", GameData.LAYOUT_RIGHT]]:
		var button := Button.new()
		button.text = option[0]
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = GameData.button_layout == option[1]
		button.custom_minimum_size = Vector2(0, 76)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiKit.style_segment(button)
		button.add_theme_font_size_override("font_size", 28)
		button.pressed.connect(_set_layout.bind(option[1]))
		layout_row.add_child(button)

	size_label = _add_caption("")
	_update_size_label()
	var slider := HSlider.new()
	slider.min_value = GameData.BUTTON_SCALE_MIN
	slider.max_value = GameData.BUTTON_SCALE_MAX
	slider.step = 0.05
	slider.value = GameData.button_scale
	slider.custom_minimum_size = Vector2(0, 48)
	UiKit.style_slider(slider)
	slider.value_changed.connect(_on_size_changed)
	slider.drag_ended.connect(_on_size_drag_ended)
	content.add_child(slider)

	preview = ButtonPreview.new()
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(preview)

	_add_expander()
	if Cloud.is_signed_in():
		_add_icon_button("EDIT PROFILE", "person", _show_edit_profile.bind(_show_settings), 84)


func _show_account() -> void:
	if not Cloud.is_signed_in():
		_show_login()
	elif not Cloud.email_verified and not Cloud.is_guest():
		_show_verify()
	else:
		_show_profile()


# After a successful login, signup or verification: into the game menu if the player
# may play now, otherwise on to the email code screen.
func _after_auth() -> void:
	if Cloud.can_play():
		_show_main()
	else:
		_show_account()


func _show_login() -> void:
	_clear()
	var page := _full_layout(18)
	page.add_child(_header("LOG IN", _show_main))
	_add_gap(20.0)
	var email_field := _add_field("Email", false, "person")
	var password_field := _add_field("Password", true, "lock")
	var status := _add_note("")
	_add_button("LOG IN", _submit_login.bind(email_field, password_field, status), 96, "primary")
	_add_button("CREATE ACCOUNT", _show_signup, 96, "warn")
	_add_divider("OR")
	_add_icon_button("CONTINUE WITH GOOGLE", "google", _continue_with_google.bind(status), 84)
	_add_icon_button("PLAY AS GUEST", "person", _continue_as_guest.bind(status), 84)


func _show_signup() -> void:
	_clear()
	var page := _full_layout(18)
	page.add_child(_header("SIGN UP", _show_main))
	_add_gap(20.0)
	var email_field := _add_field("Email", false, "person")
	var password_field := _add_field("Password (6+ characters)", true, "lock")
	var status := _add_note("")
	_add_button("CREATE ACCOUNT", _submit_signup.bind(email_field, password_field, status), 96, "primary")
	_add_divider("OR")
	_add_icon_button("CONTINUE WITH GOOGLE", "google", _continue_with_google.bind(status), 84)
	_add_button("I ALREADY HAVE AN ACCOUNT", _show_login, 84)


func _show_verify() -> void:
	_clear()
	var page := _full_layout(18)
	page.add_child(_header("VERIFY EMAIL", _show_main))
	_add_gap(20.0)
	var note := _add_note("We emailed a 6-digit code to")
	note.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	var address := _add_note(Cloud.email)
	address.add_theme_font_size_override("font_size", 32)
	var code_field := _add_code_boxes()
	var status := _add_note("")
	if not pending_notice.is_empty():
		_show_error(status, pending_notice)
		pending_notice = ""
	_add_button("VERIFY", _submit_code.bind(code_field, status), 96, "primary")

	var resend := Button.new()
	resend.flat = true
	resend.add_theme_font_size_override("font_size", 28)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color"]:
		resend.add_theme_color_override(color_name, Color("5aa2ff"))
	resend.add_theme_color_override("font_disabled_color", Color(0.5, 0.6, 0.66))
	resend.pressed.connect(_resend_verification.bind(status, resend))
	content.add_child(resend)
	_tick_resend(resend)

	_add_expander()
	_add_button("LOG OUT", _log_out, 84, "danger")


func _show_profile() -> void:
	_clear()
	var page := _full_layout(18)
	page.add_child(_header("ACCOUNT", _show_main))
	_add_gap(8.0)

	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 20)
	who.add_child(UiKit.Avatar.new(Cloud.shown_name(), 100.0))
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", -2)
	var shown := Label.new()
	shown.text = Cloud.shown_name()
	shown.clip_text = true
	shown.add_theme_font_size_override("font_size", 44)
	names.add_child(shown)
	var detail := Label.new()
	detail.text = ("@%s" % Cloud.display_name) if not Cloud.full_name.is_empty() else Cloud.email
	if Cloud.is_guest():
		detail.text = "Guest"
	detail.clip_text = true
	detail.add_theme_font_size_override("font_size", 24)
	detail.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	names.add_child(detail)
	who.add_child(names)
	content.add_child(who)

	if Cloud.is_guest():
		var warning := UiKit.card(Color(UiKit.GOLD, 0.08), Color(UiKit.GOLD, 0.85), 18, 24.0, 20.0)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 14)
		warning.add_child(column)
		var message := Label.new()
		message.text = "You are playing as a guest. Create an account to save your progress and appear on leaderboards."
		message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		message.add_theme_font_size_override("font_size", 26)
		message.add_theme_color_override("font_color", UiKit.GOLD)
		column.add_child(message)
		var create := _make_button("CREATE ACCOUNT", _show_signup, 72, "yellow")
		create.add_theme_font_size_override("font_size", 30)
		column.add_child(create)
		content.add_child(warning)

	_add_gap(6.0)
	var best_caption := _add_caption("ENDLESS BEST")
	best_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var best := UiKit.title("%d m" % GameData.best_endless, 64, Color("5aa2ff"))
	content.add_child(best)

	_add_expander()
	_add_icon_button("LEADERBOARD", "trophy", _show_leaderboard, 88)
	_add_icon_button("EDIT PROFILE", "person", _show_edit_profile.bind(_show_profile), 88)
	_add_button("LOG OUT", _log_out, 84, "danger")


# Username and optional full name. `back` is the screen to return to.
func _show_edit_profile(back: Callable) -> void:
	_clear()
	var page := _full_layout(14)
	page.add_child(_header("EDIT PROFILE", back))
	_add_gap(16.0)
	_add_caption("Username")
	var username_field := _add_field("Username")
	username_field.text = Cloud.display_name
	username_field.max_length = Cloud.NAME_MAX
	_add_caption("Full name (optional)")
	var full_name_field := _add_field("Your name")
	full_name_field.text = Cloud.full_name
	full_name_field.max_length = Cloud.FULL_NAME_MAX
	var status := _add_note("Shown on the leaderboard. Leave the full name empty to show only your username.")
	status.add_theme_font_size_override("font_size", 24)
	status.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	_add_expander()
	_add_button("SAVE", _submit_profile.bind(username_field, full_name_field, status, back), 96, "primary")


func _submit_profile(username_field: LineEdit, full_name_field: LineEdit, status: Label, back: Callable) -> void:
	if busy:
		return
	busy = true
	_show_info(status, "Saving...")
	var result: Dictionary = await Cloud.update_profile(username_field.text, full_name_field.text)
	busy = false
	if not _still_showing(status):
		return
	if result.ok:
		back.call()
	else:
		_show_error(status, result.message)


func _submit_login(email_field: LineEdit, password_field: LineEdit, status: Label) -> void:
	if busy:
		return
	busy = true
	_show_info(status, "Logging in...")
	var result: Dictionary = await Cloud.sign_in(email_field.text.strip_edges(), password_field.text)
	busy = false
	if not _still_showing(status):
		return
	if result.ok:
		_after_auth()
	else:
		_show_error(status, result.message)


func _submit_signup(email_field: LineEdit, password_field: LineEdit, status: Label) -> void:
	if busy:
		return
	busy = true
	_show_info(status, "Creating account...")
	var result: Dictionary = await Cloud.sign_up(email_field.text.strip_edges(), password_field.text)
	busy = false
	if not _still_showing(status):
		return
	if result.ok:
		pending_notice = str(result.get("notice", ""))
		resend_ready_ms = Time.get_ticks_msec() + RESEND_COOLDOWN_MS
		_after_auth()
	else:
		_show_error(status, result.message)


func _continue_with_google(status: Label) -> void:
	if busy:
		return
	busy = true
	_show_info(status, "Finish signing in in your browser,\nthen come back to the game.")
	var result: Dictionary = await Cloud.sign_in_with_google()
	busy = false
	if not _still_showing(status):
		return
	if result.ok:
		_after_auth()
	else:
		_show_error(status, result.message)


func _continue_as_guest(status: Label) -> void:
	if busy:
		return
	busy = true
	_show_info(status, "Setting up your guest account...")
	var result: Dictionary = await Cloud.sign_in_as_guest()
	busy = false
	if not _still_showing(status):
		return
	if result.ok:
		_after_auth()
	else:
		_show_error(status, result.message)


func _submit_code(code_field: LineEdit, status: Label) -> void:
	if busy:
		return
	busy = true
	_show_info(status, "Checking...")
	var result: Dictionary = await Cloud.verify_code(code_field.text.strip_edges())
	busy = false
	if not _still_showing(status):
		return
	if result.ok:
		_after_auth()
	else:
		_show_error(status, result.message)


func _resend_verification(status: Label, resend_button: Button) -> void:
	if busy:
		return
	busy = true
	_show_info(status, "Sending...")
	var result: Dictionary = await Cloud.send_verification()
	busy = false
	if _still_showing(status):
		if result.ok:
			_show_info(status, "Code sent. Check your inbox and spam folder.")
			resend_ready_ms = Time.get_ticks_msec() + RESEND_COOLDOWN_MS
			_tick_resend(resend_button)
		else:
			_show_error(status, result.message)


func _log_out() -> void:
	Cloud.sign_out()
	_show_main()


func _show_leaderboard(endless := true) -> void:
	_clear()
	var page := _full_layout(16)
	page.add_child(_header("GLOBAL TOP", _show_main))

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 0)
	page.add_child(tabs)
	for tab in [["LEVELS", false], ["ENDLESS", true]]:
		var tab_button := _make_button(tab[0], _show_leaderboard.bind(tab[1]), 76, "blue" if tab[1] == endless else "dark")
		tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_button.add_theme_font_size_override("font_size", 32)
		tabs.add_child(tab_button)

	var subtitle := _add_label("Best distance in Endless mode" if endless else "Total stars collected in Levels")
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	var status := _add_note("Loading...")

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	if not Cloud.can_play():
		_add_button("LOG IN TO JOIN", _show_account, 88, "primary")
	_load_leaderboard(list, status, endless)


func _load_leaderboard(list: VBoxContainer, status: Label, endless: bool) -> void:
	var result: Dictionary = await Cloud.fetch_top("leaderboard" if endless else "starboard")
	if not _still_showing(status):
		return
	if not result.ok:
		_show_error(status, result.message)
		return
	var entries: Array = result.entries
	status.text = "" if not entries.is_empty() else "No scores yet. Be the first!"
	status.visible = not status.text.is_empty()
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var mine: bool = entry.uid == Cloud.uid
		var row_card := UiKit.card(
			Color(UiKit.BLUE, 0.55) if mine else Color(0.03, 0.07, 0.13, 0.82),
			Color(UiKit.BLUE.lightened(0.3), 0.9) if mine else Color(UiKit.CYAN, 0.22), 18, 18.0, 10.0)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var rank := _make_row_label("%d" % (i + 1), 48)
		# Full name on top when the player gave one, with the username under it.
		var shown: String = entry.full_name if not entry.full_name.is_empty() else entry.name
		var player := _make_row_label(shown, 0)
		player.clip_text = true
		var player_box := VBoxContainer.new()
		player_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		player_box.add_theme_constant_override("separation", -4)
		player_box.add_child(player)
		if not entry.full_name.is_empty():
			var handle := _make_row_label("@" + entry.name, 0)
			handle.add_theme_font_size_override("font_size", 22)
			handle.modulate = Color(1, 1, 1, 0.6)
			handle.clip_text = true
			player_box.add_child(handle)
		var score := _make_row_label(("%d m" if endless else "%d stars") % entry.score, 160)
		score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if mine:
			for label in [rank, player, score]:
				label.add_theme_color_override("font_color", Color.WHITE)
		elif i < 3:
			rank.add_theme_color_override("font_color", [UiKit.GOLD, Color("cfd8dc"), Color("d08a4e")][i])
		row.add_child(rank)
		row.add_child(UiKit.Avatar.new(shown, 56.0))
		row.add_child(player_box)
		if i < 3:
			var crown := UiKit.Icon.new("crown", 30.0, [UiKit.GOLD, Color("cfd8dc"), Color("d08a4e")][i])
			crown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(crown)
		row.add_child(score)
		row_card.add_child(row)
		list.add_child(row_card)


func _make_row_label(text: String, min_width: int) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = min_width
	label.add_theme_font_size_override("font_size", 32)
	return label


func _show_achievements() -> void:
	_clear()
	var page := _full_layout(14)
	page.add_child(_header("BADGES", _show_main))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)
	for badge in _badges():
		list.add_child(_badge_card(badge))


func _set_layout(layout: String) -> void:
	GameData.button_layout = layout
	GameData.save()
	preview.queue_redraw()


func _on_sound_toggled(on: bool) -> void:
	GameData.muted = not on
	GameData.apply_mute()
	GameData.save()
	if on:
		Sfx.play("checkpoint")


func _on_vibration_toggled(on: bool) -> void:
	GameData.vibration = on
	GameData.save()
	if on:
		Input.vibrate_handheld(80)


func _on_shake_toggled(on: bool) -> void:
	GameData.screen_shake = on
	GameData.save()


func _on_size_changed(value: float) -> void:
	GameData.button_scale = value
	_update_size_label()
	preview.queue_redraw()


func _on_size_drag_ended(_value_changed: bool) -> void:
	GameData.save()


func _update_size_label() -> void:
	size_label.text = "BUTTON SIZE   %d%%" % roundi(GameData.button_scale * 100.0)


func _start_level(world: int, level_number: int) -> void:
	GameData.selected_world = world
	GameData.selected_level = level_number
	get_tree().change_scene_to_file(CAMPAIGN_SCENE)



# Wipes the screen and starts a plain centred column for the form screens (login, settings...).
func _clear() -> void:
	# Leaving a screen abandons a Google sign-in that is waiting on the browser.
	Cloud.cancel_google()
	for child in host.get_children():
		host.remove_child(child)
		child.queue_free()

	var center := CenterContainer.new()
	host.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 28)
	center.add_child(content)


# Swaps the centred column for one that fills the screen, so a screen can pin things to the
# top and bottom. Call right after _clear(). Returns the new column (also `content`).
func _full_layout(separation := 20) -> VBoxContainer:
	var center := content.get_parent()
	host.remove_child(center)
	center.queue_free()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 56)
	margin.add_theme_constant_override("margin_bottom", 40)
	host.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", separation)
	margin.add_child(content)
	return content


func _add_title(text: String, font_size: int) -> Label:
	var title := UiKit.title(text, font_size, UiKit.CYAN)
	content.add_child(title)
	return title


func _add_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	content.add_child(label)
	return label


func _add_field(placeholder: String, secret := false, icon_kind := "") -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.secret = secret
	field.custom_minimum_size = Vector2(520, 88)
	field.add_theme_font_size_override("font_size", 32)
	UiKit.style_field(field)
	if icon_kind != "":
		for style_name in ["normal", "focus"]:
			(field.get_theme_stylebox(style_name) as StyleBoxFlat).content_margin_left = 84.0
		var icon := UiKit.Icon.new(icon_kind, 36.0, Color(0.6, 0.72, 0.8))
		icon.anchor_top = 0.5
		icon.anchor_bottom = 0.5
		icon.offset_left = 28.0
		icon.offset_right = 64.0
		icon.offset_top = -18.0
		icon.offset_bottom = 18.0
		field.add_child(icon)
	if secret:
		(field.get_theme_stylebox("normal") as StyleBoxFlat).content_margin_right = 84.0
		(field.get_theme_stylebox("focus") as StyleBoxFlat).content_margin_right = 84.0
		var eye := Button.new()
		eye.flat = true
		eye.anchor_left = 1.0
		eye.anchor_right = 1.0
		eye.anchor_bottom = 1.0
		eye.offset_left = -84.0
		eye.pressed.connect(func(): field.secret = not field.secret)
		var eye_icon := UiKit.Icon.new("eye", 38.0, Color(0.6, 0.72, 0.8))
		eye_icon.anchor_left = 0.5
		eye_icon.anchor_right = 0.5
		eye_icon.anchor_top = 0.5
		eye_icon.anchor_bottom = 0.5
		eye_icon.offset_left = -19.0
		eye_icon.offset_right = 19.0
		eye_icon.offset_top = -19.0
		eye_icon.offset_bottom = 19.0
		eye.add_child(eye_icon)
		field.add_child(eye)
	content.add_child(field)
	return field


# Wrapping text for messages and errors.
func _add_note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 560
	label.add_theme_font_size_override("font_size", 28)
	content.add_child(label)
	return label


func _show_info(status: Label, text: String) -> void:
	status.remove_theme_color_override("font_color")
	status.text = text


func _show_error(status: Label, text: String) -> void:
	status.add_theme_color_override("font_color", ERROR_COLOR)
	status.text = text
	status.visible = true


# False if the player left the screen that `anchor` belongs to while a request ran.
func _still_showing(anchor: Control) -> bool:
	return is_instance_valid(anchor) and anchor.is_inside_tree()


# `kind` picks the colour: "primary" (green), "warn" (orange), "blue", or "dark" (outlined).
func _make_button(text: String, on_pressed: Callable, height := 120, kind := "dark") -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, height)
	button.add_theme_font_size_override("font_size", 40)
	UiKit.style_button(button, kind)
	button.pressed.connect(on_pressed)
	return button


func _add_button(text: String, on_pressed: Callable, height := 120, kind := "dark") -> Button:
	var button := _make_button(text, on_pressed, height, kind)
	button.custom_minimum_size.x = 520.0
	content.add_child(button)
	return button


# A button that flips between "<name>: ON" and "<name>: OFF" and reports the new state.
func _add_toggle(label_text: String, initial: bool, on_changed: Callable) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 72.0
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.add_theme_font_size_override("font_size", 32)
	row.add_child(label)
	var toggle := UiKit.Switch.new(initial)
	toggle.toggled.connect(on_changed)
	row.add_child(toggle)
	content.add_child(row)


# A small square menu tile: icon over a tiny caption.
func _nav_tile(text: String, icon_kind: String, on_pressed: Callable) -> Button:
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(0.0, 112.0)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.style_button(tile, "dark")
	tile.pressed.connect(on_pressed)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 6)
	tile.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var icon := UiKit.Icon.new(icon_kind, 44.0, UiKit.CYAN)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(icon)
	var caption := Label.new()
	caption.text = text
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	column.add_child(caption)
	UiKit.ignore_mouse(tile)
	return tile


# Badges worked out from the saved progress: name, description, current value, goal, icon.
func _badges() -> Array:
	var cleared := 0
	var perfect := 0
	for world in WorldData.WORLD_COUNT:
		for n in range(1, WorldData.LEVELS_PER_WORLD + 1):
			var earned := GameData.stars_for(world, n)
			if earned > 0:
				cleared += 1
			if earned >= 3:
				perfect += 1
	var worlds_open := 0
	for world in WorldData.WORLD_COUNT:
		if GameData.is_world_unlocked(world):
			worlds_open += 1
	return [
		{"name": "First Steps", "desc": "Clear your first level", "value": cleared, "goal": 1, "icon": "play"},
		{"name": "Collector", "desc": "Collect 500 stars", "value": GameData.total_stars(), "goal": 500, "icon": "crown"},
		{"name": "Explorer", "desc": "Unlock all 4 worlds", "value": worlds_open, "goal": WorldData.WORLD_COUNT, "icon": "unlock"},
		{"name": "Marathoner", "desc": "Run 1,000 m in Endless", "value": GameData.best_endless, "goal": 1000, "icon": "restart"},
		{"name": "Perfectionist", "desc": "Earn 3 stars on 50 levels", "value": perfect, "goal": 50, "icon": "shield"},
	]


func _badge_card(badge: Dictionary) -> Control:
	var goal: int = badge["goal"]
	var value: int = mini(badge["value"], goal)
	var done := value >= goal
	var accent := UiKit.GOLD if done else Color(0.55, 0.68, 0.78)
	var card := UiKit.card(Color(0.03, 0.07, 0.13, 0.85), Color(accent, 0.55), 20, 20.0, 18.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)
	var icon := UiKit.Icon.new(badge["icon"], 64.0, accent)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)
	var title_label := Label.new()
	title_label.text = badge["name"]
	title_label.add_theme_font_size_override("font_size", 32)
	info.add_child(title_label)
	var desc := Label.new()
	desc.text = badge["desc"]
	desc.add_theme_font_size_override("font_size", 22)
	desc.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	info.add_child(desc)
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 12)
	var bar := UiKit.progress(value, goal, UiKit.GREEN if done else UiKit.BLUE)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_row.add_child(bar)
	var count := Label.new()
	count.text = "%d / %d" % [value, goal]
	count.add_theme_font_size_override("font_size", 20)
	count.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	bar_row.add_child(count)
	info.add_child(bar_row)

	if done:
		var check := UiKit.Icon.new("check", 40.0, UiKit.GREEN)
		check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(check)
	return card


# A flexible gap that pushes what follows to the bottom of a full-screen column.
func _add_expander() -> void:
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(gap)


func _add_gap(height: float) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	content.add_child(gap)


# Small dim heading above a control, left aligned.
func _add_caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	content.add_child(label)
	return label


# A line with a word in the middle, e.g. "OR".
func _add_divider(text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	for i in 3:
		if i == 1:
			var label := Label.new()
			label.text = text
			label.add_theme_font_size_override("font_size", 22)
			label.add_theme_color_override("font_color", UiKit.TEXT_DIM)
			row.add_child(label)
		else:
			var line := ColorRect.new()
			line.color = Color(1, 1, 1, 0.18)
			line.custom_minimum_size.y = 2.0
			line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(line)
	content.add_child(row)


# Six digit boxes drawn over an invisible LineEdit that does the real typing.
func _add_code_boxes() -> LineEdit:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0.0, 100.0)
	content.add_child(holder)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	holder.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cells: Array = []
	for i in 6:
		var cell := PanelContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var digit := Label.new()
		digit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		digit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		digit.add_theme_font_size_override("font_size", 44)
		digit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(digit)
		row.add_child(cell)
		cells.append(cell)

	var field := LineEdit.new()
	field.max_length = 6
	field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	holder.add_child(field)
	field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var clear := Color(0, 0, 0, 0)
	field.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	field.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for color_name in ["font_color", "font_selected_color", "caret_color", "selection_color"]:
		field.add_theme_color_override(color_name, clear)
	field.text_changed.connect(func(_text: String): _refresh_code_boxes(field, cells))
	field.focus_entered.connect(func(): _refresh_code_boxes(field, cells))
	field.focus_exited.connect(func(): _refresh_code_boxes(field, cells))
	_refresh_code_boxes(field, cells)
	return field


func _refresh_code_boxes(field: LineEdit, cells: Array) -> void:
	var typed := field.text
	for i in cells.size():
		var cell: PanelContainer = cells[i]
		(cell.get_child(0) as Label).text = typed[i] if i < typed.length() else ""
		var active := field.has_focus() and i == mini(typed.length(), cells.size() - 1)
		cell.add_theme_stylebox_override("panel", UiKit.box(
			Color(0.02, 0.08, 0.12, 0.92), UiKit.CYAN if active else Color(UiKit.CYAN, 0.3), 14, 3))


# A button with a drawn icon at its left edge.
func _add_icon_button(text: String, icon_kind: String, on_pressed: Callable, height := 100, kind := "dark") -> Button:
	var button := _add_button(text, on_pressed, height, kind)
	UiKit.add_button_icon(button, icon_kind, 44.0, Color.WHITE if kind != "dark" else UiKit.CYAN)
	if icon_kind == "google":
		(button.get_child(0) as Control).modulate = Color.WHITE
	return button


# Counts the resend link down from the last time a code was sent.
func _tick_resend(button: Button) -> void:
	while _still_showing(button):
		var left := ceili((resend_ready_ms - Time.get_ticks_msec()) / 1000.0)
		if left <= 0:
			button.disabled = false
			button.text = "Resend code"
			return
		button.disabled = true
		button.text = "Resend code (%02d:%02d)" % [left / 60, left % 60]
		await get_tree().create_timer(1.0).timeout
