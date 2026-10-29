extends CharacterBody2D

# Emitted when the player dies: touching a "hazard", or burning to death
# (then the source is the player itself).
signal hit_hazard(hazard: Node)

const HAZARD_GROUP := "hazard"
const LANE_WIDTH := 720.0
const REVIVE_INVULNERABLE_TIME := 2.0
const NEON_CYAN := Color("00e5ff")
const FIRE_ORANGE := Color("ff5a1f")
const ICE_BLUE := Color("bfefff")
const SLOW_BLUE := Color("5ec8ff")

# Fire: touching it starts a burn that kills after BURN_TIME, unless ice puts it out.
# Ice: puts out a burn, freezes in place for FREEZE_TIME, then moves at SLOW_SCALE
# speed for SLOW_TIME.
const BURN_TIME := 10.0
const FREEZE_TIME := 1.0
const SLOW_TIME := 5.0
const SLOW_SCALE := 0.8

@export var speed := 400.0
# Sideways speed from the steering buttons.
@export var side_speed := 360.0
# Gap kept between the player's centre and the screen edge (about its radius).
@export var edge_margin := 32.0

var alive := true
var invulnerable := false
var was_holding := false
# True during the level's 3-2-1 intro: no movement, no hazards moving either.
var frozen_for_intro := false

var burn_left := 0.0
var freeze_left := 0.0
var slow_left := 0.0

var _drawn_color := NEON_CYAN
var _dust: CPUParticles2D

@onready var hitbox: Area2D = $HitBox
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	hitbox.body_entered.connect(_on_hitbox_entered)
	hitbox.area_entered.connect(_on_hitbox_entered)
	_dust = _make_dust()
	add_child(_dust)
	_play("idle")


func _physics_process(delta: float) -> void:
	if not alive or frozen_for_intro:
		_dust.emitting = false
		return

	_update_effects(delta)
	if not alive:  # burned to death this frame
		return

	# Controls (autoload) merges touch, mouse and keyboard; see controls.gd.
	var holding := Controls.is_forward()
	if holding != was_holding:
		was_holding = holding
		Sfx.play("start" if holding else "stop")

	if freeze_left > 0.0:
		velocity = Vector2.ZERO  # frozen solid: no forward, no steering
	else:
		var speed_scale := SLOW_SCALE if slow_left > 0.0 else 1.0
		# Forward is up the screen while held; releasing freezes instantly.
		velocity.y = -speed * speed_scale if holding else 0.0
		velocity.x = Controls.steer() * side_speed * speed_scale

	move_and_slide()

	_clamp_to_screen()
	_update_animation(holding)
	_dust.emitting = holding and freeze_left <= 0.0


# Picks the sprite animation from the current state. Death is played by _die().
# Steering sideways uses the side-view walk, even while frozen in place by the brake.
func _update_animation(holding: bool) -> void:
	if burn_left > 0.0:
		_play("hurt")
	elif velocity.x < -1.0:
		_play("walk_left")
	elif velocity.x > 1.0:
		_play("walk_right")
	elif freeze_left > 0.0 or not holding:
		_play("idle")
	elif slow_left > 0.0:
		_play("walk")
	else:
		_play("run")


func _play(animation_name: StringName) -> void:
	if sprite.animation != animation_name or not sprite.is_playing():
		sprite.play(animation_name)


# The camera never moves sideways, so the screen always shows x = 0 to the
# viewport width (720 in this project, whatever the phone's shape). Keep the
# player inside that, and never outside the 720px lane.
func _clamp_to_screen() -> void:
	var screen_width := minf(get_viewport_rect().size.x, LANE_WIDTH)
	global_position.x = clampf(global_position.x, edge_margin, screen_width - edge_margin)


# Freezes the player for good (used when the level is finished).
func stop() -> void:
	alive = false
	velocity = Vector2.ZERO
	_play("idle")


