extends Control

const LevelData = preload("res://level_data.gd")
const JungleBackground := preload("res://jungle_background.gd")
const ButtonPreview := preload("res://button_preview.gd")
const UI_THEME := preload("res://ui_theme.tres")

const NEON_CYAN := Color("00e5ff")
const NEON_PINK := Color("ff2e93")
const ERROR_COLOR := Color("ff6b6b")
const CAMPAIGN_SCENE := "res://campaign.tscn"
const ENDLESS_SCENE := "res://endless.tscn"
const LEVEL_BUTTON_COLUMNS := 5

var content: VBoxContainer
var preview: Control
var size_label: Label
# True while a sign-in or similar request is in flight, so taps don't stack up.
var busy := false
# A problem from signup (e.g. the code email failed) to show on the verify screen.
var pending_notice := ""


func _ready() -> void:
	theme = UI_THEME
	_add_background()

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 28)
	center.add_child(content)

	_show_main()


# Jungle floor, darkened towards the bottom so the buttons stand out.
func _add_background() -> void:
	add_child(JungleBackground.new())

	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.0, 0.03, 0.05, 0.85), Color(0.0, 0.0, 0.0, 0.55)])
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
	var title := _add_title("TAP N GO", 96)
	# Slow glow pulse on the title.
	var pulse := title.create_tween().set_loops()
	pulse.tween_property(title, "modulate", Color(1.4, 1.4, 1.4, 1.0), 1.2).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(title, "modulate", Color.WHITE, 1.2).set_trans(Tween.TRANS_SINE)

	# Nothing to play until the player has logged in (or chosen guest).
	if not Cloud.can_play():
		_add_note("Verify your email to play." if Cloud.is_signed_in() else "Log in to play.")
		_add_button("Verify email" if Cloud.is_signed_in() else "Log in", _show_account)
		_add_button("Settings", _show_settings, 100)
		return

	var stats := Label.new()
	stats.text = "Endless best: %d m\nLevels cleared: %d / %d" % [
		GameData.best_endless, GameData.levels_cleared, LevelData.LEVEL_COUNT]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 30)
	stats.add_theme_color_override("font_color", NEON_PINK)
	content.add_child(stats)

	_add_button("Levels", _show_levels)
	_add_button("Endless Mode", func(): get_tree().change_scene_to_file(ENDLESS_SCENE))
	_add_button("Leaderboard", _show_leaderboard, 100)
	_add_button("Achievements", _show_achievements, 100)
	_add_button("Settings", _show_settings, 100)
	_add_button(Cloud.display_name, _show_account, 88)


func _show_levels() -> void:
	_clear()
	_add_title("SELECT LEVEL", 56)

	var grid := GridContainer.new()
	grid.columns = LEVEL_BUTTON_COLUMNS
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	content.add_child(grid)

	for n in range(1, LevelData.LEVEL_COUNT + 1):
		var button := Button.new()
		button.text = str(n)
		button.custom_minimum_size = Vector2(120, 120)
		button.add_theme_font_size_override("font_size", 40)
		button.disabled = not GameData.is_level_unlocked(n)
		button.pressed.connect(_start_level.bind(n))
		grid.add_child(button)

	_add_button("Back", _show_main)


