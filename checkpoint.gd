extends Area2D

# Emitted the first time the player crosses this line.
signal reached(checkpoint: Node2D)

const OFF_TEXTURE := preload("res://assets/themes/jungle/level_objects/checkpoint_off.png")
const ON_TEXTURE := preload("res://assets/themes/jungle/level_objects/checkpoint_on.png")
const HEIGHT := 64.0

var activated := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body_entered.connect(_on_body_entered)


func _draw() -> void:
	# Lane-wide marker centred on the line; the node sits at x = 0.
	draw_texture_rect(ON_TEXTURE if activated else OFF_TEXTURE, Rect2(0.0, -HEIGHT / 2.0, 720.0, HEIGHT), false)


func _on_body_entered(body: Node2D) -> void:
	if not activated and body.is_in_group("player"):
		activated = true
		queue_redraw()
		# Bright flash across the lane that settles back to normal.
		modulate = Color(2.5, 2.5, 2.5, 1.0)
		create_tween().tween_property(self, "modulate", Color.WHITE, 0.6)
		reached.emit(self)
