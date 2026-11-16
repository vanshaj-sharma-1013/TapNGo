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
const SAND_TAN := Color("e0b060")
const GLITCH_PINK := Color("ff6bc0")
const BOOST_YELLOW := Color("ffe27a")
const BOOST_PURPLE := Color("b48cff")

const WorldData = preload("res://world_data.gd")
const RunDust := preload("res://run_dust.gd")
const Potions := preload("res://potions.gd")

# Fire: touching it starts a burn that kills after BURN_TIME, unless ice puts it out.
# Ice: puts out a burn, freezes in place for FREEZE_TIME, then moves at SLOW_SCALE
# speed for SLOW_TIME.
const BURN_TIME := 10.0
const FREEZE_TIME := 1.0
const SLOW_TIME := 5.0
const SLOW_SCALE := 0.8

# Quicksand: moves at MIRE_SCALE speed while in it and for MIRE_TIME after.
# Glitch zone: left and right swap for SCRAMBLE_TIME.
# Frost patch: pushes SLIP_DISTANCE px forward or back over SLIP_TIME, at most once
# every SLIP_COOLDOWN seconds.
const MIRE_TIME := 2.0
const MIRE_SCALE := 0.55
const SCRAMBLE_TIME := 2.0
const SLIP_DISTANCE := 120.0
const SLIP_TIME := 0.3
const SLIP_COOLDOWN := 1.5

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
var mire_left := 0.0
var scramble_left := 0.0
var slip_left := 0.0
var slip_velocity := 0.0   # px/s along the lane while slipping; positive is forward
var slip_cooldown := 0.0
# Potion effects: a speed multiplier for a while, and short immunity to fire / ice.
var boost_left := 0.0
var boost_scale := 1.0
var fire_immune_left := 0.0
var ice_immune_left := 0.0

# The current world's movement rules (see WorldData): speed multiplier, sideways
# acceleration (0 = instant) and how long the player slides after letting go (0 = stops).
var speed_mult := 1.0
var steer_accel := 0.0
var stop_slide := 0.0

var _drawn_color := NEON_CYAN
var _dust   # run_dust.gd

@onready var hitbox: Area2D = $HitBox
@onready var sprite: Node2D = $CharacterView  # character_view.gd


func _ready() -> void:
	hitbox.body_entered.connect(_on_hitbox_entered)
	hitbox.area_entered.connect(_on_hitbox_entered)
	_dust = RunDust.new()
	_dust.position = Vector2(0.0, 22.0)
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
		var speed_scale := _speed_scale()
		var forward := speed * speed_mult * speed_scale
		# Forward is up the screen while held. Releasing freezes at once, except in worlds
		# with a stop slide, where the player coasts to a halt.
		if holding or stop_slide <= 0.0:
			velocity.y = -forward if holding else 0.0
		else:
			velocity.y = move_toward(velocity.y, 0.0, speed * speed_mult / stop_slide * delta)

		var steer := -Controls.steer() if scramble_left > 0.0 else Controls.steer()
		var side := steer * side_speed * speed_scale
		# Loose steering (sand) builds up and fades gradually instead of switching at once.
		velocity.x = side if steer_accel <= 0.0 else move_toward(velocity.x, side, steer_accel * delta)

		if slip_left > 0.0:
			velocity.y -= slip_velocity

	move_and_slide()

	_clamp_to_screen()
	# A hazard that switches on under the player (trapdoor, pulse barrier) never "enters".
	for other in hitbox.get_overlapping_areas():
		_on_hitbox_entered(other)
	if not alive:  # died just now: keep the death animation
		return
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
	if not alive or invulnerable or burn_left > 0.0 or fire_immune_left > 0.0:
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
	if ice_immune_left > 0.0 or freeze_left > 0.0 or slow_left > 0.0:
		return
	freeze_left = FREEZE_TIME
	slow_left = SLOW_TIME  # only starts counting down once the freeze ends


# Speed potion: the run speed is multiplied by `scale` for `time` seconds (replaces any earlier one).
func apply_speed_potion(scale: float, time: float) -> void:
	boost_scale = scale
	boost_left = time
	_refresh_color()
	potion_flash(BOOST_YELLOW if scale > 1.0 else BOOST_PURPLE)


# Cooldown potion: puts out a burn. Returns false (and does nothing) if not burning.
func extinguish() -> bool:
	if not alive or burn_left <= 0.0:
		return false
	burn_left = 0.0
	fire_immune_left = Potions.IMMUNE_TIME
	_refresh_color()
	potion_flash(SLOW_BLUE)
	return true