func _show_settings() -> void:
	_clear()
	content.add_theme_constant_override("separation", 18)
	_add_title("SETTINGS", 64)

	_add_toggle("Sound", not GameData.muted, _on_sound_toggled)
	_add_toggle("Vibration", GameData.vibration, _on_vibration_toggled)
	_add_toggle("Screen shake", GameData.screen_shake, _on_shake_toggled)

	_add_label("Button layout")
	var layout_row := HBoxContainer.new()
	layout_row.add_theme_constant_override("separation", 12)
	content.add_child(layout_row)
	var group := ButtonGroup.new()
	for option in [["Split", GameData.LAYOUT_SPLIT], ["Left", GameData.LAYOUT_LEFT], ["Right", GameData.LAYOUT_RIGHT]]:
		var button := Button.new()
		button.text = option[0]
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = GameData.button_layout == option[1]
		button.custom_minimum_size = Vector2(160, 88)
		button.add_theme_font_size_override("font_size", 30)
		button.pressed.connect(_set_layout.bind(option[1]))
		layout_row.add_child(button)

	size_label = _add_label("")
	_update_size_label()
	var slider := HSlider.new()
	slider.min_value = GameData.BUTTON_SCALE_MIN
	slider.max_value = GameData.BUTTON_SCALE_MAX
	slider.step = 0.05
	slider.value = GameData.button_scale
	slider.custom_minimum_size = Vector2(520, 48)
	slider.value_changed.connect(_on_size_changed)
	slider.drag_ended.connect(_on_size_drag_ended)
	content.add_child(slider)

	preview = ButtonPreview.new()
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(preview)

	_add_button("Back", _show_main, 88)


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
	content.add_theme_constant_override("separation", 18)
	_add_title("LOG IN", 64)
	var email_field := _add_field("Email")
	var password_field := _add_field("Password", true)
	var status := _add_note("")
	_add_button("Log in", _submit_login.bind(email_field, password_field, status), 100)
	_add_button("Continue with Google", _continue_with_google.bind(status), 88)
	_add_button("Continue as Guest", _continue_as_guest.bind(status), 88)
	_add_button("Create account", _show_signup, 88)
	_add_button("Back", _show_main, 88)


func _show_signup() -> void:
	_clear()
	content.add_theme_constant_override("separation", 18)
	_add_title("SIGN UP", 64)
	var name_field := _add_field("Username")
	var email_field := _add_field("Email")
	var password_field := _add_field("Password (6+ characters)", true)
	var status := _add_note("")
	_add_button("Create account", _submit_signup.bind(name_field, email_field, password_field, status), 100)
	_add_button("Continue with Google", _continue_with_google.bind(status), 88)
	_add_button("I already have an account", _show_login, 88)
	_add_button("Back", _show_main, 88)


func _show_verify() -> void:
	_clear()
	content.add_theme_constant_override("separation", 18)
	_add_title("VERIFY EMAIL", 56)
	_add_note("We emailed a 6-digit code to\n%s" % Cloud.email)
	var code_field := _add_field("6-digit code")
	code_field.max_length = 6
	code_field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	var status := _add_note("")
	if not pending_notice.is_empty():
		_show_error(status, pending_notice)
		pending_notice = ""
	_add_button("Verify", _submit_code.bind(code_field, status), 100)
	_add_button("Resend code", _resend_verification.bind(status), 88)
	_add_button("Log out", _log_out, 88)
	_add_button("Back", _show_main, 88)


func _show_profile() -> void:
	_clear()
	content.add_theme_constant_override("separation", 18)
	_add_title("ACCOUNT", 64)
	if Cloud.is_guest():
		_add_note("%s (guest)\nGuest progress is lost if you log out or delete the app. Create an account to keep it." % Cloud.display_name)
	else:
		_add_note("%s\n%s" % [Cloud.display_name, Cloud.email])
	_add_note("Endless best: %d m" % GameData.best_endless)
	_add_button("Leaderboard", _show_leaderboard, 100)
	if Cloud.is_guest():
		_add_button("Create account", _show_signup, 88)
	_add_button("Log out", _log_out, 88)
	_add_button("Back", _show_main, 88)


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


func _submit_signup(name_field: LineEdit, email_field: LineEdit, password_field: LineEdit, status: Label) -> void:
	if busy:
		return
	busy = true
	_show_info(status, "Creating account...")
	var result: Dictionary = await Cloud.sign_up(name_field.text.strip_edges(), email_field.text.strip_edges(), password_field.text)
	busy = false
	if not _still_showing(status):
		return
	if result.ok:
		pending_notice = str(result.get("notice", ""))
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


func _resend_verification(status: Label) -> void:
	if busy:
		return
	busy = true
	_show_info(status, "Sending...")
	var result: Dictionary = await Cloud.send_verification()
	busy = false
	if _still_showing(status):
		if result.ok:
			_show_info(status, "Code sent. Check your inbox and spam folder.")
		else:
			_show_error(status, result.message)


