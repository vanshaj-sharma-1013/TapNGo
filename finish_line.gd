extends Area2D

# Emitted when the player crosses the finish line.
signal reached

const GATE := preload("res://assets/themes/jungle/level_objects/finish_gate.png")
const GATE_HEIGHT := 120.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body_entered.connect(_on_body_entered)


func _draw() -> void:
	# Lane-wide gate standing on the finish line; the node sits at x = 0.
	draw_texture_rect(GATE, Rect2(0.0, -GATE_HEIGHT, 720.0, GATE_HEIGHT), false)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		reached.emit()
