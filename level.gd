extends Node2D

# Shared controller for every mode: camera, HUD, crash / revive / restart flow.
# campaign.gd (levels) and endless.gd (endless mode) extend it.

const SideButtons := preload("res://side_buttons.gd")
const JungleBackground := preload("res://jungle_background.gd")

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

const UI_THEME := preload("res://ui_theme.tres")
const NEON_CYAN := Color("00e5ff")
const NEON_YELLOW := Color("ffd36b")

# Level intro: title, then 3-2-1, then GO.
const INTRO_TITLE_TIME := 1.0
const COUNT_STEP_TIME := 0.7
const HINT_TIME := 3.5

@export var level_number := 1

# Player is left untyped on purpose: it calls revive() / stop() from player.gd.
@onready var player = $Player
@onready var camera: Camera2D = $Player/Camera2D

# Set by campaign.gd; null in endless mode.
var finish_line: Node2D = null
var respawn_point: Vector2
var revive_used := false
var ui: Control
var hud_label: Label
var status_label: Label
var panel: Control


func _ready() -> void:
	add_child(JungleBackground.new())
	respawn_point = player.global_position
	_build_ui()
	player.hit_hazard.connect(_on_player_hit)
	_setup_world()
	_setup_camera()  # after the world, since it needs the finish line's position
	_start_countdown()


func _process(_delta: float) -> void:
	status_label.text = player.status_text()


# Hook: the big title shown before the countdown.
func _intro_title() -> String:
	return "Level %d" % level_number


# Hook: a one-time tutorial hint shown when the run starts. Empty = none.
# Shown once per hint_id (saved in GameData).
func _hint_text() -> String:
	return ""


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
	if hint != "" and not GameData.has_seen_hint(level_number):
		GameData.mark_hint_seen(level_number)
		_show_banner(hint, 0.22, 38, NEON_YELLOW, HINT_TIME)


# Big centred text that pops in and fades out. Returns the tween so callers can await it.
func _flash_text(text: String, hold: float, font_size: int, color: Color) -> Tween:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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


# Hook: called when the crash can't be revived. Default is an instant restart.
func _on_final_crash() -> void:
	get_tree().create_timer(player.death_duration() + RESTART_HOLD).timeout.connect(_restart)


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

	if revive_used:
		_on_final_crash()
	else:
		var title := _crash_title()
		if source == player:  # the player's own burn killed them
			title = title.replace("Crashed!", "Burned!")
		_show_panel(title, [
			["Revive (watch ad)", _on_revive_pressed],
			["Restart", _restart],
			["Menu", _go_to_menu],
		])


func _on_finished() -> void:
	if not player.alive:
		return
	player.stop()
	Sfx.play("finish")
	GameData.mark_level_cleared(level_number)
	_show_panel("Level Complete!", _finish_options())
	Ads.on_level_cleared(level_number)


func _on_revive_pressed() -> void:
	Ads.show_rewarded(_grant_revive)


func _grant_revive() -> void:
	revive_used = true
	_close_panel()
	Sfx.play("revive")
	player.revive(respawn_point)


func _restart() -> void:
	get_tree().reload_current_scene.call_deferred()


func _go_to_menu() -> void:
	get_tree().change_scene_to_file.call_deferred(MENU_SCENE)


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


func _set_hud(text: String) -> void:
	hud_label.text = text


# options: Array of [button_text: String, on_pressed: Callable]
func _show_panel(title: String, options: Array) -> void:
	_close_panel()

	var center := CenterContainer.new()
	ui.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	center.add_child(box)

	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	box.add_child(label)

	for option in options:
		var button := Button.new()
		button.text = option[0]
		button.custom_minimum_size = Vector2(580, 110)
		button.add_theme_font_size_override("font_size", 32)
		button.pressed.connect(option[1])
		box.add_child(button)

	panel = center


func _close_panel() -> void:
	if panel:
		panel.queue_free()
		panel = null
