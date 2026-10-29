extends Camera2D

# Follows the player up and down only. The camera's x is locked to the middle
# of the lane, so the layout never shifts when the player steers sideways.
# level.gd sets base_offset (where the player sits on screen); shake() adds a
# decaying random wobble on top of it.

var base_offset := Vector2.ZERO

var _strength := 0.0
var _duration := 0.0
var _time_left := 0.0

@onready var target: Node2D = get_parent()


func _ready() -> void:
	# Detach from the player's transform; _follow() places the camera by hand.
	top_level = true
	_follow()


func shake(strength: float, duration: float) -> void:
	_strength = strength
	_duration = duration
	_time_left = duration


# Runs after the player's own physics step (children run after their parent).
func _physics_process(_delta: float) -> void:
	_follow()


func _process(delta: float) -> void:
	_follow()
	if _time_left > 0.0:
		_time_left = maxf(_time_left - delta, 0.0)
		var falloff := _time_left / _duration
		offset = base_offset + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _strength * falloff
	else:
		offset = base_offset


func _follow() -> void:
	global_position = Vector2(get_viewport_rect().size.x / 2.0, target.global_position.y)
