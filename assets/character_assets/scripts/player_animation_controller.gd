extends CharacterBody2D
## Minimal Godot 4.x animation controller for an AnimatedSprite2D child.
## Expected animation names: idle, walk, run, jump, fall, hurt, death.
## Configure these in SpriteFrames and set looping as described in README.md.

@export var walk_speed: float = 120.0
@export var run_speed: float = 220.0
@export var jump_velocity: float = -320.0
@export var gravity: float = 900.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y += gravity * delta

    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = jump_velocity

    var direction := Input.get_axis("move_left", "move_right")
    var running := Input.is_action_pressed("run")
    var speed := run_speed if running else walk_speed
    velocity.x = direction * speed

    move_and_slide()

    if not is_on_floor():
        if velocity.y < 0.0:
            _play_if_needed("jump")
        else:
            _play_if_needed("fall")
    elif absf(velocity.x) < 1.0:
        _play_if_needed("idle")
    elif running:
        _play_if_needed("run")
    else:
        _play_if_needed("walk")

    if absf(velocity.x) > 1.0:
        animated_sprite.flip_h = velocity.x < 0.0

func _play_if_needed(animation_name: StringName) -> void:
    if animated_sprite.animation != animation_name or not animated_sprite.is_playing():
        animated_sprite.play(animation_name)