func _log_out() -> void:
	Cloud.sign_out()
	_show_main()


func _show_leaderboard() -> void:
	_clear()
	content.add_theme_constant_override("separation", 18)
	_add_title("GLOBAL TOP", 64)
	_add_label("Endless mode, best distance")
	var status := _add_note("Loading...")

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	if not Cloud.can_play():
		_add_button("Log in to join", _show_account, 88)
	_add_button("Back", _show_main, 88)
	_load_leaderboard(list, status)


func _load_leaderboard(list: VBoxContainer, status: Label) -> void:
	var result: Dictionary = await Cloud.fetch_top()
	if not _still_showing(status):
		return
	if not result.ok:
		_show_error(status, result.message)
		return
	var entries: Array = result.entries
	status.text = "" if not entries.is_empty() else "No scores yet. Be the first!"
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var row := HBoxContainer.new()
		var rank := _make_row_label("%d." % (i + 1), 80)
		var player := _make_row_label(entry.name, 0)
		player.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		player.clip_text = true
		var score := _make_row_label("%d m" % entry.score, 160)
		score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if entry.uid == Cloud.uid:
			for label in [rank, player, score]:
				label.add_theme_color_override("font_color", NEON_CYAN)
		row.add_child(rank)
		row.add_child(player)
		row.add_child(score)
		list.add_child(row)


func _make_row_label(text: String, min_width: int) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = min_width
	label.add_theme_font_size_override("font_size", 32)
	return label


func _show_achievements() -> void:
	_clear()
	content.add_theme_constant_override("separation", 18)
	_add_title("ACHIEVEMENTS", 56)
	_add_note("Coming soon.\nYour achievements will show up here.")
	_add_button("Back", _show_main, 88)


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
	size_label.text = "Button size: %d%%" % roundi(GameData.button_scale * 100.0)


func _start_level(level_number: int) -> void:
	GameData.selected_level = level_number
	get_tree().change_scene_to_file(CAMPAIGN_SCENE)


func _clear() -> void:
	# Leaving a screen abandons a Google sign-in that is waiting on the browser.
	Cloud.cancel_google()
	content.add_theme_constant_override("separation", 28)
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()


func _add_title(text: String, font_size: int) -> Label:
	var title := Label.new()
	title.text = text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", font_size)
	title.add_theme_color_override("font_color", NEON_CYAN)
	title.add_theme_color_override("font_outline_color", Color(NEON_PINK, 0.8))
	title.add_theme_constant_override("outline_size", 8)
	content.add_child(title)
	return title


func _add_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	content.add_child(label)
	return label


func _add_field(placeholder: String, secret := false) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.secret = secret
	field.custom_minimum_size = Vector2(520, 88)
	field.add_theme_font_size_override("font_size", 32)
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


# False if the player left the screen that `anchor` belongs to while a request ran.
func _show_info(status: Label, text: String) -> void:
	status.remove_theme_color_override("font_color")
	status.text = text


func _show_error(status: Label, text: String) -> void:
	status.add_theme_color_override("font_color", ERROR_COLOR)
	status.text = text


func _still_showing(anchor: Control) -> bool:
	return is_instance_valid(anchor) and anchor.is_inside_tree()


func _add_button(text: String, on_pressed: Callable, height := 120) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(520, height)
	button.add_theme_font_size_override("font_size", 40)
	button.pressed.connect(on_pressed)
	content.add_child(button)


# A button that flips between "<name>: ON" and "<name>: OFF" and reports the new state.
func _add_toggle(label: String, initial: bool, on_changed: Callable) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(520, 88)
	button.add_theme_font_size_override("font_size", 34)
	button.toggle_mode = true
	button.button_pressed = initial
	button.text = "%s: %s" % [label, "ON" if initial else "OFF"]
	button.toggled.connect(_on_toggle_pressed.bind(button, label, on_changed))
	content.add_child(button)


func _on_toggle_pressed(on: bool, button: Button, label: String, on_changed: Callable) -> void:
	button.text = "%s: %s" % [label, "ON" if on else "OFF"]
	on_changed.call(on)
