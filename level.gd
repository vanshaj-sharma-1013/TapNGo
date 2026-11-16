extends Node2D

# Shared controller for every mode: camera, HUD, crash / revive / restart flow.
# campaign.gd (levels) and endless.gd (endless mode) extend it.

const SideButtons := preload("res://side_buttons.gd")
const WorldBackground := preload("res://world_background.gd")
const WorldData := preload("res://world_data.gd")
const StarRow := preload("res://star_row.gd")
const UiKit := preload("res://ui_kit.gd")
const Potions := preload("res://potions.gd")

const MENU_SCENE := "res://menu.tscn"

# Where the player sits on screen (0 = top, 1 = bottom), so there is room to see ahead.
const PLAYER_SCREEN_FRACTION := 0.7
# Extra room past the camera limits so screen shake isn't clamped away.
const CAMERA_MARGIN := 40.0
const VIEW_PAST_FINISH := 100

const CRASH_SHAKE_STRENGTH := 24.0
const CRASH_SHAKE_TIME := 0.4
const CRASH_VIBRATE_MS := 200
# After the last crash, wait for the death animation to finish plus a short beat, then restart.
const RESTART_HOLD := 0.35
# Pause after the death animation before the crash panel shows.
const PANEL_DELAY := 0.3

const PAUSE_BUTTON_SIZE := 96.0
const PAUSE_BUTTON_MARGIN := 24.0
const PANEL_WIDTH := 560.0

const UI_THEME := preload("res://ui_theme.tres")
const NEON_CYAN := Color("00e5ff")
const NEON_YELLOW := Color("ffd36b")

# Level intro: title, then 3-2-1, then GO.
const INTRO_TITLE_TIME := 1.0
const COUNT_STEP_TIME := 0.7
const HINT_TIME := 3.5

@export var level_number := 1
# Which world's art and movement rules the level uses (WorldData). Set before super() runs.
var world := WorldData.JUNGLE

# Seconds of play since GO (paused time and the intro don't count), for the star rating.
var run_time := 0.0
var start_y := 0.0

# Player is left untyped on purpose: it calls revive() / stop() from player.gd.
@onready var player = $Player
@onready var camera: Camera2D = $Player/Camera2D

# Set by campaign.gd; null in endless mode.
var finish_line: Node2D = null
var respawn_point: Vector2
# True once any revive was used (the star rating looks at this); revives_used counts them.
var revive_used := false
var revives_used := 0
# True while a revive ad is on its way, so a second tap can't start another.
var _revive_pending := false
var ui: Control
var hud_label: Label
var status_label: Label
var panel: Control
# Potion buttons in the HUD: potion id -> {"button": Button, "count": Label}.
var _potion_buttons := {}


func _ready() -> void:
	add_child(_make_background())
	player.apply_world(world)
	respawn_point = player.global_position
	start_y = player.global_position.y
	_build_ui()
	player.hit_hazard.connect(_on_player_hit)
	_setup_world()
	_setup_camera()  # after the world, since it needs the finish line's position
	_start_countdown()


func _process(_delta: float) -> void:
	status_label.text = player.status_text()


func _physics_process(delta: float) -> void:
	if player.alive and not player.frozen_for_intro:
		run_time += delta


# Hook: the floor behind the lane.
func _make_background() -> Node2D:
	return WorldBackground.new(world)


func _exit_tree() -> void:
	Controls.blocked_rect = Rect2()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_pause()


# Pause when the app loses focus (phone call, app switch).
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_pause()


# Hook: the big title shown before the countdown.
func _intro_title() -> String:
	return "Level %d" % level_number


# Hook: a one-time tutorial hint shown when the run starts. Empty = none.
# Shown once per _hint_id() (saved in GameData).
func _hint_text() -> String:
	return ""


func _hint_id() -> int:
	return level_number