# Puts the player back at `at`, ignoring hazards for a short grace period.
func revive(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	alive = true
	invulnerable = true
	was_holding = false
	_clear_effects()
	_play("idle")

	var blink := create_tween().set_loops()
	blink.tween_property(self, "modulate:a", 0.3, 0.125)
	blink.tween_property(self, "modulate:a", 1.0, 0.125)

	await get_tree().create_timer(REVIVE_INVULNERABLE_TIME).timeout

	blink.kill()
	modulate.a = 1.0
	invulnerable = false
	# A hazard that is already overlapping won't fire "entered" again, so check now.
	for other in hitbox.get_overlapping_bodies() + hitbox.get_overlapping_areas():
		_on_hitbox_entered(other)


# Called by an active fire patch. Starts the burn once; it can't be put out.
func ignite() -> void:
	if not alive or invulnerable or burn_left > 0.0:
		return
	burn_left = BURN_TIME


# Called by an active ice patch. It always puts out a burn; the freeze and slow
# are ignored while already frozen or slowed.
func freeze() -> void:
	if not alive or invulnerable:
		return
	if burn_left > 0.0:
		burn_left = 0.0
		_refresh_color()
	if freeze_left > 0.0 or slow_left > 0.0:
		return
	freeze_left = FREEZE_TIME
	slow_left = SLOW_TIME  # only starts counting down once the freeze ends


# Text for the HUD, e.g. "BURNING 2.3  SLOWED 4.1". Empty when nothing is active.
func status_text() -> String:
	var parts := PackedStringArray()
	if burn_left > 0.0:
		parts.append("BURNING %.1f" % burn_left)
	if freeze_left > 0.0:
		parts.append("FROZEN %.1f" % freeze_left)
	elif slow_left > 0.0:
		parts.append("SLOWED %.1f" % slow_left)
	return "  ".join(parts)


func _update_effects(delta: float) -> void:
	if burn_left > 0.0:
		burn_left = maxf(burn_left - delta, 0.0)
		if burn_left == 0.0:
			_die(self)
			return

	if freeze_left > 0.0:
		freeze_left = maxf(freeze_left - delta, 0.0)
	elif slow_left > 0.0:
		slow_left = maxf(slow_left - delta, 0.0)

	_refresh_color()


func _clear_effects() -> void:
	burn_left = 0.0
	freeze_left = 0.0
	slow_left = 0.0
	_refresh_color()


func _body_color() -> Color:
	if burn_left > 0.0:
		return FIRE_ORANGE
	if freeze_left > 0.0:
		return ICE_BLUE
	if slow_left > 0.0:
		return SLOW_BLUE
	return NEON_CYAN


# Tints the sprite for fire / ice / slow. The neutral colour leaves it untinted.
func _refresh_color() -> void:
	var color := _body_color()
	if color != _drawn_color:
		_drawn_color = color
		sprite.modulate = Color.WHITE if color == NEON_CYAN else color


func _die(source: Node) -> void:
	alive = false
	velocity = Vector2.ZERO
	sprite.modulate = Color.WHITE
	_dust.emitting = false
	_play("death")
	_spawn_burst(FIRE_ORANGE if source == self else NEON_CYAN)
	hit_hazard.emit(source)


# How long the death animation takes, so the level can wait for it before restarting.
func death_duration() -> float:
	var frames := sprite.sprite_frames
	var total := 0.0
	for i in frames.get_frame_count("death"):
		total += frames.get_frame_duration("death", i)
	return total / frames.get_animation_speed("death")


# Small puffs kicked up behind the player while running. Stays in the world, so it trails behind.
func _make_dust() -> CPUParticles2D:
	var dust := CPUParticles2D.new()
	dust.position = Vector2(0.0, 22.0)
	dust.z_index = -1
	dust.local_coords = false
	dust.emitting = false
	dust.amount = 10
	dust.lifetime = 0.45
	dust.direction = Vector2(0.0, 1.0)
	dust.spread = 30.0
	dust.initial_velocity_min = 30.0
	dust.initial_velocity_max = 70.0
	dust.scale_amount_min = 3.0
	dust.scale_amount_max = 6.0
	dust.color = Color(0.85, 0.95, 0.85, 0.35)
	dust.color_ramp = _fade_out_ramp()
	return dust


# One-shot burst where the player died. Added to the level so it outlives the player's state.
func _spawn_burst(color: Color) -> void:
	var burst := CPUParticles2D.new()
	burst.global_position = global_position
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 28
	burst.lifetime = 0.7
	burst.spread = 180.0
	burst.gravity = Vector2.ZERO
	burst.initial_velocity_min = 140.0
	burst.initial_velocity_max = 320.0
	burst.damping_min = 80.0
	burst.damping_max = 140.0
	burst.scale_amount_min = 4.0
	burst.scale_amount_max = 9.0
	burst.color = color
	burst.color_ramp = _fade_out_ramp()
	get_parent().add_child(burst)
	burst.emitting = true
	get_tree().create_timer(burst.lifetime + 0.2).timeout.connect(burst.queue_free)


func _fade_out_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	return ramp


# Hazards hurt on any overlap, whether the player is moving or frozen.
func _on_hitbox_entered(other: Node) -> void:
	if alive and not invulnerable and other.is_in_group(HAZARD_GROUP):
		_die(other)