# Burning potion: melts a freeze and the slowdown after it. Returns false if not frozen or slowed.
func thaw() -> bool:
	if not alive or (freeze_left <= 0.0 and slow_left <= 0.0):
		return false
	freeze_left = 0.0
	slow_left = 0.0
	ice_immune_left = Potions.IMMUNE_TIME
	_refresh_color()
	potion_flash(FIRE_ORANGE)
	return true


# A burst of particles and a little pop of the character when a potion is drunk.
func potion_flash(color: Color) -> void:
	_spawn_burst(color)
	var base := sprite.scale
	var pop := create_tween()
	pop.tween_property(sprite, "scale", base * 1.25, 0.1)
	pop.tween_property(sprite, "scale", base, 0.2)


# Called by an active quicksand patch. Slows the player for as long as they stay in it.
func mire() -> void:
	if not alive or invulnerable:
		return
	mire_left = MIRE_TIME


# Called by an active glitch zone. Left and right swap for SCRAMBLE_TIME.
func scramble() -> void:
	if not alive or invulnerable:
		return
	scramble_left = maxf(scramble_left, SCRAMBLE_TIME)


# Called by an active frost patch: a short push forward or back, chosen at random.
func slip() -> void:
	if not alive or invulnerable or slip_cooldown > 0.0:
		return
	slip_cooldown = SLIP_COOLDOWN
	slip_left = SLIP_TIME
	slip_velocity = SLIP_DISTANCE / SLIP_TIME * (1.0 if randf() < 0.5 else -1.0)


# Sets the movement rules of a world (speed, steering feel, stop slide).
func apply_world(world_index: int) -> void:
	var rules := WorldData.world(world_index)
	speed_mult = rules["speed_mult"]
	steer_accel = rules["steer_accel"]
	stop_slide = rules["stop_slide"]


# Text for the HUD, e.g. "BURNING 2.3  SLOWED 4.1". Empty when nothing is active.
func status_text() -> String:
	var parts := PackedStringArray()
	if burn_left > 0.0:
		parts.append("BURNING %.1f" % burn_left)
	if freeze_left > 0.0:
		parts.append("FROZEN %.1f" % freeze_left)
	elif slow_left > 0.0:
		parts.append("SLOWED %.1f" % slow_left)
	if mire_left > 0.0:
		parts.append("MIRED")
	if scramble_left > 0.0:
		parts.append("SCRAMBLED %.1f" % scramble_left)
	if boost_left > 0.0:
		parts.append(("SPEED UP %.1f" if boost_scale > 1.0 else "SLOW DOWN %.1f") % boost_left)
	if fire_immune_left > 0.0:
		parts.append("FIREPROOF %.1f" % fire_immune_left)
	if ice_immune_left > 0.0:
		parts.append("ICEPROOF %.1f" % ice_immune_left)
	return "  ".join(parts)


# Slowest of the active slowdowns.
func _speed_scale() -> float:
	var factor := 1.0
	if slow_left > 0.0:
		factor = SLOW_SCALE
	if mire_left > 0.0:
		factor = minf(factor, MIRE_SCALE)
	if boost_left > 0.0:
		factor *= boost_scale
	return factor


func _update_effects(delta: float) -> void:
	mire_left = maxf(mire_left - delta, 0.0)
	scramble_left = maxf(scramble_left - delta, 0.0)
	slip_left = maxf(slip_left - delta, 0.0)
	slip_cooldown = maxf(slip_cooldown - delta, 0.0)
	boost_left = maxf(boost_left - delta, 0.0)
	fire_immune_left = maxf(fire_immune_left - delta, 0.0)
	ice_immune_left = maxf(ice_immune_left - delta, 0.0)

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
	mire_left = 0.0
	scramble_left = 0.0
	slip_left = 0.0
	slip_cooldown = 0.0
	boost_left = 0.0
	fire_immune_left = 0.0
	ice_immune_left = 0.0
	_refresh_color()


func _body_color() -> Color:
	if burn_left > 0.0:
		return FIRE_ORANGE
	if freeze_left > 0.0:
		return ICE_BLUE
	if slow_left > 0.0:
		return SLOW_BLUE
	if mire_left > 0.0:
		return SAND_TAN
	if scramble_left > 0.0:
		return GLITCH_PINK
	if boost_left > 0.0:
		return BOOST_YELLOW if boost_scale > 1.0 else BOOST_PURPLE
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
	return sprite.death_duration()


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