# Holds the player and the hazards still while the title and 3-2-1 play.
func _start_countdown() -> void:
	player.frozen_for_intro = true
	get_tree().call_group("hazard", "set", "running", false)

	await _flash_text(_intro_title(), INTRO_TITLE_TIME, 84, NEON_CYAN).finished
	for step in ["3", "2", "1"]:
		await _flash_text(step, COUNT_STEP_TIME, 160, Color.WHITE).finished

	player.frozen_for_intro = false
	get_tree().call_group("hazard", "set", "running", true)
	_flash_text("GO!", COUNT_STEP_TIME, 160, NEON_YELLOW)

	var hint := _hint_text()
	if hint != "" and not GameData.has_seen_hint(_hint_id()):
		GameData.mark_hint_seen(_hint_id())
		_show_banner(hint, 0.22, 38, NEON_YELLOW, HINT_TIME)


# Big centred text that pops in and fades out. Returns the tween so callers can await it.
func _flash_text(text: String, hold: float, font_size: int, color: Color) -> Tween:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # long world names wrap
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("outline_size", 12)
	var view := get_viewport_rect().size
	label.size = view
	label.pivot_offset = view / 2.0
	label.scale = Vector2(1.5, 1.5)
	label.modulate.a = 0.0
	ui.add_child(label)

	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 1.0, 0.15)
	tween.tween_interval(maxf(hold - 0.4, 0.0))
	tween.tween_property(label, "modulate:a", 0.0, 0.2)
	tween.tween_callback(label.queue_free)
	return tween


