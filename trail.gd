extends Line2D

# Fading trail behind the player. Points are stored in world space, so the line
# stays where the player has been. It grows while moving and shrinks when frozen.

const MAX_POINTS := 28
# A jump this big (e.g. a revive teleport) clears the trail instead of drawing a streak.
const TELEPORT_DISTANCE := 150.0

@onready var player = get_parent()


func _ready() -> void:
	top_level = true
	clear_points()


func _physics_process(_delta: float) -> void:
	var moving: bool = player.alive and player.velocity != Vector2.ZERO
	if moving:
		var head: Vector2 = player.global_position
		if get_point_count() > 0 and get_point_position(get_point_count() - 1).distance_to(head) > TELEPORT_DISTANCE:
			clear_points()
		add_point(head)

	if get_point_count() > 0 and (not moving or get_point_count() > MAX_POINTS):
		remove_point(0)