# Wrapped text banner near the top that fades in, holds, then fades out. Doesn't block input.
func _show_banner(text: String, y_fraction: float, font_size: int, color: Color, hold: float) -> void:
	var view := get_viewport_rect().size
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("outline_size", 10)
	label.size = Vector2(view.x - 80.0, 0.0)
	label.position = Vector2(40.0, view.y * y_fraction)
	label.modulate.a = 0.0
	ui.add_child(label)

	var tween := label.create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.25)
	tween.tween_interval(hold)
	tween.tween_property(label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(label.queue_free)


# Hook: build the level's contents.
func _setup_world() -> void:
	pass


# Hook: text for the crash panel.
func _crash_title() -> String:
	return "Crashed!"


# Hook: called on every crash, before the revive offer.
func _on_run_crashed() -> void:
	pass


# Hook: how many revives a run gets. Levels get one; Endless more (each costing a bigger ad).
func _max_revives() -> int:
	return 1


# Hook: text of the revive button. It must start with "Revive".
func _revive_label() -> String:
	return "Revive (watch ad)"


# Hook: called when the crash can't be revived. Default is an instant restart.
func _on_final_crash() -> void:
	get_tree().create_timer(RESTART_HOLD).timeout.connect(_restart)


# Hook: buttons on the level-complete panel.
func _finish_options() -> Array:
	return [
		["Play Again", _restart],
		["Menu", _go_to_menu],
	]


func _setup_camera() -> void:
	var view := get_viewport_rect().size
	camera.base_offset = Vector2(0.0, -view.y * (PLAYER_SCREEN_FRACTION - 0.5))
	camera.limit_left = int(-CAMERA_MARGIN)
	camera.limit_right = int(view.x + CAMERA_MARGIN)
	# The view stops when the player's start position is PLAYER_SCREEN_FRACTION down the screen.
	camera.limit_bottom = int(player.global_position.y + view.y * (1.0 - PLAYER_SCREEN_FRACTION) + CAMERA_MARGIN)
	if finish_line:
		camera.limit_top = int(finish_line.global_position.y) - VIEW_PAST_FINISH


func _on_checkpoint_reached(checkpoint: Node2D) -> void:
	Sfx.play("checkpoint")
	_show_banner("CHECKPOINT", 0.3, 56, NEON_CYAN, 0.6)
	# Only move the respawn point forward (up the screen = smaller y).
	if checkpoint.global_position.y < respawn_point.y:
		respawn_point = Vector2(player.global_position.x, checkpoint.global_position.y)


func _on_player_hit(source: Node) -> void:
	if GameData.screen_shake:
		camera.shake(CRASH_SHAKE_STRENGTH, CRASH_SHAKE_TIME)
	if GameData.vibration:
		Input.vibrate_handheld(CRASH_VIBRATE_MS)
	Sfx.play("crash")
	_on_run_crashed()

	# Let the death animation play out before the crash panel (or restart) appears.
	await get_tree().create_timer(player.death_duration() + PANEL_DELAY).timeout
	if not is_inside_tree() or player.alive:
		return
	var ad_revive := revives_used < _max_revives()
	var potions_left := GameData.potion_count(Potions.REVIVE)
	if not ad_revive and potions_left <= 0:
		_on_final_crash()
		return
	var title := _crash_title()
	if source == player:  # the player's own burn killed them
		title = title.replace("Crashed!", "Burned!")
	var options := []
	if potions_left > 0:
		options.append(["Revive Potion x%d" % potions_left, _on_revive_potion_pressed])
	if ad_revive:
		options.append([_revive_label(), _on_revive_pressed])
	options.append(["Restart", _restart])
	options.append(["Menu", _go_to_menu])
	_show_panel(title, options)


func _on_finished() -> void:
	if not player.alive:
		return
	player.stop()
	Sfx.play("finish")

	var earned := _stars_earned()
	var next_world := world + 1
	var was_open := next_world >= WorldData.WORLD_COUNT or GameData.is_world_unlocked(next_world)
	GameData.record_stars(world, level_number, earned)
	var title := "Level Complete!"
	if GameData.last_award > 0:
		title += "\nCoins +%d" % GameData.last_award
	if not was_open and GameData.is_world_unlocked(next_world):
		title += "\n%s unlocked!" % WorldData.world_name(next_world)
	_show_panel(title, _finish_options(), StarRow.new(earned, 56.0))
	Ads.on_level_cleared()


# 1 star for finishing, 2 for finishing without the revive, 3 for also beating the par time.
func _stars_earned() -> int:
	if revive_used:
		return 1
	return 3 if run_time <= _par_time() else 2


# Time a clean run takes at full speed, plus the world's allowance for waiting at gaps.
func _par_time() -> float:
	if finish_line == null:
		return INF
	var rules := WorldData.world(world)
	var distance := start_y - finish_line.global_position.y
	return distance / (player.speed * float(rules["speed_mult"])) * (1.0 + float(rules["par_allowance"]))


func _on_revive_pressed() -> void:
	if _revive_pending:
		return
	_revive_pending = true
	Ads.show_revive_ad(revives_used + 1, _grant_revive, _on_revive_failed)


func _on_revive_failed(reason: String) -> void:
	_revive_pending = false
	if not is_inside_tree():
		return
	var message := "Watch the whole ad to revive."
	if reason == "unavailable":
		message = "No ad available right now.\nTry again in a moment."
	_show_banner(message, 0.12, 36, NEON_YELLOW, 2.5)


func _grant_revive() -> void:
	revives_used += 1
	_do_revive()


# A revive potion: free, and it doesn't use up one of the run's ad revives.
func _on_revive_potion_pressed() -> void:
	if _revive_pending or not GameData.use_potion(Potions.REVIVE):
		return
	_do_revive()


func _do_revive() -> void:
	_revive_pending = false
	revive_used = true
	_close_panel()
	Sfx.play("revive")
	player.revive(respawn_point)
	_refresh_potion_bar()
	_show_banner("REVIVED!", 0.3, 56, Color("ff4d6d"), 1.0)


# A restart from a dead player is a failed attempt; the 3rd in a row on one level earns an interstitial.
func _restart() -> void:
	if not player.alive and finish_line != null:
		Ads.on_level_failed(world, level_number)
	Ads.before_restart(_reload_scene)


func _reload_scene() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene.call_deferred()


func _go_to_menu() -> void:
	Ads.before_menu(_load_menu)


func _load_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(MENU_SCENE)


# Not offered while a panel is open or the player is dead, so it never replaces the crash panel.
func _pause() -> void:
	if get_tree().paused or panel != null or not player.alive:
		return
	get_tree().paused = true
	Controls.release_all()
	_show_panel("Paused", [
		["Resume", _resume],
		["Restart", _restart],
		["Menu", _go_to_menu],
	])
	panel.process_mode = Node.PROCESS_MODE_ALWAYS


func _resume() -> void:
	_close_panel()
	get_tree().paused = false


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	# CanvasLayers can't hold a theme, so everything sits under a full-screen Control that does.
	# It ignores the mouse: touches are read by the Controls autoload.
	ui = Control.new()
	ui.theme = UI_THEME
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	hud_label = Label.new()
	hud_label.position = Vector2(24, 16)
	hud_label.add_theme_font_size_override("font_size", 40)
	ui.add_child(hud_label)

	ui.add_child(SideButtons.new())

	status_label = Label.new()
	status_label.position = Vector2(24, 68)
	status_label.add_theme_font_size_override("font_size", 34)
	status_label.add_theme_color_override("font_color", Color("ffd36b"))
	ui.add_child(status_label)

	var pause_button := Button.new()
	pause_button.text = "II"
	pause_button.add_theme_font_size_override("font_size", 40)
	UiKit.style_button(pause_button, "dark")
	pause_button.size = Vector2(PAUSE_BUTTON_SIZE, PAUSE_BUTTON_SIZE)
	pause_button.position = Vector2(get_viewport_rect().size.x - PAUSE_BUTTON_MARGIN - PAUSE_BUTTON_SIZE, PAUSE_BUTTON_MARGIN)
	pause_button.pressed.connect(_pause)
	ui.add_child(pause_button)
	# A tap on the button must not also count as "move forward".
	var blocked := Rect2(pause_button.position, pause_button.size).grow(12.0)
	blocked = blocked.merge(_build_potion_bar(pause_button.position + Vector2(0.0, PAUSE_BUTTON_SIZE + 12.0)).grow(12.0))
	Controls.blocked_rect = blocked


# One round button per potion, in a column under the pause button. Returns the area they cover
# (a touch there must not count as "move forward"). Dimmed when the bag has none of that potion.
func _build_potion_bar(top_left: Vector2) -> Rect2:
	var ids := Potions.hud_ids()
	var gap := 10.0
	var size := PAUSE_BUTTON_SIZE
	for i in ids.size():
		var id: String = ids[i]
		var info := Potions.get_potion(id)
		var color: Color = info["color"]
		var button := Button.new()
		button.size = Vector2(size, size)
		button.position = top_left + Vector2(0.0, i * (size + gap))
		var normal := UiKit.box(Color(0.03, 0.07, 0.13, 0.85), Color(color, 0.9), 28, 3)
		var pressed := UiKit.box(Color(color, 0.4), Color.WHITE, 28, 3)
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", normal)
		button.add_theme_stylebox_override("pressed", pressed)
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.pressed.connect(_use_potion.bind(id))
		ui.add_child(button)

		var icon := Potions.PotionIcon.new(id, size * 0.7)
		icon.position = Vector2(size * 0.15, size * 0.1)
		icon.size = Vector2(size * 0.7, size * 0.7)
		button.add_child(icon)

		var count := Label.new()
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count.add_theme_font_size_override("font_size", 26)
		count.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		count.add_theme_constant_override("outline_size", 8)
		count.position = Vector2(size - 36.0, size - 40.0)
		button.add_child(count)
		_potion_buttons[id] = {"button": button, "count": count}
	_refresh_potion_bar()
	return Rect2(top_left, Vector2(size, ids.size() * (size + gap) - gap))


func _refresh_potion_bar() -> void:
	for id in _potion_buttons:
		var owned := GameData.potion_count(id)
		_potion_buttons[id]["count"].text = str(owned)
		_potion_buttons[id]["button"].modulate = Color.WHITE if owned > 0 else Color(1, 1, 1, 0.45)


# Drinks a potion mid-run. A potion that has nothing to do right now (not burning, not frozen,
# speed already boosted) is not used up.
func _use_potion(id: String) -> void:
	if not player.alive or player.frozen_for_intro or get_tree().paused or panel != null:
		return
	var info := Potions.get_potion(id)
	var color: Color = info["color"]
	if GameData.potion_count(id) <= 0:
		_show_banner("No %s - buy some in the Shop" % info["name"], 0.12, 34, NEON_YELLOW, 2.0)
		return
	var note := ""
	match id:
		Potions.SPEED_UP, Potions.SPEED_DOWN:
			var up := id == Potions.SPEED_UP
			if player.boost_left > 0.0 and (player.boost_scale > 1.0) == up:
				note = "Already active"
			else:
				GameData.use_potion(id)
				player.apply_speed_potion(Potions.SPEED_UP_SCALE if up else Potions.SPEED_DOWN_SCALE,
						Potions.SPEED_UP_TIME if up else Potions.SPEED_DOWN_TIME)
				_potion_used("SPEED UP!" if up else "SLOW DOWN", color)
		Potions.COOLDOWN:
			if player.burn_left <= 0.0:
				note = "You're not on fire"
			else:
				GameData.use_potion(id)
				player.extinguish()
				_potion_used("COOLED DOWN!", color)
		Potions.BURNING:
			if player.freeze_left <= 0.0 and player.slow_left <= 0.0:
				note = "You're not frozen"
			else:
				GameData.use_potion(id)
				player.thaw()
				_potion_used("THAWED!", color)
	if note != "":
		_show_banner(note, 0.12, 36, NEON_YELLOW, 1.2)


func _potion_used(text: String, color: Color) -> void:
	Sfx.play("revive")
	_refresh_potion_bar()
	_show_banner(text, 0.3, 56, color, 0.8)


func _set_hud(text: String) -> void:
	hud_label.text = text


# options: Array of [button_text: String, on_pressed: Callable]
# title: the first line is the heading; each further line is a detail ("Score 12", "NEW BEST!").
# extra: an optional Control (e.g. the star row) shown under the heading.
func _show_panel(title: String, options: Array, extra: Control = null) -> void:
	_close_panel()

	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Darkens the level behind the card.
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.02, 0.06, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var lines := title.split("\n")
	var accent := _panel_accent(lines[0])
	var card := UiKit.card(Color(0.03, 0.06, 0.12, 0.96), Color(accent, 0.45))
	center.add_child(card)

	var box := VBoxContainer.new()
	box.custom_minimum_size.x = PANEL_WIDTH
	box.add_theme_constant_override("separation", 20)
	card.add_child(box)

	var heading := UiKit.title(lines[0].to_upper(), 64 if lines[0].length() <= 10 else 46, accent)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(heading)

	if extra != null:
		extra.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(extra)

	for i in range(1, lines.size()):
		box.add_child(_panel_line(lines[i]))

	for i in options.size():
		var option: Array = options[i]
		var kind := "dark"
		var icon := ""
		var text := str(option[0])
		if text.begins_with("Revive"):
			kind = "purple"
			icon = "play"
		elif text == "Resume":
			kind = "blue"
			icon = "play"
		elif text == "Restart" or text == "Play Again":
			kind = "warn"
			icon = "restart"
		elif text == "Menu":
			icon = "home"
		var button := Button.new()
		button.text = text.to_upper()
		button.custom_minimum_size = Vector2(0.0, 100.0)
		button.add_theme_font_size_override("font_size", 34)
		UiKit.style_button(button, kind)
		if icon != "":
			UiKit.add_button_icon(button, icon, 40.0, Color.WHITE if kind != "dark" else UiKit.CYAN)
		button.pressed.connect(option[1])
		box.add_child(button)

	panel = root


func _panel_accent(heading: String) -> Color:
	match heading:
		"Paused":
			return Color("4fc3ff")
		"Level Complete!":
			return UiKit.GOLD
	return UiKit.RED


# "Score 12" and "Best 40" become a label-and-value row; other lines are plain centred text.
func _panel_line(text: String) -> Control:
	for key in ["Score ", "Best ", "Coins "]:
		if text.begins_with(key):
			var row := HBoxContainer.new()
			var name_label := Label.new()
			name_label.text = key.strip_edges().to_upper()
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_label.add_theme_font_size_override("font_size", 30)
			name_label.add_theme_color_override("font_color", UiKit.TEXT_DIM)
			row.add_child(name_label)
			var value_label := Label.new()
			value_label.text = text.substr(key.length())
			value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			value_label.add_theme_font_size_override("font_size", 40)
			if key == "Coins ":
				value_label.add_theme_color_override("font_color", UiKit.GOLD)
			row.add_child(value_label)
			return row

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 34)
	if text.ends_with("unlocked!"):
		label.add_theme_color_override("font_color", UiKit.GREEN)
	elif text == "NEW BEST!":
		label.add_theme_color_override("font_color", Color.WHITE)
		var ribbon := UiKit.card(Color("d8452b"), Color("ffb347"), 10, 18.0, 6.0)
		ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ribbon.add_child(label)
		return ribbon
	return label


func _close_panel() -> void:
	if panel:
		panel.queue_free()
		panel = null
